# Kolor Activ ERP — React + TypeScript + PostgreSQL

This version upgrades the earlier HTML ERP into a remote multi-user architecture.

## Architecture
- React + TypeScript + Vite frontend
- Supabase Auth for individual user accounts
- PostgreSQL normalized tables for PM, FG, transactions, production, audits and approvals
- Row Level Security (RLS) and role/permission matrix
- Supabase Realtime for live team updates
- Supabase Storage for private photos/documents
- Audit trail for sensitive actions
- Approval workflow table and approval screen
- Daily application-level backup snapshots in PostgreSQL
- CSV/print reporting and responsive PWA UI

## Setup
1. Create a Supabase project.
2. Open SQL Editor and run `supabase_setup.sql` completely.
3. Create team accounts in Supabase Authentication.
4. After each account is created, update its row in `public.profiles` and assign one of:
   `super_admin`, `ho_admin`, `production_manager`, `store_manager`, `employee`, `viewer`.
5. Copy `.env.example` to `.env` and fill the Supabase URL and anon key.
6. Run:
   ```bash
   npm install
   npm run dev
   ```
7. For production:
   ```bash
   npm run build
   ```
   Deploy the generated `dist` folder to a static host.

## Important security model
The browser never receives a service-role key. The app uses the Supabase anon key + Auth session. PostgreSQL RLS controls access. Keep the Supabase service-role key out of the frontend.

## Backup
The app creates a daily application snapshot in `backup_snapshots` when a signed-in user saves. Supabase's own database backup/point-in-time features should also be enabled according to the plan you use.

## Legacy files
`legacy-production.html` and `legacy-store-host.html` are retained as references while the React application is migrated.
