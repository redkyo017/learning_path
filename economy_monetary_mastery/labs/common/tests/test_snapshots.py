import pandas as pd
import pytest

from common import data

FRED = "WALCL WRESBAL DFF IORB RRPONTSYD CPIAUCSL DGS3MO DGS2 DGS10 T10Y2Y T5YIE UNRATE INDPRO M2SL DTWEXBGS DEXKOUS DEXBZUS DEXINUS DEXTHUS DEXMXUS".split()
TICKERS = "SPY QQQ IWF IWD TLT IEF AGG GLD EFA EEM VNM VND=X DX-Y.NYB BTC-USD ETH-USD".split()
VN = "VNINDEX VN30 FPT HPG VCB".split()


@pytest.mark.parametrize("sid", FRED)
def test_fred_snapshot(sid):
    s = data.load_fred(sid)
    assert len(s) > 50 and s.index.max() <= pd.Timestamp("2026-09-30")


def test_price_snapshots():
    df = data.load_prices(TICKERS)
    assert df["SPY"].dropna().size > 4000


@pytest.mark.parametrize("sym", VN)
def test_vn_snapshot(sym):
    s = data.load_vn(sym)
    assert len(s) > 1000
    if sym not in data.VN_INDICES:
        assert s.median() > 1000  # VND, not thousands


def test_vn_history_depth():
    assert data.load_vn("VNINDEX").index.min() <= pd.Timestamp("2011-12-31")


def test_crypto_snapshots():
    assert len(data.load_crypto_ohlcv("BTC/USDT")) > 1500
    assert len(data.load_crypto_ohlcv("ETH/USDT")) > 1500
    assert len(data.load_crypto_ohlcv("BTC/USDT:USDT")) > 1000
    assert len(data.load_funding()) > 3000


def test_eth_fixtures():
    block = data.load_json("eth/block.json")
    receipt = data.load_json("eth/receipt.json")
    assert block["number"].startswith("0x") and "baseFeePerGas" in block
    assert receipt["gasUsed"].startswith("0x") and "effectiveGasPrice" in receipt
