# LearnLynk Technical Assessment - Solution

**Author:** Vividh Labana 
**Email:** vividhlabana32@gmail.com  
**GitHub:** [vividh-labana](https://github.com/vividh-labana)

---

## Tech Stack

- **Database:** Supabase (PostgreSQL)
- **Backend:** Supabase Edge Functions (Deno/TypeScript)
- **Frontend:** Next.js 14 + TypeScript
- **Authentication:** Supabase Auth with JWT

---

## Project Structure

```
learnlynk-tech-test/
├── backend/
│   ├── schema.sql                          # Task 1: Database schema
│   ├── rls_policies.sql                    # Task 2: Row-Level Security
│   └── edge-functions/
│       └── create-task/
│           └── index.ts                    # Task 3: Edge Function
├── frontend/
│   ├── pages/
│   │   └── dashboard/
│   │       └── today.tsx                   # Task 4: Dashboard page
│   ├── lib/
│   │   └── supabaseClient.ts
│   └── package.json
└── README.md                               # Task 5: Stripe Answer
```

---

## Task 1 — Database Schema

**File:** `backend/schema.sql`

Created three tables with proper relationships:

| Table | Purpose |
|-------|---------|
| `leads` | Stores prospective student information |
| `applications` | Application records linked to leads |
| `tasks` | Follow-up tasks linked to applications |

**Features implemented:**
- UUID primary keys with `gen_random_uuid()`
- Foreign key constraints (`applications.lead_id` → `leads.id`, `tasks.application_id` → `applications.id`)
- Check constraint: `tasks.type IN ('call', 'email', 'review')`
- Check constraint: `tasks.due_at >= tasks.created_at`
- Indexes for common queries (tenant_id, owner_id, stage, due_at, status)
- Auto-update triggers for `updated_at` timestamps

---

## Task 2 — Row-Level Security

**File:** `backend/rls_policies.sql`

Implemented RLS policies using `auth.jwt()` for role-based access:

**SELECT Policy:**
- Admins → See all leads in their tenant
- Counselors → See leads they own OR leads assigned to their team

**INSERT Policy:**
- Counselors and Admins can insert leads into their own tenant

**Implementation:**
```sql
CREATE POLICY "leads_select_policy" ON public.leads
FOR SELECT USING (
  tenant_id = (auth.jwt() ->> 'tenant_id')::uuid
  AND (
    (auth.jwt() ->> 'role') = 'admin'
    OR owner_id = (auth.jwt() ->> 'user_id')::uuid
    OR EXISTS (SELECT 1 FROM user_teams ut WHERE ut.user_id = ... AND ut.team_id = leads.team_id)
  )
);
```

---

## Task 3 — Edge Function: create-task

**File:** `backend/edge-functions/create-task/index.ts`

POST endpoint that creates tasks with validation.

**Input:**
```json
{
  "application_id": "uuid",
  "task_type": "call",
  "due_at": "2025-01-01T12:00:00Z"
}
```

**Features:**
- Validates `task_type` is one of: `call`, `email`, `review`
- Validates `due_at` is a future timestamp
- Validates `application_id` exists
- Inserts task using Supabase service role client
- Emits Realtime broadcast event: `task.created`
- Returns `{ success: true, task_id: "..." }`
- Proper error handling: 400 for validation, 500 for server errors

---

## Task 4 — Frontend Dashboard

**File:** `frontend/pages/dashboard/today.tsx`

Next.js page displaying today's tasks.

**Features:**
- Fetches tasks due today where `status ≠ completed`
- Displays: Type, Title, Application ID, Due At, Status
- "Mark Complete" button updates task in Supabase
- Loading state with animated spinner
- Error state with retry button
- Overdue task highlighting
- Responsive table design

---

## Setup & Running Locally

### Prerequisites
- Node.js >= 18.17.0
- Supabase account (free tier)

### Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vividh-labana/learnlynk-tech-test.git
   cd learnlynk-tech-test
   ```

2. **Set up Supabase:**
   - Create a new project at [supabase.com](https://supabase.com)
   - Run `backend/schema.sql` in SQL Editor

3. **Configure frontend:**
   ```bash
   cd frontend
   cp .env.local.example .env.local
   # Edit .env.local with your Supabase URL and anon key
   ```

4. **Install and run:**
   ```bash
   npm install
   npm run dev
   ```

5. **Open:** http://localhost:3000/dashboard/today

---

## Stripe Answer

**Implementing Stripe Checkout for Application Fee:**

1. **Storing payment_request**: When user clicks "Pay Fee", I first insert a `payment_requests` row with `application_id`, `amount`, `currency`, and `status: 'pending'` to track the payment intent before calling Stripe.

2. **Creating Checkout Session**: I call `stripe.checkout.sessions.create()` with line items (fee amount), `success_url`, `cancel_url`, and pass `payment_requests.id` in metadata for webhook correlation. I store the returned `session_id` in the payment_requests row.

3. **Redirect to Stripe**: User is redirected to the Checkout Session URL where they complete payment securely on Stripe's hosted page.

4. **Handling Stripe Webhook**: I configure a `/api/webhooks/stripe` endpoint to receive `checkout.session.completed` events. I verify the webhook signature using `stripe.webhooks.constructEvent(body, sig, secret)` to ensure the request is genuinely from Stripe.

5. **Updating payment status**: On successful webhook, I extract `payment_requests.id` from `session.metadata`, update `payment_requests.status` to `'paid'`, and store `payment_intent_id` and `paid_at` timestamp.

6. **Updating application stage/timeline**: After confirming payment, I update the `applications` table: set `stage` from `'payment_pending'` to `'submitted'`, update `payment_status: 'paid'`, and insert a record in `application_timeline` with event `'fee_paid'` and timestamp to maintain audit history.
