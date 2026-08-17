# BEAT 2026 — Supabase Connection Setup

Wires the BEAT submission form to the dedicated **`lpet-marketing`** Supabase project (created 27 Apr 2026).

| Detail | Value |
|---|---|
| Project name | `lpet-marketing` |
| Project ref | `uudwwhlmiradgbhfgnjv` |
| Project URL | `https://uudwwhlmiradgbhfgnjv.supabase.co` |
| Region | us-east-1 (Virginia) |
| Tier | micro ($10/month) |
| Org | la palma y el tucan (Pro) |

This project is **isolated from `craftlab` and `lpt-discovery`** — marketing forms have their own lifecycle and won't affect product or research data.

The migration is additive: creates one new table (`beat_submissions_2026`) plus indexes, policies, and a pipeline view. First migration of this project.

---

## Step 1 — Run the SQL migration

The migration file lives in the **private** centro-control repo:

```
referencias/proyectos/landing-beat-2026/migrations/001_beat_submissions.sql
```

You can run it any of three ways:

### Option A: Supabase MCP (your other terminal)
```
Run /Users/felipesardi/Desktop/DOCS CAFE TOSTADO/AI STRATEGY/lpet-marketing-hub/referencias/proyectos/landing-beat-2026/migrations/001_beat_submissions.sql against project uudwwhlmiradgbhfgnjv
```

### Option B: Supabase Dashboard SQL Editor
1. Open https://supabase.com/dashboard/project/uudwwhlmiradgbhfgnjv/sql
2. Paste the contents of `001_beat_submissions.sql`
3. Click "Run"

### Option C: `supabase` CLI (if linked locally)
```bash
cd ~/Desktop/craftlab-lpet
cp "../DOCS CAFE TOSTADO/AI STRATEGY/lpet-marketing-hub/referencias/proyectos/landing-beat-2026/migrations/001_beat_submissions.sql" supabase/migrations/
supabase db push
```

### Verification
After running, confirm with:
```sql
SELECT * FROM public.beat_submissions_2026 LIMIT 1;
SELECT * FROM public.beat_submissions_pipeline;
```

Both should return without errors (the first will return zero rows; the second returns one row per status).

---

## Step 2 — Get your Supabase URL and anon key

1. Open https://supabase.com/dashboard/project/uudwwhlmiradgbhfgnjv/settings/api
2. Copy these two values:
   - **Project URL** (looks like `https://uudwwhlmiradgbhfgnjv.supabase.co`)
   - **anon / public** API key (the one labeled `anon`, NOT `service_role`)

> The anon key is **public by design**. It's safe to ship in browser JS. The `service_role` key, however, must NEVER be in browser code.

---

## Step 3 — Plug the keys into the landing

Open `index.html`. Find this block near the bottom (around line 1280):

```javascript
const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY_HERE';
```

Replace with the values from Step 2:

```javascript
const SUPABASE_URL = 'https://uudwwhlmiradgbhfgnjv.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ...';  // your anon key
```

Save, commit, push.

---

## Step 4 — Test the form locally

```bash
cd ecommerce/landing-beat-2026
open index.html
```

Click "Submit your video" → fill the form with a test entry → submit.

Then verify in Supabase:
```sql
SELECT id, full_name, email, country, category, status, created_at
FROM public.beat_submissions_2026
ORDER BY created_at DESC
LIMIT 5;
```

You should see your test row.

To delete the test row:
```sql
DELETE FROM public.beat_submissions_2026 WHERE email = 'your-test-email@example.com';
```

---

## Step 5 — Deploy

Push to GitHub. GitHub Pages auto-redeploys from `main`:
```bash
git push origin main
```

Live URL: https://beat.lapalmayeltucan.com/

---

## How it works

```
┌──────────────┐    POST    ┌─────────────────────────┐
│  Browser     │───────────▶│  Supabase REST API      │
│  (anon key)  │            │  (anon role + RLS)      │
└──────────────┘            └────────────┬────────────┘
                                          │ INSERT only
                                          ▼
                            ┌──────────────────────────┐
                            │  beat_submissions_2026   │
                            │  (table)                 │
                            └──────────────────────────┘
                                          ▲
                                          │ SELECT / UPDATE
                            ┌──────────────────────────┐
                            │  Authenticated admins    │
                            │  (felipe@, jeffry@,      │
                            │   elisa@)                │
                            └──────────────────────────┘
```

**Security model:**
- Anonymous users (the public web visitor) can ONLY insert rows — never read them
- Three admin emails can read, update, and triage submissions
- The anon key in browser JS is public by design — it can only do what RLS policies allow

---

## Reviewing submissions (Felipe / Jeffry workflow)

### Quick admin SQL queries

**List all pending submissions:**
```sql
SELECT id, full_name, country, category, video_url, created_at
FROM public.beat_submissions_2026
WHERE status = 'pending'
ORDER BY created_at DESC;
```

**Pipeline overview (one row per status):**
```sql
SELECT * FROM public.beat_submissions_pipeline;
```

**Mark a submission as reviewed:**
```sql
UPDATE public.beat_submissions_2026
SET status = 'reviewed',
    jury_score_technical    = 8.5,
    jury_score_storytelling = 9.0,
    jury_score_communication = 7.5,
    jury_score_impact       = 8.0,
    jury_notes = 'Strong storytelling, technical execution clean.'
WHERE id = 'uuid-here';
```

**Find shortlisted candidates:**
```sql
SELECT
  full_name, country, instagram_handle, video_url,
  (jury_score_technical * 0.30
 + jury_score_storytelling * 0.30
 + jury_score_communication * 0.20
 + jury_score_impact * 0.20) AS weighted_score
FROM public.beat_submissions_2026
WHERE status IN ('reviewed','shortlisted')
ORDER BY weighted_score DESC NULLS LAST;
```

---

## Future enhancements (not done yet)

These are on the roadmap once the form is live and accepting submissions:

1. **HubSpot bridge** — N8N workflow that triggers on new Supabase row, creates a HubSpot contact + custom object `beat_submission`. So Jeffry sees it in his CRM.
2. **Admin dashboard** — Streamlit or simple React page that reads from Supabase with admin auth, visualizes pipeline, lets jury score in-app.
3. **Email confirmation** — Supabase Edge Function that sends "we got your submission" email via SendGrid/Resend after each insert.
4. **Public leaderboard** — Optional public view ranking community-likes per submission, with anonymized names. Drives the "voting bonus" mechanic.

Each of these is a separate sprint — let me know which one you want next.

---

*Last updated: 27 Apr 2026 · Session 31*
*Migration file: `referencias/proyectos/landing-beat-2026/migrations/001_beat_submissions.sql` (centro-control, private)*

---

## ⚠️ Migration 003 — required before the 2026/27 form goes live

The landing was rewritten in August 2026 with new eligibility policies. The form now
sends two fields the table does not have yet:

| Field | Type | Notes |
|---|---|---|
| `sponsor_status` | text | Required in the form. Independence / small-business gate. |
| `consent_content` | boolean | Optional. Permission to publish training and competition content, with credit. |

**Until this migration runs, every submission fails to insert.**

```
referencias/proyectos/landing-beat-2026/migrations/003_new_policies_2026_27.sql
```

Three existing columns changed meaning but not type, so they need no migration:
`national_registration` (now "how many national appearances", required),
`target_competition` (now free text instead of a fixed 2026 dropdown),
and `category` (now only `barista` or `brewers_cup`).
