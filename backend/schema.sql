-- LearnLynk Tech Test - Task 1: Database Schema
-- Author: Vividh Laban
-- Description: Schema for leads, applications, and tasks tables

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- LEADS TABLE
-- Stores information about prospective students/applicants
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  owner_id UUID NOT NULL,              -- The counselor who owns this lead
  team_id UUID,                         -- Team assignment for shared access
  email TEXT,
  phone TEXT,
  full_name TEXT,
  stage TEXT NOT NULL DEFAULT 'new',   -- Lead stage: new, contacted, qualified, etc.
  source TEXT,                          -- Lead source: website, referral, etc.
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for leads table (optimized for common query patterns)
CREATE INDEX IF NOT EXISTS idx_leads_tenant_id ON public.leads(tenant_id);
CREATE INDEX IF NOT EXISTS idx_leads_owner_id ON public.leads(owner_id);
CREATE INDEX IF NOT EXISTS idx_leads_stage ON public.leads(stage);
CREATE INDEX IF NOT EXISTS idx_leads_tenant_owner ON public.leads(tenant_id, owner_id);
CREATE INDEX IF NOT EXISTS idx_leads_tenant_stage ON public.leads(tenant_id, stage);
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON public.leads(created_at DESC);

-- =============================================================================
-- APPLICATIONS TABLE
-- Stores application records linked to leads
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  lead_id UUID NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  program_id UUID,                      -- Reference to program being applied to
  intake_id UUID,                       -- Reference to intake/batch
  stage TEXT NOT NULL DEFAULT 'inquiry', -- Application stage
  status TEXT NOT NULL DEFAULT 'open',  -- Application status: open, submitted, accepted, rejected
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for applications table
CREATE INDEX IF NOT EXISTS idx_applications_tenant_id ON public.applications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_applications_lead_id ON public.applications(lead_id);
CREATE INDEX IF NOT EXISTS idx_applications_tenant_lead ON public.applications(tenant_id, lead_id);
CREATE INDEX IF NOT EXISTS idx_applications_stage ON public.applications(stage);
CREATE INDEX IF NOT EXISTS idx_applications_status ON public.applications(status);

-- =============================================================================
-- TASKS TABLE
-- Stores tasks/follow-ups linked to applications
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  application_id UUID NOT NULL REFERENCES public.applications(id) ON DELETE CASCADE,
  title TEXT,
  type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open', -- Task status: open, in_progress, completed
  due_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Constraint: type must be one of: call, email, review
  CONSTRAINT tasks_type_check CHECK (type IN ('call', 'email', 'review')),
  
  -- Constraint: due_at must be >= created_at (can't schedule tasks in the past relative to creation)
  CONSTRAINT tasks_due_at_check CHECK (due_at >= created_at)
);

-- Indexes for tasks table (optimized for "today's tasks" queries)
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_id ON public.tasks(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tasks_due_at ON public.tasks(due_at);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_application_id ON public.tasks(application_id);
CREATE INDEX IF NOT EXISTS idx_tasks_tenant_due_status ON public.tasks(tenant_id, due_at, status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_status ON public.tasks(due_at, status) 
  WHERE status != 'completed'; -- Partial index for active tasks

-- =============================================================================
-- HELPER FUNCTION: Auto-update updated_at timestamp
-- =============================================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers to auto-update updated_at on modifications
DROP TRIGGER IF EXISTS update_leads_updated_at ON public.leads;
CREATE TRIGGER update_leads_updated_at
  BEFORE UPDATE ON public.leads
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_applications_updated_at ON public.applications;
CREATE TRIGGER update_applications_updated_at
  BEFORE UPDATE ON public.applications
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_tasks_updated_at ON public.tasks;
CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
