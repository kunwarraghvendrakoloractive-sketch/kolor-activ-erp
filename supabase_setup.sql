-- KOLOR ACTIV ERP V2 - NORMALIZED SUPABASE SCHEMA
-- Run once in Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  employee_code text unique,
  role text not null default 'viewer' check (role in ('super_admin','ho_admin','production_manager','store_manager','employee','viewer')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_permissions (
  id uuid primary key default gen_random_uuid(),
  role text not null,
  permission text not null,
  unique(role, permission)
);

create table if not exists public.pm_items (
  id text primary key,
  code text,
  name text not null,
  shade_name text,
  shade_code text,
  uom text not null default 'PCS',
  stock numeric not null default 0,
  min_stock numeric not null default 0,
  max_stock numeric not null default 0,
  location text,
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fg_items (
  id text primary key,
  code text,
  name text not null,
  shade_name text,
  shade_code text,
  uom text not null default 'PCS',
  batch text not null,
  qty numeric not null default 0,
  mfg_date date,
  expiry_date date,
  location text,
  active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.stock_transactions (
  id text primary key,
  doc_no text,
  txn_date date not null default current_date,
  txn_type text not null,
  module text not null,
  code text,
  name text,
  batch text,
  qty_in numeric not null default 0,
  qty_out numeric not null default 0,
  department text,
  remarks text,
  status text not null default 'approved' check (status in ('draft','pending','approved','rejected','cancelled')),
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.production_logs (
  id text primary key,
  log_date date not null default current_date,
  line text not null,
  shift text,
  product text,
  batch text,
  good_qty numeric not null default 0,
  rejected_qty numeric not null default 0,
  worker text,
  status text not null default 'approved' check (status in ('draft','pending','approved','rejected')),
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  approved_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.stock_audits (
  id text primary key,
  audit_date timestamptz not null default now(),
  module text not null,
  item text not null,
  batch text,
  system_qty numeric not null default 0,
  physical_qty numeric not null default 0,
  variance numeric generated always as (physical_qty-system_qty) stored,
  remarks text,
  created_by uuid references auth.users(id),
  approved_by uuid references auth.users(id),
  status text not null default 'pending' check (status in ('pending','approved','rejected'))
);

create table if not exists public.approvals (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id text not null,
  action text not null default 'approve',
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  requested_by uuid references auth.users(id),
  decided_by uuid references auth.users(id),
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  remarks text
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id),
  action text not null,
  entity_type text,
  entity_id text,
  old_data jsonb,
  new_data jsonb,
  ip_hint text,
  created_at timestamptz not null default now()
);

create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id text not null,
  file_name text not null,
  storage_path text not null unique,
  mime_type text,
  size_bytes bigint,
  uploaded_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.backup_snapshots (
  id uuid primary key default gen_random_uuid(),
  snapshot_date date not null default current_date,
  created_by uuid references auth.users(id),
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_txn_date on public.stock_transactions(txn_date);
create index if not exists idx_txn_status on public.stock_transactions(status);
create index if not exists idx_prod_date on public.production_logs(log_date);
create index if not exists idx_approval_status on public.approvals(status);
create index if not exists idx_audit_entity on public.audit_logs(entity_type, entity_id);
create index if not exists idx_attachment_entity on public.attachments(entity_type, entity_id);

-- Permissions
insert into public.erp_permissions(role,permission) values
('super_admin','*'),('ho_admin','*'),
('production_manager','dashboard.read'),('production_manager','production.read'),('production_manager','production.write'),('production_manager','production.approve'),('production_manager','reports.read'),
('store_manager','dashboard.read'),('store_manager','packing.read'),('store_manager','packing.write'),('store_manager','fg.read'),('store_manager','fg.write'),('store_manager','stock.approve'),('store_manager','audit.write'),('store_manager','reports.read'),
('employee','dashboard.read'),('employee','production.read'),('employee','production.write'),('employee','packing.read'),('employee','fg.read'),
('viewer','dashboard.read'),('viewer','reports.read')
on conflict do nothing;

-- RLS helpers
create or replace function public.current_role() returns text language sql stable security definer set search_path=public as $$
  select coalesce((select role from public.profiles where id=auth.uid() and active=true),'viewer');
$$;
create or replace function public.has_permission(p text) returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.erp_permissions where role=public.current_role() and (permission='*' or permission=p));
$$;

-- Profile creation for new Auth users
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name,employee_code,role) values (new.id, coalesce(new.raw_user_meta_data->>'full_name',new.email), new.raw_user_meta_data->>'employee_code','viewer') on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Audit helper
create or replace function public.write_audit(p_action text,p_entity_type text,p_entity_id text,p_old jsonb,p_new jsonb) returns void language sql security definer set search_path=public as $$
 insert into public.audit_logs(user_id,action,entity_type,entity_id,old_data,new_data) values(auth.uid(),p_action,p_entity_type,p_entity_id,p_old,p_new);
$$;

-- RLS
alter table public.profiles enable row level security;
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

-- Safe policies: authenticated users can read permitted operational data; writes require module permission.
drop policy if exists profiles_read on public.profiles; create policy profiles_read on public.profiles for select to authenticated using (id=auth.uid() or public.has_permission('*'));
drop policy if exists profiles_admin on public.profiles; create policy profiles_admin on public.profiles for all to authenticated using (public.has_permission('*')) with check (public.has_permission('*'));
drop policy if exists perms_read on public.erp_permissions; create policy perms_read on public.erp_permissions for select to authenticated using (true);

drop policy if exists pm_read on public.pm_items; create policy pm_read on public.pm_items for select to authenticated using (public.has_permission('packing.read'));
drop policy if exists pm_write on public.pm_items; create policy pm_write on public.pm_items for all to authenticated using (public.has_permission('packing.write')) with check (public.has_permission('packing.write'));
drop policy if exists fg_read on public.fg_items; create policy fg_read on public.fg_items for select to authenticated using (public.has_permission('fg.read'));
drop policy if exists fg_write on public.fg_items; create policy fg_write on public.fg_items for all to authenticated using (public.has_permission('fg.write')) with check (public.has_permission('fg.write'));
drop policy if exists tx_read on public.stock_transactions; create policy tx_read on public.stock_transactions for select to authenticated using (public.has_permission('dashboard.read'));
drop policy if exists tx_write on public.stock_transactions; create policy tx_write on public.stock_transactions for insert to authenticated with check (public.has_permission('packing.write') or public.has_permission('fg.write'));
drop policy if exists prod_read on public.production_logs; create policy prod_read on public.production_logs for select to authenticated using (public.has_permission('production.read'));
drop policy if exists prod_write on public.production_logs; create policy prod_write on public.production_logs for insert to authenticated with check (public.has_permission('production.write'));
drop policy if exists audit_read on public.stock_audits; create policy audit_read on public.stock_audits for select to authenticated using (public.has_permission('dashboard.read'));
drop policy if exists audit_write on public.stock_audits; create policy audit_write on public.stock_audits for all to authenticated using (public.has_permission('audit.write')) with check (public.has_permission('audit.write'));
drop policy if exists approval_read on public.approvals; create policy approval_read on public.approvals for select to authenticated using (requested_by=auth.uid() or public.has_permission('production.approve') or public.has_permission('stock.approve') or public.has_permission('*'));
drop policy if exists approval_insert on public.approvals; create policy approval_insert on public.approvals for insert to authenticated with check (requested_by=auth.uid());
drop policy if exists approval_update on public.approvals; create policy approval_update on public.approvals for update to authenticated using (public.has_permission('production.approve') or public.has_permission('stock.approve') or public.has_permission('*')) with check (public.has_permission('production.approve') or public.has_permission('stock.approve') or public.has_permission('*'));
drop policy if exists auditlog_read on public.audit_logs; create policy auditlog_read on public.audit_logs for select to authenticated using (user_id=auth.uid() or public.has_permission('*'));
drop policy if exists auditlog_insert on public.audit_logs; create policy auditlog_insert on public.audit_logs for insert to authenticated with check (user_id=auth.uid());
drop policy if exists attach_read on public.attachments; create policy attach_read on public.attachments for select to authenticated using (true);
drop policy if exists attach_insert on public.attachments; create policy attach_insert on public.attachments for insert to authenticated with check (uploaded_by=auth.uid());
drop policy if exists backup_read on public.backup_snapshots; create policy backup_read on public.backup_snapshots for select to authenticated using (created_by=auth.uid() or public.has_permission('*'));
drop policy if exists backup_insert on public.backup_snapshots; create policy backup_insert on public.backup_snapshots for insert to authenticated with check (created_by=auth.uid());

-- Storage bucket for photos/documents
insert into storage.buckets(id,name,public) values ('erp-attachments','erp-attachments',false) on conflict (id) do nothing;
drop policy if exists erp_storage_read on storage.objects;
create policy erp_storage_read on storage.objects for select to authenticated using (bucket_id='erp-attachments');
drop policy if exists erp_storage_insert on storage.objects;
create policy erp_storage_insert on storage.objects for insert to authenticated with check (bucket_id='erp-attachments');
drop policy if exists erp_storage_delete on storage.objects;
create policy erp_storage_delete on storage.objects for delete to authenticated using (bucket_id='erp-attachments' and public.has_permission('*'));

-- Realtime for operational dashboards
alter publication supabase_realtime add table public.pm_items;
alter publication supabase_realtime add table public.fg_items;
alter publication supabase_realtime add table public.stock_transactions;
alter publication supabase_realtime add table public.production_logs;
alter publication supabase_realtime add table public.stock_audits;
alter publication supabase_realtime add table public.approvals;
alter publication supabase_realtime add table public.audit_logs;
