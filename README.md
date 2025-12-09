# LearnLynk – Technical Assessment 

Thanks for taking the time to complete this assessment. The goal is to understand how you think about problems and how you structure real project work. This is a small, self-contained exercise that should take around **2–3 hours**. It’s completely fine if you don’t finish everything—just note any assumptions or TODOs.

We use:

- **Supabase Postgres**
- **Supabase Edge Functions (TypeScript)**
- **Next.js + TypeScript**

You may use your own free Supabase project.

---

## Overview

There are four technical tasks:

1. Database schema — `backend/schema.sql`  
2. RLS policies — `backend/rls_policies.sql`  
3. Edge Function — `backend/edge-functions/create-task/index.ts`  
4. Next.js page — `frontend/pages/dashboard/today.tsx`  

There is also a short written question about Stripe in this README.

Feel free to use Supabase/PostgreSQL docs, or any resource you normally use.

---

## Task 1 — Database Schema

File: `backend/schema.sql`

Create the following tables:

- `leads`  
- `applications`  
- `tasks`  

Each table should include standard fields:

```sql
id uuid primary key default gen_random_uuid(),
tenant_id uuid not null,
created_at timestamptz default now(),
updated_at timestamptz default now()
```

Additional requirements:

- `applications.lead_id` → FK to `leads.id`  
- `tasks.application_id` → FK to `applications.id`  
- `tasks.type` should only allow: `call`, `email`, `review`  
- `tasks.due_at >= tasks.created_at`  
- Add reasonable indexes for typical queries:  
  - Leads: `tenant_id`, `owner_id`, `stage`  
  - Applications: `tenant_id`, `lead_id`  
  - Tasks: `tenant_id`, `due_at`, `status`  

---

## Task 2 — Row-Level Security

File: `backend/rls_policies.sql`

We want:

- Counselors can see:
  - Leads they own, or  
  - Leads assigned to any team they belong to  
- Admins can see all leads belonging to their tenant

Assume the existence of:

```
users(id, tenant_id, role)
teams(id, tenant_id)
user_teams(user_id, team_id)
```

JWT contains:

- `user_id`
- `role`
- `tenant_id`

Tasks:

1. Enable RLS on `leads`  
2. Write a **SELECT** policy enforcing the rules above  
3. Write an **INSERT** policy that allows counselors/admins to add leads under their tenant  

---

## Task 3 — Edge Function: create-task

File: `backend/edge-functions/create-task/index.ts`

Write a simple POST endpoint that:

### Input:
```json
{
  "application_id": "uuid",
  "task_type": "call",
  "due_at": "2025-01-01T12:00:00Z"
}
```

### Requirements:
- Validate:
  - `task_type` is `call`, `email`, or `review`
  - `due_at` is a valid *future* timestamp  
- Insert a row into `tasks` using the service role key  
- Return:

```json
{ "success": true, "task_id": "..." }
```

On validation error → return **400**  
On internal errors → return **500**

---

## Task 4 — Frontend Page: `/dashboard/today`

File: `frontend/pages/dashboard/today.tsx`

Build a small page that:

- Fetches tasks due **today** (status ≠ completed)  
- Uses the provided Supabase client  
- Displays:  
  - type  
  - application_id  
  - due_at  
  - status  
- Adds a “Mark Complete” button that updates the task in Supabase  

---

## Task 5 — Stripe Checkout (Written Answer)

Add a section titled:

```
## Stripe Answer
```

Write **8–12 lines** describing how you would implement a Stripe Checkout flow for an application fee, including:

- When you insert a `payment_requests` row  
- When you call Stripe  
- What you store from the checkout session  
- How you handle webhooks  
- How you update the application after payment succeeds  

---

## Submission

1. Push your work to a public GitHub repo.  
2. Add your Stripe answer at the bottom of this file.  
3. Share the link.

Good luck.

---

## Stripe Answer

**Implementing Stripe Checkout for Application Fee:**

1. **Storing payment_request**: When user clicks "Pay Fee", I first insert a `payment_requests` row with `application_id`, `amount`, `currency`, and `status: 'pending'` to track the payment intent before calling Stripe.

2. **Creating Checkout Session**: I call `stripe.checkout.sessions.create()` with line items (fee amount), `success_url`, `cancel_url`, and pass `payment_requests.id` in metadata for webhook correlation. I store the returned `session_id` in the payment_requests row.

3. **Redirect to Stripe**: User is redirected to the Checkout Session URL where they complete payment securely on Stripe's hosted page.

4. **Handling Stripe Webhook**: I configure a `/api/webhooks/stripe` endpoint to receive `checkout.session.completed` events. I verify the webhook signature using `stripe.webhooks.constructEvent(body, sig, secret)` to ensure the request is genuinely from Stripe.

5. **Updating payment status**: On successful webhook, I extract `payment_requests.id` from `session.metadata`, update `payment_requests.status` to `'paid'`, and store `payment_intent_id` and `paid_at` timestamp.

6. **Updating application stage/timeline**: After confirming payment, I update the `applications` table: set `stage` from `'payment_pending'` to `'submitted'`, update `payment_status: 'paid'`, and insert a record in `application_timeline` with event `'fee_paid'` and timestamp to maintain audit history.

---

## Notes & Assumptions

### Task 1 - Database Schema
- Added `team_id` to leads table for team-based access control
- Created auto-update triggers for `updated_at` timestamps
- Added partial index on tasks for active (non-completed) tasks to optimize dashboard queries

### Task 2 - RLS Policies
- Created helper functions to extract JWT claims safely with null handling
- Added UPDATE and DELETE policies beyond the required SELECT/INSERT for completeness
- Applied basic tenant isolation RLS to applications and tasks tables as well

### Task 3 - Edge Function
- Validates application exists before creating task (prevents orphan tasks)
- Inherits `tenant_id` from the parent application automatically
- Added CORS headers for browser-based API calls
- Returns detailed validation errors for better debugging

### Task 4 - Frontend Dashboard
- Uses date range filtering (start/end of today) for accurate "today" queries
- Optimistic UI update on task completion (removes from list immediately)
- Added visual indicators: task type badges, overdue highlighting
- Included refresh button and loading/error states for better UX

### Technologies Used
- PostgreSQL with Supabase extensions
- Supabase Edge Functions (Deno runtime)
- Next.js with TypeScript
- Supabase JS Client v2

---

**Author:** Vividh Laban  
**Email:** vividhlabana32@gmail.com  
**GitHub:** [vividh-labana](https://github.com/vividh-labana)
