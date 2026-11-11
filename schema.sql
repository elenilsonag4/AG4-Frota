-- Gestão de Frota | Supabase PostgreSQL
-- Execute no SQL Editor do projeto Supabase. Auth usa auth.users.
create extension if not exists pgcrypto;
create type public.app_role as enum ('Leitor','Motorista','Alimentador','Gerenciador','Administrador');
create type public.record_status as enum ('Ativo','Inativo');

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique,
  role public.app_role not null default 'Leitor',
  status public.record_status not null default 'Ativo',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(), name text not null, plate text not null unique,
  model text, year integer, category text, fuel_type text, km numeric(12,1) not null default 0,
  status text not null default 'Ativo' check(status in ('Ativo','Em manutenção','Inativo')),
  notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  license_cat text not null,
  license_expiry date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.fuelings (
  id uuid primary key default gen_random_uuid(), date date not null default current_date,
  vehicle_id uuid not null references public.vehicles(id), driver_id uuid references public.drivers(id),
  fuel_type text, liters numeric(12,3) not null check(liters > 0), price_per_liter numeric(12,3) not null check(price_per_liter >= 0),
  odometer numeric(12,1), station text, notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.maintenance (
  id uuid primary key default gen_random_uuid(), date date not null default current_date,
  vehicle_id uuid not null references public.vehicles(id), type text not null, description text not null,
  odometer numeric(12,1), next_km numeric(12,1), next_date date, cost numeric(12,2) not null default 0,
  supplier text, status text not null default 'Agendada' check(status in ('Agendada','Em andamento','Concluída','Cancelada')),
  notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.stock_items (
  id uuid primary key default gen_random_uuid(), name text not null, category text, code text unique,
  quantity numeric(12,2) not null default 0 check(quantity >= 0), min_quantity numeric(12,2) not null default 0,
  unit text, unit_cost numeric(12,2) not null default 0, supplier text, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(), item_id uuid not null references public.stock_items(id),
  movement_type text not null check(movement_type in ('Entrada','Saída','Ajuste')),
  quantity numeric(12,2) not null check(quantity > 0), unit_cost numeric(12,2), reason text,
  created_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table if not exists public.finance_entries (
  id uuid primary key default gen_random_uuid(), date date not null default current_date,
  type text not null check(type in ('Despesa','Receita')), category text not null,
  vehicle_id uuid references public.vehicles(id), description text not null,
  amount numeric(12,2) not null check(amount >= 0), status text not null default 'Pendente'
    check(status in ('Pago','Pendente','Recebido','Atrasado')),
  notes text, created_by uuid references auth.users(id), created_at timestamptz not null default now()
);

create or replace function public.current_app_role() returns public.app_role
language sql stable security definer set search_path=public
as $$ select role from public.profiles where id=auth.uid() and status='Ativo' limit 1 $$;
create or replace function public.is_active_user() returns boolean
language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles where id=auth.uid() and status='Ativo') $$;
create or replace function public.can_read_module(module_name text) returns boolean
language sql stable security definer set search_path=public
as $$ select case public.current_app_role()
 when 'Administrador' then true
 when 'Gerenciador' then module_name in ('vehicles','drivers','fuelings','maintenance','stock_items','stock_movements','finance_entries','reports','profiles')
 when 'Alimentador' then module_name in ('vehicles','drivers','fuelings','maintenance','stock_items','stock_movements','finance_entries','reports')
 when 'Motorista' then module_name in ('vehicles','drivers')
 when 'Leitor' then module_name in ('vehicles','drivers')
 else false end $$;
create or replace function public.can_write_module(module_name text) returns boolean
language sql stable security definer set search_path=public
as $$ select case public.current_app_role()
 when 'Administrador' then true
 when 'Gerenciador' then module_name <> 'profiles'
 when 'Alimentador' then module_name in ('maintenance')
 else false end $$;

alter table public.profiles enable row level security;
alter table public.vehicles enable row level security;
alter table public.drivers enable row level security;
alter table public.fuelings enable row level security;
alter table public.maintenance enable row level security;
alter table public.stock_items enable row level security;
alter table public.stock_movements enable row level security;
alter table public.finance_entries enable row level security;

-- Usuário consulta o próprio perfil; administrador gerencia todos.
create policy "profile self read" on public.profiles for select to authenticated using(id=auth.uid() or public.current_app_role()='Administrador');
create policy "admin manage profiles" on public.profiles for all to authenticated using(public.current_app_role()='Administrador') with check(public.current_app_role()='Administrador');
create policy "manager read lower profiles" on public.profiles for select to authenticated using(public.current_app_role()='Gerenciador' and role in ('Leitor','Motorista','Alimentador'));
create policy "manager manage lower profiles" on public.profiles for all to authenticated using(public.current_app_role()='Gerenciador' and role in ('Leitor','Motorista','Alimentador')) with check(public.current_app_role()='Gerenciador' and role in ('Leitor','Motorista','Alimentador'));
-- Políticas de leitura e escrita respeitam o nível de acesso.
create policy "vehicles read" on public.vehicles for select to authenticated using(public.is_active_user() and public.can_read_module('vehicles'));
create policy "vehicles write" on public.vehicles for all to authenticated using(public.can_write_module('vehicles')) with check(public.can_write_module('vehicles'));
create policy "drivers read" on public.drivers for select to authenticated using(public.is_active_user() and public.can_read_module('drivers'));
create policy "drivers write" on public.drivers for all to authenticated using(public.can_write_module('drivers')) with check(public.can_write_module('drivers'));
create policy "fuelings read" on public.fuelings for select to authenticated using(public.is_active_user() and public.can_read_module('fuelings'));
create policy "fuelings write" on public.fuelings for all to authenticated using(public.can_write_module('fuelings')) with check(public.can_write_module('fuelings'));
create policy "maintenance read" on public.maintenance for select to authenticated using(public.is_active_user() and public.can_read_module('maintenance'));
create policy "maintenance write" on public.maintenance for all to authenticated using(public.can_write_module('maintenance')) with check(public.can_write_module('maintenance'));
create policy "stock read" on public.stock_items for select to authenticated using(public.is_active_user() and public.can_read_module('stock_items'));
create policy "stock write" on public.stock_items for all to authenticated using(public.can_write_module('stock_items')) with check(public.can_write_module('stock_items'));
create policy "stock movement read" on public.stock_movements for select to authenticated using(public.is_active_user() and public.can_read_module('stock_movements'));
create policy "stock movement write" on public.stock_movements for all to authenticated using(public.can_write_module('stock_movements')) with check(public.can_write_module('stock_movements'));
create policy "finance read" on public.finance_entries for select to authenticated using(public.is_active_user() and public.can_read_module('finance_entries'));
create policy "finance write" on public.finance_entries for all to authenticated using(public.can_write_module('finance_entries')) with check(public.can_write_module('finance_entries'));

-- Cria perfil automaticamente quando uma conta é criada pelo Supabase Auth.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public
as $$ begin insert into public.profiles(id,name,email,role) values(new.id,coalesce(new.raw_user_meta_data->>'name','Usuário'),new.email,coalesce((new.raw_user_meta_data->>'role')::public.app_role,'Leitor')); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
