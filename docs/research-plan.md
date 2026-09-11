# Gold Guard research plan

## Data roles

- **2024:** failure discovery / whipsaw stress. Do not tune for profit.
- **2025:** calibration / robustness. Contains large profitable regime plus weekend/holiday failures.
- **2026 Jan-Aug:** validation against a very favorable Gold Hunter regime. Guard must not destroy the edge.
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

## Anti-overfit procedure

1. Seed broad thresholds from known failure signatures.
2. Calibrate only on 2024 + 2025.
3. Require robustness across nearby parameter values, not one exact winner.
4. Validate unchanged on 2026 Jan-Aug.
5. Freeze policy.
6. Run 2023 once as blind validation.
7. Only then implement active MQL5 intervention.

## Important replay limitation

The Python counterfactual replay can tell us which historical trades would have been blocked. It cannot know which future trades Gold Hunter would have generated after being suspended. Therefore Python replay is a **screening tool**, not final backtest evidence. Final evidence must come from MT5 Strategy Tester with an intervention-capable controller and deterministic cached news inputs.
