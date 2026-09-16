# Kolor Activ — Three Separate Remote Apps

This package deploys three independent Vercel applications using one Supabase backend:

- `apps/sales` — Sales team only (`VITE_APP_MODE=sales`)
- `apps/store` — Store / inventory only (`VITE_APP_MODE=store`)
- `apps/production` — Production only (`VITE_APP_MODE=production`)

All three share Supabase authentication, PostgreSQL, RLS, audit and realtime infrastructure, while each Vercel project has its own URL and environment variables.

Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in each Vercel project. Never put a service-role key in the browser app.
