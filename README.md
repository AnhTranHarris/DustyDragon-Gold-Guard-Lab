# Dusty Dragon Gold Guard Lab

Public research harness for supervising **Gold Hunter V8** without modifying its compiled EX5.

> **Repository hygiene:** this repository is public. Do **not** commit the Gold Hunter EX5, third-party preset files, broker credentials, account identifiers, raw private account exports, or other proprietary/private artifacts. Only original research code, hashes, sanitized telemetry, and derived research outputs belong here.

## Scope

This milestone is deliberately **research-only**. It does not place trades, close positions, cancel Gold Hunter orders, or toggle AutoTrading. It answers one question first:

> When did Gold Hunter's edge appear active, and when should a future guard have suspended new risk?

The lab combines:

- Gold Hunter trade-history telemetry (Magic Number `5555`)
- rolling expectancy / win-rate / profit-factor / losing-streak signals
- weekend and holiday-risk flags
- spread and directional-efficiency features when available
- high-impact USD event proximity when supplied
- replay scoring with GREEN / AMBER / RED decisions

## Why a research harness first?

A guard tuned directly inside MT5 can accidentally overfit 2024/2025. This harness lets us replay candidate rules, measure profit retained versus losses avoided, and freeze a policy before implementing live trade intervention.

## Quick start

Python 3.11+.

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -e .
python -m unittest discover -s tests -v
```

To export historical deals directly from a local MT5 terminal (official MetaQuotes Python package required on Windows):

```powershell
python scripts\export_mt5_history.py --from 2025-01-01 --to 2025-12-31 --symbol XAUUSD --magic 5555 --out data\deals_2025.csv
```

Replay them:

```powershell
python scripts\replay_csv.py data\deals_2025.csv --policy config\research_seed.json
```

## MetaQuotes design constraints

- Economic Calendar API timestamps use **trade-server time**.
- Economic Calendar functions are **not available inside Strategy Tester**; historical calendar data must be cached/exported for tester use.
- The passive observer keeps `OnTradeTransaction()` lightweight and defers telemetry I/O/news lookup to `OnTimer()` so high-frequency trade events do not spend unnecessary time in MetaTrader's trade-transaction queue.
- Broker session boundaries should ultimately be derived from `SymbolInfoSessionTrade()` rather than hard-coded clock assumptions.

See `docs/metaquotes-research.md` for the source-backed engineering notes.

## Current stage

**M001**: Gold Guard research harness + passive MQL5 observer. No intervention logic is enabled yet.
