# Kolor Activ ERP V2 — Go-Live Checklist

## 1. Supabase
- Create one Supabase project.
- Run `supabase_setup.sql` in SQL Editor.
- Confirm tables: `profiles`, `pm_items`, `fg_items`, `stock_transactions`, `production_logs`, `stock_audits`, `approvals`, `audit_logs`, `attachments`, `backup_snapshots`.
- Confirm Storage bucket: `erp-attachments`.
- Enable Realtime for the operational tables.

## 2. Team accounts
Create each employee in Supabase Authentication, then assign their role in `public.profiles`.

Recommended roles:
- `super_admin`: technical owner
- `ho_admin`: HO control / all ERP functions
- `production_manager`: production + production approvals
- `store_manager`: packing/FG + stock approvals
- `employee`: assigned operational entry
- `viewer`: dashboard/reports only

## 3. Environment
Copy `.env.example` to `.env`:

`VITE_SUPABASE_URL=...`

`VITE_SUPABASE_ANON_KEY=...`

Never put a Supabase service-role key in the frontend.

## 4. Local test
```bash
npm install
npm run dev
```
Test with two different user accounts in two browsers.

## 5. Production build
```bash
npm run build
```
Deploy `dist/` to a static web host. The same URL can be used by HO, production and store teams.

## 6. Data safety
The browser keeps a local fallback cache. Signed-in saves write to normalized PostgreSQL tables. A daily application snapshot is stored in `backup_snapshots`. Use Supabase's database backup/PITR capability for disaster recovery where available on your plan.
