# MetaQuotes design research for M001

This milestone intentionally follows documented MT5/MQL5 behavior rather than UI automation or undocumented terminal hooks.

## 1. Trade attribution by Magic Number

Gold Hunter V8's preset uses Magic Number `5555`. MQL5 exposes `DEAL_MAGIC`, `ORDER_MAGIC`, and `POSITION_MAGIC`. Historical deals can be read with `HistoryDealGetInteger`; open orders/positions can be enumerated with `OrderGetTicket` / `PositionGetTicket` and corresponding property getters.

Sources:
- https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties
- https://www.mql5.com/en/docs/trading/HistoryDealGetInteger
- https://www.mql5.com/en/docs/trading/OrderGetInteger
- https://www.mql5.com/en/docs/trading/positiongetinteger

## 2. Event-driven telemetry

`OnTradeTransaction()` receives server-originated trade-transaction events, including pending-order activation and deal additions. MetaQuotes warns that account state can continue changing while the handler is executing, and the transaction queue is limited to 1024 elements. A slow handler can therefore allow older transactions to be superseded.

M001 keeps `OnTradeTransaction()` intentionally lightweight: it validates Hunter deals and queues the ticket. Calendar lookup, file output and flushing are deferred to `OnTimer()`.

Sources:
- https://www.mql5.com/en/docs/event_handlers/ontradetransaction
- https://www.mql5.com/en/book/automation/experts/experts_ontradetransaction

## 3. Timed market-state sampling

`EventSetTimer()` + `OnTimer()` gives each EA its own periodic timer. We use a one-second observer timer for research telemetry, not for trading decisions yet.

Sources:
- https://www.mql5.com/en/docs/eventfunctions/eventsettimer
- https://www.mql5.com/en/docs/event_handlers/ontimer

## 4. Spread / tick data

MetaQuotes recommends `SymbolInfoTick()` for current Bid/Ask. Spread in points can be computed from `(ask-bid)/SYMBOL_POINT`; `SymbolInfoInteger(..., SYMBOL_SPREAD)` is also available.

Sources:
- https://www.mql5.com/en/docs/marketinformation/symbolinfotick
- https://www.mql5.com/en/docs/marketinformation/symbolinfointeger
- https://www.mql5.com/en/docs/marketinformation/symbolinfodouble

## 5. Broker trading sessions

`SymbolInfoSessionTrade()` exposes session start/end by symbol and weekday. This is preferable to hard-coding a universal Friday close or Monday reopen clock. M001 keeps the Python policy threshold configurable; a later milestone will derive broker session boundaries directly.

Source:
- https://www.mql5.com/en/docs/marketinformation/symbolinfosessiontrade

## 6. Economic calendar

`CalendarValueHistory()` supports currency filtering such as USD. `CalendarEventById()` exposes importance and event name. Calendar timestamps use **trade-server time**, not the user's local time.

Sources:
- https://www.mql5.com/en/docs/calendar
- https://www.mql5.com/en/docs/calendar/calendarvaluehistory
- https://www.mql5.com/en/docs/calendar/calendareventbyid
- https://www.mql5.com/en/docs/constants/structures/mqlcalendar

### Critical tester limitation

MetaQuotes' Algo Book states calendar functions cannot be used in Strategy Tester; calls produce `FUNCTION_NOT_ALLOWED (4014)`. Historical calendar testing therefore requires first saving/caching calendar records while online, then loading that deterministic dataset in the tester. MetaQuotes also notes that trade-server timezone/DST handling matters for historical news alignment.

Sources:
- https://www.mql5.com/en/book/advanced/calendar
- https://www.mql5.com/en/book/advanced/calendar/calendar_cache_tester
- https://www.mql5.com/en/book/advanced/calendar/calendar_trading

This is why M001 does **not** pretend a live calendar query can make historical tester runs reproducible. A future Guard backtest will use an exported historical calendar dataset or embedded resource.

## 7. File telemetry and sandboxing

MQL5 file operations are sandboxed. `FILE_COMMON` writes to the shared terminal common-files directory, allowing the observer output to be consumed by another local process without DLLs. `FileOpen()` can create missing subfolders for write access.

Sources:
- https://www.mql5.com/en/docs/files/fileopen
- https://www.mql5.com/en/docs/files/FileWrite
- https://www.mql5.com/en/docs/constants/io_constants/fileflags

## 8. Strategy Tester fidelity

For a seconds-scale XAUUSD system, use `Every tick based on real ticks`. MetaTrader documentation states this uses broker-accumulated real tick data and is the closest tester mode to real conditions. Faster OHLC/open-price modes are unsuitable as final evidence for this scalper.

Source:
- https://www.metatrader5.com/en/terminal/help/algotrading/testing

## 9. Python bridge

MetaQuotes' official Python integration can retrieve historical deals, orders, bars and ticks from the local terminal. `history_deals_get` is therefore the preferred ingestion path for the research harness instead of depending on enormous tester HTML/XLSX exports.

Sources:
- https://www.mql5.com/en/docs/python_metatrader5
- https://www.mql5.com/en/docs/python_metatrader5/mt5historydealsget_py
- https://www.mql5.com/en/docs/python_metatrader5/mt5historyordersget_py
- https://www.mql5.com/en/docs/python_metatrader5/mt5copyticksrange_py

## 10. No intervention in M001

The observer does not call `CTrade`, `OrderDelete`, `PositionClose`, `ChartApplyTemplate`, `ExpertRemove`, or terminal-wide AutoTrading controls. We need to establish whether the proposed policy improves selectivity before giving it authority over Gold Hunter.
