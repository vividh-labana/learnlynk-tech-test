-- LearnLynk Test Data - Run this after schema.sql
-- This creates sample data for testing the dashboard

-- Create a test tenant
INSERT INTO public.leads (id, tenant_id, owner_id, full_name, email, stage)
VALUES 
  ('11111111-1111-1111-1111-111111111111', 
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'John Doe', 'john@example.com', 'new'),
  ('22222222-2222-2222-2222-222222222222',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'Jane Smith', 'jane@example.com', 'contacted');

-- Create test applications
INSERT INTO public.applications (id, tenant_id, lead_id, stage, status)
VALUES 
  ('33333333-3333-3333-3333-333333333333',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '11111111-1111-1111-1111-111111111111',
   'inquiry', 'open'),
  ('44444444-4444-4444-4444-444444444444',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '22222222-2222-2222-2222-222222222222',
   'submitted', 'open');

-- Create test tasks due TODAY (change date if needed)
INSERT INTO public.tasks (tenant_id, application_id, title, type, status, due_at)
VALUES 
  -- Tasks due today (future times)
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '33333333-3333-3333-3333-333333333333',
   'Follow up call with John',
   'call', 'open', 
   (CURRENT_DATE + INTERVAL '10 hours')::timestamptz),
  
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '33333333-3333-3333-3333-333333333333',
   'Send application documents',
   'email', 'open',
   (CURRENT_DATE + INTERVAL '14 hours')::timestamptz),
  
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '44444444-4444-4444-4444-444444444444',
   'Review Jane application',
   'review', 'open',
   (CURRENT_DATE + INTERVAL '16 hours')::timestamptz);

-- Overdue task (needs explicit created_at to satisfy constraint: due_at >= created_at)
INSERT INTO public.tasks (tenant_id, application_id, title, type, status, due_at, created_at, updated_at)
VALUES 
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   '44444444-4444-4444-4444-444444444444',
   'Urgent: Missing documents',
   'call', 'open',
   (CURRENT_DATE + INTERVAL '1 hour')::timestamptz,      -- due_at: 1 hour from start of today (likely past)
   (CURRENT_DATE - INTERVAL '1 day')::timestamptz,       -- created_at: yesterday
   (CURRENT_DATE - INTERVAL '1 day')::timestamptz);

-- Verify data
SELECT 'Tasks created:' as info, count(*) as count FROM public.tasks;

