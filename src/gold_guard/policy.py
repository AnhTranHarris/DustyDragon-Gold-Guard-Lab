from __future__ import annotations

from dataclasses import dataclass

from .metrics import RollingMetrics
from .model import Decision, DecisionRecord, MarketSnapshot


@dataclass(frozen=True)
class PolicyConfig:
    min_trades_for_expectancy: int = 20
    red_profit_factor: float = 0.80
    amber_profit_factor: float = 1.10
    red_win_rate: float = 0.40
    amber_win_rate: float = 0.50
    red_loss_streak: int = 10
    amber_loss_streak: int = 6
    max_spread_points_green: float = 60.0
    max_spread_points_amber: float = 100.0
    min_directional_efficiency_green: float = 0.30
    min_directional_efficiency_amber: float = 0.15
    high_impact_window_minutes: float = 30.0
    friday_lock_hour_server: int = 20
    monday_reopen_guard_minutes: int = 90
    session_close_guard_minutes: int = 45


class GuardPolicy:
    """Research policy: calendar proximity alone never forces RED."""

    def __init__(self, config: PolicyConfig) -> None:
        self.config = config

    def evaluate(self, metrics: RollingMetrics, market: MarketSnapshot) -> DecisionRecord:
        score = 100.0
        reasons: list[str] = []
        hard_red = False

        if market.is_holiday:
            hard_red = True
            reasons.append("holiday-risk")

        if market.time.weekday() == 4 and market.time.hour >= self.config.friday_lock_hour_server:
            hard_red = True
            reasons.append("friday-close-risk")

        if (
            market.time.weekday() == 0
            and market.minutes_from_session_open is not None
            and market.minutes_from_session_open < self.config.monday_reopen_guard_minutes
        ):
            hard_red = True
            reasons.append("monday-reopen-risk")

        if (
            market.minutes_to_session_close is not None
            and market.minutes_to_session_close < self.config.session_close_guard_minutes
        ):
            score -= 30
            reasons.append("near-session-close")

        if metrics.count >= self.config.min_trades_for_expectancy:
            if metrics.profit_factor < self.config.red_profit_factor:
                hard_red = True
                reasons.append("rolling-pf-red")
            elif metrics.profit_factor < self.config.amber_profit_factor:
                score -= 30
                reasons.append("rolling-pf-amber")

            if metrics.win_rate < self.config.red_win_rate:
                hard_red = True
                reasons.append("rolling-winrate-red")
            elif metrics.win_rate < self.config.amber_win_rate:
                score -= 25
                reasons.append("rolling-winrate-amber")

        if metrics.loss_streak >= self.config.red_loss_streak:
            hard_red = True
            reasons.append("loss-streak-red")
        elif metrics.loss_streak >= self.config.amber_loss_streak:
            score -= 25
            reasons.append("loss-streak-amber")

        if market.spread_points is not None:
            if market.spread_points > self.config.max_spread_points_amber:
                hard_red = True
                reasons.append("spread-red")
            elif market.spread_points > self.config.max_spread_points_green:
                score -= 25
                reasons.append("spread-amber")

        if market.directional_efficiency is not None:
            if market.directional_efficiency < self.config.min_directional_efficiency_amber:
                hard_red = True
                reasons.append("whipsaw-red")
            elif market.directional_efficiency < self.config.min_directional_efficiency_green:
                score -= 25
                reasons.append("whipsaw-amber")

        if (
            market.high_impact_usd_minutes is not None
            and abs(market.high_impact_usd_minutes) <= self.config.high_impact_window_minutes
        ):
            score -= 15
            reasons.append("high-impact-usd-near")

        if hard_red:
            decision = Decision.RED
            score = min(score, 39.0)
        elif score < 60:
            decision = Decision.RED
        elif score < 80:
            decision = Decision.AMBER
        else:
            decision = Decision.GREEN

        return DecisionRecord(
            time=market.time,
            decision=decision,
            score=max(0.0, min(100.0, score)),
            reasons=tuple(reasons),
        )
