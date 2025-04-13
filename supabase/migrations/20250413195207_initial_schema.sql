-- Custom Types
CREATE TYPE deal_stage AS ENUM (
    'Lead',
    'Qualification',
    'Needs Analysis',
    'Proposal Sent',
    'Negotiation',
    'Closed Won',
    'Closed Lost',
    'On Hold'
);

CREATE TYPE project_status AS ENUM (
    'Not Started',
    'In Progress',
    'On Hold',
    'Completed',
    'Cancelled'
);

CREATE TYPE task_status AS ENUM (
    'To Do',
    'In Progress',
    'Blocked',
    'In Review',
    'Done'
);


-- Deals Table
CREATE TABLE deals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    name TEXT NOT NULL,
    client_name TEXT,
    description TEXT,
    estimated_value NUMERIC(12, 2), -- Example: 12 total digits, 2 after decimal
    stage deal_stage DEFAULT 'Lead' NOT NULL,
    next_step_date DATE,
    assigned_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Link to Supabase Auth user
    source TEXT -- e.g., 'Email', 'Manual Entry', 'Slack'
);

-- Enable Row Level Security (RLS) for Deals
ALTER TABLE deals ENABLE ROW LEVEL SECURITY;
-- Basic policy: Logged-in users can see/manage their own deals or deals assigned to them. Adjust as needed.
CREATE POLICY "Allow users to manage their assigned deals" ON deals
    FOR ALL
    USING (auth.uid() = assigned_user_id)
    WITH CHECK (auth.uid() = assigned_user_id);
CREATE POLICY "Allow users to see all deals (Read Only)" ON deals -- More open read access, refine later if needed
    FOR SELECT
    USING (auth.role() = 'authenticated');


-- Projects Table
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    status project_status DEFAULT 'Not Started' NOT NULL,
    start_date DATE,
    due_date DATE,
    owner_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    related_deal_id UUID REFERENCES deals(id) ON DELETE SET NULL -- Optional link to a deal
);

-- Enable RLS for Projects
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
-- Basic policy: Logged-in users can manage projects they own.
CREATE POLICY "Allow owners to manage their projects" ON projects
    FOR ALL
    USING (auth.uid() = owner_user_id)
    WITH CHECK (auth.uid() = owner_user_id);
CREATE POLICY "Allow users to see all projects (Read Only)" ON projects -- More open read access
    FOR SELECT
    USING (auth.role() = 'authenticated');


-- Tasks Table
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    status task_status DEFAULT 'To Do' NOT NULL,
    due_date DATE,
    priority INTEGER DEFAULT 0, -- e.g., 0=Normal, 1=High, 2=Urgent
    assigned_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE -- Link to project, cascade delete if project is deleted
);

-- Index for faster lookup by project
CREATE INDEX idx_tasks_project_id ON tasks(project_id);
-- Index for faster lookup by assignee
CREATE INDEX idx_tasks_assigned_user_id ON tasks(assigned_user_id);

-- Enable RLS for Tasks
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
-- Basic policy: Users can manage tasks assigned to them or tasks within projects they own.
CREATE POLICY "Allow users to manage assigned tasks or tasks in owned projects" ON tasks
    FOR ALL
    USING (
        auth.uid() = assigned_user_id OR
        project_id IN (SELECT id FROM projects WHERE owner_user_id = auth.uid())
    )
    WITH CHECK (
        auth.uid() = assigned_user_id OR
        project_id IN (SELECT id FROM projects WHERE owner_user_id = auth.uid())
    );
CREATE POLICY "Allow users to see all tasks (Read Only)" ON tasks -- More open read access
    FOR SELECT
    USING (auth.role() = 'authenticated');


-- Subtasks Table (Simple version, links to Task)
CREATE TABLE subtasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    title TEXT NOT NULL,
    is_completed BOOLEAN DEFAULT false NOT NULL,
    parent_task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE -- Link to parent task
);

-- Index for faster lookup by parent task
CREATE INDEX idx_subtasks_parent_task_id ON subtasks(parent_task_id);

-- Enable RLS for Subtasks
ALTER TABLE subtasks ENABLE ROW LEVEL SECURITY;
-- Policy: Users can manage subtasks if they can manage the parent task.
CREATE POLICY "Allow users to manage subtasks based on parent task access" ON subtasks
    FOR ALL
    USING (parent_task_id IN (SELECT id FROM tasks)) -- Relies on task policy checking access
    WITH CHECK (parent_task_id IN (SELECT id FROM tasks)); -- Relies on task policy checking access


-- Checklists Table (Can be linked to Project or Task potentially, or standalone templates)
-- For now, let's assume they are templates or standalone. Add project/task links if needed later.
CREATE TABLE checklists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    is_template BOOLEAN DEFAULT true NOT NULL -- Identify if it's a reusable template
    -- created_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL -- Optional: track who created it
);

-- Enable RLS for Checklists
ALTER TABLE checklists ENABLE ROW LEVEL SECURITY;
-- Basic policy: Logged-in users can view/use templates. Could restrict creation later.
CREATE POLICY "Allow authenticated users to manage checklists" ON checklists
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');


-- Checklist Items Table (Items belonging to a checklist)
CREATE TABLE checklist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    title TEXT NOT NULL,
    item_order INTEGER DEFAULT 0, -- For ordering within the checklist
    checklist_id UUID NOT NULL REFERENCES checklists(id) ON DELETE CASCADE -- Link to checklist
    -- is_completed BOOLEAN DEFAULT false NOT NULL -- Note: Completion state might belong to an *instance* of a checklist applied to a task/project, not the template item itself. We can add an "AppliedChecklist" concept later if needed.
);

-- Index for faster lookup by checklist
CREATE INDEX idx_checklist_items_checklist_id ON checklist_items(checklist_id);

-- Enable RLS for Checklist Items
ALTER TABLE checklist_items ENABLE ROW LEVEL SECURITY;
-- Policy: Users can manage items if they can manage the parent checklist.
CREATE POLICY "Allow users to manage items based on parent checklist access" ON checklist_items
    FOR ALL
    USING (checklist_id IN (SELECT id FROM checklists))
    WITH CHECK (checklist_id IN (SELECT id FROM checklists));

-- Function to update 'updated_at' column automatically
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for all tables to auto-update 'updated_at'
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON deals
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON projects
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON subtasks
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON checklists
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();

-- Note: ChecklistItems might not need updated_at if they are just template items. Added trigger anyway for consistency.
CREATE TRIGGER set_timestamp
BEFORE UPDATE ON checklist_items
FOR EACH ROW
EXECUTE FUNCTION trigger_set_timestamp();
