# Kolor Activ ERP — Vercel Deployment Package

## 1. Supabase
1. Open the Supabase project used for Kolor Activ ERP.
2. Run `supabase_setup.sql` in SQL Editor.
3. Confirm the required tables, Storage bucket `erp-attachments`, and Realtime are configured as described in `DEPLOYMENT_CHECKLIST.md`.
4. Create the Host/Admin account in Supabase Authentication and assign the appropriate role in `public.profiles`.

## 2. Vercel
Import this folder/repository into Vercel.
- Framework: Vite
- Build Command: `npm run build`
- Output Directory: `dist`

Add these Environment Variables in Vercel for Production (and Preview if desired):
- `VITE_SUPABASE_URL` = your Supabase project URL
- `VITE_SUPABASE_ANON_KEY` = your Supabase anon/publishable key

Never add the Supabase `service_role` key to Vercel frontend environment variables.

## 3. SPA routing
`vercel.json` rewrites all application routes to `index.html`, so direct links such as `/production`, `/reports`, and `/settings` work after deployment.

## 4. Production verification
After deployment, test:
- Host/Admin login
- Employee login
- Role-based navigation
- PostgreSQL save/load
- Realtime update
- Approvals
- Audit Trail
- Attachments
- Reports/export
- Sign out and session persistence

## Important
This package is deployment-ready, but the actual public deployment requires the user's authenticated Vercel/Supabase project and their public Supabase URL/key. Do not commit `.env` or any service-role secret.
