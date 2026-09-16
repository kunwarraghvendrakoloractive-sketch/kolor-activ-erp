-- Compatibility patch: retain existing Remote Sales schema while restoring legacy ERP tables.
create extension if not exists pgcrypto;

create table if not exists public.erp_permissions (
  id uuid primary key default gen_random_uuid(), role text not null, permission text not null,
  unique(role, permission)
);
create table if not exists public.pm_items (
  id text primary key, code text, name text not null, shade_name text, shade_code text,
  uom text not null default 'PCS', stock numeric not null default 0, min_stock numeric not null default 0,
  max_stock numeric not null default 0, location text, active boolean not null default true,
  created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.fg_items (
  id text primary key, code text, name text not null, shade_name text, shade_code text,
  uom text not null default 'PCS', batch text not null, qty numeric not null default 0,
  mfg_date date, expiry_date date, location text, active boolean not null default true,
  created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.stock_transactions (
  id text primary key, doc_no text, txn_date date not null default current_date, txn_type text not null,
  module text not null, code text, name text, batch text, qty_in numeric not null default 0,
  qty_out numeric not null default 0, department text, remarks text,
  status text not null default 'approved' check (status in ('draft','pending','approved','rejected','cancelled')),
  created_by uuid references auth.users(id), approved_by uuid references auth.users(id), approved_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.production_logs (
  id text primary key, log_date date not null default current_date, line text not null, shift text,
  product text, batch text, good_qty numeric not null default 0, rejected_qty numeric not null default 0, worker text,
  status text not null default 'approved' check (status in ('draft','pending','approved','rejected')),
  created_by uuid references auth.users(id), approved_by uuid references auth.users(id), approved_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.stock_audits (
  id text primary key, audit_date timestamptz not null default now(), module text not null, item text not null,
  batch text, system_qty numeric not null default 0, physical_qty numeric not null default 0,
  variance numeric generated always as (physical_qty-system_qty) stored, remarks text,
  created_by uuid references auth.users(id), approved_by uuid references auth.users(id),
  status text not null default 'pending' check (status in ('pending','approved','rejected'))
);
create table if not exists public.approvals (
  id uuid primary key default gen_random_uuid(), entity_type text not null, entity_id text not null,
  action text not null default 'approve', status text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_by uuid references auth.users(id), decided_by uuid references auth.users(id), requested_at timestamptz not null default now(), decided_at timestamptz, remarks text
);
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key, user_id uuid references auth.users(id), action text not null,
  entity_type text, entity_id text, old_data jsonb, new_data jsonb, ip_hint text, created_at timestamptz not null default now()
);
create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(), entity_type text not null, entity_id text not null, file_name text not null,
  storage_path text not null unique, mime_type text, size_bytes bigint, uploaded_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.backup_snapshots (
  id uuid primary key default gen_random_uuid(), snapshot_date date not null default current_date,
  created_by uuid references auth.users(id), payload jsonb not null, created_at timestamptz not null default now()
);

insert into public.erp_permissions(role,permission) values
('super_admin','*'),('ho_admin','*'),('sales_manager','*'),
('sales_executive','dashboard.read'),('sales_executive','production.read'),('sales_executive','packing.read'),('sales_executive','fg.read'),
('viewer','dashboard.read'),('viewer','reports.read') on conflict do nothing;

create or replace function public.current_role() returns text language sql stable security definer set search_path=public as $$
  select coalesce((select role::text from public.profiles where id=auth.uid() and is_active=true),'viewer');
$$;
create or replace function public.has_permission(p text) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.erp_permissions where role=public.current_role() and (permission='*' or permission=p));
$$;

alter table public.erp_permissions enable row level security;
alter table public.pm_items enable row level security;
alter table public.fg_items enable row level security;
alter table public.stock_transactions enable row level security;
alter table public.production_logs enable row level security;
alter table public.stock_audits enable row level security;
alter table public.approvals enable row level security;
alter table public.audit_logs enable row level security;
alter table public.attachments enable row level security;
alter table public.backup_snapshots enable row level security;

drop policy if exists perms_read on public.erp_permissions; create policy perms_read on public.erp_permissions for select to authenticated using (true);
drop policy if exists pm_read on public.pm_items; create policy pm_read on public.pm_items for select to authenticated using (public.has_permission('packing.read'));
drop policy if exists pm_write on public.pm_items; create policy pm_write on public.pm_items for all to authenticated using (public.has_permission('packing.write')) with check (public.has_permission('packing.write'));
drop policy if exists fg_read on public.fg_items; create policy fg_read on public.fg_items for select to authenticated using (public.has_permission('fg.read'));
drop policy if exists fg_write on public.fg_items; create policy fg_write on public.fg_items for all to authenticated using (public.has_permission('fg.write')) with check (public.has_permission('fg.write'));
drop policy if exists tx_read on public.stock_transactions; create policy tx_read on public.stock_transactions for select to authenticated using (public.has_permission('dashboard.read'));
drop policy if exists tx_write on public.stock_transactions; create policy tx_write on public.stock_transactions for insert to authenticated with check (public.has_permission('packing.write') or public.has_permission('fg.write') or public.has_permission('*'));
drop policy if exists prod_read on public.production_logs; create policy prod_read on public.production_logs for select to authenticated using (public.has_permission('production.read'));
drop policy if exists prod_write on public.production_logs; create policy prod_write on public.production_logs for insert to authenticated with check (public.has_permission('production.write') or public.has_permission('*'));
drop policy if exists audit_read on public.stock_audits; create policy audit_read on public.stock_audits for select to authenticated using (public.has_permission('dashboard.read'));
drop policy if exists audit_write on public.stock_audits; create policy audit_write on public.stock_audits for all to authenticated using (public.has_permission('audit.write') or public.has_permission('*')) with check (public.has_permission('audit.write') or public.has_permission('*'));
drop policy if exists approval_read on public.approvals; create policy approval_read on public.approvals for select to authenticated using (requested_by=auth.uid() or public.has_permission('*'));
drop policy if exists approval_insert on public.approvals; create policy approval_insert on public.approvals for insert to authenticated with check (requested_by=auth.uid());
drop policy if exists approval_update on public.approvals; create policy approval_update on public.approvals for update to authenticated using (public.has_permission('*')) with check (public.has_permission('*'));
drop policy if exists auditlog_read on public.audit_logs; create policy auditlog_read on public.audit_logs for select to authenticated using (user_id=auth.uid() or public.has_permission('*'));
drop policy if exists auditlog_insert on public.audit_logs; create policy auditlog_insert on public.audit_logs for insert to authenticated with check (user_id=auth.uid());
drop policy if exists attach_read on public.attachments; create policy attach_read on public.attachments for select to authenticated using (true);
drop policy if exists attach_insert on public.attachments; create policy attach_insert on public.attachments for insert to authenticated with check (uploaded_by=auth.uid());
drop policy if exists backup_read on public.backup_snapshots; create policy backup_read on public.backup_snapshots for select to authenticated using (created_by=auth.uid() or public.has_permission('*'));
drop policy if exists backup_insert on public.backup_snapshots; create policy backup_insert on public.backup_snapshots for insert to authenticated with check (created_by=auth.uid());

insert into storage.buckets(id,name,public) values ('erp-attachments','erp-attachments',false) on conflict (id) do nothing;
drop policy if exists erp_storage_read on storage.objects; create policy erp_storage_read on storage.objects for select to authenticated using (bucket_id='erp-attachments');
drop policy if exists erp_storage_insert on storage.objects; create policy erp_storage_insert on storage.objects for insert to authenticated with check (bucket_id='erp-attachments');
drop policy if exists erp_storage_delete on storage.objects; create policy erp_storage_delete on storage.objects for delete to authenticated using (bucket_id='erp-attachments' and public.has_permission('*'));

create index if not exists idx_txn_date on public.stock_transactions(txn_date);
create index if not exists idx_txn_status on public.stock_transactions(status);
create index if not exists idx_prod_date on public.production_logs(log_date);
create index if not exists idx_approval_status on public.approvals(status);
create index if not exists idx_audit_entity on public.audit_logs(entity_type,entity_id);
create index if not exists idx_attachment_entity on public.attachments(entity_type,entity_id);

-- Add tables to Realtime only when not already present.
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='pm_items') then alter publication supabase_realtime add table public.pm_items; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='fg_items') then alter publication supabase_realtime add table public.fg_items; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='stock_transactions') then alter publication supabase_realtime add table public.stock_transactions; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='production_logs') then alter publication supabase_realtime add table public.production_logs; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='stock_audits') then alter publication supabase_realtime add table public.stock_audits; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='approvals') then alter publication supabase_realtime add table public.approvals; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='audit_logs') then alter publication supabase_realtime add table public.audit_logs; end if;
end $$;
