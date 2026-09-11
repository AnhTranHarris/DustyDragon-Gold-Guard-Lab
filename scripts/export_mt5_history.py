from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export MT5 deal history for Gold Guard research")
    p.add_argument("--from", dest="date_from", required=True)
    p.add_argument("--to", dest="date_to", required=True)
    p.add_argument("--symbol", default="XAUUSD")
    p.add_argument("--magic", type=int, default=5555)
    p.add_argument("--out", required=True)
    return p.parse_args()


def main() -> int:
    args = parse_args()
    try:
        import MetaTrader5 as mt5
    except ImportError:
        raise SystemExit("Install optional dependency first: pip install -e .[mt5]")

    date_from = datetime.fromisoformat(args.date_from)
    date_to = datetime.fromisoformat(args.date_to)
    if date_from.tzinfo is None:
        date_from = date_from.replace(tzinfo=timezone.utc)
    else:
        date_from = date_from.astimezone(timezone.utc)
    if date_to.tzinfo is None:
        date_to = date_to.replace(tzinfo=timezone.utc)
    else:
        date_to = date_to.astimezone(timezone.utc)

    if not mt5.initialize():
        raise SystemExit(f"mt5.initialize() failed: {mt5.last_error()}")
    try:
        deals = mt5.history_deals_get(date_from, date_to, group=f"*{args.symbol}*")
        if deals is None:
            raise SystemExit(f"history_deals_get failed: {mt5.last_error()}")
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        fields = [
            "ticket", "order", "time", "time_msc", "type", "entry", "magic",
            "position_id", "reason", "volume", "price", "commission", "swap",
            "profit", "fee", "symbol", "comment",
        ]
        with out.open("w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=fields)
            w.writeheader()
            count = 0
            for deal in deals:
                d = deal._asdict()
                if int(d.get("magic", 0)) != args.magic:
                    continue
                d["time"] = datetime.fromtimestamp(d["time"], tz=timezone.utc).isoformat()
                w.writerow({k: d.get(k, "") for k in fields})
                count += 1
        print(f"Exported {count} deals to {out}")
        return 0
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
