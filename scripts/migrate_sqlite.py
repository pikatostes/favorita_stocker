#!/usr/bin/env python3
"""Migra la base SQLite de favorita_stocker a Supabase.

Uso:
    # 1. Exportar la SQLite a JSON (no toca la red)
    python scripts/migrate_sqlite.py export --db privado/stock_bar.db

    # 2. Importar a Supabase (necesita la clave SECRETA, solo en local)
    $env:SUPABASE_URL = "https://xxxx.supabase.co"
    $env:SUPABASE_SECRET_KEY = "sb_secret_..."
    python scripts/migrate_sqlite.py push

    # 3. Verificar conteos
    python scripts/migrate_sqlite.py verify

La clave secreta NUNCA se escribe en el repo ni se pasa por el chat.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_DB = ROOT / "privado" / "stock_bar.db"
DEFAULT_JSON = ROOT / "privado" / "export.json"

# Orden de inserción respetando las claves foráneas.
TABLES = [
    "category",
    "box_type",
    "product_group",
    "subcategory",
    "product",
    "night",
    "consumption",
    "special_day",
    "job_role",
    "profiles",
    "shift",
]

COUNT_TABLES = [
    "category",
    "box_type",
    "product_group",
    "subcategory",
    "product",
    "night",
    "consumption",
    "special_day",
    "job_role",
    "profiles",
    "shift",
]


def iso_from_ms(value: object) -> str | None:
    if value is None:
        return None
    try:
        ms = int(value)
    except (TypeError, ValueError):
        return None
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).isoformat()


def as_bool(value: object) -> bool:
    return value in (1, "1", True, "true", "t")


def as_int(value: object, default: int = 0) -> int:
    if value is None:
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def as_float(value: object, default: float = 1.0) -> float:
    try:
        result = float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return default
    return result if result > 0 else default


def rows(conn: sqlite3.Connection, sql: str) -> list[dict]:
    conn.row_factory = sqlite3.Row
    return [dict(row) for row in conn.execute(sql).fetchall()]


def export(db_path: Path, out_path: Path) -> dict:
    if not db_path.exists():
        raise SystemExit(f"No existe la base de datos: {db_path}")

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        category = rows(conn, "SELECT id, name FROM category ORDER BY id")

        box_type = [
            {
                "id": r["id"],
                "type": r["type"],
                "units_per_box": as_int(r["units_per_box"], 24),
                "size": as_float(r["size"]),
                "height": as_float(r["height"]),
                "width": as_float(r["width"]),
                "format": as_int(r["format"], 1),
                "trip_capacity": as_int(r["trip_capacity"], 5),
                "created_at": iso_from_ms(r["created_at"]),
                "updated_at": iso_from_ms(r["updated_at"]),
            }
            for r in rows(conn, "SELECT * FROM box ORDER BY id")
        ]

        product_group = [
            {
                "id": r["id"],
                "category_id": r["category_id"],
                "name": r["name"],
                "image": r["image"],
                "created_at": iso_from_ms(r["created_at"]),
                "updated_at": iso_from_ms(r["updated_at"]),
            }
            for r in rows(conn, "SELECT * FROM product_group ORDER BY id")
        ]

        subcategory = [
            {"id": r["id"], "group_id": r["group_id"], "name": r["name"]}
            for r in rows(conn, "SELECT * FROM subcategory ORDER BY id")
        ]

        product = [
            {
                "id": r["id"],
                "name": r["name"],
                "box_id": r["box_id"],
                "group_id": r["group_id"],
                "subcategory_id": r["subcategory_id"],
                "image": r["image"],
                "unit_in_stock": as_int(r["unit_in_stock"], 0),
                "created_at": iso_from_ms(r["created_at"]),
                "updated_at": iso_from_ms(r["updated_at"]),
                "deleted_at": iso_from_ms(r["deleted_at"]),
            }
            for r in rows(conn, "SELECT * FROM product ORDER BY id")
        ]

        night = [
            {
                "id": r["id"],
                "date": r["date"],
                "note": r["note"],
                "created_at": iso_from_ms(r["created_at"]),
            }
            for r in rows(conn, "SELECT * FROM night ORDER BY id")
        ]

        consumption = [
            {
                "id": r["id"],
                "night_id": r["night_id"],
                "product_id": r["product_id"],
                "quantity": as_int(r["quantity"], 0),
            }
            for r in rows(conn, "SELECT * FROM consumption ORDER BY id")
        ]

        special_day = [
            {
                "date": r["date"],
                "open": as_bool(r["open"]),
                "note": r["note"],
            }
            for r in rows(conn, "SELECT * FROM special_day ORDER BY date")
        ]

        job_role = [
            {
                "id": r["id"],
                "name": r["name"],
                "name_key": r["name_key"] or r["name"].strip().lower(),
                "floor": r["floor"],
                "note": r["note"] or "",
                "created_at": iso_from_ms(r["created_at"]),
                "updated_at": iso_from_ms(r["updated_at"]),
            }
            for r in rows(conn, "SELECT * FROM role ORDER BY id")
        ]

        users = [
            {
                "old_id": r["id"],
                "name": r["name"],
                "surname": r["surname"] or "",
                "email": (r["email"] or "").strip().lower(),
                "role": r["role"] or "employee",
                "job_role_id": r["role_id"],
                "active": as_bool(r["active"]),
                "opener": as_bool(r["opener"]),
                "working_days": r["working_days"] or "",
                "created_at": iso_from_ms(r["created_at"]),
                "updated_at": iso_from_ms(r["updated_at"]),
            }
            for r in rows(conn, "SELECT * FROM users ORDER BY id")
        ]

        shift = [
            {
                "id": r["id"],
                "date": r["date"],
                "old_user_id": r["user_id"],
                "user_name": r["user_name"],
                "role_id": r["role_id"],
                "role_name": r["role_name"],
                "floor": r["floor"],
                "start_min": as_int(r["start_min"]),
                "end_min": as_int(r["end_min"]),
                "break_min": as_int(r["break_min"]),
                "status": r["status"] or "borrador",
                "note": r["note"],
                "created_at": iso_from_ms(r["created_at"]),
                "updated_at": iso_from_ms(r["updated_at"]),
            }
            for r in rows(conn, "SELECT * FROM shift ORDER BY id")
        ]
    finally:
        conn.close()

    data = {
        "meta": {
            "source": str(db_path),
            "exported_at": datetime.now(timezone.utc).isoformat(),
            "counts": {
                "category": len(category),
                "box_type": len(box_type),
                "product_group": len(product_group),
                "subcategory": len(subcategory),
                "product": len(product),
                "night": len(night),
                "consumption": len(consumption),
                "special_day": len(special_day),
                "job_role": len(job_role),
                "users": len(users),
                "shift": len(shift),
            },
        },
        "category": category,
        "box_type": box_type,
        "product_group": product_group,
        "subcategory": subcategory,
        "product": product,
        "night": night,
        "consumption": consumption,
        "special_day": special_day,
        "job_role": job_role,
        "users": users,
        "shift": shift,
    }

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), "utf-8")

    print(f"Exportado: {out_path}")
    for table, count in data["meta"]["counts"].items():
        print(f"  {table:15} {count:6}")
    return data


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Falta la variable de entorno {name}")
    return value


def request(
    url: str,
    method: str,
    key: str,
    body: object | None = None,
    headers: dict[str, str] | None = None,
) -> tuple[int, str, dict[str, str]]:
    data = None
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode("utf-8")

    request_headers = {
        "apikey": key,
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates,return=minimal",
    }
    if headers:
        request_headers.update(headers)

    req = urllib.request.Request(
        url, data=data, method=method, headers=request_headers
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status, resp.read().decode("utf-8"), dict(resp.headers)
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8"), dict(error.headers)


def rest_upsert(base: str, key: str, table: str, payload: list[dict]) -> None:
    if not payload:
        return
    status, body, _ = request(f"{base}/rest/v1/{table}", "POST", key, payload)
    if status >= 300:
        raise SystemExit(f"Error insertando {table} ({status}): {body}")
    print(f"  {table:15} {len(payload):6} filas")


def admin_request(
    base: str, key: str, path: str, body: object | None = None
) -> tuple[int, object]:
    status, text, _ = request(
        f"{base}{path}",
        "POST" if body is not None else "GET",
        key,
        body,
        {"Authorization": f"Bearer {key}"},
    )
    try:
        parsed = json.loads(text) if text else None
    except json.JSONDecodeError:
        parsed = text
    return status, parsed


def list_auth_users(base: str, key: str) -> list[dict]:
    users: list[dict] = []
    page = 1
    while True:
        status, data = admin_request(
            base, key, f"/auth/v1/admin/users?page={page}&per_page=100"
        )
        if status >= 300:
            raise SystemExit(f"Error listando usuarios ({status}): {data}")
        if not isinstance(data, dict):
            break
        batch = data.get("users", [])
        if not batch:
            break
        users.extend(batch)
        if len(batch) < 100:
            break
        page += 1
    return users


def push(json_path: Path, password: str) -> None:
    if not json_path.exists():
        raise SystemExit(f"No existe el export: {json_path}")

    data = json.loads(json_path.read_text("utf-8"))
    base = env("SUPABASE_URL").rstrip("/")
    key = env("SUPABASE_SECRET_KEY")

    print("1) Creando/cargando cuentas de Auth…")
    existing = {u["email"].lower(): u for u in list_auth_users(base, key) if u.get("email")}
    old_to_auth: dict[int, str] = {}

    for user in data["users"]:
        email = user["email"]
        auth_user = existing.get(email)
        if auth_user is None:
            status, created = admin_request(
                base,
                key,
                "/auth/v1/admin/users",
                {
                    "email": email,
                    "password": password,
                    "email_confirm": True,
                    "user_metadata": {
                        "name": user["name"],
                        "surname": user["surname"],
                    },
                },
            )
            if status >= 300 or not isinstance(created, dict):
                raise SystemExit(f"Error creando {email} ({status}): {created}")
            auth_user = created
            print(f"  creado {email}")
        else:
            print(f"  existe {email}")
        old_to_auth[user["old_id"]] = auth_user["id"]

    print("2) Leyendo perfiles creados por el trigger…")
    status, profiles = request(
        f"{base}/rest/v1/profiles?select=id,auth_id,email", "GET", key
    )
    if status >= 300:
        raise SystemExit(f"Error leyendo profiles ({status}): {profiles}")
    profile_rows = json.loads(profiles) if profiles else []
    auth_to_profile = {p["auth_id"]: p for p in profile_rows}

    old_to_profile: dict[int, int] = {}
    profile_payload: list[dict] = []
    for user in data["users"]:
        auth_id = old_to_auth[user["old_id"]]
        profile = auth_to_profile.get(auth_id)
        if not profile:
            raise SystemExit(
                f"No se creó el perfil de {user['email']}. "
                "¿Está el trigger handle_new_user instalado?"
            )
        old_to_profile[user["old_id"]] = profile["id"]
        profile_payload.append(
            {
                "auth_id": auth_id,
                "name": user["name"],
                "surname": user["surname"],
                "email": user["email"],
                "role": user["role"],
                "job_role_id": user["job_role_id"],
                "active": user["active"],
                "opener": user["opener"],
                "working_days": user["working_days"],
                "must_change_password": True,
                "created_at": user["created_at"],
                "updated_at": user["updated_at"],
            }
        )

    # Los perfiles ya existen: se actualizan por auth_id, no se insertan.
    print("3) Actualizando perfiles…")
    for profile in profile_payload:
        status, body, _ = request(
            f"{base}/rest/v1/profiles?auth_id=eq.{profile['auth_id']}",
            "PATCH",
            key,
            {k: v for k, v in profile.items() if k != "auth_id"},
        )
        if status >= 300:
            raise SystemExit(f"Error actualizando perfil ({status}): {body}")
    print(f"  profiles        {len(profile_payload):6} filas")

    print("4) Insertando datos…")
    for table in TABLES:
        if table in ("profiles", "shift"):
            continue
        rest_upsert(base, key, table, data.get(table, []))

    shifts = []
    for shift in data.get("shift", []):
        profile_id = old_to_profile.get(shift["old_user_id"])
        if profile_id is None:
            raise SystemExit(
                f"Turno {shift['id']} apunta a un usuario inexistente "
                f"({shift['old_user_id']})"
            )
        payload = {k: v for k, v in shift.items() if k != "old_user_id"}
        payload["user_id"] = profile_id
        shifts.append(payload)

    rest_upsert(base, key, "shift", shifts)

    print("5) Reajustando secuencias…")
    status, body, _ = request(f"{base}/rest/v1/rpc/reset_sequences", "POST", key, {})
    if status >= 300:
        print(
            f"  AVISO: no se pudieron reajustar las secuencias ({status}): {body}\n"
            "  Ejecuta a mano el SQL de reset_sequences o revisa sus grants."
        )
    else:
        print("  secuencias OK")

    print("Migración terminada.")


def verify() -> None:
    base = env("SUPABASE_URL").rstrip("/")
    key = env("SUPABASE_SECRET_KEY")
    print("Conteos en Supabase:")
    for table in COUNT_TABLES:
        status, body, headers = request(
            f"{base}/rest/v1/{table}?select=*",
            "GET",
            key,
            headers={"Range": "0-0", "Prefer": "count=exact"},
        )
        if status >= 300:
            print(f"  {table:15} ERROR {status}: {body}")
            continue
        content_range = headers.get("Content-Range", "0-0/0")
        total = content_range.split("/")[-1]
        print(f"  {table:15} {total:>6}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action", choices=["export", "push", "verify"], help="Acción a ejecutar"
    )
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--json", type=Path, default=DEFAULT_JSON)
    parser.add_argument(
        "--password",
        default="favorita",
        help="Contraseña temporal de las cuentas nuevas (por defecto: favorita)",
    )
    args = parser.parse_args()

    if args.action == "export":
        export(args.db, args.json)
    elif args.action == "push":
        push(args.json, args.password)
    elif args.action == "verify":
        verify()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
