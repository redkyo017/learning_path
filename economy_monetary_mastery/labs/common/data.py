"""Loaders: frozen snapshots by default (offline, deterministic); live=True fetches into .cache/."""
import json
from pathlib import Path

import pandas as pd

from common import fetch

LABS_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = LABS_DIR / "data"
CACHE_DIR = LABS_DIR / ".cache"
VN_INDICES = {"VNINDEX", "VN30", "HNXINDEX", "UPCOMINDEX"}


def snapshot_path(kind: str, name: str) -> Path:
    return DATA_DIR / kind / name


def _safe(name: str) -> str:
    return name.replace("/", "_").replace(":", "_").replace("=", "_").replace("^", "_")


def _read_series(path: Path, name: str) -> pd.Series:
    if not path.exists():
        raise FileNotFoundError(
            f"No snapshot {path.relative_to(LABS_DIR) if path.is_relative_to(LABS_DIR) else path} "
            f"for {name!r}. Available snapshots are listed in data/MANIFEST.md; "
            f"or call the loader with live=True to fetch it.")
    df = pd.read_csv(path, index_col=0, parse_dates=True)
    return df.iloc[:, 0].astype(float).dropna().rename(name)


def _cache(kind: str, name: str, s: pd.Series | pd.DataFrame) -> None:
    out = CACHE_DIR / kind / f"{_safe(name)}.csv"
    out.parent.mkdir(parents=True, exist_ok=True)
    s.to_csv(out)


def load_fred(series_id: str, live: bool = False) -> pd.Series:
    if live:
        s = fetch.fred(series_id)
        _cache("fred", series_id, s)
        return s
    return _read_series(snapshot_path("fred", f"{series_id}.csv"), series_id)


def load_prices(tickers: str | list[str], live: bool = False) -> pd.DataFrame:
    tickers = [tickers] if isinstance(tickers, str) else list(tickers)
    cols = {}
    for t in tickers:
        if live:
            cols[t] = fetch.prices(t)
            _cache("prices", t, cols[t])
        else:
            cols[t] = _read_series(snapshot_path("prices", f"{_safe(t)}.csv"), t)
    return pd.concat(cols, axis=1)[tickers]


def load_crypto_ohlcv(symbol: str = "BTC/USDT", exchange: str = "binance",
                      live: bool = False) -> pd.DataFrame:
    name = f"{exchange}_{_safe(symbol)}_1d"
    if live:
        df = fetch.crypto_ohlcv(symbol, exchange)
        _cache("crypto", name, df)
        return df
    path = snapshot_path("crypto", f"{name}.csv")
    if not path.exists():
        _read_series(path, symbol)  # raises the standard message
    return pd.read_csv(path, index_col=0, parse_dates=True).astype(float)


def load_funding(symbol: str = "BTC/USDT:USDT", exchange: str = "binance",
                 live: bool = False) -> pd.Series:
    name = f"{exchange}_{_safe(symbol)}_funding"
    if live:
        s = fetch.funding(symbol, exchange)
        _cache("crypto", name, s)
        return s
    return _read_series(snapshot_path("crypto", f"{name}.csv"), "funding_rate")


def normalize_vn_prices(s: pd.Series, symbol: str) -> pd.Series:
    """VN stock prices often arrive in thousands of VND; indices are points and never scaled."""
    if symbol.upper() in VN_INDICES:
        return s.astype(float)
    return s.astype(float) * 1000 if s.median() < 1000 else s.astype(float)


def load_vn(symbol: str = "VNINDEX", live: bool = False) -> pd.Series:
    if live:
        s = fetch.vn(symbol)  # VCI is already VND / index points: no scaling
        _cache("vn", symbol, s)
        return s
    return _read_series(snapshot_path("vn", f"{symbol}.csv"), symbol)


def load_json(relpath: str) -> dict:
    path = DATA_DIR / relpath
    if not path.exists():
        raise FileNotFoundError(f"No snapshot data/{relpath}; see data/MANIFEST.md "
                                f"(live=True is not available for JSON fixtures).")
    return json.loads(path.read_text())
