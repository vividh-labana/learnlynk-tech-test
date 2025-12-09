-- LearnLynk Tech Test - Task 2: Row-Level Security Policies
-- Author: Vividh Laban
-- Description: RLS policies for leads table based on user roles

-- =============================================================================
-- ASSUMPTIONS:
-- 1. JWT contains: user_id, role, tenant_id (accessible via request.jwt.claims)
-- 2. Roles: 'counselor', 'admin'
-- 3. Tables exist: users, teams, user_teams (for team membership lookup)
-- =============================================================================

-- Helper function to extract JWT claims safely
CREATE OR REPLACE FUNCTION public.get_jwt_claim(claim TEXT)
RETURNS TEXT AS $$
BEGIN
  RETURN COALESCE(
    current_setting('request.jwt.claims', true)::jsonb ->> claim,
    NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's tenant_id from JWT
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN (public.get_jwt_claim('tenant_id'))::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's id from JWT
CREATE OR REPLACE FUNCTION public.get_current_user_id()
RETURNS UUID AS $$
BEGIN
  RETURN (public.get_jwt_claim('user_id'))::UUID;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to get current user's role from JWT
CREATE OR REPLACE FUNCTION public.get_current_role()
RETURNS TEXT AS $$
BEGIN
  RETURN public.get_jwt_claim('role');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Helper function to check if user belongs to a specific team
CREATE OR REPLACE FUNCTION public.user_belongs_to_team(check_team_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.user_teams ut
    WHERE ut.user_id = public.get_current_user_id()
      AND ut.team_id = check_team_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- ENABLE RLS ON LEADS TABLE
-- =============================================================================
ALTER TABLE public.leads ENABLE ROW LEVEL SECURITY;

-- Force RLS for table owners too (important for security)
ALTER TABLE public.leads FORCE ROW LEVEL SECURITY;

-- =============================================================================
-- SELECT POLICY: Who can view leads?
-- - Admins: Can see ALL leads in their tenant
-- - Counselors: Can see leads they OWN or leads assigned to their TEAMS
-- =============================================================================
DROP POLICY IF EXISTS "leads_select_policy" ON public.leads;

CREATE POLICY "leads_select_policy"
ON public.leads
FOR SELECT
USING (
  -- Must be in the same tenant
  tenant_id = public.get_current_tenant_id()
  AND (
    -- ADMIN: Can see all leads in their tenant
    public.get_current_role() = 'admin'
    OR
    -- COUNSELOR: Can see leads they own
    owner_id = public.get_current_user_id()
    OR
    -- COUNSELOR: Can see leads assigned to any team they belong to
    (
      public.get_current_role() = 'counselor'
      AND team_id IS NOT NULL
      AND public.user_belongs_to_team(team_id)
    )
  )
);

-- =============================================================================
-- INSERT POLICY: Who can create leads?
-- - Both counselors and admins can insert leads under their tenant
-- - tenant_id must match the user's tenant
-- =============================================================================
DROP POLICY IF EXISTS "leads_insert_policy" ON public.leads;

CREATE POLICY "leads_insert_policy"
ON public.leads
FOR INSERT
WITH CHECK (
  -- Must insert into their own tenant
  tenant_id = public.get_current_tenant_id()
  AND (
    -- Must be either admin or counselor
    public.get_current_role() IN ('admin', 'counselor')
  )
);

-- =============================================================================
-- UPDATE POLICY: Who can update leads?
-- - Admins: Can update any lead in their tenant
-- - Counselors: Can only update leads they own
-- =============================================================================
DROP POLICY IF EXISTS "leads_update_policy" ON public.leads;

CREATE POLICY "leads_update_policy"
ON public.leads
FOR UPDATE
USING (
  tenant_id = public.get_current_tenant_id()
  AND (
    public.get_current_role() = 'admin'
    OR owner_id = public.get_current_user_id()
  )
)
WITH CHECK (
  -- Cannot change tenant_id during update
  tenant_id = public.get_current_tenant_id()
);

-- =============================================================================
-- DELETE POLICY: Who can delete leads?
-- - Only admins can delete leads in their tenant
-- =============================================================================
DROP POLICY IF EXISTS "leads_delete_policy" ON public.leads;

CREATE POLICY "leads_delete_policy"
ON public.leads
FOR DELETE
USING (
  tenant_id = public.get_current_tenant_id()
  AND public.get_current_role() = 'admin'
);

-- =============================================================================
-- OPTIONAL: Enable RLS on applications and tasks tables too
-- (Following similar patterns for consistency)
-- =============================================================================

-- Applications RLS
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications FORCE ROW LEVEL SECURITY;

CREATE POLICY "applications_tenant_isolation"
ON public.applications
FOR ALL
USING (tenant_id = public.get_current_tenant_id())
WITH CHECK (tenant_id = public.get_current_tenant_id());

-- Tasks RLS
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks FORCE ROW LEVEL SECURITY;

CREATE POLICY "tasks_tenant_isolation"
ON public.tasks
FOR ALL
USING (tenant_id = public.get_current_tenant_id())
WITH CHECK (tenant_id = public.get_current_tenant_id());
