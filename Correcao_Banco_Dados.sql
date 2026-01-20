-- Script de Correção para Problemas de Permissão e Visualização de Produtos
-- Execute este script no SQL Editor do Supabase para corrigir a tabela user_tenants e as funções RPC.

-- 1. Garantir que a tabela user_tenants existe e tem permissões corretas
create table if not exists public.user_tenants (
  auth_user_id uuid primary key,
  id_usuario bigint not null,
  id_empresa bigint not null,
  role text not null default 'user'
);
create unique index if not exists user_tenants_auth_user_id_idx on public.user_tenants(auth_user_id);
alter table public.user_tenants disable row level security;
grant select on table public.user_tenants to authenticated;

-- 2. Recriar a função e trigger de sincronização (sync_user_tenants)
create or replace function public.sync_user_tenants()
returns trigger
language plpgsql
security definer
as $$
begin
  if TG_OP = 'INSERT' or TG_OP = 'UPDATE' then
    insert into public.user_tenants (auth_user_id, id_usuario, id_empresa, role)
    values (new.auth_user_id, new.id, new.id_empresa, coalesce(new.role, 'user'))
    on conflict (auth_user_id) do update
    set id_usuario = excluded.id_usuario,
        id_empresa = excluded.id_empresa,
        role = excluded.role;
  elsif TG_OP = 'DELETE' then
    delete from public.user_tenants where auth_user_id = old.auth_user_id;
  end if;
  return null;
end;
$$;

drop trigger if exists sync_user_tenants_trigger on public.usuarios;
create trigger sync_user_tenants_trigger
after insert or update or delete on public.usuarios
for each row execute function public.sync_user_tenants();

-- 3. Recriar a função upsert_user_tenant (usada no login)
create or replace function public.upsert_user_tenant()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_u record;
begin
  select id, id_empresa, role into v_u
  from public.usuarios
  where auth_user_id = auth.uid()
  limit 1;

  if v_u.id is not null then
    insert into public.user_tenants(auth_user_id, id_usuario, id_empresa, role)
    values (auth.uid(), v_u.id, v_u.id_empresa, v_u.role)
    on conflict (auth_user_id) do update
      set id_usuario = excluded.id_usuario,
          id_empresa = excluded.id_empresa,
          role = excluded.role;
  end if;
end;
$$;
grant execute on function public.upsert_user_tenant() to authenticated;

-- 4. FORÇAR a atualização da tabela user_tenants com base nos usuários existentes
-- Isso corrige o problema se a tabela estiver vazia ou desatualizada
insert into public.user_tenants(auth_user_id, id_usuario, id_empresa, role)
select u.auth_user_id, u.id, u.id_empresa, u.role
from public.usuarios u
where u.auth_user_id is not null
on conflict (auth_user_id) do update
set id_usuario = excluded.id_usuario,
    id_empresa = excluded.id_empresa,
    role = excluded.role;

-- 5. Garantir que a função get_products_for_empresa está correta (correção do bug de self-reference)
-- Primeiro, removemos TODAS as assinaturas possíveis para evitar erro de ambiguidade "Could not choose the best candidate function"
drop function if exists public.get_products_for_empresa(uuid);
drop function if exists public.get_products_for_empresa(uuid, text, boolean);

create or replace function public.get_products_for_empresa(
  p_session_id uuid default null,
  p_search text default null,
  p_is_counted boolean default null
)
returns table (
  id uuid,
  codigo text,
  descricao text,
  localizacao text,
  quantidade_atual integer,
  quantidade_contada integer,
  scanned_qty integer,
  is_counted boolean,
  expected_qty integer,
  session_id uuid,
  created_at timestamp with time zone,
  counting_session_name text
)
language sql
security definer
stable
set search_path = public
as $$
  with me as (
    select id_empresa
    from public.user_tenants
    where auth_user_id = auth.uid()
    limit 1
  )
  select 
    p.id,
    p.codigo,
    p.descricao,
    p.localizacao,
    p.quantidade_atual,
    p.quantidade_contada,
    p.scanned_qty,
    p.is_counted,
    p.expected_qty,
    p.session_id,
    p.created_at,
    cs.session_name as counting_session_name
  from public.products p
  join public.counting_sessions cs on cs.id = p.session_id
  join me on me.id_empresa = cs.id_empresa
  where (p_session_id is null or p.session_id = p_session_id)
    and (p_search is null 
         or p.codigo ilike '%' || p_search || '%' 
         or p.descricao ilike '%' || p_search || '%')
    and (p_is_counted is null or p.is_counted = p_is_counted)
  order by p.created_at desc
$$;
grant execute on function public.get_products_for_empresa(uuid, text, boolean) to authenticated;

-- 6. Garantir que insert_scan existe (para bipagens) e popula todos os campos
create or replace function public.insert_scan(
  p_session_id uuid,
  p_code text,
  p_quantity integer,
  p_description text
)
returns public.scans
language sql
security definer
volatile
set search_path = public
as $$
  with me as (
    select t.id_empresa, t.id_usuario, t.role
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
    limit 1
  ),
  sess as (
    select cs.id, cs.id_empresa, cs.id_usuario
    from public.counting_sessions cs
    join me on me.id_empresa = cs.id_empresa
    where cs.id = p_session_id
    limit 1
  ),
  prod as (
    select id
    from public.products
    where session_id = p_session_id
      and codigo = p_code
    limit 1
  ),
  ins as (
    insert into public.scans (session_id, code, codigo, product_id, quantity, description)
    select 
      p_session_id, 
      p_code, 
      p_code, 
      (select id from prod),
      coalesce(p_quantity, 1), 
      nullif(p_description,'')
    from sess
    returning *
  )
  select * from ins;
$$;
grant execute on function public.insert_scan(uuid, text, integer, text) to authenticated;
