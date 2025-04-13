# Development Plan: The Gavel

**Goal:** Build a company operating system named "The Gavel" to replace Podio and Basecamp functionality, starting with deal tracking and project management, incorporating AI (OpenAI `gpt-4o-latest`) for automation, and using a Supabase/Python/Streamlit/Railway stack.

## Phase 1: Foundation & Setup (Completed)

*   Supabase project creation & Google Auth setup.
*   Local Python project structure (Poetry, Streamlit).
*   Core database schema definition and migration (Deals, Projects, Tasks, Subtasks, Checklists).
*   Basic Google Authentication implementation in Streamlit app using `streamlit-oauth`.
*   Git repository setup and initial push to GitHub ([https://github.com/willtmc/gavel](https://github.com/willtmc/gavel)).

## Phase 2: Core Web Interface (Streamlit) - Current Phase

*   **Objective:** Build the essential user interface elements for manually managing core data within the Streamlit application.
*   **Steps:**
    1.  **Deal Management UI:**
        *   Create a page/section in Streamlit to display a list/table of deals fetched from the Supabase `deals` table.
        *   Implement forms (using `st.form` or similar) to create new deals and edit existing deals, interacting with the Supabase API via `supabase-py`.
        *   Include fields corresponding to the `deals` table schema (Name, Client, Description, Value, Stage, Next Step, Assignee).
        *   Add basic filtering/sorting capabilities.
    2.  **Project Management UI:**
        *   Create a page/section to display a list/table of projects from the `projects` table.
        *   Implement forms for creating/editing projects (Name, Description, Status, Dates, Owner, link to Deal).
        *   Display associated tasks for a selected project.
    3.  **Task Management UI:**
        *   Create a view (likely within the Project view) to display tasks associated with a project from the `tasks` table.
        *   Implement forms for creating/editing tasks (Title, Description, Status, Due Date, Assignee, Priority).
    4.  **Subtask & Checklist Integration:**
        *   Within the Task view/edit form, add functionality to view, add, edit, and mark subtasks as complete (interacting with the `subtasks` table).
        *   Develop UI for managing checklist templates (`checklists` and `checklist_items` tables).
        *   Implement functionality to *apply* a checklist template to a Task or Project (this might require an additional "applied\_checklists" table linking templates to specific task/project instances and tracking item completion - *to be designed*).
*   **Technology:** Streamlit, `supabase-py` client.

## Phase 3: Email-to-Deal AI Pipeline

*   **Objective:** Automate deal creation by parsing incoming emails sent to a specific address.
*   **Steps:**
    1.  **Email Provider Setup:** Finalize setup of an email service (e.g., SendGrid) for inbound parsing, including DNS (MX records) configuration for the designated email address (e.g., `deals@gavel.yourdomain.com`). Securely store API keys.
    2.  **Supabase Edge Function Development:**
        *   Use the Supabase CLI to create a new Edge Function (`supabase functions new email-parser`).
        *   Write TypeScript code for the function to:
            *   Receive webhook requests from the email provider.
            *   Verify the webhook source (using a shared secret).
            *   Extract relevant email content (sender, subject, body).
            *   Construct a prompt for OpenAI `gpt-4o-latest` to parse the email body and extract structured deal information (Client Name, Description, potential Value, etc.) in a defined format (e.g., JSON).
            *   Call the OpenAI API (using the `OPENAI_API_KEY`).
            *   Parse the OpenAI response.
            *   Use the Supabase client within the Edge Function (using the `SUPABASE_SERVICE_ROLE_KEY`) to insert a new record into the `deals` table with the extracted data and set the source to 'Email'.
            *   Implement robust error handling and logging (e.g., for OpenAI errors, database errors, parsing failures).
    3.  **Function Deployment & Webhook Configuration:**
        *   Deploy the Edge Function using the Supabase CLI (`supabase functions deploy email-parser`).
        *   Configure the email provider (e.g., SendGrid Inbound Parse) to send POST requests to the deployed Edge Function's secure URL.
*   **Technology:** Supabase Edge Functions (TypeScript/Deno), OpenAI API, Email Provider (e.g., SendGrid).

## Phase 4: Deployment & Initial Testing

*   **Objective:** Deploy the application to a cloud platform and conduct initial user testing.
*   **Steps:**
    1.  **Railway Setup:** Create a new project on Railway.
    2.  **Connect Repository:** Link the GitHub repository (`willtmc/gavel`) to the Railway project.
    3.  **Configure Deployment:** Set up the build and run commands for the Streamlit application (likely involving Poetry).
    4.  **Environment Variables:** Securely configure all necessary environment variables (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `OPENAI_API_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, email webhook secret) in Railway.
    5.  **Deploy:** Trigger the deployment.
    6.  **Update Google OAuth Redirect URI:** Add the deployed application's URL (provided by Railway) to the list of Authorized Redirect URIs in the Google Cloud Console.
    7.  **Testing:** Conduct thorough testing of:
        *   Login/Logout flow on the deployed app.
        *   Manual CRUD operations for Deals, Projects, Tasks.
        *   The Email-to-Deal pipeline by sending test emails.
    8.  **Initial User Rollout:** Onboard the initial group of 9 users for testing and feedback collection.
*   **Technology:** Railway, Git, Google Cloud Console.

## Phase 5: Enhancements & Iteration (Ongoing)

*   **Objective:** Refine existing features and add new capabilities based on user feedback and evolving requirements.
*   **Potential Features (based on initial request):**
    *   **Advanced AI:**
        *   Slack integration for task/deal creation.
        *   Automated follow-ups (potentially requiring background jobs/scheduling).
        *   AI-driven reporting (summaries, progress tracking).
        *   AI assistance for drafting outputs (emails, reports, task descriptions).
    *   **Project Management:**
        *   Refined checklist template system.
        *   Task dependencies.
        *   Calendar views.
        *   Notifications.
    *   **Reporting:** More sophisticated dashboards and custom report generation.
    *   **UI/UX Improvements:** Polish the Streamlit interface based on feedback.
    *   **Scalability & Maintainability:** Refactor code, optimize queries, potentially split Streamlit app into multi-page structure as it grows.

**Next Immediate Step:** Begin **Phase 2: Core Web Interface**, starting with the UI for either Deals, Projects, or Tasks. 