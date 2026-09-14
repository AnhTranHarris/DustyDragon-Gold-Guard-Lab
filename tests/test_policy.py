import unittest
from datetime import datetime

from gold_guard.metrics import RollingMetrics
from gold_guard.model import Decision, MarketSnapshot, Trade
from gold_guard.policy import GuardPolicy, PolicyConfig
from gold_guard.replay import replay


class GoldGuardPolicyTests(unittest.TestCase):
    def setUp(self):
        self.policy = GuardPolicy(PolicyConfig())

    def test_good_regime_is_green(self):
        m = RollingMetrics(30, 24, 6, 0.8, 4.0, 18.0, 0)
        snap = MarketSnapshot(datetime(2025, 5, 13, 15, 0), spread_points=25, directional_efficiency=0.5)
        self.assertEqual(self.policy.evaluate(m, snap).decision, Decision.GREEN)

    def test_whipsaw_is_red(self):
        m = RollingMetrics(30, 11, 19, 11/30, 0.7, -8.0, 4)
        snap = MarketSnapshot(datetime(2024, 1, 9, 15, 0), spread_points=25, directional_efficiency=0.10)
        self.assertEqual(self.policy.evaluate(m, snap).decision, Decision.RED)

    def test_news_alone_is_not_blanket_red(self):
        m = RollingMetrics(30, 24, 6, 0.8, 4.0, 18.0, 0)
        snap = MarketSnapshot(datetime(2024, 1, 5, 15, 0), spread_points=25, directional_efficiency=0.55, high_impact_usd_minutes=0)
        self.assertEqual(self.policy.evaluate(m, snap).decision, Decision.GREEN)

    def test_friday_close_is_red(self):
        m = RollingMetrics(30, 24, 6, 0.8, 4.0, 18.0, 0)
        snap = MarketSnapshot(datetime(2025, 11, 28, 21, 0))
        self.assertEqual(self.policy.evaluate(m, snap).decision, Decision.RED)

    def test_replay_reports_profit_retention(self):
        trades = [Trade(datetime(2025, 1, 6, 10, i), profit=p) for i, p in enumerate([1, 1, 1, -1, 1, 1])]
        result = replay(trades, self.policy, lambda t: MarketSnapshot(time=t.time), window_size=3)
        self.assertAlmostEqual(result.baseline_net, 4.0)
        self.assertGreaterEqual(result.retained_profit_ratio, 0.0)
        self.assertLessEqual(result.retained_profit_ratio, 1.0)


if __name__ == "__main__":
    unittest.main()
