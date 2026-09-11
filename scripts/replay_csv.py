from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from gold_guard.csvio import read_deals_csv
from gold_guard.model import MarketSnapshot
from gold_guard.policy import GuardPolicy, PolicyConfig
from gold_guard.replay import replay


def main() -> int:
    p = argparse.ArgumentParser(description="Replay a Gold Hunter deal export")
    p.add_argument("csv")
    p.add_argument("--policy", default="config/research_seed.json")
    p.add_argument("--window", type=int, default=30)
    args = p.parse_args()

    cfg_raw = json.loads(Path(args.policy).read_text(encoding="utf-8"))
    config = PolicyConfig(**cfg_raw)
    policy = GuardPolicy(config)
    trades = read_deals_csv(args.csv)

    result = replay(
        trades,
        policy,
        lambda t: MarketSnapshot(time=t.time),
        window_size=args.window,
    )
    print(json.dumps({k: v for k, v in asdict(result).items() if k != "decisions"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
