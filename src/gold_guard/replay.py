from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterable

from .metrics import RollingTradeWindow
from .model import Decision, DecisionRecord, MarketSnapshot, Trade
from .policy import GuardPolicy


@dataclass(frozen=True)
class ReplayResult:
    baseline_net: float
    guarded_net: float
    blocked_profit: float
    blocked_loss: float
    retained_profit_ratio: float
    prevented_loss_ratio: float
    decisions: tuple[DecisionRecord, ...]


MarketProvider = Callable[[Trade], MarketSnapshot]


def replay(
    trades: Iterable[Trade],
    policy: GuardPolicy,
    market_provider: MarketProvider,
    window_size: int = 30,
) -> ReplayResult:
    """Counterfactual selectivity screen, not a valid MT5 intervention backtest."""
    window = RollingTradeWindow(window_size)
    baseline_net = 0.0
    guarded_net = 0.0
    blocked_profit = 0.0
    blocked_loss = 0.0
    gross_loss = 0.0
    gross_profit = 0.0
    decisions: list[DecisionRecord] = []

    for trade in sorted(trades, key=lambda t: t.time):
        net = trade.net
        baseline_net += net
        if net > 0:
            gross_profit += net
        elif net < 0:
            gross_loss += abs(net)

        decision = policy.evaluate(window.metrics(), market_provider(trade))
        decisions.append(decision)

        if decision.decision is Decision.RED:
            if net > 0:
                blocked_profit += net
            elif net < 0:
                blocked_loss += abs(net)
        else:
            guarded_net += net

        window.add(net)

    retained = 1.0 if gross_profit == 0 else max(0.0, 1.0 - blocked_profit / gross_profit)
    prevented = 0.0 if gross_loss == 0 else blocked_loss / gross_loss
    return ReplayResult(
        baseline_net=baseline_net,
        guarded_net=guarded_net,
        blocked_profit=blocked_profit,
        blocked_loss=blocked_loss,
        retained_profit_ratio=retained,
        prevented_loss_ratio=prevented,
        decisions=tuple(decisions),
    )
