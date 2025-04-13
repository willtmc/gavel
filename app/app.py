import streamlit as st
import os
from supabase import create_client, Client, PostgrestAPIError, AuthApiError
from dotenv import load_dotenv
import asyncio # Import asyncio for streamlit_oauth
from streamlit_oauth import OAuth2Component # Import the component
import base64 # Add base64 import
import json # Add json import

# Load environment variables
load_dotenv()

# --- Configuration --- #
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_ANON_KEY")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")
GOOGLE_CLIENT_SECRET = os.getenv("GOOGLE_CLIENT_SECRET")
# This is the URL Supabase provides for the Google Auth callback.
# It MUST match EXACTLY what you configured in Google Cloud Console.
# You previously shared: https://fnqckovbtrgccnxywlnn.supabase.co/auth/v1/callback
# Let's derive the authorization and token URLs from standard Google endpoints.
AUTHORIZE_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
REVOKE_ENDPOINT = "https://oauth2.googleapis.com/revoke"
# Scopes determine what permissions we ask for
SCOPES = ["openid", "email", "profile"]
REDIRECT_URI = "http://localhost:8501" # Where Google redirects after auth

# --- Error Checking --- #
if not all([SUPABASE_URL, SUPABASE_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET]):
    st.error("Missing required environment variables (Supabase URL/Key, Google Client ID/Secret).")
    st.stop()

# --- Initialize Supabase Client --- #
try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
except Exception as e:
    st.error(f"Error initializing Supabase client: {e}")
    st.stop()

# --- Initialize OAuth2 Component --- #
oauth2 = OAuth2Component(
    client_id=GOOGLE_CLIENT_ID,
    client_secret=GOOGLE_CLIENT_SECRET,
    authorize_endpoint=AUTHORIZE_ENDPOINT,
    token_endpoint=TOKEN_ENDPOINT,
    refresh_token_endpoint=TOKEN_ENDPOINT, # Google uses the same endpoint for refresh
)

st.set_page_config(page_title="The Gavel", layout="wide")
st.title("The Gavel ⚖️")

def handle_logout(token):
    """Clears session state (token revocation removed)."""
    # Token revocation removed as endpoint is not configured
    # oauth2.revoke_token(token=token['access_token'])
    # Clear streamlit session state
    st.session_state['user_info'] = None
    st.session_state['token'] = None
    # Optionally sign out of Supabase if session was set
    # try:
    #     supabase.auth.sign_out()
    # except AuthApiError as e:
    #     st.warning(f"Supabase sign-out error: {e.message}")
    st.rerun()

def decode_id_token_payload(id_token: str) -> dict | None:
    """Decodes the payload from a Google ID token JWT (without verification)."""
    try:
        # JWT is header.payload.signature
        payload_segment = id_token.split('.')[1]
        # Fix Base64 padding
        payload_segment += '=='
        # Decode Base64 (URL-safe variant)
        payload_bytes = base64.urlsafe_b64decode(payload_segment)
        # Decode bytes to UTF-8 string and parse JSON
        payload = json.loads(payload_bytes.decode('utf-8'))
        return payload
    except Exception as e:
        st.error(f"Error decoding ID token payload: {e}")
        return None

def main():
    # Check if user info is already in session state
    if 'user_info' not in st.session_state:
        st.session_state['user_info'] = None
    if 'token' not in st.session_state:
        st.session_state['token'] = None

    # If not logged in, show the login button
    if not st.session_state['user_info']:
        st.header("Login Required")
        st.write("Please login using your Google account to access The Gavel.")

        # Run the OAuth component
        # This function returns user info if login is successful, None otherwise
        # It handles the button display and the redirect/callback flow.
        result = oauth2.authorize_button(
            redirect_uri=REDIRECT_URI,
            name="Login with Google",
            icon="https://www.google.com.tw/favicon.ico", # Optional icon
            scope=" ".join(SCOPES),
            use_container_width=True
        )

        if result:
            token_data = result.get('token')
            st.session_state['token'] = token_data

            if token_data and 'id_token' in token_data:
                id_token = token_data['id_token']
                # Decode the payload from the id_token
                decoded_payload = decode_id_token_payload(id_token)

                if decoded_payload and decoded_payload.get('email'):
                    # Extract user info from the decoded payload
                    st.session_state['user_info'] = {
                        'email': decoded_payload.get('email'),
                        'name': decoded_payload.get('name'),
                        'picture': decoded_payload.get('picture')
                        # Add other relevant fields if needed, e.g., 'sub' for user ID
                    }
                    st.rerun()
                else:
                    st.error("Login successful, but could not decode user information from ID token or email is missing.")
                    st.write("Decoded Payload:")
                    st.json(decoded_payload or {})
                    st.write("Raw Token Data:")
                    st.json(token_data)
            else:
                st.error("Login successful, but ID token not found in the response.")
                st.write("Received data:")
                st.json(result)

    # If logged in, show the main app
    else:
        user_info = st.session_state['user_info']
        token = st.session_state['token']

        st.sidebar.success(f"Logged in as {user_info['email']}")
        if user_info.get('picture'):
            st.sidebar.image(user_info['picture'])
        st.sidebar.button("Logout", on_click=handle_logout, args=(token,))

        # --- Main App Interface --- #
        st.header("Dashboard")
        st.write(f"Welcome {user_info.get('name', 'User')}!")
        # TODO: Add Deal Tracking, Project Management sections
        # Example: Display user info from Google
        st.write("User Info:", user_info)

if __name__ == "__main__":
    main() 