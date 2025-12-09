-- LearnLynk Tech Test - Task 2: Row-Level Security Policies
-- Author: Vividh Laban
-- Description: RLS policies for leads table based on user roles

-- =============================================================================
-- ASSUMPTIONS:
-- 1. JWT contains: user_id, role, tenant_id (accessible via auth.jwt())
-- 2. Roles: 'counselor', 'admin'
-- 3. Tables exist: users, teams, user_teams (for team membership lookup)
-- =============================================================================

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
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    -- ADMIN: Can see all leads in their tenant
    (auth.jwt() ->> 'role') = 'admin'
    OR
    -- COUNSELOR: Can see leads they own (owner_id matches user_id from JWT)
    owner_id = (auth.jwt() ->> 'user_id')::uuid
    OR
    -- COUNSELOR: Can see leads assigned to any team they belong to
    (
      (auth.jwt() ->> 'role') = 'counselor'
      AND team_id IS NOT NULL
      AND EXISTS (
        SELECT 1 
        FROM public.user_teams ut
        WHERE ut.user_id = (auth.jwt() ->> 'user_id')::uuid
          AND ut.team_id = leads.team_id
      )
    )
  )
);

-- =============================================================================
-- INSERT POLICY: Who can create leads?
-- - Both counselors and admins can insert leads under their tenant
-- - tenant_id must match the user's tenant from JWT
-- =============================================================================
DROP POLICY IF EXISTS "leads_insert_policy" ON public.leads;

CREATE POLICY "leads_insert_policy"
ON public.leads
FOR INSERT
WITH CHECK (
  -- Must insert into their own tenant
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    -- Must be either admin or counselor
    (auth.jwt() ->> 'role') IN ('admin', 'counselor')
  )
);

-- =============================================================================
-- OPTIONAL: UPDATE POLICY
-- - Admins: Can update any lead in their tenant
-- - Counselors: Can only update leads they own
-- =============================================================================
DROP POLICY IF EXISTS "leads_update_policy" ON public.leads;

CREATE POLICY "leads_update_policy"
ON public.leads
FOR UPDATE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    (auth.jwt() ->> 'role') = 'admin'
    OR owner_id = (auth.jwt() ->> 'user_id')::uuid
  )
)
WITH CHECK (
  -- Cannot change tenant_id during update
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
);

-- =============================================================================
-- OPTIONAL: DELETE POLICY
-- - Only admins can delete leads in their tenant
-- =============================================================================
DROP POLICY IF EXISTS "leads_delete_policy" ON public.leads;

CREATE POLICY "leads_delete_policy"
ON public.leads
FOR DELETE
USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (auth.jwt() ->> 'role') = 'admin'
);

-- =============================================================================
-- OPTIONAL: Enable RLS on applications and tasks tables too
-- =============================================================================
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications FORCE ROW LEVEL SECURITY;

CREATE POLICY "applications_tenant_isolation"
ON public.applications
FOR ALL
USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid)
WITH CHECK (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks FORCE ROW LEVEL SECURITY;

CREATE POLICY "tasks_tenant_isolation"
ON public.tasks
FOR ALL
USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid)
WITH CHECK (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);
