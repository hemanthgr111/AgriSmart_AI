-- =============================================================================
-- AgriSmart AI - Migration ledger
-- Creates application-level tracking for this project's migrations.
--
-- Context: migrations 0001-0003 predate any tracking table. Their application
-- history is NOT verified, so this ledger must never pre-seed rows for them.
-- A version is recorded ONLY after that file executed successfully against the
-- database in question (evidence-first). Absence of evidence = do not record.
--
-- Execution order:
--   Existing (live) database: run this file FIRST (0004), then 0005. 0001/0002
--   are pre-ledger baselines; the removed 0003 draft is superseded by 0005 and
--   none may be recorded on the live database without evidence.
--   Fresh database: run this file FIRST (0004), then 0001, then 0005,
--   recording 0001 and 0005 immediately after each succeeds.
--
-- Idempotent - safe to re-run.
-- =============================================================================

create table if not exists public.schema_migrations (
    version     text primary key,
    name        text not null,
    applied_at  timestamptz not null default now()
);

-- Record this file's own execution (the table now exists).
insert into public.schema_migrations (version, name)
values ('0004', '0004_schema_migrations.sql')
on conflict (version) do nothing;

-- =============================================================================
-- Recording a migration (performed by the operator immediately after the file
-- succeeds, never inside the migration):
--
--   insert into public.schema_migrations (version, name)
--   values ('0001', '0001_init.sql')
--   on conflict (version) do nothing;
--
-- A version may be recorded ONLY after that migration was executed
-- successfully against this database. Absence of evidence = do not record.
-- =============================================================================
