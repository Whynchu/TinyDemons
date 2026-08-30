create schema if not exists private;

create table if not exists private.recovery_vaults (
  vault_id text primary key check (length(vault_id) between 32 and 128),
  write_verifier text not null check (length(write_verifier) = 64),
  revision bigint not null default 1 check (revision > 0),
  cipher_version smallint not null default 1 check (cipher_version = 1),
  ciphertext text not null check (octet_length(ciphertext) <= 1048576),
  updated_at timestamptz not null default now(),
  expires_at timestamptz
);

revoke all on schema private from public, anon, authenticated;
revoke all on table private.recovery_vaults from public, anon, authenticated;

comment on table private.recovery_vaults is
  'Opaque client-encrypted Tiny Demons save vaults; accessible only through the recovery-vault Edge Function.';

create or replace function public.td_vault_read(requested_vault_id text)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'revision', revision,
    'cipher_version', cipher_version,
    'ciphertext', ciphertext,
    'updated_at', updated_at
  )
  from private.recovery_vaults
  where vault_id = requested_vault_id
    and (expires_at is null or expires_at > now());
$$;

create or replace function public.td_vault_create(
  requested_vault_id text,
  requested_write_verifier text,
  requested_ciphertext text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.recovery_vaults(vault_id, write_verifier, ciphertext)
  values (requested_vault_id, requested_write_verifier, requested_ciphertext)
  on conflict do nothing;
  return found;
end;
$$;

create or replace function public.td_vault_update(
  requested_vault_id text,
  requested_write_verifier text,
  requested_revision bigint,
  requested_ciphertext text
) returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare next_revision bigint;
begin
  update private.recovery_vaults
  set ciphertext = requested_ciphertext,
      revision = revision + 1,
      updated_at = now()
  where vault_id = requested_vault_id
    and write_verifier = requested_write_verifier
    and revision = requested_revision
  returning revision into next_revision;
  return next_revision;
end;
$$;

create or replace function public.td_vault_delete(
  requested_vault_id text,
  requested_write_verifier text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from private.recovery_vaults
  where vault_id = requested_vault_id
    and write_verifier = requested_write_verifier;
  return found;
end;
$$;

revoke all on function public.td_vault_read(text) from public, anon, authenticated;
revoke all on function public.td_vault_create(text, text, text) from public, anon, authenticated;
revoke all on function public.td_vault_update(text, text, bigint, text) from public, anon, authenticated;
revoke all on function public.td_vault_delete(text, text) from public, anon, authenticated;
grant execute on function public.td_vault_read(text) to service_role;
grant execute on function public.td_vault_create(text, text, text) to service_role;
grant execute on function public.td_vault_update(text, text, bigint, text) to service_role;
grant execute on function public.td_vault_delete(text, text) to service_role;
