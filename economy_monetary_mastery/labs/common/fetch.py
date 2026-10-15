"""Network fetchers. Used only by data/snapshot.py and by loaders called with live=True."""
import io
import time

import pandas as pd
import requests

END = "2026-09-30"
DEFAULT_RPC = "https://ethereum-rpc.publicnode.com"
VCI_URL = "https://trading.vietcap.com.vn/api/chart/OHLCChart/gap-chart"
_UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
       "(KHTML, like Gecko) Chrome/126.0 Safari/537.36")


def parse_fred_text(text: str, series_id: str) -> pd.Series:
    df = pd.read_csv(io.StringIO(text), na_values=["."])
    df.columns = ["date", series_id]  # header is DATE or observation_date depending on era
    s = df.set_index(pd.to_datetime(df["date"]))[series_id].astype(float).dropna()
    s.index.name = "date"
    return s


def fred(series_id: str) -> pd.Series:
    url = f"https://fred.stlouisfed.org/graph/fredgraph.csv?id={series_id}"
    r = requests.get(url, timeout=60)
    r.raise_for_status()
    return parse_fred_text(r.text, series_id)


def prices(ticker: str, start: str = "2005-01-01", end: str = END) -> pd.Series:
    import yfinance as yf

    df = yf.download(ticker, start=start, end=end, auto_adjust=True, progress=False)
    close = df["Close"]
    if isinstance(close, pd.DataFrame):  # newer yfinance returns a ticker-level column
        close = close.iloc[:, 0]
    s = close.dropna().astype(float).rename(ticker)
    s.index = pd.to_datetime(s.index).tz_localize(None)
    s.index.name = "date"
    return s


def _exchange(name: str):
    import ccxt

    return getattr(ccxt, name)({"enableRateLimit": True})


def crypto_ohlcv(symbol: str, exchange: str = "binance", since: str = "2019-01-01",
                 end: str = END) -> pd.DataFrame:
    ex = _exchange(exchange)
    ms = ex.parse8601(f"{since}T00:00:00Z")
    stop = ex.parse8601(f"{end}T00:00:00Z")
    rows = []
    while ms < stop:
        batch = ex.fetch_ohlcv(symbol, timeframe="1d", since=ms, limit=1000)
        if not batch:
            break
        rows += batch
        ms = batch[-1][0] + 86_400_000
        time.sleep(ex.rateLimit / 1000)
    df = pd.DataFrame(rows, columns=["ts", "open", "high", "low", "close", "volume"])
    df = df.drop_duplicates("ts")
    df.index = pd.to_datetime(df.pop("ts"), unit="ms")
    df.index.name = "date"
    return df[df.index <= pd.Timestamp(end)].astype(float)


def funding(symbol: str, exchange: str = "binance", since: str = "2020-01-01",
            end: str = END) -> pd.Series:
    ex = _exchange(exchange)
    ms = ex.parse8601(f"{since}T00:00:00Z")
    stop = ex.parse8601(f"{end}T00:00:00Z")
    rows = []
    while ms < stop:
        batch = ex.fetch_funding_rate_history(symbol, since=ms, limit=1000)
        if not batch:
            break
        rows += [(b["timestamp"], b["fundingRate"]) for b in batch]
        ms = batch[-1]["timestamp"] + 1
        time.sleep(ex.rateLimit / 1000)
    df = pd.DataFrame(rows, columns=["ts", "funding_rate"]).drop_duplicates("ts")
    s = pd.Series(df["funding_rate"].astype(float).values,
                  index=pd.to_datetime(df["ts"], unit="ms"), name="funding_rate")
    s.index.name = "date"
    return s[s.index <= pd.Timestamp(end)]


def parse_vci_chart(payload: list, symbol: str) -> pd.Series:
    """Parse a Vietcap OHLC chart payload (t = unix seconds as strings, c = closes)."""
    entry = next((e for e in payload if e.get("symbol") == symbol), None)
    if entry is None:
        raise ValueError(f"VCI payload has no entry for {symbol!r}")
    # stamps may be UTC-midnight or VN-midnight; judge the date in Vietnam local time
    idx = (pd.to_datetime([int(x) for x in entry["t"]], unit="s", utc=True)
           .tz_convert("Asia/Ho_Chi_Minh").normalize().tz_localize(None))
    s = pd.Series([float(c) for c in entry["c"]], index=idx, name=symbol)
    s = s[~s.index.duplicated(keep="last")].sort_index()
    s.index.name = "date"
    return s


def vn(symbol: str, start: str = "2010-01-01", end: str = END) -> pd.Series:
    """Daily closes from Vietcap's public chart API (stocks already in VND, indices in points).

    Pages backwards (to = earliest returned t - 1) in case the server caps countBack.
    """
    to = int(pd.Timestamp(f"{end} 23:59:59", tz="UTC").timestamp())
    start_ts = pd.Timestamp(start)
    parts: list[pd.Series] = []
    for _ in range(50):
        count_back = (pd.Timestamp(to, unit="s") - start_ts).days + 10
        r = requests.post(VCI_URL, json={"timeFrame": "ONE_DAY", "symbols": [symbol],
                                         "to": to, "countBack": count_back},
                          headers={"User-Agent": _UA}, timeout=60)
        r.raise_for_status()
        payload = r.json()
        if not any(e.get("symbol") == symbol and e.get("t") for e in payload):
            break
        chunk = parse_vci_chart(payload, symbol)
        parts.append(chunk)
        earliest = min(int(x) for e in payload if e.get("symbol") == symbol for x in e["t"])
        if chunk.index.min() <= start_ts or earliest - 1 >= to:
            break
        to = earliest - 1
    if not parts:
        raise ValueError(f"VCI returned no data for {symbol!r}")
    s = pd.concat(parts).sort_index()
    s = s[~s.index.duplicated(keep="last")]
    s.index.name = "date"
    return s.loc[start_ts:pd.Timestamp(end)]


def eth_rpc(method: str, params: list, url: str = DEFAULT_RPC) -> dict:
    r = requests.post(url, json={"jsonrpc": "2.0", "id": 1, "method": method,
                                 "params": params}, timeout=30)
    r.raise_for_status()
    body = r.json()
    if "error" in body:
        raise RuntimeError(body["error"])
    return body["result"]
