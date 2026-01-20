-- Limpeza TOTAL de policies antigas para evitar recursão
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Remove policies de usuarios
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'usuarios' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.usuarios';
    END LOOP;

    -- Remove policies de counting_sessions
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'counting_sessions' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.counting_sessions';
    END LOOP;
    
    -- Remove policies de products
    FOR r IN SELECT policyname FROM pg_policies WHERE tablename = 'products' AND schemaname = 'public'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.products';
    END LOOP;
END $$;

create table if not exists public.configuracao_estoque (
  id uuid not null default gen_random_uuid (),
  tipo_contagem_padrao text not null default 'normal'::text,
  tipo_importacao_padrao text not null default 'csv'::text,
  tipo_exportacao_padrao text not null default 'csv'::text,
  tipo_exportacao text not null default 'detalhada'::text,
  importacao_incluir_codigo boolean not null default true,
  importacao_incluir_quantidade boolean not null default true,
  importacao_incluir_descricao boolean not null default false,
  importacao_incluir_localizacao boolean not null default false,
  exportacao_incluir_codigo boolean not null default true,
  exportacao_incluir_quantidade boolean not null default true,
  exportacao_incluir_descricao boolean not null default false,
  exportacao_incluir_localizacao boolean not null default false,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  id_empresa bigint null,
  constraint configuracao_estoque_pkey primary key (id),
  constraint configuracao_estoque_id_empresa_fkey foreign KEY (id_empresa) references empresas (id),
  constraint configuracao_estoque_tipo_contagem_padrao_check check (
    (
      tipo_contagem_padrao = any (array['normal'::text, 'avulsa'::text])
    )
  ),
  constraint configuracao_estoque_tipo_exportacao_check check (
    (
      tipo_exportacao = any (array['agrupada'::text, 'detalhada'::text])
    )
  ),
  constraint configuracao_estoque_tipo_exportacao_padrao_check check (
    (
      tipo_exportacao_padrao = any (array['csv'::text, 'txt'::text])
    )
  ),
  constraint configuracao_estoque_tipo_importacao_padrao_check check (
    (
      tipo_importacao_padrao = any (array['csv'::text, 'txt'::text])
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_configuracao_estoque_tipo_contagem on public.configuracao_estoque using btree (tipo_contagem_padrao) TABLESPACE pg_default;

create index IF not exists idx_configuracao_estoque_tipo_arquivo on public.configuracao_estoque using btree (tipo_importacao_padrao, tipo_exportacao_padrao) TABLESPACE pg_default;
grant select, insert, update, delete on public.configuracao_estoque to authenticated;

drop trigger if exists update_configuracao_estoque_updated_at on public.configuracao_estoque;
create trigger update_configuracao_estoque_updated_at BEFORE
update on configuracao_estoque for EACH row
execute FUNCTION update_updated_at_column ();

create table if not exists public.counting_sessions (
  id uuid not null default gen_random_uuid (),
  session_name text not null,
  description text null,
  count_type text not null,
  status text null default 'waiting'::text,
  total_items integer null default 0,
  counted_items integer null default 0,
  scanned_items integer null default 0,
  started_at timestamp with time zone null default now(),
  ended_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  arquivo_uploaded text null,
  id_usuario bigint null,
  id_empresa bigint null,
  constraint counting_sessions_pkey primary key (id),
  constraint counting_sessions_id_empresa_fkey foreign KEY (id_empresa) references empresas (id),
  constraint counting_sessions_id_usuario_id_empresa_fkey foreign KEY (id_usuario, id_empresa) references usuarios (id, id_empresa),
  constraint counting_sessions_count_type_check check (
    (
      count_type = any (array['normal'::text, 'avulsa'::text])
    )
  ),
  constraint counting_sessions_status_check check (
    (
      status = any (
        array[
          'waiting'::text,
          'active'::text,
          'completed'::text,
          'cancelled'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_counting_sessions_status on public.counting_sessions using btree (status) TABLESPACE pg_default;

drop trigger if exists update_counting_sessions_updated_at on public.counting_sessions;
create trigger update_counting_sessions_updated_at BEFORE
update on counting_sessions for EACH row
execute FUNCTION update_updated_at_column ();

create table if not exists public.empresas (
  id bigserial not null,
  nome character varying(255) not null,
  email character varying(255) null,
  endereco character varying(255) null,
  cnpj character(14) null,
  cpf character(11) null,
  inscricao_estadual character varying(50) null,
  tipo_pessoa character varying(20) null default 'J'::character varying,
  numero integer null,
  complemento character varying(100) null,
  cep character varying(10) null,
  uf character varying(2) null,
  cidade character varying(100) null,
  contatos character varying(200) null,
  telefone character varying(20) null,
  celular character varying(20) null,
  website character varying(100) null,
  senha text null,
  mensagem text null,
  import_limit smallint null default '1000'::smallint,
  ativo boolean null default true,
  constraint empresas_pkey primary key (id),
  constraint empresas_email_key unique (email),
  constraint empresas_tipo_pessoa_check check (
    (
      (tipo_pessoa)::text = any (array['F'::text, 'J'::text])
    )
  )
) TABLESPACE pg_default;

create table if not exists public.products (
  id uuid not null default gen_random_uuid (),
  session_id uuid not null,
  codigo text not null,
  descricao text not null,
  quantidade_atual integer null default 0,
  quantidade_contada integer null default 0,
  is_counted boolean null default false,
  scanned_qty integer null default 0,
  expected_qty integer null default 0,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  localizacao text null,
  constraint products_pkey primary key (id),
  constraint products_session_id_codigo_key unique (session_id, codigo),
  constraint products_session_id_fkey foreign KEY (session_id) references counting_sessions (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_products_session_id on public.products using btree (session_id) TABLESPACE pg_default;

create index IF not exists idx_products_codigo on public.products using btree (codigo) TABLESPACE pg_default;

drop trigger if exists update_products_updated_at on public.products;
create trigger update_products_updated_at BEFORE
update on products for EACH row
execute FUNCTION update_updated_at_column ();

create table if not exists public.scans (
  id uuid not null default gen_random_uuid (),
  session_id uuid not null,
  product_id uuid null,
  codigo character varying(100) null,
  code character varying(100) not null,
  quantity integer null default 1,
  qty integer null default 1,
  description text null,
  scan_type text null default 'barcode'::text,
  scanned_at timestamp with time zone null default now(),
  created_at timestamp with time zone null default now(),
  constraint scans_pkey primary key (id),
  constraint scans_product_id_fkey foreign KEY (product_id) references products (id) on delete CASCADE,
  constraint scans_session_id_fkey foreign KEY (session_id) references counting_sessions (id) on delete CASCADE,
  constraint scans_scan_type_check check (
    (
      scan_type = any (array['barcode'::text, 'manual'::text])
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_scans_session_id on public.scans using btree (session_id) TABLESPACE pg_default;

create index IF not exists idx_scans_product_id on public.scans using btree (product_id) TABLESPACE pg_default;

-- (Tabela empresas duplicada removida)


create table if not exists public.usuarios (
  id bigserial not null,
  nome character varying(100) not null,
  email character varying(100) not null,
  ativo boolean null default true,
  funcao character varying(50) null default ''::character varying,
  created_at timestamp with time zone null default now(),
  senha character varying(5) null,
  fone_celular text null,
  role text null default 'user'::text,
  id_empresa bigint not null,
  constraint usuarios_pkey primary key (id, id_empresa),
  constraint usuarios_email_key unique (email),
  constraint usuarios_id_empresa_fkey foreign KEY (id_empresa) references empresas (id),
  constraint usuarios_role_check check ((role = any (array['user'::text, 'admin'::text])))
) TABLESPACE pg_default;

alter table public.usuarios add column if not exists auth_user_id uuid;
create unique index if not exists usuarios_auth_user_id_unique on public.usuarios(auth_user_id) where auth_user_id is not null;
alter table public.usuarios enable row level security;
drop policy if exists usuarios_select_self on public.usuarios;
create policy usuarios_select_self on public.usuarios for select using (auth.uid() = auth_user_id);
drop policy if exists usuarios_select_admin_company on public.usuarios;
-- Helper function to avoid recursion in policies
create or replace function public.is_admin_for_empresa(target_id_empresa bigint)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.user_tenants
    where auth_user_id = auth.uid()
      and role = 'admin'
      and id_empresa = target_id_empresa
  );
$$;
grant execute on function public.is_admin_for_empresa(bigint) to authenticated;

drop policy if exists usuarios_select_admin_company on public.usuarios;
create policy usuarios_select_admin_company on public.usuarios for select using (
  exists (
    select 1 from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.role = 'admin'
      and t.id_empresa = public.usuarios.id_empresa
  )
);
grant usage on schema public to authenticated;
grant select on table public.usuarios to authenticated;

create or replace function public.get_usuario_perfil()
returns table (
  id bigint,
  nome character varying(100),
  email character varying(100),
  ativo boolean,
  funcao character varying(50),
  created_at timestamp with time zone,
  fone_celular text,
  role text,
  id_empresa bigint,
  auth_user_id uuid
)
language sql
security definer
stable
set search_path = public
as $$
  select 
    id,
    nome,
    email,
    ativo,
    funcao,
    created_at,
    fone_celular,
    role,
    id_empresa,
    auth_user_id
  from public.usuarios
  where auth_user_id = auth.uid()
  limit 1
$$;
grant execute on function public.get_usuario_perfil() to authenticated;

create or replace function public.get_empresa_for_current_user()
returns table (
  id bigint,
  nome character varying(255),
  email character varying(255),
  endereco character varying(255),
  cnpj character(14),
  cpf character(11),
  inscricao_estadual character varying(50),
  tipo_pessoa character varying(20),
  numero integer,
  complemento character varying(100),
  cep character varying(10),
  uf character varying(2),
  cidade character varying(100),
  contatos character varying(200),
  telefone character varying(20),
  celular character varying(20),
  website character varying(100),
  senha text,
  mensagem text,
  import_limit smallint,
  ativo boolean
)
language sql
security definer
stable
set search_path = public
as $$
  select 
    e.id,
    e.nome,
    e.email,
    e.endereco,
    e.cnpj,
    e.cpf,
    e.inscricao_estadual,
    e.tipo_pessoa,
    e.numero,
    e.complemento,
    e.cep,
    e.uf,
    e.cidade,
    e.contatos,
    e.telefone,
    e.celular,
    e.website,
    e.senha,
    e.mensagem,
    e.import_limit,
    e.ativo
  from public.empresas e
  join public.usuarios u on u.id_empresa = e.id
  where u.auth_user_id = auth.uid()
  limit 1
$$;
grant execute on function public.get_empresa_for_current_user() to authenticated;
grant select on table public.empresas to authenticated;

create or replace function public.get_usuarios_da_empresa()
returns table (
  id bigint,
  nome character varying(100)
)
language sql
security definer
stable
set search_path = public
as $$
  with me as (
    select id_empresa
    from public.usuarios
    where auth_user_id = auth.uid()
    limit 1
  )
  select u.id, u.nome
  from public.usuarios u
  join me on me.id_empresa = u.id_empresa
  where u.ativo = true
  order by u.nome
$$;
grant execute on function public.get_usuarios_da_empresa() to authenticated;

create table if not exists public.user_tenants (
  auth_user_id uuid primary key,
  id_usuario bigint not null,
  id_empresa bigint not null,
  role text not null default 'user'
);
create unique index if not exists user_tenants_auth_user_id_idx on public.user_tenants(auth_user_id);
alter table public.user_tenants disable row level security;
grant select on table public.user_tenants to authenticated;

-- Trigger to maintain user_tenants
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

-- Backfill mapping from usuarios (execute once after deployment)
insert into public.user_tenants(auth_user_id, id_usuario, id_empresa, role)
select u.auth_user_id, u.id, u.id_empresa, u.role
from public.usuarios u
where u.auth_user_id is not null
on conflict (auth_user_id) do update
set id_usuario = excluded.id_usuario,
    id_empresa = excluded.id_empresa,
    role = excluded.role;

alter table public.counting_sessions enable row level security;
drop policy if exists counting_sessions_select_company on public.counting_sessions;
create policy counting_sessions_select_company on public.counting_sessions
for select using (
  exists (
    select 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_empresa = public.counting_sessions.id_empresa
  )
);

drop policy if exists counting_sessions_modify_owner_or_admin on public.counting_sessions;
create policy counting_sessions_modify_owner_or_admin on public.counting_sessions
for insert
with check (
  exists (
    select 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = public.counting_sessions.id_usuario
      and t.id_empresa = public.counting_sessions.id_empresa
  )
  or exists (
    select 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.role = 'admin'
      and t.id_empresa = public.counting_sessions.id_empresa
  )
);
drop policy if exists counting_sessions_update_owner_or_admin on public.counting_sessions;
create policy counting_sessions_update_owner_or_admin on public.counting_sessions
for update
using (
  exists (
    select 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = public.counting_sessions.id_usuario
      and t.id_empresa = public.counting_sessions.id_empresa
  )
  or exists (
    select 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.role = 'admin'
      and t.id_empresa = public.counting_sessions.id_empresa
  )
);

drop policy if exists counting_sessions_delete_owner_or_admin on public.counting_sessions;
create policy counting_sessions_delete_owner_or_admin on public.counting_sessions
for delete
using (
  exists (
    select 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = public.counting_sessions.id_usuario
      and t.id_empresa = public.counting_sessions.id_empresa
  )
  or exists (
    select 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.role = 'admin'
      and t.id_empresa = public.counting_sessions.id_empresa
  )
);

grant select, insert, update, delete on table public.counting_sessions to authenticated;

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

create or replace function public.get_counting_sessions_for_current_user()
returns setof public.counting_sessions
language sql
security definer
stable
set search_path = public
as $$
  select cs.*
  from public.counting_sessions cs
  join public.user_tenants t
    on t.auth_user_id = auth.uid()
   and t.id_empresa = cs.id_empresa
  where t.role = 'admin' or cs.id_usuario = t.id_usuario
  order by cs.created_at desc
$$;
grant execute on function public.update_session_file_info(uuid, text, text) to authenticated;

-- Drop old signatures to avoid ambiguity
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

create or replace function public.insert_products_for_session(
  p_session_id uuid,
  p_products jsonb
)
returns setof public.products
language sql
security definer
volatile
set search_path = public
as $$
  with me as (
    select id_empresa
    from public.user_tenants
    where auth_user_id = auth.uid()
    limit 1
  ),
  sess as (
    select cs.id
    from public.counting_sessions cs
    join me on me.id_empresa = cs.id_empresa
    where cs.id = p_session_id
    limit 1
  ),
  ins as (
    insert into public.products (session_id, codigo, descricao, localizacao, expected_qty, quantidade_atual, quantidade_contada, is_counted, scanned_qty)
    select p_session_id, rec.codigo, rec.descricao, nullif(rec.localizacao,''), coalesce(rec.expected_qty,0), coalesce(rec.quantidade_atual,0), 0, false, 0
    from jsonb_to_recordset(p_products) as rec(codigo text, descricao text, localizacao text, expected_qty integer, quantidade_atual integer)
    returning *
  )
  select * from ins;
$$;
grant execute on function public.insert_products_for_session(uuid, jsonb) to authenticated;

create or replace function public.update_session_total(p_session_id uuid)
returns void
language sql
security definer
volatile
set search_path = public
as $$
  update public.counting_sessions
  set total_items = (
    select count(*) from public.products where session_id = p_session_id
  )
  where id = p_session_id;
$$;
grant execute on function public.update_session_total(uuid) to authenticated;

create or replace function public.update_session_file_info(
  p_session_id uuid,
  p_file_name text,
  p_session_name text default null
)
returns void
language sql
security definer
volatile
set search_path = public
as $$
  update public.counting_sessions cs
  set 
    arquivo_uploaded = p_file_name,
    session_name = coalesce(p_session_name, cs.session_name)
  from public.user_tenants t
  where cs.id = p_session_id
    and t.auth_user_id = auth.uid()
    and t.id_empresa = cs.id_empresa;
$$;
grant execute on function public.update_session_file_info(uuid, text, text) to authenticated;

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

alter table public.products enable row level security;
drop policy if exists products_select_company on public.products;
create policy products_select_company on public.products
for select using (
  exists (
    select 1
    from public.counting_sessions cs
    join public.user_tenants t on t.auth_user_id = auth.uid()
    where cs.id = public.products.session_id
      and cs.id_empresa = t.id_empresa
  )
);

drop policy if exists products_insert_session_company on public.products;
create policy products_insert_session_company on public.products
for insert
with check (
  exists (
    select 1
    from public.counting_sessions cs
    join public.user_tenants t on t.auth_user_id = auth.uid()
    where cs.id = public.products.session_id
      and cs.id_empresa = t.id_empresa
  )
);

drop policy if exists products_update_owner_or_admin on public.products;
create policy products_update_owner_or_admin on public.products
for update
using (
  exists (
    select 1
    from public.counting_sessions cs
    join public.user_tenants t on t.auth_user_id = auth.uid()
    where cs.id = public.products.session_id
      and cs.id_empresa = t.id_empresa
      and (t.role = 'admin' or cs.id_usuario = t.id_usuario)
  )
);

drop policy if exists products_delete_owner_or_admin on public.products;
create policy products_delete_owner_or_admin on public.products
for delete
using (
  exists (
    select 1
    from public.counting_sessions cs
    join public.user_tenants t on t.auth_user_id = auth.uid()
    where cs.id = public.products.session_id
      and cs.id_empresa = t.id_empresa
      and (t.role = 'admin' or cs.id_usuario = t.id_usuario)
  )
);

grant select, insert, update, delete on table public.products to authenticated;

create or replace function public.delete_product(p_product_id uuid)
returns void
language plpgsql
security definer
volatile
set search_path = public
as $$
declare
  v_session uuid;
  v_emp bigint;
  v_owner bigint;
  v_role text;
begin
  select p.session_id into v_session
  from public.products p
  where p.id = p_product_id;

  if v_session is null then
    raise exception 'Produto nÃ£o encontrado';
  end if;

  select cs.id_empresa, cs.id_usuario into v_emp, v_owner
  from public.counting_sessions cs
  where cs.id = v_session;

  select t.role into v_role
  from public.user_tenants t
  where t.auth_user_id = auth.uid()
    and t.id_empresa = v_emp
  limit 1;

  if v_role is null then
    raise exception 'PermissÃ£o negada';
  end if;

  if v_role <> 'admin' then
    perform 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = v_owner
      and t.id_empresa = v_emp;
    if not found then
      raise exception 'PermissÃ£o negada';
    end if;
  end if;

  delete from public.products where id = p_product_id;
end;
$$;
grant execute on function public.delete_product(uuid) to authenticated;

create or replace function public.get_dashboard_stats_for_current_user()
returns table (
  total integer,
  counted integer,
  scanned integer
)
language sql
security definer
stable
set search_path = public
as $$
  with me as (
    select id_empresa, id_usuario, role
    from public.user_tenants
    where auth_user_id = auth.uid()
    limit 1
  ),
  sessions as (
    select cs.id
    from public.counting_sessions cs
    join me on me.id_empresa = cs.id_empresa
    where me.role = 'admin' or cs.id_usuario = me.id_usuario
  )
  select
    coalesce((select count(*) from public.products p where p.session_id in (select id from sessions)), 0) as total,
    coalesce((select count(*) from public.products p where p.session_id in (select id from sessions) and (p.is_counted = true or (p.quantidade_contada is not null and p.quantidade_contada > 0))), 0) as counted,
    coalesce((select sum(p.scanned_qty) from public.products p where p.session_id in (select id from sessions)), 0) as scanned
$$;
grant execute on function public.get_dashboard_stats_for_current_user() to authenticated;
create or replace function public.delete_counting_session(p_session_id uuid)
returns void
language plpgsql
security definer
volatile
set search_path = public
as $$
declare
  v_emp bigint;
  v_owner bigint;
  v_role text;
begin
  select cs.id_empresa, cs.id_usuario into v_emp, v_owner
  from public.counting_sessions cs
  where cs.id = p_session_id;

  if v_emp is null then
    raise exception 'SessÃ£o nÃ£o encontrada';
  end if;

  select t.role into v_role
  from public.user_tenants t
  where t.auth_user_id = auth.uid()
    and t.id_empresa = v_emp
  limit 1;

  if v_role is null then
    raise exception 'PermissÃ£o negada';
  end if;

  if v_role <> 'admin' then
    perform 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = v_owner
      and t.id_empresa = v_emp;
    if not found then
      raise exception 'PermissÃ£o negada';
    end if;
  end if;

  delete from public.products where session_id = p_session_id;
  delete from public.counting_sessions where id = p_session_id;
end;
$$;
grant execute on function public.delete_counting_session(uuid) to authenticated;
create or replace function public.create_counting_session(
  p_id_usuario bigint,
  p_id_empresa bigint,
  p_session_name text,
  p_description text,
  p_count_type text,
  p_arquivo_uploaded text default null
)
returns public.counting_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  new_row public.counting_sessions;
begin
  insert into public.counting_sessions(
    id_usuario, id_empresa, session_name, description, count_type,
    status, total_items, counted_items, scanned_items, arquivo_uploaded
  )
  values (
    p_id_usuario, p_id_empresa, p_session_name, coalesce(p_description, ''),
    p_count_type, 'waiting', 0, 0, 0, p_arquivo_uploaded
  )
  returning * into new_row;
  return new_row;
end;
$$;
grant execute on function public.create_counting_session(bigint, bigint, text, text, text, text) to authenticated;

create or replace function public.update_session_status(
  p_session_id uuid,
  p_new_status text
)
returns void
language plpgsql
security definer
volatile
set search_path = public
as $$
declare
  v_emp bigint;
  v_owner bigint;
  v_role text;
begin
  select cs.id_empresa, cs.id_usuario into v_emp, v_owner
  from public.counting_sessions cs
  where cs.id = p_session_id;

  if v_emp is null then
    raise exception 'SessÃ£o nÃ£o encontrada';
  end if;

  select t.role into v_role
  from public.user_tenants t
  where t.auth_user_id = auth.uid()
    and t.id_empresa = v_emp
  limit 1;

  if v_role is null then
    raise exception 'PermissÃ£o negada';
  end if;

  if p_new_status not in ('waiting','active','completed','cancelled') then
    raise exception 'Status invÃ¡lido';
  end if;

  if v_role <> 'admin' then
    perform 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = v_owner
      and t.id_empresa = v_emp;
    if not found then
      raise exception 'PermissÃ£o negada';
    end if;
  end if;

  update public.counting_sessions
  set status = p_new_status,
      started_at = case when p_new_status = 'active' and started_at is null then now() else started_at end,
      ended_at = case when p_new_status = 'completed' then now() else null end
  where id = p_session_id
    and id_empresa = v_emp;
end;
$$;
grant execute on function public.update_session_status(uuid, text) to authenticated;

create or replace function public.update_session_counts(
  p_session_id uuid,
  p_counted_items integer,
  p_scanned_items integer
)
returns void
language plpgsql
security definer
volatile
set search_path = public
as $$
declare
  v_emp bigint;
  v_owner bigint;
  v_role text;
begin
  select cs.id_empresa, cs.id_usuario into v_emp, v_owner
  from public.counting_sessions cs
  where cs.id = p_session_id;

  if v_emp is null then
    raise exception 'SessÃ£o nÃ£o encontrada';
  end if;

  select t.role into v_role
  from public.user_tenants t
  where t.auth_user_id = auth.uid()
    and t.id_empresa = v_emp
  limit 1;

  if v_role is null then
    raise exception 'PermissÃ£o negada';
  end if;

  if v_role <> 'admin' then
    perform 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = v_owner
      and t.id_empresa = v_emp;
    if not found then
      raise exception 'PermissÃ£o negada';
    end if;
  end if;

  update public.counting_sessions
  set counted_items = p_counted_items,
      scanned_items = p_scanned_items
  where id = p_session_id
    and id_empresa = v_emp;
end;
$$;
grant execute on function public.update_session_counts(uuid, integer, integer) to authenticated;

create or replace function public.update_product_counts(
  p_session_id uuid,
  p_codigo text,
  p_new_quantidade_contada integer,
  p_new_scanned_qty integer,
  p_is_counted boolean default true
)
returns void
language plpgsql
security definer
volatile
set search_path = public
as $$
declare
  v_emp bigint;
  v_owner bigint;
  v_role text;
begin
  select cs.id_empresa, cs.id_usuario into v_emp, v_owner
  from public.counting_sessions cs
  where cs.id = p_session_id;

  if v_emp is null then
    raise exception 'SessÃ£o nÃ£o encontrada';
  end if;

  select t.role into v_role
  from public.user_tenants t
  where t.auth_user_id = auth.uid()
    and t.id_empresa = v_emp
  limit 1;

  if v_role is null then
    raise exception 'PermissÃ£o negada';
  end if;

  if v_role <> 'admin' then
    perform 1
    from public.user_tenants t
    where t.auth_user_id = auth.uid()
      and t.id_usuario = v_owner
      and t.id_empresa = v_emp;
    if not found then
      raise exception 'PermissÃ£o negada';
    end if;
  end if;

  update public.products p
  set quantidade_contada = p_new_quantidade_contada,
      scanned_qty = p_new_scanned_qty,
      is_counted = coalesce(p_is_counted, true)
  where p.session_id = p_session_id
    and p.codigo = p_codigo;
end;
$$;
grant execute on function public.update_product_counts(uuid, text, integer, integer, boolean) to authenticated;

create or replace function public.search_products_for_empresa(
  p_session_id uuid,
  p_search text,
  p_is_counted boolean
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
  created_at timestamptz,
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
    p.id, p.codigo, p.descricao, p.localizacao, p.quantidade_atual,
    p.quantidade_contada, p.scanned_qty, p.is_counted, p.expected_qty,
    p.session_id, p.created_at, cs.session_name as counting_session_name
  from public.products p
  join public.counting_sessions cs on cs.id = p.session_id
  join me on me.id_empresa = cs.id_empresa
  where (p_session_id is null or p.session_id = p_session_id)
    and (p_search is null 
         or p.codigo ilike '%'||p_search||'%'
         or p.descricao ilike '%'||p_search||'%')
    and (p_is_counted is null or p.is_counted = p_is_counted)
  order by p.created_at desc
$$;
grant execute on function public.search_products_for_empresa(uuid, text, boolean) to authenticated;

