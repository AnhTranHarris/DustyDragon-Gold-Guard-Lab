# Gold Guard research plan

## Data roles

- **2024:** failure discovery / whipsaw stress. Do not tune for profit.
- **2025:** calibration / robustness. Contains large profitable regime plus weekend/holiday failures.
- **2026 Jan-Aug:** validation against a very favorable Gold Hunter regime. Guard must not destroy the edge.
- **2026-09-13/14 live sample:** live failure signature / runtime calibration evidence only. Do not optimize exclusively to this one session.
- **2023:** keep sealed for final out-of-sample validation after policy freeze.

## Primary objective

Maximize profitable-trade retention while removing disproportionate loss regimes.

Track two explicit ratios:

1. **Profit Retention Ratio** = retained gross winning P&L / baseline gross winning P&L.
2. **Prevented Loss Ratio** = blocked gross losing P&L / baseline gross losing P&L.

A candidate guard is rejected if it achieves lower drawdown mainly by suppressing most of Gold Hunter's profitable opportunity.

## Vulnerability signatures to test

1. **Whipsaw attrition** — rapid stop-outs, falling rolling PF/win rate, low directional efficiency.
2. **Weekend / reopen dislocation** — Friday carry and first liquidity after reopening.
3. **Holiday liquidity** — Thanksgiving/Christmas/New Year/abnormal session schedules.
4. **Spread/execution degradation** — widening Bid/Ask relative to recent baseline.
5. **High-impact USD events** — treated as a risk multiplier, not an unconditional shutdown.
6. **Fast expectancy collapse** — a very poor rolling-10 PF + win-rate combination can trip RED before a slower rolling-20 confirmation window.

## 2026-09-13/14 live evidence

The first live Hunter-attribution sample produced a persistent negative-expectancy burst rather than one isolated bad trade. Approximate exit-level reconstruction from the observer showed the first 10 exits at PF ~0.19, win rate 30%, net about -5.93. A fast-collapse rule using PF <= 0.45, win rate <= 30%, negative net and 10 completed exits would have turned RED around 04:01:30 quote-server time in this sample. From that point to the end of the capture, roughly another 43.91 of balance deterioration occurred. Treat this as a hypothesis generator, not proof of a production threshold.

## Community cross-check incorporated into M002

Recent ForexFactory Gold breakout/scalping discussions repeatedly emphasize that blind first-touch breakouts are vulnerable to fake breaks, spread widening and exhausted session moves. Suggested mitigations include waiting for confirmed closes, using ATR/body-quality filters, and avoiding repeated attempts after an initial failed breakout. Reddit systematic-trading discussions independently converge on regime filters, directional-efficiency / trend-strength measures, volatility filters and explicit sit-out logic during chop. These are community observations rather than authoritative evidence, so M002 uses them only to define hypotheses that must survive our own replay and live evidence.

## M002 guard design

The M002 MQL5 guard remains advisory-only. It does not send, close, delete or modify trades. It adds:

- rolling 10-trade fast-collapse metrics;
- rolling 20-trade confirmation metrics;
- consecutive-loss detection;
- 60-second directional-efficiency estimation from observed mid-price path;
- adaptive spread stress relative to an EWMA baseline instead of fixed XAUUSD point thresholds;
- broker-data-driven market-reopen detection from long tick gaps, followed by a warm-up state;
- high-impact USD calendar telemetry retained as a risk context, not an automatic RED by itself;
- state/reason logging to `regime_guard.csv`.

Active intervention remains deferred until the guard policy passes historical replay and live shadow-mode validation. Applying templates or removing the Hunter while it has pending orders or open positions can create unmanaged state, so that control path must be separately tested before it is permitted to act.

## Anti-overfit procedure

1. Seed broad thresholds from known failure signatures.
2. Calibrate only on 2024 + 2025 plus explicitly labeled live failure evidence.
3. Require robustness across nearby parameter values, not one exact winner.
4. Validate unchanged on 2026 Jan-Aug.
5. Shadow-run M002 live and compare GREEN/AMBER/RED decisions with actual subsequent Hunter outcomes.
6. Freeze policy.
7. Run 2023 once as blind validation.
8. Only then implement active MQL5 intervention.

## Important replay limitation

The Python counterfactual replay can tell us which historical trades would have been blocked. It cannot know which future trades Gold Hunter would have generated after being suspended. Therefore Python replay is a **screening tool**, not final backtest evidence. Final evidence must come from MT5 Strategy Tester with an intervention-capable controller and deterministic cached news inputs.
