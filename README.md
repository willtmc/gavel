# The Gavel

Company Operating System.

## Setup

1. Install dependencies: `poetry install`
2. Configure environment: Copy `.env.example` to `.env` and fill in secrets.
3. Apply database migrations: `supabase db push`
4. Run the app: `poetry run streamlit run app/app.py` 