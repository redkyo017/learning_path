import pandas as pd
import pytest

from common.risk import breakeven_cost_bps, vol_target_weights


def test_reference_risk():
    assert breakeven_cost_bps(pd.Series([0.01, 0.02]), pd.Series([1.0, 2.0])) == pytest.approx(100.0)
    assert vol_target_weights(pd.Series([1e-6, -1e-6] * 30), 0.1, 20, 2.0).iloc[-1] == 2.0
