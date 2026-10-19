"""Static safeguards for the SQL migration files.

These tests read the migration ``.sql`` files from disk and assert the agreed
safeguards. They never connect to, read from, or write to a database, and they
do not apply migrations.

Two kinds of checks are performed:

* **Immutability** - the historical migration ``0001`` is pinned by content
  digest so an accidental edit fails the suite.
* **Contract** - the forward-only reconcile (``0005``) and the ledger
  (``0004``) keep the agreed behaviors: lazy profile creation (no signup
  trigger), unchanged RLS policies, additive-only changes, and a ledger that
  records only its own version.
"""

from __future__ import annotations

import hashlib
import re
from pathlib import Path

MIGRATIONS_DIR = Path(__file__).resolve().parents[1] / "migrations"

# Content digest of the frozen historical migration, computed over the file
# text with CRLF/LF normalized so it is stable across checkouts. Update the
# digest ONLY alongside a deliberate, separately reviewed migration change.
_FROZEN_DIGESTS = {
    "0001_init.sql": (
        "917ef173f80f1c035a30e4679fdc08779d2ce48794dad29ab5b447199bbb234c"
    ),
}


def _read(name: str) -> str:
    return (MIGRATIONS_DIR / name).read_text(encoding="utf-8")


def _sql_only(text: str) -> str:
    """Return only executable lines, dropping comment-only lines.

    The migrations carry prose in ``--`` comments (including sample SQL), so
    assertions must inspect the executable SQL rather than the raw file.
    """
    return "\n".join(
        line for line in text.splitlines() if not line.strip().startswith("--")
    )


def _digest(name: str) -> str:
    normalized = _read(name).replace("\r\n", "\n").replace("\r", "\n")
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def test_historical_migrations_are_unchanged() -> None:
    for name, expected in _FROZEN_DIGESTS.items():
        assert _digest(name) == expected, f"{name} was modified; review required"


def test_ledger_creates_tracking_table() -> None:
    sql = _sql_only(_read("0004_schema_migrations.sql"))
    assert "create table if not exists public.schema_migrations" in sql
    assert "version" in sql
    assert "applied_at" in sql


def test_ledger_records_only_its_own_version() -> None:
    # The ledger must not fabricate history: the only recorded version is 0004.
    sql = _sql_only(_read("0004_schema_migrations.sql"))
    recorded = set(re.findall(r"values\s*\(\s*'(\d{4})'", sql))
    assert recorded == {"0004"}


def test_reconcile_does_not_register_signup_trigger() -> None:
    # Lazy-profile behavior: no trigger on auth.users.
    sql = _sql_only(_read("0005_reconcile_profiles.sql"))
    assert "on_auth_user_created" not in sql
    assert "handle_new_user" not in sql
    assert "auth.users" not in sql


def test_reconcile_does_not_touch_rls_policies() -> None:
    # Authenticated access is preserved by leaving the policy set untouched.
    sql = _sql_only(_read("0005_reconcile_profiles.sql"))
    assert "drop policy" not in sql
    assert "create policy" not in sql
    assert "enable row level security" not in sql


def test_reconcile_aligns_profile_contract() -> None:
    sql = _sql_only(_read("0005_reconcile_profiles.sql"))
    assert "add column if not exists username text" in sql
    assert "add column if not exists preferred_language text default 'en'" in sql
    assert "alter column preferred_language set default 'en'" in sql
    assert "create unique index if not exists profiles_username_key" in sql
    assert "alter column created_at set not null" in sql
    assert "alter column updated_at set not null" in sql


def test_reconcile_guards_trigger_without_replacing_it() -> None:
    sql = _sql_only(_read("0005_reconcile_profiles.sql"))
    assert "create or replace function public.set_updated_at" in sql
    assert "pg_trigger" in sql
    assert "drop trigger" not in sql


def test_reconcile_records_only_its_own_version() -> None:
    sql = _sql_only(_read("0005_reconcile_profiles.sql"))
    recorded = set(re.findall(r"select\s+'(\d{4})'", sql))
    assert recorded == {"0005"}
    assert "schema_migrations" in sql
