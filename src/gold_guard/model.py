from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional


class Decision(str, Enum):
    GREEN = "GREEN"
    AMBER = "AMBER"
    RED = "RED"


@dataclass(frozen=True)
class Trade:
    time: datetime
    profit: float
    symbol: str = "XAUUSD"
    magic: int = 5555
    ticket: Optional[int] = None
    position_id: Optional[int] = None
    volume: float = 0.01
    entry: Optional[int] = None
    reason: Optional[int] = None
    commission: float = 0.0
    swap: float = 0.0

    @property
    def net(self) -> float:
        return self.profit + self.commission + self.swap


@dataclass(frozen=True)
class MarketSnapshot:
    time: datetime
    spread_points: Optional[float] = None
    directional_efficiency: Optional[float] = None
    high_impact_usd_minutes: Optional[float] = None
    is_holiday: bool = False
    minutes_from_session_open: Optional[float] = None
    minutes_to_session_close: Optional[float] = None


@dataclass(frozen=True)
class DecisionRecord:
    time: datetime
    decision: Decision
    score: float
    reasons: tuple[str, ...] = field(default_factory=tuple)
