from __future__ import annotations

import csv
from datetime import datetime
from pathlib import Path

from .model import Trade


def read_deals_csv(path: str | Path, *, magic: int = 5555, symbol_contains: str = "XAUUSD") -> list[Trade]:
    rows: list[Trade] = []
    with Path(path).open("r", newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        required = {"time", "profit", "magic", "symbol"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing CSV columns: {sorted(missing)}")
        for row in reader:
            row_magic = int(float(row["magic"]))
            symbol = row["symbol"]
            if row_magic != magic or symbol_contains not in symbol:
                continue
            ts = datetime.fromisoformat(row["time"])
            rows.append(
                Trade(
                    time=ts,
                    profit=float(row.get("profit") or 0.0),
                    symbol=symbol,
                    magic=row_magic,
                    ticket=int(row["ticket"]) if row.get("ticket") else None,
                    position_id=int(row["position_id"]) if row.get("position_id") else None,
                    volume=float(row.get("volume") or 0.0),
                    entry=int(row["entry"]) if row.get("entry") else None,
                    reason=int(row["reason"]) if row.get("reason") else None,
                    commission=float(row.get("commission") or 0.0),
                    swap=float(row.get("swap") or 0.0),
                )
            )
    return rows
