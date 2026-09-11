from __future__ import annotations

from collections import deque
from dataclasses import dataclass
from math import inf


@dataclass(frozen=True)
class RollingMetrics:
    count: int
    wins: int
    losses: int
    win_rate: float
    profit_factor: float
    net: float
    loss_streak: int


class RollingTradeWindow:
    def __init__(self, size: int) -> None:
        if size < 1:
            raise ValueError("size must be >= 1")
        self._values: deque[float] = deque(maxlen=size)

    def add(self, net_profit: float) -> None:
        self._values.append(float(net_profit))

    def metrics(self) -> RollingMetrics:
        vals = list(self._values)
        wins = [x for x in vals if x > 0]
        losses = [x for x in vals if x < 0]
        gross_profit = sum(wins)
        gross_loss = abs(sum(losses))
        if gross_loss == 0:
            pf = inf if gross_profit > 0 else 0.0
        else:
            pf = gross_profit / gross_loss
        streak = 0
        for x in reversed(vals):
            if x < 0:
                streak += 1
            else:
                break
        count = len(vals)
        return RollingMetrics(
            count=count,
            wins=len(wins),
            losses=len(losses),
            win_rate=(len(wins) / count) if count else 0.0,
            profit_factor=pf,
            net=sum(vals),
            loss_streak=streak,
        )
