# Data directory

Do not commit proprietary EX5 binaries, preset files, broker credentials, raw private account exports, or giant MT5 tester reports to this public repository.

Preferred research inputs:

- compact, sanitized CSV deal exports from `scripts/export_mt5_history.py`
- passive observer CSV from `mql5/DD_GoldGuardObserver.mq5`
- locally cached economic-calendar datasets for Strategy Tester

Gold Hunter V8 baseline identifiers currently used by the lab:

- Magic Number: `5555`
- baseline lot size: `0.01`
