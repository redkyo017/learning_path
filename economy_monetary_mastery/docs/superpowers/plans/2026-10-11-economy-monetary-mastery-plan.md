# Economy, Monetary & Currency Systems Mastery (Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author a 30-day "follow the money" course in `economy_monetary_mastery/`. It pairs a content file per day with a self-checking Python lab per day, plus a tested lab harness, frozen data snapshots, and course-level docs (strategy, roadmap, progress, journal, glossary).

**Architecture:** Content lives in `content/dayNN.md`. Labs live in `labs/dayNN/`, each with a `lab.py` stub file, a `test_lab.py`, and a reference `solution.py`. The `common.labimpl.load_impl` helper makes a test target the learner's file (default) or the reference (`LAB_IMPL=solution`). Shared loaders in `labs/common/` read frozen CSV/JSON snapshots in `labs/data/`, so every test runs offline and deterministically. Two tool scripts enforce the contract: `labs/tools/verify_labs.py` and `labs/tools/check_content.py`.

**Tech Stack:** Python 3.12 managed by uv. Libraries: pandas, numpy, matplotlib, requests, yfinance, ccxt, vnstock, vectorbt, alpaca-py, python-dotenv and pytest.

**Spec:** `economy_monetary_mastery/docs/superpowers/specs/2026-10-11-economy-monetary-mastery-design.md`

## Global Constraints

- Course root is `economy_monetary_mastery/`. All paths below are relative to it unless they start with `labs/` (relative to `economy_monetary_mastery/labs/`).
- Python `>=3.12,<3.13`, managed by `uv`. Every command runs from `economy_monetary_mastery/labs/` as `uv run …`.
- Phase 1 never uses real money. Paper trading and testnets only. Day 29 adapters must force paper/sandbox mode.
- Use free data only: FRED public CSV (no key), yfinance, ccxt public endpoints, vnstock, and a public Ethereum RPC.
- No credentials in any file. `labs/.env.example` holds placeholders only, and `.env` and `.cache/` are gitignored.
- Tests read only frozen snapshots in `labs/data/`. Network fetches happen only with `live=True` and write to `labs/.cache/`, never to `labs/data/`.
- Time-sensitive facts (Vietnamese market rules, stablecoin regulation, settlement cycles, rate levels, ETF availability, Ethereum gas limit) must be web-verified and stamped "as of 2026-10".
- Every exercise ships a hint and a solution sketch. Every lab ships README.md, SOLUTION.md and a teardown note.
- Daily budget is ~3.5 h: 1.5 theory, 1.5 lab, 0.5 exercises and journal. Content is 1,800–3,000 words per day file.
- Content is educational, not financial advice. README and Day 29 carry a one-paragraph note. No preaching elsewhere.
- **Subagents run no git commands.** Commit steps are performed by the controller on the scratch branch `authoring/economy_monetary`. Never push.
- Subagents must not run trading code against live endpoints. Only Task 2 (the controller) performs network fetches.

## Review Focus

1. **Fresh clone, snapshot missing, or offline**: a loader called for an absent snapshot must raise `FileNotFoundError` naming the file and suggesting `live=True`, not a pandas stack trace. Pinned in Task 1 `test_data.py::test_missing_snapshot_message`.
2. **FRED missing values (`.`) and the renamed date header** (`observation_date` vs `DATE`): loaders and Day 1's parser must drop `.` rows and accept either header. Pinned in Task 1 `test_fetch.py::test_parse_fred_text` and in Day 1.
3. **Day 29 broker adapters accidentally pointing at real-money endpoints**: `CcxtBroker` must call `set_sandbox_mode(True)`, and `AlpacaBroker` must construct its client with `paper=True`. Pinned in Task 32 tests.
4. **Partially implemented `lab.py`**: importing a stub file must never execute stubs (no module-level calls; `main()` only under `__main__`). Each test must exercise one function so finished functions pass while others still fail. Enforced by `verify_labs.py` (collection errors flagged) in Task 1.
5. **Vietnamese prices quoted in thousands of VND**: stock prices must be scaled to VND, and indices never scaled. Pinned in Task 1 `test_data.py::test_normalize_vn_prices`.

---

## File Structure

```
economy_monetary_mastery/
├── README.md  STRATEGY.md  ROADMAP.md  PROGRESS.md  journal.md      # Task 3
├── content/
│   ├── GLOSSARY.md                                                  # Task 34
│   └── day01.md … day30.md                                          # Tasks 4–33
└── labs/
    ├── pyproject.toml  .gitignore  .env.example  conftest.py        # Task 1
    ├── common/
    │   ├── __init__.py
    │   ├── labimpl.py     # load_impl(test_file) -> module           (Task 1)
    │   ├── fetch.py       # network fetchers (live only)             (Task 1)
    │   ├── data.py        # snapshot/live loaders                    (Task 1)
    │   ├── quant.py       # returns, vol, sharpe, drawdown, cagr     (Task 1)
    │   ├── backtest.py    # reference backtest + momentum            (Task 28)
    │   ├── stats.py       # PSR / DSR reference                      (Task 29)
    │   ├── risk.py        # vol targeting, breakeven cost            (Task 30)
    │   └── tests/ test_labimpl.py test_fetch.py test_data.py test_quant.py
    ├── tools/
    │   ├── verify_labs.py  check_content.py                         (Task 1)
    │   ├── fixtures/day99/ lab.py solution.py test_lab.py           (Task 1)
    │   └── tests/ test_verify_labs.py test_check_content.py
    ├── data/
    │   ├── snapshot.py  MANIFEST.md                                 (Task 2)
    │   ├── fred/<ID>.csv  prices/<TICKER>.csv  crypto/*.csv
    │   ├── vn/<SYMBOL>.csv  eth/block.json eth/receipt.json
    └── day01/ … day30/  README.md lab.py test_lab.py solution.py SOLUTION.md
```

## Shared Conventions (apply to every day task)

**Lab file contract**
- `lab.py` starts with a module docstring stating the day's goal. It then holds the given code (dataclasses, helpers, `main()`) complete, and every function or method the learner implements has a full docstring and a body of exactly `raise NotImplementedError("TODO: <short hint>")`.
- `lab.py` and `solution.py` export identical public names and signatures. `solution.py` is `lab.py` with every TODO body implemented, plus explanatory comments.
- Both end with:
  ```python
  if __name__ == "__main__":
      main()
  ```
  `main()` loads snapshot data via `common.data`, calls the day's functions, prints a short summary, and saves any figure to `labs/.cache/plots/dayNN.png` (creating the dir). Run it with `uv run python -m dayNN.lab` from `labs/`. `main()` must never be called at import time.
- `test_lab.py` starts with:
  ```python
  from common.labimpl import load_impl
  m = load_impl(__file__)
  ```
  and refers to every lab name as `m.<name>`.

**`labs/dayNN/README.md` template**
```markdown
# Lab NN — <title>

**Goal:** <one line>   **Time:** ~1.5 h   **Content:** `../../content/dayNN.md`

## Steps
1. Read the content file sections "Core concepts" and "Worked example".
2. Open `lab.py`. Implement the TODO functions in the order listed below.
3. After each function: `uv run pytest dayNN -k <function_name>`.
4. When all pass: `uv run python -m dayNN.lab` and inspect the printed summary / `.cache/plots/dayNN.png`.

## Functions to implement (in order)
<numbered list, one line each>

## Success signal
`uv run pytest dayNN` — all tests pass.

## Explore further (optional)
<1–3 ideas, e.g. `live=True` refresh>

## Teardown
Nothing billable is created. <Day 29: revoke paper/testnet keys.>
```

**`labs/dayNN/SOLUTION.md`**: for each function, give the key idea in 2–5 sentences, the formula, the most common mistake and how the test catches it. End with "What the output means", 1 paragraph interpreting `main()`'s output on the snapshot.

**`content/dayNN.md`**: use the spec's Content Day Skeleton exactly. Headings, in order: `## Why this matters`, `## Core concepts`, `## Worked example`, `## Exercises`, `## Anti-patterns / Common mistakes`, `## Lab`, `## Teardown`, `## Journal prompt`. Integration days (06, 12, 18, 24, 30) add `## Checkpoint quiz` (≥12 questions) and `## Answer key` after `## Exercises`. The blockquote under the title contains `facts as of 2026-10`. Exercises are numbered `1.` `2.` … with `**Hint:**` and `**Solution sketch:**` in each item. Solution sketches must not contain numbered lists (use `;` or `-` bullets). Normal days have ≥5 exercises, integration days ≥3. Wherever money moves, draw a T-account as a fenced text block:
```
        Bank A                       
  Assets      | Liabilities          
  Loans +100  | Deposit:Alice +100   
```
Link primary sources (FRED series pages, Fed/SBV pages, whitepapers) inline.

**Per-day verification commands** (run from `labs/`):
```bash
LAB_IMPL=solution uv run pytest dayNN          # expect: all pass
uv run python tools/verify_labs.py dayNN       # expect: "dayNN  solution:PASS  stub:FAIL-CLEAN"
uv run python tools/check_content.py dayNN     # expect: "dayNN OK"
```

---

### Task 1: Lab harness (project, loaders, quant helpers, verification tools)

**Files:**
- Create: `labs/pyproject.toml`, `labs/.gitignore`, `labs/.env.example`, `labs/conftest.py`
- Create: `labs/common/__init__.py`, `labs/common/labimpl.py`, `labs/common/fetch.py`, `labs/common/data.py`, `labs/common/quant.py`
- Create: `labs/common/tests/test_labimpl.py`, `test_fetch.py`, `test_data.py`, `test_quant.py`
- Create: `labs/tools/verify_labs.py`, `labs/tools/check_content.py`, `labs/tools/fixtures/day99/{lab.py,solution.py,test_lab.py}`, `labs/tools/fixtures/content/day99.md`, `labs/tools/tests/test_verify_labs.py`, `labs/tools/tests/test_check_content.py`

**Interfaces:**
- Produces:
  - `common.labimpl.load_impl(test_file: str) -> types.ModuleType`
  - `common.fetch.parse_fred_text(text: str, series_id: str) -> pd.Series`; `fred(series_id) -> pd.Series`; `prices(ticker, start="2005-01-01", end="2026-09-30") -> pd.Series`; `crypto_ohlcv(symbol, exchange="binance", since="2019-01-01", end="2026-09-30") -> pd.DataFrame`; `funding(symbol, exchange="binance", since="2020-01-01", end="2026-09-30") -> pd.Series`; `vn(symbol, start="2010-01-01", end="2026-09-30") -> pd.Series`; `eth_rpc(method: str, params: list, url=DEFAULT_RPC) -> dict`
  - `common.data.load_fred(series_id, live=False) -> pd.Series` (name = id, float, DatetimeIndex, NaN dropped); `load_prices(tickers: str | list[str], live=False) -> pd.DataFrame` (one column per ticker, adjusted close); `load_crypto_ohlcv(symbol="BTC/USDT", exchange="binance", live=False) -> pd.DataFrame` (cols open, high, low, close, volume); `load_funding(symbol="BTC/USDT:USDT", exchange="binance", live=False) -> pd.Series`; `load_vn(symbol="VNINDEX", live=False) -> pd.Series` (VND or index points); `load_json(relpath: str) -> dict`; `normalize_vn_prices(s: pd.Series, symbol: str) -> pd.Series`; `snapshot_path(kind: str, name: str) -> Path`
  - `common.quant`: `simple_returns(p)`, `log_returns(p)`, `cagr(p)`, `annualize_vol(r, periods_per_year=252)`, `sharpe(r, rf=0.0, periods_per_year=252)`, `drawdown_series(p)`, `max_drawdown(p)`, `equity_curve(r, start=1.0)`. All accept Series and DataFrames.
  - `tools.verify_labs.verify_day(day_dir: Path) -> DayResult` where `DayResult` is a dataclass `(name: str, solution_ok: bool, stub_clean: bool, detail: str)`
  - `tools.check_content.check_day_file(path: Path, integration: bool) -> list[str]` (error strings); `scan_secrets(root: Path) -> list[str]`

- [ ] **Step 1: Write project config**

`labs/pyproject.toml`:
```toml
[project]
name = "economy-monetary-labs"
version = "0.1.0"
description = "Self-checking labs for the economy/monetary/currency mastery course"
requires-python = ">=3.12,<3.13"
dependencies = [
    "pandas>=2.2",
    "numpy>=1.26",
    "matplotlib>=3.8",
    "requests>=2.31",
    "yfinance>=0.2.40",
    "ccxt>=4.3",
    "vnstock>=3.2",
    "vectorbt>=0.26",
    "alpaca-py>=0.30",
    "python-dotenv>=1.0",
]

[dependency-groups]
dev = ["pytest>=8", "jupyter>=1.0"]

[tool.uv]
package = false

[tool.pytest.ini_options]
pythonpath = ["."]
addopts = "--import-mode=importlib -q"
norecursedirs = [".*", "fixtures", "data", "__pycache__", ".cache"]
```

`labs/.gitignore`:
```
.env
.cache/
.venv/
__pycache__/
.pytest_cache/
```

`labs/.env.example`:
```bash
# Copy to .env and fill in. NEVER commit .env. Paper / testnet keys ONLY.
# Alpaca paper trading: https://app.alpaca.markets (Paper account → API keys)
ALPACA_API_KEY=your-paper-key-here
ALPACA_SECRET_KEY=your-paper-secret-here
# Binance spot testnet: https://testnet.binance.vision
BINANCE_TESTNET_API_KEY=your-testnet-key-here
BINANCE_TESTNET_SECRET=your-testnet-secret-here
```

`labs/conftest.py`:
```python
import os


def pytest_report_header(config):
    return f"LAB_IMPL={os.environ.get('LAB_IMPL', 'lab')}"
```

Run: `cd economy_monetary_mastery/labs && uv sync`
Expected: the environment resolves and installs. If resolution fails because of `vectorbt` (numpy pin conflict), change its line to `"vectorbt>=0.27"`. If it still fails, move vectorbt into a `research = ["vectorbt>=0.26"]` dependency group and note in Task 28's README that the cross-check needs `uv sync --group research`. Record what happened in the task report.

- [ ] **Step 2: Write failing tests for labimpl, fetch parsing, data, quant**

`labs/common/tests/test_labimpl.py`:
```python
import pytest

from common.labimpl import load_impl


def _make(tmp_path):
    (tmp_path / "lab.py").write_text("def f():\n    raise NotImplementedError('TODO')\n")
    (tmp_path / "solution.py").write_text("def f():\n    return 42\n")
    return str(tmp_path / "test_lab.py")


def test_default_loads_lab(tmp_path, monkeypatch):
    monkeypatch.delenv("LAB_IMPL", raising=False)
    m = load_impl(_make(tmp_path))
    with pytest.raises(NotImplementedError):
        m.f()


def test_solution_switch(tmp_path, monkeypatch):
    monkeypatch.setenv("LAB_IMPL", "solution")
    assert load_impl(_make(tmp_path)).f() == 42


def test_bad_value_rejected(tmp_path, monkeypatch):
    monkeypatch.setenv("LAB_IMPL", "answers")
    with pytest.raises(ValueError, match="LAB_IMPL"):
        load_impl(_make(tmp_path))


def test_dataclasses_work_in_loaded_module(tmp_path, monkeypatch):
    monkeypatch.delenv("LAB_IMPL", raising=False)
    (tmp_path / "lab.py").write_text(
        "from dataclasses import dataclass\n@dataclass\nclass P:\n    x: int\n"
    )
    m = load_impl(str(tmp_path / "test_lab.py"))
    assert m.P(1).x == 1
```

`labs/common/tests/test_fetch.py`:
```python
import pandas as pd

from common.fetch import parse_fred_text


def test_parse_fred_text_new_header_and_missing_dots():
    text = "observation_date,DFF\n2024-01-01,5.33\n2024-01-02,.\n2024-01-03,5.31\n"
    s = parse_fred_text(text, "DFF")
    assert s.name == "DFF"
    assert isinstance(s.index, pd.DatetimeIndex)
    assert list(s.values) == [5.33, 5.31]


def test_parse_fred_text_old_header():
    s = parse_fred_text("DATE,X\n2020-01-01,1.5\n", "X")
    assert s.iloc[0] == 1.5
```

`labs/common/tests/test_data.py`:
```python
import pandas as pd
import pytest

import common.data as data


@pytest.fixture
def snap(tmp_path, monkeypatch):
    monkeypatch.setattr(data, "DATA_DIR", tmp_path)
    (tmp_path / "fred").mkdir()
    (tmp_path / "fred" / "DFF.csv").write_text("date,DFF\n2024-01-01,5.33\n2024-01-02,5.31\n")
    (tmp_path / "prices").mkdir()
    (tmp_path / "prices" / "SPY.csv").write_text("date,close\n2024-01-02,470.0\n2024-01-03,468.0\n")
    (tmp_path / "prices" / "TLT.csv").write_text("date,close\n2024-01-02,98.0\n2024-01-03,99.0\n")
    return tmp_path


def test_load_fred_from_snapshot(snap):
    s = data.load_fred("DFF")
    assert s.name == "DFF" and len(s) == 2 and s.dtype == float


def test_load_prices_wide(snap):
    df = data.load_prices(["SPY", "TLT"])
    assert list(df.columns) == ["SPY", "TLT"]
    assert df.loc["2024-01-03", "TLT"] == 99.0


def test_load_prices_single_string(snap):
    assert list(data.load_prices("SPY").columns) == ["SPY"]


def test_missing_snapshot_message(snap):
    with pytest.raises(FileNotFoundError) as e:
        data.load_fred("NOPE")
    msg = str(e.value)
    assert "NOPE" in msg and "live=True" in msg


def test_normalize_vn_prices():
    stock = pd.Series([95.5, 96.0, 97.2])          # thousands of VND
    index = pd.Series([1250.3, 1260.1, 1270.0])     # points
    assert data.normalize_vn_prices(stock, "FPT").tolist() == [95500.0, 96000.0, 97200.0]
    assert data.normalize_vn_prices(index, "VNINDEX").tolist() == [1250.3, 1260.1, 1270.0]
    already = pd.Series([95500.0, 96000.0])
    assert data.normalize_vn_prices(already, "FPT").tolist() == [95500.0, 96000.0]
```

`labs/common/tests/test_quant.py`:
```python
import numpy as np
import pandas as pd
import pytest

from common import quant


@pytest.fixture
def p():
    return pd.Series([100.0, 120.0, 90.0, 130.0],
                     index=pd.date_range("2020-01-01", periods=4, freq="D"))


def test_returns(p):
    assert quant.simple_returns(p).tolist() == pytest.approx([0.2, -0.25, 130 / 90 - 1])
    assert quant.log_returns(p).sum() == pytest.approx(np.log(1.3))


def test_drawdown(p):
    assert quant.drawdown_series(p).tolist() == pytest.approx([0, 0, -0.25, 0])
    assert quant.max_drawdown(p) == pytest.approx(-0.25)


def test_cagr_uses_calendar_time():
    s = pd.Series([100.0, 200.0], index=pd.to_datetime(["2010-01-01", "2020-01-01"]))
    years = (s.index[-1] - s.index[0]).days / 365.25
    assert quant.cagr(s) == pytest.approx(2 ** (1 / years) - 1)


def test_vol_and_sharpe():
    r = pd.Series([0.01, -0.005] * 126)
    assert quant.annualize_vol(r) == pytest.approx(r.std(ddof=1) * np.sqrt(252))
    assert quant.sharpe(r) == pytest.approx(r.mean() / r.std(ddof=1) * np.sqrt(252))
    rf = 0.0252
    ex = r - rf / 252
    assert quant.sharpe(r, rf=rf) == pytest.approx(ex.mean() / ex.std(ddof=1) * np.sqrt(252))


def test_equity_curve():
    assert quant.equity_curve(pd.Series([0.1, -0.1])).tolist() == pytest.approx([1.1, 0.99])


def test_dataframe_support(p):
    df = pd.DataFrame({"a": p, "b": p * 2})
    assert list(quant.max_drawdown(df)) == pytest.approx([-0.25, -0.25])
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `uv run pytest common`
Expected: FAIL with `ModuleNotFoundError: No module named 'common.labimpl'` (and similar).

- [ ] **Step 4: Implement `common/`**

`labs/common/__init__.py`: empty file.

`labs/common/labimpl.py`:
```python
"""Load a lab's learner file (lab.py) or reference (solution.py) next to a test file."""
import importlib.util
import os
import sys
from pathlib import Path
from types import ModuleType

_VALID = ("lab", "solution")


def load_impl(test_file: str) -> ModuleType:
    which = os.environ.get("LAB_IMPL", "lab")
    if which not in _VALID:
        raise ValueError(f"LAB_IMPL must be one of {_VALID}, got {which!r}")
    path = Path(test_file).resolve().with_name(f"{which}.py")
    mod_name = f"_lab_{path.parent.name}_{which}"
    spec = importlib.util.spec_from_file_location(mod_name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[mod_name] = module  # dataclasses look their module up here
    spec.loader.exec_module(module)
    return module
```

`labs/common/fetch.py`:
```python
"""Network fetchers. Used only by data/snapshot.py and by loaders called with live=True."""
import io
import time

import pandas as pd
import requests

END = "2026-09-30"
DEFAULT_RPC = "https://ethereum-rpc.publicnode.com"


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


def vn(symbol: str, start: str = "2010-01-01", end: str = END) -> pd.Series:
    from vnstock import Vnstock

    last_err = None
    for source in ("VCI", "TCBS"):
        try:
            df = Vnstock().stock(symbol=symbol, source=source).quote.history(
                start=start, end=end, interval="1D")
            s = pd.Series(df["close"].astype(float).values,
                          index=pd.to_datetime(df["time"]), name=symbol)
            s.index.name = "date"
            return s
        except Exception as e:  # source outages are common; try the next one
            last_err = e
    raise RuntimeError(f"vnstock failed for {symbol}: {last_err}")


def eth_rpc(method: str, params: list, url: str = DEFAULT_RPC) -> dict:
    r = requests.post(url, json={"jsonrpc": "2.0", "id": 1, "method": method,
                                 "params": params}, timeout=30)
    r.raise_for_status()
    body = r.json()
    if "error" in body:
        raise RuntimeError(body["error"])
    return body["result"]
```

`labs/common/data.py`:
```python
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
        s = normalize_vn_prices(fetch.vn(symbol), symbol)
        _cache("vn", symbol, s)
        return s
    return _read_series(snapshot_path("vn", f"{symbol}.csv"), symbol)


def load_json(relpath: str) -> dict:
    path = DATA_DIR / relpath
    if not path.exists():
        raise FileNotFoundError(f"No snapshot data/{relpath}; see data/MANIFEST.md "
                                f"(live=True is not available for JSON fixtures).")
    return json.loads(path.read_text())
```
(`test_missing_snapshot_message` only checks for `live=True` in the message. Keep the phrase "live=True" in both messages.)

`labs/common/quant.py`:
```python
"""Reference quant helpers. Learners re-implement several of these in Days 2–10;
Block 5 labs import these canonical versions."""
import numpy as np
import pandas as pd


def simple_returns(p):
    return p.pct_change().dropna(how="all")


def log_returns(p):
    return np.log(p / p.shift(1)).dropna(how="all")


def cagr(p):
    years = (p.index[-1] - p.index[0]).days / 365.25
    return (p.iloc[-1] / p.iloc[0]) ** (1 / years) - 1


def annualize_vol(r, periods_per_year: int = 252):
    return r.std(ddof=1) * np.sqrt(periods_per_year)


def sharpe(r, rf: float = 0.0, periods_per_year: int = 252):
    ex = r - rf / periods_per_year
    return ex.mean() / ex.std(ddof=1) * np.sqrt(periods_per_year)


def drawdown_series(p):
    return p / p.cummax() - 1


def max_drawdown(p):
    return drawdown_series(p).min()


def equity_curve(r, start: float = 1.0):
    return start * (1 + r).cumprod()
```

- [ ] **Step 5: Run common tests to verify they pass**

Run: `uv run pytest common`
Expected: all pass (17 tests).

- [ ] **Step 6: Write failing tests for the tools**

`labs/tools/fixtures/day99/lab.py`:
```python
"""Fixture lab used to test tools/verify_labs.py."""


def double(x):
    raise NotImplementedError("TODO: return 2*x")


def main():
    print(double(2))


if __name__ == "__main__":
    main()
```
`labs/tools/fixtures/day99/solution.py`: the same file with `return 2 * x` as the body of `double`.
`labs/tools/fixtures/day99/test_lab.py`:
```python
from common.labimpl import load_impl

m = load_impl(__file__)


def test_double():
    assert m.double(3) == 6
```
`labs/tools/fixtures/content/day99.md`: a valid day file for the content checker. It has `# Day 99 — Fixture`, then `> Block 0 · ~3.5 h · facts as of 2026-10`, all eight required headings, and under `## Exercises` five items in this exact form:
`1. Do X. — **Hint:** think Y. — **Solution sketch:** Z.`

`labs/tools/tests/test_verify_labs.py`:
```python
import shutil
from pathlib import Path

from tools.verify_labs import verify_day

FIX = Path(__file__).resolve().parents[1] / "fixtures" / "day99"


def test_good_fixture_passes():
    r = verify_day(FIX)
    assert r.solution_ok and r.stub_clean, r.detail


def test_import_time_crash_is_not_clean(tmp_path):
    bad = tmp_path / "day98"
    shutil.copytree(FIX, bad)
    (bad / "lab.py").write_text("raise NotImplementedError('boom at import')\n")
    r = verify_day(bad)
    assert r.solution_ok
    assert not r.stub_clean
```

`labs/tools/tests/test_check_content.py`:
```python
from pathlib import Path

from tools.check_content import check_day_file, scan_secrets

FIX = Path(__file__).resolve().parents[1] / "fixtures" / "content" / "day99.md"


def test_fixture_ok():
    assert check_day_file(FIX, integration=False) == []


def test_missing_hint_detected(tmp_path):
    p = tmp_path / "day98.md"
    p.write_text(FIX.read_text().replace("**Hint:**", "Hint:", 1))
    errs = check_day_file(p, integration=False)
    assert any("hint" in e.lower() for e in errs)


def test_integration_requires_quiz(tmp_path):
    errs = check_day_file(FIX, integration=True)
    assert any("Checkpoint quiz" in e for e in errs)


def test_missing_stamp(tmp_path):
    p = tmp_path / "day97.md"
    p.write_text(FIX.read_text().replace("as of 2026-10", ""))
    assert any("as of 2026-10" in e for e in check_day_file(p, integration=False))


def test_scan_secrets(tmp_path):
    (tmp_path / "ok.env.example").write_text("ALPACA_API_KEY=your-paper-key-here\n")
    (tmp_path / "leak.py").write_text('API_KEY = "AKIAABCDEFGHIJKLMNOP1234"\n')
    hits = scan_secrets(tmp_path)
    assert len(hits) == 1 and "leak.py" in hits[0]
```
`tools` is importable as a package via `pythonpath = ["."]` once `labs/tools/__init__.py` exists (Step 7). `tools/tests/` needs no `__init__.py` (importlib mode).

Run: `uv run pytest tools`
Expected: FAIL with `ModuleNotFoundError: No module named 'tools.verify_labs'`.

- [ ] **Step 7: Implement the tools**

`labs/tools/__init__.py`: empty.

`labs/tools/verify_labs.py`:
```python
"""Check every lab: reference passes, learner stub fails cleanly (NotImplementedError only).

Usage (from labs/):  uv run python tools/verify_labs.py [day01 day02 ...]
"""
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

LABS = Path(__file__).resolve().parents[1]
_DIRTY = ("ImportError", "ModuleNotFoundError", "SyntaxError", "error during collection",
          "errors during collection", "NameError", "AttributeError")


@dataclass
class DayResult:
    name: str
    solution_ok: bool
    stub_clean: bool
    detail: str


def _run(day_dir: Path, impl: str) -> tuple[int, str]:
    env = {**os.environ, "LAB_IMPL": impl}
    # -c/--rootdir pin the labs config even when day_dir lives outside labs/ (tests use tmp dirs)
    p = subprocess.run([sys.executable, "-m", "pytest", str(day_dir), "-q",
                        "-c", str(LABS / "pyproject.toml"), "--rootdir", str(LABS),
                        "-p", "no:cacheprovider"],
                       cwd=LABS, env=env, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def verify_day(day_dir: Path) -> DayResult:
    rc_s, out_s = _run(day_dir, "solution")
    rc_l, out_l = _run(day_dir, "lab")
    solution_ok = rc_s == 0
    stub_clean = (rc_l == 1 and "NotImplementedError" in out_l
                  and not any(d in out_l for d in _DIRTY))
    detail = "" if solution_ok and stub_clean else (out_s[-1500:] + "\n---\n" + out_l[-1500:])
    return DayResult(day_dir.name, solution_ok, stub_clean, detail)


def main(argv: list[str]) -> int:
    days = sorted(d for d in LABS.glob("day[0-9][0-9]") if (d / "test_lab.py").exists())
    if argv:
        days = [d for d in days if d.name in argv]
    bad = 0
    for d in days:
        r = verify_day(d)
        sol = "PASS" if r.solution_ok else "FAIL"
        stub = "FAIL-CLEAN" if r.stub_clean else "DIRTY"
        print(f"{r.name}  solution:{sol}  stub:{stub}")
        if not (r.solution_ok and r.stub_clean):
            bad += 1
            print(r.detail)
    print(f"{len(days) - bad}/{len(days)} labs OK")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```
Note: AttributeError is "dirty" because it means the stub is missing a name the tests use. Tests must never expect AttributeError from the lab.

`labs/tools/check_content.py`:
```python
"""Check content/dayNN.md structure and sweep the course tree for secrets.

Usage (from labs/):  uv run python tools/check_content.py [day01 ...]
"""
import re
import sys
from pathlib import Path

COURSE = Path(__file__).resolve().parents[2]
INTEGRATION_DAYS = {6, 12, 18, 24, 30}
REQUIRED = ["## Why this matters", "## Core concepts", "## Worked example", "## Exercises",
            "## Anti-patterns / Common mistakes", "## Lab", "## Teardown", "## Journal prompt"]
INTEGRATION_EXTRA = ["## Checkpoint quiz", "## Answer key"]
SECRET_PATTERNS = [
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"(?i)(api[_-]?key|secret[_-]?key|secret)\s*[:=]\s*['\"]?(?!your-)[A-Za-z0-9/+]{20,}"),
]


def _section(text: str, heading: str) -> str:
    start = text.find(heading)
    if start < 0:
        return ""
    nxt = text.find("\n## ", start + len(heading))
    return text[start:nxt if nxt >= 0 else len(text)]


def check_day_file(path: Path, integration: bool) -> list[str]:
    text = path.read_text()
    errs = [f"missing heading '{h}'" for h in REQUIRED if h not in text]
    if integration:
        errs += [f"missing heading '{h}'" for h in INTEGRATION_EXTRA if h not in text]
    if "as of 2026-10" not in text:
        errs.append("missing 'as of 2026-10' stamp")
    ex = _section(text, "## Exercises")
    items = len(re.findall(r"^\d+\.\s", ex, re.M))
    hints, sols = ex.count("**Hint:**"), ex.count("**Solution sketch:**")
    minimum = 3 if integration else 5
    if items < minimum:
        errs.append(f"only {items} exercises (need >= {minimum})")
    if hints != items:
        errs.append(f"{items} exercises but {hints} **Hint:** markers")
    if sols != items:
        errs.append(f"{items} exercises but {sols} **Solution sketch:** markers")
    return errs


def scan_secrets(root: Path) -> list[str]:
    hits = []
    for f in root.rglob("*"):
        if not f.is_file() or any(p in f.parts for p in (".venv", ".cache", "__pycache__", ".git")):
            continue
        if f.suffix in {".csv", ".json", ".png", ".pyc"}:
            continue
        try:
            text = f.read_text()
        except UnicodeDecodeError:
            continue
        for pat in SECRET_PATTERNS:  # one hit per file is enough to flag it
            m = pat.search(text)
            if m:
                hits.append(f"{f}: {m.group(0)[:40]}")
                break
    return hits


def main(argv: list[str]) -> int:
    files = sorted((COURSE / "content").glob("day[0-9][0-9].md"))
    if argv:
        files = [f for f in files if f.stem in argv]
    bad = 0
    for f in files:
        errs = check_day_file(f, integration=int(f.stem[3:]) in INTEGRATION_DAYS)
        print(f"{f.stem} OK" if not errs else f"{f.stem} FAIL: " + "; ".join(errs))
        bad += bool(errs)
    secrets = scan_secrets(COURSE)
    for s in secrets:
        print("SECRET?", s)
    return 1 if bad or secrets else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 8: Run all harness tests**

Run: `uv run pytest common tools`
Expected: all pass (24 tests). Then `uv run python tools/verify_labs.py`. Expected: `0/0 labs OK`, exit 0.

- [ ] **Step 9: Commit (controller)**

```bash
git add economy_monetary_mastery/labs
git commit -m "WIP: task 1 lab harness (scratch)"
```

---

### Task 2: Frozen data snapshots (controller runs this; needs network)

**Files:**
- Create: `labs/data/snapshot.py`, `labs/data/MANIFEST.md` (generated), plus the CSV/JSON files under `labs/data/`

**Interfaces:**
- Consumes: `common.fetch.*` (Task 1), `common.data._safe` naming via `snapshot_path`
- Produces the snapshot files every later lab test and `main()` read:
  - `data/fred/<ID>.csv` (`date,<ID>`) for: `WALCL WRESBAL DFF IORB RRPONTSYD CPIAUCSL DGS3MO DGS2 DGS10 T10Y2Y T5YIE UNRATE INDPRO M2SL DTWEXBGS DEXKOUS DEXBZUS DEXINUS DEXTHUS DEXMXUS`
  - `data/prices/<safe ticker>.csv` (`date,close`) for: `SPY QQQ IWF IWD TLT IEF AGG GLD EFA EEM VNM VND=X DX-Y.NYB BTC-USD ETH-USD`. Safe names replace `/ : = ^` with `_`, so `VND=X` → `VND_X.csv` and `DX-Y.NYB` → `DX-Y.NYB.csv`.
  - `data/crypto/binance_BTC_USDT_1d.csv`, `binance_ETH_USDT_1d.csv`, `binance_BTC_USDT_USDT_1d.csv` (perp), `binance_BTC_USDT_USDT_funding.csv`
  - `data/vn/VNINDEX.csv`, `VN30.csv`, `FPT.csv`, `HPG.csv`, `VCB.csv` (stocks normalized to VND)
  - `data/eth/block.json` (`eth_getBlockByNumber` for `finalized`, `false`), `data/eth/receipt.json` (`eth_getTransactionReceipt` of the block's first tx hash)
  - All series end on or before 2026-09-30.

- [ ] **Step 1: Write the failing snapshot completeness test**

`labs/common/tests/test_snapshots.py`:
```python
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
```
Run: `uv run pytest common/tests/test_snapshots.py`
Expected: FAIL with `FileNotFoundError ... live=True`.

- [ ] **Step 2: Write `labs/data/snapshot.py`**

```python
"""Create the frozen snapshots in labs/data/. Run once during authoring (needs network):

    uv run python data/snapshot.py            # everything
    uv run python data/snapshot.py fred vn    # subsets: fred prices crypto vn eth
"""
import json
import sys
from datetime import date
from pathlib import Path

from common import fetch
from common.data import DATA_DIR, _safe, normalize_vn_prices

FRED = "WALCL WRESBAL DFF IORB RRPONTSYD CPIAUCSL DGS3MO DGS2 DGS10 T10Y2Y T5YIE UNRATE INDPRO M2SL DTWEXBGS DEXKOUS DEXBZUS DEXINUS DEXTHUS DEXMXUS".split()
TICKERS = "SPY QQQ IWF IWD TLT IEF AGG GLD EFA EEM VNM VND=X DX-Y.NYB BTC-USD ETH-USD".split()
VN = "VNINDEX VN30 FPT HPG VCB".split()
END = "2026-09-30"
manifest: list[str] = []


def _save(kind: str, name: str, obj, source: str) -> None:
    path = DATA_DIR / kind / f"{_safe(name)}.csv"
    path.parent.mkdir(parents=True, exist_ok=True)
    obj = obj[obj.index <= END]
    obj.to_csv(path, header=True, index_label="date")
    manifest.append(f"| `{path.relative_to(DATA_DIR)}` | {source} | {len(obj)} rows "
                    f"| {obj.index.min().date()} → {obj.index.max().date()} |")


def do_fred():
    for sid in FRED:
        _save("fred", sid, fetch.fred(sid), f"FRED {sid}")


def do_prices():
    for t in TICKERS:
        _save("prices", t, fetch.prices(t).rename("close"), f"Yahoo Finance {t} (adj. close)")


def do_crypto():
    for sym in ("BTC/USDT", "ETH/USDT", "BTC/USDT:USDT"):
        _save("crypto", f"binance_{_safe(sym)}_1d", fetch.crypto_ohlcv(sym), f"Binance {sym} 1d")
    _save("crypto", "binance_BTC_USDT_USDT_funding", fetch.funding("BTC/USDT:USDT"),
          "Binance BTC/USDT perp funding")


def do_vn():
    for sym in VN:
        _save("vn", sym, normalize_vn_prices(fetch.vn(sym), sym).rename("close"),
              f"vnstock {sym}")


def do_eth():
    out = DATA_DIR / "eth"
    out.mkdir(parents=True, exist_ok=True)
    block = fetch.eth_rpc("eth_getBlockByNumber", ["finalized", False])
    receipt = fetch.eth_rpc("eth_getTransactionReceipt", [block["transactions"][0]])
    (out / "block.json").write_text(json.dumps(block, indent=1))
    (out / "receipt.json").write_text(json.dumps(receipt, indent=1))
    manifest.append(f"| `eth/block.json` | publicnode eth_getBlockByNumber finalized | "
                    f"block {int(block['number'], 16)} | — |")
    manifest.append("| `eth/receipt.json` | publicnode eth_getTransactionReceipt | 1 tx | — |")


STEPS = {"fred": do_fred, "prices": do_prices, "crypto": do_crypto, "vn": do_vn, "eth": do_eth}

if __name__ == "__main__":
    for name in sys.argv[1:] or list(STEPS):
        print("snapshot:", name)
        STEPS[name]()
    with (DATA_DIR / "MANIFEST.md").open("a") as f:
        f.write(f"\n## Snapshot run {date.today()} (cut-off {END})\n\n"
                "| File | Source | Size | Range |\n|---|---|---|---|\n")
        f.write("\n".join(manifest) + "\n")
```

- [ ] **Step 3: Run the snapshot (controller, network)**

Run: `uv run python data/snapshot.py`
Expected: prints each step and writes the files plus `MANIFEST.md`. Fallbacks:
- If Binance is blocked, pass `"okx"` as the exchange in `do_crypto` (same symbols), save as `okx_*` file names, change the default `exchange=` arguments of `load_crypto_ohlcv`/`load_funding` in `common/data.py` to `"okx"`, and update the file names in `test_snapshots.py`.
- If `fetch.vn` fails because the vnstock API changed, adapt only `fetch.vn` (check `help(vnstock)`). Its contract is a float Series of daily closes named by symbol.
- If vnstock fails for both sources, stop and ask the user. Do not fabricate VN data.
- If `IORB` is short (it starts 2021-07-29), that is expected. The test only needs >50 rows.

- [ ] **Step 4: Size and test check**

Run: `du -sh data && uv run pytest common/tests/test_snapshots.py`
Expected: total under 15 MB, and all tests pass.

- [ ] **Step 5: Prepend MANIFEST header**

Edit `labs/data/MANIFEST.md` so it starts with:
```markdown
# Data snapshots

Frozen copies of public data so every lab test is offline and deterministic.
Tests never fetch. To explore fresher data, call a loader with `live=True` — results go to
`labs/.cache/`, never here. Re-create everything with `uv run python data/snapshot.py`
(the old files are overwritten; tests may then need their data-dependent assertions re-checked).

Units: FRED rates are **percent** (5.33 = 5.33%); WALCL is **millions USD**; WRESBAL is
**billions USD**; VND=X is VND per USD; VN stock prices are VND; VN indices are points.
```

- [ ] **Step 6: Commit (controller)**

```bash
git add economy_monetary_mastery/labs/data economy_monetary_mastery/labs/common/tests/test_snapshots.py
git commit -m "WIP: task 2 data snapshots (scratch)"
```

---

### Task 3: Course-level documents

**Files:**
- Create: `README.md`, `STRATEGY.md`, `ROADMAP.md`, `PROGRESS.md`, `journal.md`

**Interfaces:**
- Consumes: spec sections "Strategy", "Curriculum", "Progress Tracking & Roadmap"
- Produces: the day index that Task 34 re-checks, and the PROGRESS table format `| NN | Title | [ ] theory | [ ] exercises | [ ] lab | [ ] quiz/— |`

- [ ] **Step 1: Write `README.md`**

Required sections, in order:
1. `# Economy, Money & Markets: Phase 1`. One paragraph on what this is (30 days, ~3.5 h/day, follow-the-money spine, Python labs).
2. `## Not financial advice`. One paragraph: educational; Phase 1 uses no real money; paper/testnet only; past performance and backtests do not predict results.
3. `## Quickstart`. Install uv (`brew install uv`). Then `cd labs && uv sync`, then `uv run pytest day01` (expect failures: that's your to-do list), then `uv run python -m day01.lab`.
4. `## How a day works`. 1.5 h theory (`content/dayNN.md`), 1.5 h lab (`labs/dayNN/`), 0.5 h exercises + journal. Tick `PROGRESS.md`.
5. `## Block map`. A table of the 5 blocks with days and one-line goals, copied from the spec's curriculum.
6. `## Day index`. A table of 30 rows `| Day | Title | Lab |` with links `content/dayNN.md` and `labs/dayNN/`. Titles are the spec curriculum "Theory" cells shortened to ≤8 words (Day 1 "What money is: IOUs and T-accounts", …, Day 30 "Capstone: idea to paper deployment").
7. `## Checking yourself`. Covers `uv run pytest dayNN`, `LAB_IMPL=solution uv run pytest dayNN` (see the reference pass; peeking is allowed after an honest attempt), and `uv run python tools/check_content.py`.
8. `## Data`. Snapshots vs `live=True`; link `labs/data/MANIFEST.md`.
9. `## Files`. The directory tree from the spec.

- [ ] **Step 2: Write `STRATEGY.md`**

Expand the spec "Strategy" section into ~1,200–1,800 words:
- `## The seven moves`: each move gets a paragraph and a concrete example from the course (e.g. move 1 cites Day 2's loan→deposit T-account; move 4 cites Day 26's p-hacking demo).
- `## Mistakes that waste 80% of beginners' time`: the spec's mistakes table, with an extra column "What to do instead".
- `## Why not the traditional path`: the textbook-first and markets-first paths and why each was rejected (from the spec).
- `## How to use the 3.5 hours`: the daily time split, the "one question per day into journal.md" habit, and when to peek at solutions (after 25 minutes stuck on one function).

- [ ] **Step 3: Write `ROADMAP.md`**

```markdown
# Roadmap

| Phase | Goal | Status |
|---|---|---|
| 1 — Foundations (this course) | Mechanistic understanding + honest research-to-paper pipeline | In progress |
| 2 — Systematic investor | Asset allocation, rebalancing, tax-aware investing for a VN resident holding US + VN assets; refine the IPS | Not started |
| 3 — Deep quant | Statistical rigor, factor models, execution, small-capital live rollout with risk limits | Not started |
| 4 — Deep monetary theory | Monetary history, MMT/Austrian/monetarist debates, CBDCs, international monetary system design | Not started |
```
Then one `## Phase N` section per phase. Each has: `**Entry criteria:**` (Phase 2–4: "Phase 1 Day 30 capstone passed the kill checklist or was honestly killed; PROGRESS.md ≥ 90% ticked"), `**Candidate topics:**` (6–10 bullets), `**Deliverable:**` (one line), `**How to start:**` "Run the building-learning-path workflow with this section as the brief".

- [ ] **Step 4: Write `PROGRESS.md`**

Header with instructions (tick each box when done; "lab" means `uv run pytest dayNN` passes on your own `lab.py`), then the 30-row table in the Interfaces format. Integration days (06, 12, 18, 24, 30) have `[ ] quiz`; the others have `—`. Add a final `## Block retros` section with 5 empty `### Block N` headings and three prompts each ("What clicked", "What is still fuzzy", "One thing to re-do").

- [ ] **Step 5: Write `journal.md`**

```markdown
# Prediction journal

Rules: one entry per day minimum (each content file ends with a prompt). State a probability.
Resolve entries when the date arrives. Score with the Brier score: (p − outcome)², outcome 1 or 0;
lower is better, 0.25 = coin-flip quality. Review calibration at each integration day.

| # | Date | Claim (falsifiable, dated) | p | Resolves on | Outcome (1/0) | Brier | Why I believed it |
|---|---|---|---|---|---|---|---|
| 1 | 2026-__-__ | Example: US 10y yield closes above 4.00% on 2026-12-31 | 0.55 | 2026-12-31 | | | |

## Calibration review
| Review date | # resolved | Mean Brier | Bucket check (p 0.6–0.8 → hit rate) | Lesson |
|---|---|---|---|---|
```

- [ ] **Step 6: Verify**

Run: `/usr/bin/grep -c '^| [0-9][0-9] ' economy_monetary_mastery/PROGRESS.md`
Expected: `30`.
Run: `/usr/bin/grep -c 'content/day' economy_monetary_mastery/README.md`
Expected: `30`.

- [ ] **Step 7: Commit (controller)**

```bash
git add economy_monetary_mastery/*.md
git commit -m "WIP: task 3 course docs (scratch)"
```

---

## Day Tasks (Tasks 4–33)

Every day task follows the same nine steps, using the values given in that task:

- [ ] **D1. Write `labs/dayNN/test_lab.py`** exactly as given in the task.
- [ ] **D2. Write `labs/dayNN/lab.py`** with the given (non-TODO) code complete and every listed learner function as a `NotImplementedError` stub with a full docstring (Shared Conventions).
- [ ] **D3. Run** `uv run pytest dayNN`. Expected: every test FAILS with `NotImplementedError`, with no collection errors.
- [ ] **D4. Write `labs/dayNN/solution.py`** implementing every stub. Formulas are given in the task.
- [ ] **D5. Run** `LAB_IMPL=solution uv run pytest dayNN`. Expected: all pass. Then `uv run python -m dayNN.solution`. Expected: prints a summary without error (the snapshot data exists from Task 2).
- [ ] **D6. Write `labs/dayNN/README.md` and `labs/dayNN/SOLUTION.md`** per Shared Conventions.
- [ ] **D7. Write `content/dayNN.md`** per Shared Conventions and the task's content requirements. Web-verify every item listed under "Verify (as of 2026-10)" and cite the source inline.
- [ ] **D8. Run** `uv run python tools/verify_labs.py dayNN && uv run python tools/check_content.py dayNN`. Expected: `dayNN  solution:PASS  stub:FAIL-CLEAN`, `dayNN OK`, exit 0.
- [ ] **D9. Commit (controller):** `git add economy_monetary_mastery && git commit -m "WIP: task N dayNN (scratch)"`

Each task below lists its own steps D1–D9 as checkboxes with the concrete values.

### Task 4: Day 01 — What money is: IOUs, the hierarchy of money, T-accounts

**Files:** `content/day01.md`, `labs/day01/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Consumes: `common.data.snapshot_path` (in `main()` only)
- Produces (lab names): `UnbalancedError(ValueError)`; `class BalanceSheet(owner: str)` with attributes `assets: dict[str, float]` and `liabilities: dict[str, float]` (equity is the liability-side key `"equity"`), and methods `apply(assets: dict | None = None, liabilities: dict | None = None) -> None`, `total_assets() -> float`, `total_liabilities() -> float`; `transfer_deposit(payer_bank, payee_bank, amount, payer: str, payee: str) -> None`; `parse_fred_csv(text: str) -> pd.Series`

**test_lab.py:**
```python
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_balanced_apply_updates_both_sides():
    b = m.BalanceSheet("bank")
    b.apply(assets={"reserves": 100}, liabilities={"equity": 100})
    b.apply(assets={"loans": 50}, liabilities={"deposit:alice": 50})
    assert b.assets == {"reserves": 100, "loans": 50}
    assert b.total_assets() == 150 and b.total_liabilities() == 150


def test_unbalanced_apply_raises_and_leaves_state_unchanged():
    b = m.BalanceSheet("bank")
    b.apply(assets={"reserves": 10}, liabilities={"equity": 10})
    with pytest.raises(m.UnbalancedError):
        b.apply(assets={"loans": 5})
    assert b.assets == {"reserves": 10} and b.liabilities == {"equity": 10}


def test_asset_swap_is_balanced():
    b = m.BalanceSheet("bank")
    b.apply(assets={"reserves": 100}, liabilities={"equity": 100})
    b.apply(assets={"reserves": -40, "treasuries": 40})
    assert b.assets == {"reserves": 60, "treasuries": 40}
    assert b.total_assets() == 100


def _banks():
    a = m.BalanceSheet("bank_a")
    a.apply(assets={"reserves": 20, "loans": 80}, liabilities={"deposit:alice": 90, "equity": 10})
    b = m.BalanceSheet("bank_b")
    b.apply(assets={"reserves": 5}, liabilities={"equity": 5})
    return a, b


def test_transfer_moves_deposits_and_reserves():
    a, b = _banks()
    m.transfer_deposit(a, b, 15, payer="alice", payee="bob")
    assert a.assets["reserves"] == 5 and a.liabilities["deposit:alice"] == 75
    assert b.assets["reserves"] == 20 and b.liabilities["deposit:bob"] == 15


def test_transfer_without_enough_reserves_raises_and_changes_nothing():
    a, b = _banks()
    with pytest.raises(ValueError):
        m.transfer_deposit(a, b, 25, payer="alice", payee="bob")
    assert a.assets["reserves"] == 20 and "deposit:bob" not in b.liabilities


def test_parse_fred_csv_handles_missing_dots_and_header():
    text = "observation_date,DFF\n2024-01-01,5.33\n2024-01-02,.\n2024-01-03,5.31\n"
    s = m.parse_fred_csv(text)
    assert s.name == "DFF"
    assert isinstance(s.index, pd.DatetimeIndex)
    assert s.tolist() == [5.33, 5.31]
```

**Given code in lab.py:** imports, `UnbalancedError`, the `BalanceSheet.__init__` (sets `owner`, empty dicts), `total_assets`, `total_liabilities`, and `main()`. `main()` reads `snapshot_path("fred", "DFF.csv").read_text()`, calls `parse_fred_csv`, prints the latest effective fed funds rate and its 1-year change, and plots the series.
**Learner stubs:** `BalanceSheet.apply`, `transfer_deposit`, `parse_fred_csv`.
**Solution notes:**
- `apply`: sum the asset deltas and the liability deltas, and raise `UnbalancedError` if `abs(diff) > 1e-9` *before* mutating anything. Add deltas with `dict.get(k, 0) + v`.
- `transfer_deposit`: check `payer_bank.assets.get("reserves", 0) >= amount`, else raise `ValueError`. Then `payer_bank.apply(assets={"reserves": -amt}, liabilities={f"deposit:{payer}": -amt})` and `payee_bank.apply(assets={"reserves": amt}, liabilities={f"deposit:{payee}": amt})`.
- `parse_fred_csv`: `pd.read_csv(io.StringIO(text), na_values=["."])`, rename the first column to date regardless of its header, set a DatetimeIndex, drop NaN, and name the series after the second column's header.

**Content requirements (`content/day01.md`, Block 1):**
- Money as a transferable IOU, with Mehrling's hierarchy of money: central-bank reserves > bank deposits > money-market claims > securities. The "money view": the payment system as a network of balance sheets.
- The functions of money (unit of account, medium of exchange, store of value), framed as a 3-line aside, not the lesson.
- The T-account and the double-entry rule; equity as the residual; why every money event touches ≥2 balance sheets.
- Who can issue what: governments, central banks, commercial banks, stablecoin issuers. A one-line preview each of Days 2, 3 and 21.
- A setup walkthrough: install uv, `uv sync`, `uv run pytest day01`, how to read a test failure, `LAB_IMPL=solution` etiquette.
- How to read FRED: units, frequency, the `.` missing-value marker, the observation_date header.
- Worked example: Alice pays Bob $15 across two banks, shown as four T-accounts.
- ≥5 exercises. Include: draw the T-accounts for cash withdrawal at an ATM; "Is a bank deposit money? For whom?"; find series DFF on FRED and state its units.
- Anti-patterns: "banks lend out deposits"; "money = cash"; reading charts without checking units.
- Journal prompt: the effective fed funds rate on 2026-12-31, with a range and a probability.
- **Verify (as of 2026-10):** the FRED CSV header name (`observation_date`) and the uv install command.

**Steps:**
- [ ] D1 write `labs/day01/test_lab.py` (above)
- [ ] D2 write `labs/day01/lab.py` (given code + stubs `BalanceSheet.apply`, `transfer_deposit`, `parse_fred_csv`)
- [ ] D3 `uv run pytest day01` → 6 FAIL with NotImplementedError
- [ ] D4 write `labs/day01/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day01` → 6 pass; `uv run python -m day01.solution` runs
- [ ] D6 write `labs/day01/README.md`, `labs/day01/SOLUTION.md`
- [ ] D7 write `content/day01.md`
- [ ] D8 `uv run python tools/verify_labs.py day01 && uv run python tools/check_content.py day01`
- [ ] D9 controller commit `WIP: task 4 day01 (scratch)`

---

### Task 5: Day 02 — Banks create money

**Files:** `content/day02.md`, `labs/day02/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `@dataclass class Bank(name: str, reserves: float, loans: float, deposits: float, equity: float)` with methods `lend(amount: float) -> None`, `capital_ratio() -> float` (equity/loans), `liquidity_ratio() -> float` (reserves/deposits); `bank_run(bank: Bank, withdrawal_fractions: list[float], fire_sale_haircut: float) -> list[dict]`; `simple_returns(prices: pd.Series) -> pd.Series`; `log_returns(prices: pd.Series) -> pd.Series`

**test_lab.py:**
```python
import math

import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def make_bank():
    return m.Bank("b", reserves=10.0, loans=90.0, deposits=90.0, equity=10.0)


def test_lending_creates_deposits_without_using_reserves():
    b = make_bank()
    b.lend(20)
    assert (b.loans, b.deposits, b.reserves) == (110, 110, 10)


def test_ratios():
    b = make_bank()
    assert b.capital_ratio() == pytest.approx(10 / 90)
    assert b.liquidity_ratio() == pytest.approx(10 / 90)


def test_small_run_is_paid_from_reserves():
    states = m.bank_run(make_bank(), [0.1], fire_sale_haircut=0.3)
    s = states[-1]
    assert s["step"] == 1 and s["status"] == "ok"
    assert s["reserves"] == pytest.approx(1) and s["deposits"] == pytest.approx(81)
    assert s["equity"] == pytest.approx(10)


def test_large_run_forces_fire_sale_and_stops_at_insolvency():
    states = m.bank_run(make_bank(), [0.5, 0.5], fire_sale_haircut=0.3)
    assert len(states) == 1
    s = states[0]
    assert s["status"] == "insolvent"
    assert s["reserves"] == pytest.approx(0)
    assert s["loans"] == pytest.approx(40)
    assert s["deposits"] == pytest.approx(45)
    assert s["equity"] == pytest.approx(-5)


def test_identity_holds_every_step_and_input_not_mutated():
    bank = make_bank()
    states = m.bank_run(bank, [0.2, 0.2, 0.2], fire_sale_haircut=0.1)
    for s in states:
        assert s["reserves"] + s["loans"] == pytest.approx(s["deposits"] + s["equity"])
    assert bank.reserves == 10.0  # bank_run works on a copy


def test_returns():
    p = pd.Series([100.0, 110.0, 99.0])
    assert m.simple_returns(p).tolist() == pytest.approx([0.1, -0.1])
    assert m.log_returns(p).sum() == pytest.approx(math.log(0.99))
```

**Given code:** the `Bank` dataclass fields, and `main()`. `main()` simulates the textbook bank under three haircut levels, prints each terminal state, then loads `SPY` via `load_prices` and prints the mean simple vs log daily return.
**Learner stubs:** `Bank.lend`, `Bank.capital_ratio`, `Bank.liquidity_ratio`, `bank_run`, `simple_returns`, `log_returns`.
**Solution notes (`bank_run` rules):**
- Work on `copy.deepcopy(bank)`. For step k (1-indexed): `need = frac * deposits`, then pay `min(need, reserves)` from reserves.
- Any shortfall is met by selling loans of book value `x = shortfall / (1 - haircut)`. If `x > loans`, sell all loans: cash raised = `loans*(1-h)`, and the remaining unpaid shortfall stays as deposits. Then `deposits -= paid`, `equity -= x*h` (the loss on the sale).
- Append `{"step", "reserves", "loans", "deposits", "equity", "status"}`. Status is `"insolvent"` if `equity <= 0` or the shortfall was not fully paid, else `"ok"`. Stop after the first `"insolvent"`.
- Returns: `pct_change().dropna()` and `np.log(p / p.shift(1)).dropna()`.

**Content requirements (Block 1):**
- "Loans create deposits" (Bank of England Quarterly Bulletin 2014 Q1, *Money creation in the modern economy*, linked). Why the money multiplier is backwards. What actually limits lending: capital, regulation, demand for credit, profitability, and the reserve and liquidity cost of payment outflows.
- Payment settlement between banks via central-bank reserves (bridging to Day 3).
- Capital vs liquidity: insolvency vs illiquidity, Basel III in plain English (CET1, LCR, NSFR) at one paragraph each.
- Bank runs: the mechanics (fire sales turn illiquidity into insolvency), deposit insurance, the lender of last resort (Bagehot's rule).
- Vietnam aside: SBV credit growth targets ("room tín dụng") as a quantity limit on lending, previewing Day 16.
- Worked example: the lab's 10/90/90/10 bank under a 50% run with a 30% haircut, step by step with T-accounts.
- Quant thread: simple vs log returns, and why log returns add over time while simple returns add across assets.
- ≥5 exercises, including: compute the haircut at which a 50% run makes this bank exactly insolvent.
- Anti-patterns: the money multiplier; "reserves are lent out"; confusing capital (a liability side) with reserves (an asset).
- **Verify (as of 2026-10):** US reserve requirement = 0% since March 2020; Basel III minimum CET1 4.5% plus 2.5% conservation buffer; FDIC insurance limit $250k; Vietnam deposit insurance limit (VND 125 million, confirm).

**Steps:**
- [ ] D1 write `labs/day02/test_lab.py` (above)
- [ ] D2 write `labs/day02/lab.py` (stubs: `Bank.lend`, `Bank.capital_ratio`, `Bank.liquidity_ratio`, `bank_run`, `simple_returns`, `log_returns`)
- [ ] D3 `uv run pytest day02` → 6 FAIL with NotImplementedError
- [ ] D4 write `labs/day02/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day02` → pass; `uv run python -m day02.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day02.md`
- [ ] D8 `uv run python tools/verify_labs.py day02 && uv run python tools/check_content.py day02`
- [ ] D9 controller commit `WIP: task 5 day02 (scratch)`

---

### Task 6: Day 03 — Central banks: corridor, open-market operations, QE/QT

**Files:** `content/day03.md`, `labs/day03/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `overnight_rate(reserves: float, iorb: float, ceiling: float, satiation: float) -> float`; `qe_postings(amount: float, seller: str) -> dict[str, dict[str, dict[str, float]]]` (seller is `"nonbank"` or `"bank"`); `align_weekly(series: dict[str, pd.Series]) -> pd.DataFrame`

**test_lab.py:**
```python
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
KW = dict(iorb=4.40, ceiling=4.50, satiation=2500.0)


def test_floor_system_rate_is_iorb_when_reserves_ample():
    assert m.overnight_rate(3000.0, **KW) == pytest.approx(4.40)
    assert m.overnight_rate(2500.0, **KW) == pytest.approx(4.40)


def test_scarce_reserves_push_rate_toward_ceiling():
    assert m.overnight_rate(0.0, **KW) == pytest.approx(4.50)
    assert m.overnight_rate(1250.0, **KW) == pytest.approx(4.45)


def test_rate_never_rises_with_more_reserves():
    rates = [m.overnight_rate(r, **KW) for r in range(0, 4001, 250)]
    assert all(a >= b for a, b in zip(rates, rates[1:]))


def test_negative_reserves_rejected():
    with pytest.raises(ValueError):
        m.overnight_rate(-1.0, **KW)


def test_qe_from_nonbank_creates_reserves_and_deposits():
    p = m.qe_postings(100.0, seller="nonbank")
    assert p["central_bank"] == {"assets": {"treasuries": 100.0},
                                 "liabilities": {"reserves:bank": 100.0}}
    assert p["bank"] == {"assets": {"reserves": 100.0},
                         "liabilities": {"deposit:seller": 100.0}}
    assert p["seller"] == {"assets": {"treasuries": -100.0, "deposit": 100.0},
                           "liabilities": {}}


def test_qe_from_bank_creates_reserves_only():
    p = m.qe_postings(100.0, seller="bank")
    assert p["bank"] == {"assets": {"reserves": 100.0, "treasuries": -100.0},
                         "liabilities": {}}
    assert "seller" not in p


@pytest.mark.parametrize("seller", ["bank", "nonbank"])
def test_every_entity_balances(seller):
    for side in m.qe_postings(50.0, seller=seller).values():
        assert sum(side["assets"].values()) == pytest.approx(sum(side["liabilities"].values()))


def test_unknown_seller_rejected():
    with pytest.raises(ValueError):
        m.qe_postings(1.0, seller="alien")


def test_align_weekly():
    daily = pd.Series(range(14), index=pd.date_range("2024-01-01", periods=14, freq="D"),
                      dtype=float)
    monthly = pd.Series([1.0], index=pd.to_datetime(["2023-12-01"]))
    df = m.align_weekly({"d": daily, "m": monthly})
    assert list(df.columns) == ["d", "m"]
    assert df.index[0] == pd.Timestamp("2024-01-03")
    assert df["d"].tolist() == [2.0, 9.0, 13.0]
    assert df["m"].tolist() == [1.0, 1.0, 1.0]
```

**Given code:** `main()` loads `WALCL` (millions → /1000 for billions), `WRESBAL`, `DFF`, `IORB` and `RRPONTSYD`, aligns them weekly with `align_weekly`, prints the 2008, 2014, 2019, 2022 and latest values, and plots the balance sheet and reserves against the policy rate on twin axes.
**Learner stubs:** `overnight_rate`, `qe_postings`, `align_weekly`.
**Solution notes:**
- `overnight_rate`: if `reserves < 0` raise; if `reserves >= satiation` return `iorb`; else `ceiling - (ceiling - iorb) * reserves / satiation`.
- `qe_postings`: return the exact dicts from the tests; raise for any other seller.
- `align_weekly`: `pd.concat({k: s.resample("W-WED").last() for k, s in series.items()}, axis=1).sort_index().ffill().dropna()`, keeping the input key order.

**Content requirements (Block 1):**
- The central bank's balance sheet: assets (securities, loans, FX reserves); liabilities (currency, bank reserves, the Treasury General Account, reverse repo).
- Corridor vs floor systems: ceiling = discount window/standing repo facility; floor = IORB and ON RRP. Why the Fed moved to "ample reserves" after 2008.
- Open-market operations, then QE and QT, with T-accounts. QE sold by a bank vs by a nonbank (the lab's two cases). Why QE ≠ "printing money into the economy" automatically.
- Reading the Fed H.4.1 release (link) and FRED `WALCL`, `WRESBAL`, `RRPONTSYD`, `IORB`.
- The SBV's toolbox at a glance: refinancing rate, OMO, credit quotas, FX intervention (preview of Day 16).
- Worked example: 2019 repo-rate spike: reserves fell below "ample", and the overnight rate jumped above IORB (use the lab's corridor function).
- ≥5 exercises.
- Anti-patterns: equating QE with M2 growth; ignoring the Treasury General Account; reading WALCL's units wrong.
- **Verify (as of 2026-10):** current fed funds target range, IORB and ON RRP rates; Fed total assets; QT status (whether runoff has ended and when); the SBV refinancing rate.

**Steps:**
- [ ] D1 write `labs/day03/test_lab.py` (above)
- [ ] D2 write `labs/day03/lab.py` (stubs: `overnight_rate`, `qe_postings`, `align_weekly`)
- [ ] D3 `uv run pytest day03` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day03/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day03` → pass; `uv run python -m day03.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day03.md`
- [ ] D8 `uv run python tools/verify_labs.py day03 && uv run python tools/check_content.py day03`
- [ ] D9 controller commit `WIP: task 6 day03 (scratch)`

---

### Task 7: Day 04 — Inflation, expectations and real rates

**Files:** `content/day04.md`, `labs/day04/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `yoy_inflation(cpi: pd.Series, periods: int = 12) -> pd.Series`; `real_rate(nominal, inflation)` (floats or Series, decimals); `compound(value: float, rate: float, years: float) -> float`; `cagr(start_value: float, end_value: float, years: float) -> float`; `real_cagr(nominal: float, inflation: float) -> float`; `years_to_double(rate: float) -> float`

**test_lab.py:**
```python
import math

import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_yoy_inflation():
    idx = pd.date_range("2020-01-01", periods=25, freq="MS")
    cpi = pd.Series(100 * 1.02 ** (np.arange(25) / 12), index=idx)
    yoy = m.yoy_inflation(cpi)
    assert len(yoy) == 13
    assert yoy.tolist() == pytest.approx([0.02] * 13)


def test_real_rate_exact_fisher():
    assert m.real_rate(0.05, 0.03) == pytest.approx(1.05 / 1.03 - 1)
    s = m.real_rate(pd.Series([0.05, 0.01]), pd.Series([0.03, 0.04]))
    assert s.tolist() == pytest.approx([1.05 / 1.03 - 1, 1.01 / 1.04 - 1])


def test_compound_and_cagr_are_inverses():
    assert m.compound(100, 0.07, 10) == pytest.approx(100 * 1.07 ** 10)
    assert m.cagr(100, 200, 10) == pytest.approx(2 ** 0.1 - 1)
    assert m.cagr(100, m.compound(100, 0.07, 10), 10) == pytest.approx(0.07)


def test_real_cagr():
    assert m.real_cagr(0.08, 0.03) == pytest.approx(1.08 / 1.03 - 1)


def test_years_to_double():
    assert m.years_to_double(0.07) == pytest.approx(math.log(2) / math.log(1.07))


def test_cagr_rejects_bad_inputs():
    with pytest.raises(ValueError):
        m.cagr(0, 100, 5)
    with pytest.raises(ValueError):
        m.cagr(100, 200, 0)
```

**Given code:** `main()` loads `CPIAUCSL` and `DFF`. It computes the YoY CPI and the monthly mean DFF/100, then the real policy rate. It prints the most negative and most positive real-rate months since 1960 and the real CAGR of SPY since 2005 (using `common.quant.cagr` on prices and the CPI CAGR over the same span), and plots the real rate.
**Learner stubs:** all six functions.
**Solution notes:** `pct_change(periods, fill_method=None).dropna()`; Fisher `(1+i)/(1+π)-1`; `value*(1+rate)**years`; `cagr` raises if `start_value <= 0 or years <= 0`; `log(2)/log(1+rate)`.

**Content requirements (Block 1):**
- CPI vs PCE vs core; how the CPI basket is built; the reasons it can mislead (substitution, quality, housing).
- Inflation sources: demand-pull, cost-push, expectations, money/credit growth. Why QE in 2010–2019 didn't produce CPI inflation but 2021 did (fiscal transfers + supply shocks).
- Fiscal vs monetary policy and fiscal dominance, in plain English.
- Expectations: breakevens (`T5YIE`), the anchoring concept.
- The Fisher equation, exact vs approximate; real rates as the true price of money; negative real rates as a hidden tax on savers (Vietnamese savers in 2022 as an example).
- Compounding, CAGR, the rule of 72 vs the exact formula.
- Worked example: the real return of holding cash at the policy rate in 2021–2022 vs 2024–2025.
- ≥5 exercises.
- Anti-patterns: comparing nominal returns across decades; the approximate Fisher equation at high inflation; "printing money always causes inflation".
- **Verify (as of 2026-10):** latest US CPI YoY and core PCE; the Fed's 2% PCE target; latest Vietnam CPI YoY and the National Assembly's inflation target for 2026.

**Steps:**
- [ ] D1 write `labs/day04/test_lab.py` (above)
- [ ] D2 write `labs/day04/lab.py` (stubs: `yoy_inflation`, `real_rate`, `compound`, `cagr`, `real_cagr`, `years_to_double`)
- [ ] D3 `uv run pytest day04` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day04/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day04` → pass; `uv run python -m day04.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day04.md`
- [ ] D8 `uv run python tools/verify_labs.py day04 && uv run python tools/check_content.py day04`
- [ ] D9 controller commit `WIP: task 7 day04 (scratch)`

---

### Task 8: Day 05 — Shadow banking, repo, and the SVB failure

**Files:** `content/day05.md`, `labs/day05/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `duration_price_change(value: float, mod_duration: float, dy: float) -> float`; `convexity_price_change(value, mod_duration, convexity, dy) -> float`; `equity_after_marking(equity: float, unrealized_loss: float) -> float`; `drawdown_series(prices: pd.Series) -> pd.Series`; `max_drawdown(prices: pd.Series) -> float`

**test_lab.py:**
```python
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_duration_approximation():
    assert m.duration_price_change(100.0, 6.0, 0.02) == pytest.approx(-12.0)
    assert m.duration_price_change(100.0, 6.0, -0.01) == pytest.approx(6.0)


def test_convexity_adjustment():
    # -D*dy*V + 0.5*C*dy^2*V = -12 + 0.8
    assert m.convexity_price_change(100.0, 6.0, 40.0, 0.02) == pytest.approx(-11.2)


def test_equity_after_marking():
    assert m.equity_after_marking(16.0, 15.1) == pytest.approx(0.9)
    assert m.equity_after_marking(16.0, -2.0) == pytest.approx(18.0)


def test_drawdowns():
    p = pd.Series([100.0, 120.0, 90.0, 130.0])
    assert m.drawdown_series(p).tolist() == pytest.approx([0, 0, -0.25, 0])
    assert m.max_drawdown(p) == pytest.approx(-0.25)


def test_max_drawdown_of_monotonic_series_is_zero():
    assert m.max_drawdown(pd.Series([1.0, 2.0, 3.0])) == 0
```

**Given code:** module constants for SVB from its FY2022 10-K, each with a source comment: `HTM_AMORTIZED_COST_BN`, `HTM_FAIR_VALUE_BN`, `TOTAL_EQUITY_BN`, `AFS_SOLD_BN`, `AFS_LOSS_BN`, `DEPOSITS_BN`, `WITHDRAWN_MAR9_BN`. The subagent must web-verify each value and record the citation. Reference values to confirm: HTM ≈ 91.3 amortized cost / ≈ 76.2 fair value; equity ≈ 16.0; AFS sale ≈ 21 at ≈ 1.8 loss; deposits ≈ 173; ≈ 42 withdrawn 2023-03-09. `main()` uses `DGS2` and `DGS10` to show the 2021→2022 rise, then backs out the implied duration `(fair-cost)/cost/Δy` using the 10y change. It prints `equity_after_marking`, then loads `TLT` and prints `max_drawdown` since 2020 and the date of the trough.
**Learner stubs:** all five functions.
**Solution notes:** `-mod_duration*dy*value`; `+0.5*convexity*dy**2*value`; `equity - unrealized_loss`; `p/p.cummax()-1`; `.min()`.

**Content requirements (Block 1):**
- Shadow banking: money-market funds, repo (with a T-account of a repo trade: collateral, haircut), the eurodollar system as offshore dollar deposits (a preview of Day 14).
- Crises as plumbing failures: 2008 (repo runs, MMF breaking the buck), March 2020 (Treasury market dash-for-cash, Fed swap lines), 2023 SVB (duration mismatch + uninsured concentrated deposits + social-media run).
- HTM vs AFS accounting and why unrealized losses mattered anyway.
- The Fed's 2023 Bank Term Funding Program (BTFP) response: lending at par against collateral.
- Duration as an interest-rate sensitivity for engineers ("% change per 1 percentage point").
- Quant thread: drawdowns and max drawdown; TLT's 2020–2023 drawdown as a "risk-free asset" losing about half its value.
- Worked example: SVB's numbers through the lab functions.
- ≥5 exercises.
- Anti-patterns: "Treasuries are risk-free" (only credit risk-free); ignoring the liability side; equating HTM with safe.
- **Verify (as of 2026-10):** every SVB constant above (10-K FY2022 + FDIC/Fed post-mortem reports, linked); the TLT max-drawdown figure computed from the snapshot.

**Steps:**
- [ ] D1 write `labs/day05/test_lab.py` (above)
- [ ] D2 write `labs/day05/lab.py` (verified SVB constants + stubs for all five functions)
- [ ] D3 `uv run pytest day05` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day05/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day05` → pass; `uv run python -m day05.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day05.md`
- [ ] D8 `uv run python tools/verify_labs.py day05 && uv run python tools/check_content.py day05`
- [ ] D9 controller commit `WIP: task 8 day05 (scratch)`

---

### Task 9: Day 06 — Integration: the plumbing dashboard

**Files:** `content/day06.md`, `labs/day06/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Consumes: `common.quant` (allowed in integration labs)
- Produces: `plumbing_dashboard(fed_assets_musd: pd.Series, reserves_busd: pd.Series, policy_rate_pct: pd.Series, cpi_index: pd.Series) -> pd.DataFrame` with columns `["fed_assets_busd", "reserves_busd", "policy_rate", "cpi_yoy", "real_rate"]` (rates as decimals), monthly month-end index; `stance(real_rate: float, band: float = 0.01) -> str` returning `"restrictive" | "neutral" | "accommodative"`

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


@pytest.fixture
def inputs():
    weekly = pd.date_range("2022-01-05", "2024-02-28", freq="W-WED")
    daily = pd.date_range("2022-01-01", "2024-02-29", freq="D")
    fed = pd.Series(8_000_000.0, index=weekly)
    res = pd.Series(3_000.0, index=weekly)
    rate = pd.Series(5.0, index=daily)
    cpi = pd.Series(100 * 1.03 ** (np.arange(26) / 12),
                    index=pd.date_range("2022-01-01", periods=26, freq="MS"))
    return fed, res, rate, cpi


def test_columns_units_and_length(inputs):
    df = m.plumbing_dashboard(*inputs)
    assert list(df.columns) == ["fed_assets_busd", "reserves_busd", "policy_rate",
                                "cpi_yoy", "real_rate"]
    assert len(df) == 14
    assert df.index[0] == pd.Timestamp("2023-01-31")
    row = df.iloc[0]
    assert row["fed_assets_busd"] == pytest.approx(8000)
    assert row["reserves_busd"] == pytest.approx(3000)
    assert row["policy_rate"] == pytest.approx(0.05)
    assert row["cpi_yoy"] == pytest.approx(0.03)
    assert row["real_rate"] == pytest.approx(1.05 / 1.03 - 1)


def test_no_nans(inputs):
    assert not m.plumbing_dashboard(*inputs).isna().any().any()


@pytest.mark.parametrize("r,expected", [(0.02, "restrictive"), (0.005, "neutral"),
                                        (-0.03, "accommodative"), (0.01, "neutral")])
def test_stance(r, expected):
    assert m.stance(r) == expected
```

**Given code:** `main()` builds the dashboard from snapshots (`WALCL`, `WRESBAL`, `DFF`, `CPIAUCSL`). It prints the last 12 months with stance labels and the stance at five dated case points (2008-12, 2013-06, 2020-04, 2022-06, latest), and plots a 2×2 panel.
**Learner stubs:** `plumbing_dashboard`, `stance`.
**Solution notes:** resample weekly/daily inputs with `.resample("ME").mean()`; `cpi.resample("ME").last().pct_change(12, fill_method=None)`; fed/1000; rate/100; real via exact Fisher; `concat(...).dropna()`. `stance`: `> band` restrictive, `< -band` accommodative, else neutral (the boundary is neutral).

**Content requirements (integration day, ~3 h):**
- `## Core concepts`: a one-page recap map of Days 1–5. Chain: issuer hierarchy → bank money creation → reserves and corridor → inflation and real rates → shadow banking and runs.
- `## Worked example`: walk the dashboard through March 2020 week by week.
- `## Exercises` (≥3, case drills): (a) Draw every T-account in a "Fed buys $100bn Treasuries from a pension fund" event across four balance sheets. (b) Explain why reserves fell in 2022–2023 even though the policy rate rose (QT + ON RRP + TGA). (c) Given a mock bank (numbers supplied), decide whether a 30% run is a liquidity or a solvency event.
- `## Checkpoint quiz`: 12–15 short questions across Days 1–5 (mix of T-account, units, concepts). `## Answer key` with 1–3 line explanations.
- Start of the prediction journal: 3 dated claims with probabilities, explained.
- **Verify (as of 2026-10):** any current-level numbers cited in the quiz.

**Steps:**
- [ ] D1 write `labs/day06/test_lab.py` (above)
- [ ] D2 write `labs/day06/lab.py` (stubs: `plumbing_dashboard`, `stance`)
- [ ] D3 `uv run pytest day06` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day06/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day06` → pass; `uv run python -m day06.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day06.md` (integration headings included)
- [ ] D8 `uv run python tools/verify_labs.py day06 && uv run python tools/check_content.py day06`
- [ ] D9 controller commit `WIP: task 9 day06 (scratch)`

---

### Task 10: Day 07 — Bonds and the yield curve

**Files:** `content/day07.md`, `labs/day07/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `bond_price(face, coupon_rate, ytm, years, freq=2) -> float`; `macaulay_duration(face, coupon_rate, ytm, years, freq=2) -> float` (years); `modified_duration(...) -> float`; `convexity(...) -> float`; `curve_slope(long: pd.Series, short: pd.Series) -> pd.Series`; `inversion_periods(slope: pd.Series) -> list[tuple[pd.Timestamp, pd.Timestamp]]`

**test_lab.py:**
```python
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_known_price():
    assert m.bond_price(100, 0.05, 0.06, 5, 2) == pytest.approx(95.7349, abs=1e-3)


def test_par_and_zero():
    assert m.bond_price(100, 0.04, 0.04, 10) == pytest.approx(100)
    assert m.bond_price(100, 0.0, 0.04, 10, 2) == pytest.approx(100 / 1.02 ** 20)


def test_zero_coupon_durations_and_convexity():
    assert m.macaulay_duration(100, 0.0, 0.04, 10, 2) == pytest.approx(10)
    assert m.modified_duration(100, 0.0, 0.04, 10, 2) == pytest.approx(10 / 1.02)
    assert m.convexity(100, 0.0, 0.04, 10, 2) == pytest.approx(10 * 10.5 / 1.02 ** 2)


def test_duration_predicts_small_moves():
    p0 = m.bond_price(100, 0.05, 0.05, 10)
    p1 = m.bond_price(100, 0.05, 0.0501, 10)
    approx = -m.modified_duration(100, 0.05, 0.05, 10) * p0 * 0.0001
    assert (p1 - p0) == pytest.approx(approx, rel=1e-3)


def test_coupon_bond_duration_below_maturity():
    assert m.macaulay_duration(100, 0.05, 0.05, 10) < 10


def test_inversions():
    idx = pd.date_range("2024-01-01", periods=5, freq="D")
    slope = m.curve_slope(pd.Series([4.5, 4.0, 3.9, 4.4, 3.5], idx),
                          pd.Series([4.0, 4.1, 4.1, 4.1, 3.9], idx))
    assert slope.tolist() == pytest.approx([0.5, -0.1, -0.2, 0.3, -0.4])
    assert m.inversion_periods(slope) == [
        (pd.Timestamp("2024-01-02"), pd.Timestamp("2024-01-03")),
        (pd.Timestamp("2024-01-05"), pd.Timestamp("2024-01-05")),
    ]
```

**Given code:** `main()` prices a 10y 4% bond across yields of 1–8% (the price/yield curve plot), loads `DGS3MO`, `DGS2` and `DGS10`, prints the inversion periods of 10y–2y since 1990 lasting ≥20 trading days, and plots the curve on four dates (2006-12, 2019-08, 2023-07, latest).
**Learner stubs:** all six functions.
**Solution notes:** cash flows `c = face*coupon_rate/freq` for k=1..n=round(years*freq), plus face at n; discount `(1+ytm/freq)**k`; Macaulay = Σ (k/freq)·PV_k / P; modified = Mac/(1+ytm/freq); convexity = Σ CF_k·t_k·(t_k+1/freq)/(1+ytm/freq)**(k+2) / P with `t_k = k/freq`; slope = long − short; inversion runs = contiguous stretches where slope < 0 (`(start, end)` inclusive).

**Content requirements (Block 2):**
- A bond as a stream of cash flows; price/yield inverse; coupon vs yield vs current yield; zero-coupon bonds.
- Duration (Macaulay, modified) and convexity, with engineering intuition (first and second derivatives).
- The yield curve: expectations + term premium; shapes; inversion as a recession signal and its track record including the 2022–2024 "false alarm" debate.
- Treasury auctions, bills vs notes vs bonds, who holds US debt; Vietnamese government bonds (VGB), very briefly.
- Worked example: price the lab's bond by hand, then by code, and estimate the 1bp move with duration.
- ≥5 exercises.
- Anti-patterns: "bond prices and yields move together"; ignoring convexity for big moves; reading inversion as a timing tool.
- **Verify (as of 2026-10):** current 2y, 10y and 3m yields and the curve shape; the date the 2022–2024 10y–2y inversion ended.

**Steps:**
- [ ] D1 write `labs/day07/test_lab.py` (above)
- [ ] D2 write `labs/day07/lab.py` (stubs: all six)
- [ ] D3 `uv run pytest day07` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day07/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day07` → pass; `uv run python -m day07.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day07.md`
- [ ] D8 `uv run python tools/verify_labs.py day07 && uv run python tools/check_content.py day07`
- [ ] D9 controller commit `WIP: task 10 day07 (scratch)`

---

### Task 11: Day 08 — Discounting everything: equities, DCF, and why rates move all assets

**Files:** `content/day08.md`, `labs/day08/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `pv_cashflows(cashflows: list[float], rate: float) -> float` (cash flow k at t=k, k starting at 1); `gordon_value(next_cf: float, r: float, g: float) -> float`; `equity_duration(r: float, g: float) -> float`; `rate_shock_pct(cashflows: list[float], rate: float, shock: float) -> float`; `beta(asset: pd.Series, market: pd.Series) -> float`; `correlation(a: pd.Series, b: pd.Series) -> float`

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_pv():
    assert m.pv_cashflows([100, 100, 100], 0.1) == pytest.approx(
        100 / 1.1 + 100 / 1.21 + 100 / 1.331)


def test_gordon_and_duration():
    assert m.gordon_value(5, 0.08, 0.03) == pytest.approx(100)
    assert m.equity_duration(0.08, 0.03) == pytest.approx(20)


@pytest.mark.parametrize("r,g", [(0.03, 0.03), (0.02, 0.05)])
def test_gordon_rejects_r_le_g(r, g):
    with pytest.raises(ValueError):
        m.gordon_value(5, r, g)


def test_long_duration_cashflows_fall_more():
    growth = [0.0] * 9 + [1000.0]
    value = [100.0] * 10
    g = m.rate_shock_pct(growth, 0.08, 0.01)
    v = m.rate_shock_pct(value, 0.08, 0.01)
    assert g < v < 0
    assert g == pytest.approx((1.08 / 1.09) ** 10 - 1)


def test_beta_and_correlation():
    rng = np.random.default_rng(0)
    mkt = pd.Series(rng.normal(0, 0.01, 500))
    asset = 2 * mkt + 0.0001
    assert m.beta(asset, mkt) == pytest.approx(2.0)
    assert m.correlation(asset, mkt) == pytest.approx(1.0)
```

**Given code:** `main()` loads `IWF` (growth), `IWD` (value), `SPY` and `DGS10`. It computes monthly returns, prints each ETF's beta to SPY and the correlation of monthly returns with the monthly change in the 10y yield for 2022 vs 2010–2019, and plots IWF/IWD relative performance against the 10y yield.
**Learner stubs:** all six.
**Solution notes:** Σ cf/(1+r)**k; `next_cf/(r-g)` raising if `r <= g`; `1/(r-g)`; `pv(r+shock)/pv(r)-1`; `cov(a,m)/var(m)` with aligned inputs and ddof=1 for both; `a.corr(b)`.

**Content requirements (Block 2):**
- What a share is: a residual claim on cash flows; earnings, dividends, buybacks; P/E and earnings yield.
- DCF in one page; the Gordon growth model; equity risk premium = earnings yield − real yield (rough).
- Why rates move every asset: the discount rate is the common factor. Growth stocks behave like long-duration bonds (2022 example).
- Beta and correlation; why correlations change across regimes (stock–bond correlation flipped positive in 2022).
- Vietnamese equities: VN-Index P/E vs history, briefly (preview of Day 16).
- Worked example: shock 8% → 9% on two cash-flow profiles (the lab test).
- ≥5 exercises.
- Anti-patterns: "low P/E = cheap"; ignoring that the discount rate is the price of money; extrapolating one regime's correlation.
- **Verify (as of 2026-10):** S&P 500 forward P/E and VN-Index trailing P/E (approximate ranges, cited).

**Steps:**
- [ ] D1 write `labs/day08/test_lab.py` (above)
- [ ] D2 write `labs/day08/lab.py` (stubs: all six)
- [ ] D3 `uv run pytest day08` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day08/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day08` → pass; `uv run python -m day08.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day08.md`
- [ ] D8 `uv run python tools/verify_labs.py day08 && uv run python tools/check_content.py day08`
- [ ] D9 controller commit `WIP: task 11 day08 (scratch)`

---

### Task 12: Day 09 — Market structure: order books, market makers, settlement, ETFs

**Files:** `content/day09.md`, `labs/day09/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `@dataclass class Order(id: str, side: str, qty: int, price: float | None = None)` (`None` = market order); `@dataclass(frozen=True) class Trade(buy_id: str, sell_id: str, price: float, qty: int)`; `class OrderBook` with `submit(order: Order) -> list[Trade]`, `best_bid() -> float | None`, `best_ask() -> float | None`, `spread() -> float | None`, `depth(side: str) -> list[tuple[float, int]]`; `average_fill_price(trades: list[Trade]) -> float`

**test_lab.py:**
```python
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
O = m.Order


def test_resting_orders_and_spread():
    ob = m.OrderBook()
    assert ob.submit(O("b1", "buy", 10, 99.0)) == []
    assert ob.submit(O("s1", "sell", 5, 101.0)) == []
    assert (ob.best_bid(), ob.best_ask(), ob.spread()) == (99.0, 101.0, 2.0)


def test_empty_book():
    ob = m.OrderBook()
    assert ob.best_bid() is None and ob.best_ask() is None and ob.spread() is None


def test_crossing_limit_trades_at_resting_price():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 5, 100.0))
    assert ob.submit(O("b1", "buy", 5, 101.0)) == [m.Trade("b1", "s1", 100.0, 5)]
    assert ob.best_ask() is None and ob.best_bid() is None


def test_partial_fill_rests_remainder():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 5, 100.0))
    assert ob.submit(O("b1", "buy", 8, 100.0)) == [m.Trade("b1", "s1", 100.0, 5)]
    assert ob.depth("buy") == [(100.0, 3)]


def test_time_priority_at_same_price():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 3, 100.0))
    ob.submit(O("s2", "sell", 3, 100.0))
    assert ob.submit(O("b1", "buy", 4, 100.0)) == [m.Trade("b1", "s1", 100.0, 3),
                                                   m.Trade("b1", "s2", 100.0, 1)]
    assert ob.depth("sell") == [(100.0, 2)]


def test_sell_side_crossing():
    ob = m.OrderBook()
    ob.submit(O("b1", "buy", 2, 100.0))
    ob.submit(O("b2", "buy", 2, 99.0))
    assert ob.submit(O("s1", "sell", 3, 99.0)) == [m.Trade("b1", "s1", 100.0, 2),
                                                   m.Trade("b2", "s1", 99.0, 1)]


def test_market_order_sweeps_levels_and_discards_remainder():
    ob = m.OrderBook()
    ob.submit(O("s1", "sell", 2, 100.0))
    ob.submit(O("s2", "sell", 3, 101.0))
    trades = ob.submit(O("b1", "buy", 10))
    assert [(t.price, t.qty) for t in trades] == [(100.0, 2), (101.0, 3)]
    assert ob.depth("sell") == [] and ob.depth("buy") == []
    assert m.average_fill_price(trades) == pytest.approx(100.6)


def test_depth_aggregates_best_first():
    ob = m.OrderBook()
    for oid, q, p in [("a", 1, 99.0), ("b", 2, 98.0), ("c", 3, 99.0)]:
        ob.submit(O(oid, "buy", q, p))
    assert ob.depth("buy") == [(99.0, 4), (98.0, 2)]


@pytest.mark.parametrize("order", [O("x", "buy", 0, 100.0), O("x", "hold", 1, 100.0),
                                   O("x", "buy", -2, 100.0)])
def test_invalid_orders_rejected(order):
    with pytest.raises(ValueError):
        m.OrderBook().submit(order)
```

**Given code:** the `Order` and `Trade` dataclasses, `OrderBook.__init__` (empty bid/ask price-level structures: `dict[float, collections.deque[Order]]`), and `main()`. `main()` builds a random book, sends market orders of increasing size, and prints the average fill price vs mid (slippage in bps), the "cost curve" a strategy will face on Day 27.
**Learner stubs:** `OrderBook.submit`, `best_bid`, `best_ask`, `spread`, `depth`, `average_fill_price`.
**Solution notes:** validate (side in {"buy","sell"}, qty > 0); match against the opposite side's best price while the price crosses (a market order always crosses); trade price = resting price; FIFO within a level; delete emptied levels; a limit remainder rests and a market remainder is discarded; depth sorts bids descending and asks ascending; average = Σp·q/Σq.

**Content requirements (Block 2):**
- Exchanges vs brokers vs market makers vs clearing houses; the order lifecycle from app tap to settlement.
- Order types (market, limit, stop, stop-limit; IOC/FOK) and when each hurts you; bid/ask, spread, depth, slippage, market impact.
- Settlement: the US moved to T+1 (2024); Vietnam is T+2 with recent reforms. Payment-for-order-flow in one paragraph.
- ETFs: creation/redemption by authorized participants; why ETF price ≈ NAV; premiums/discounts; VNM and Vietnamese domestic ETFs (E1VFVN30, FUEVFVND) as examples.
- Worked example: walk a 10-share market order through a 2-level book.
- ≥5 exercises.
- Anti-patterns: market orders in illiquid names; ignoring the spread in backtests; assuming you trade at the close price.
- **Verify (as of 2026-10):** US T+1 effective date; Vietnam settlement cycle and the non-prefunding rule for foreign institutional investors; KRX trading system status on HOSE; VN lot size (100 shares) and trading sessions (ATO/continuous/ATC).

**Steps:**
- [ ] D1 write `labs/day09/test_lab.py` (above)
- [ ] D2 write `labs/day09/lab.py` (stubs: `submit`, `best_bid`, `best_ask`, `spread`, `depth`, `average_fill_price`)
- [ ] D3 `uv run pytest day09` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day09/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day09` → pass; `uv run python -m day09.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day09.md`
- [ ] D8 `uv run python tools/verify_labs.py day09 && uv run python tools/check_content.py day09`
- [ ] D9 controller commit `WIP: task 12 day09 (scratch)`

---

### Task 13: Day 10 — Portfolio theory: diversification, Sharpe, the frontier

**Files:** `content/day10.md`, `labs/day10/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `annualize_vol(returns: pd.Series, periods: int = 252) -> float`; `sharpe(returns: pd.Series, rf: float = 0.0, periods: int = 252) -> float`; `portfolio_returns(returns: pd.DataFrame, weights) -> pd.Series`; `portfolio_vol(weights, cov) -> float`; `min_variance_weights(cov) -> np.ndarray`; `frontier_two_asset(mu, cov, n: int = 101) -> pd.DataFrame` (columns `w1, ret, vol`)

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_vol_and_sharpe():
    r = pd.Series([0.01, -0.005] * 126)
    assert m.annualize_vol(r) == pytest.approx(r.std(ddof=1) * np.sqrt(252))
    assert m.sharpe(r) == pytest.approx(r.mean() / r.std(ddof=1) * np.sqrt(252))
    ex = r - 0.0252 / 252
    assert m.sharpe(r, rf=0.0252) == pytest.approx(ex.mean() / ex.std(ddof=1) * np.sqrt(252))


def test_portfolio_returns():
    df = pd.DataFrame({"a": [0.1, 0.0], "b": [0.0, 0.2]})
    assert m.portfolio_returns(df, [0.5, 0.5]).tolist() == pytest.approx([0.05, 0.1])


def test_portfolio_vol():
    cov = np.array([[0.04, 0.0], [0.0, 0.04]])
    assert m.portfolio_vol(np.array([0.5, 0.5]), cov) == pytest.approx(np.sqrt(0.02))


def test_min_variance():
    w = m.min_variance_weights(np.array([[0.04, 0.0], [0.0, 0.01]]))
    assert w == pytest.approx([0.2, 0.8])
    assert w.sum() == pytest.approx(1.0)


def test_frontier_perfect_hedge():
    cov = np.array([[0.04, -0.04], [-0.04, 0.04]])
    f = m.frontier_two_asset([0.08, 0.03], cov)
    assert list(f.columns) == ["w1", "ret", "vol"] and len(f) == 101
    mid = f.loc[np.isclose(f["w1"], 0.5)].iloc[0]
    assert mid["vol"] == pytest.approx(0.0, abs=1e-9)
    assert mid["ret"] == pytest.approx(0.055)
    assert f["w1"].iloc[0] == 0.0 and f["w1"].iloc[-1] == 1.0
```

**Given code:** `main()` loads SPY and IEF (plus GLD), builds 100/0, 60/40 and 60/30/10 portfolios with daily rebalancing via `portfolio_returns`, prints the CAGR (`common.quant.cagr` on the equity curve), vol, Sharpe and max drawdown for each, and plots the two-asset frontier from sample statistics.
**Learner stubs:** all six.
**Solution notes:** std·√p; excess = r − rf/p; `returns @ np.asarray(weights)`; `sqrt(max(w@C@w, 0))`; `inv(C)@1 / (1@inv(C)@1)`; `w1 = linspace(0, 1, n)`, ret = w1·mu0 + (1−w1)·mu1, vol from the 2×2 formula clipped at 0.

**Content requirements (Block 2):**
- Risk = volatility as a convention, and its limits (fat tails, drawdowns matter more to humans).
- Diversification math: why correlation < 1 reduces risk; the "only free lunch".
- The Sharpe ratio; the efficient frontier; the capital market line, in one paragraph. Why estimated mean returns are noisy and minimum-variance is more robust.
- Factors in plain English (market, size, value, momentum, quality); a factor ETF is a rules-based portfolio.
- Index investing: the base-rate argument (SPIVA scorecards: most active funds underperform), the bar every strategy must beat.
- Worked example: 60/40 vs 100% equity, 2008 and 2022.
- ≥5 exercises.
- Anti-patterns: optimizing on sample means; "diversified" across correlated assets; ignoring that correlations jump in crises.
- **Verify (as of 2026-10):** the latest SPIVA US scorecard headline number (share of large-cap funds underperforming over 15 years).

**Steps:**
- [ ] D1 write `labs/day10/test_lab.py` (above)
- [ ] D2 write `labs/day10/lab.py` (stubs: all six)
- [ ] D3 `uv run pytest day10` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day10/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day10` → pass; `uv run python -m day10.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day10.md`
- [ ] D8 `uv run python tools/verify_labs.py day10 && uv run python tools/check_content.py day10`
- [ ] D9 controller commit `WIP: task 13 day10 (scratch)`

---

### Task 14: Day 11 — Business cycle, macro regimes, and "priced in"

**Files:** `content/day11.md`, `labs/day11/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `classify_regime(growth: pd.Series, inflation: pd.Series, lag: int = 3) -> pd.Series` (values `"goldilocks" | "reflation" | "stagflation" | "deflation"`); `rolling_zscore(s: pd.Series, window: int) -> pd.Series`; `surprise_z(actual: float, expected: float, std: float) -> float`; `regime_mean_returns(returns: pd.DataFrame, regimes: pd.Series) -> pd.DataFrame`

**test_lab.py:**
```python
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.date_range("2020-01-31", periods=8, freq="ME")


def regimes():
    growth = pd.Series([1, 2, 3, 4, 3, 2, 1, 0], IDX, dtype=float)
    infl = pd.Series([1, 1, 1, 1, 2, 3, 4, 5], IDX, dtype=float)
    return m.classify_regime(growth, infl)


def test_classify_regime():
    r = regimes()
    assert r.index[0] == IDX[3]
    assert r.tolist() == ["goldilocks", "reflation", "stagflation", "stagflation",
                          "stagflation"]


def test_flat_inflation_counts_as_not_rising():
    assert regimes().iloc[0] == "goldilocks"


def test_rolling_zscore():
    z = m.rolling_zscore(pd.Series([1.0, 2.0, 3.0, 4.0, 5.0]), 3)
    assert z.isna().sum() == 2
    assert z.iloc[2] == pytest.approx(1.0)


def test_surprise_z():
    assert m.surprise_z(0.3, 0.2, 0.1) == pytest.approx(1.0)
    with pytest.raises(ValueError):
        m.surprise_z(0.3, 0.2, 0.0)


def test_regime_mean_returns():
    rets = pd.DataFrame({"spy": [0.01, 0.02, -0.01, -0.03, -0.02]}, index=IDX[3:])
    out = m.regime_mean_returns(rets, regimes())
    assert out.loc["goldilocks", "spy"] == pytest.approx(0.01)
    assert out.loc["reflation", "spy"] == pytest.approx(0.02)
    assert out.loc["stagflation", "spy"] == pytest.approx(-0.02)
```

**Given code:** `main()` uses `INDPRO` YoY as growth and `CPIAUCSL` YoY as inflation (monthly), classifies regimes since 1990, joins the monthly returns of SPY, TLT and GLD (from 2005), prints the regime-mean returns table and the current regime, and plots regimes as background colors.
**Learner stubs:** all four.
**Solution notes:** up = `diff(lag) > 0` (strict); map (g_up, i_up) → (T,T) reflation, (T,F) goldilocks, (F,T) stagflation, (F,F) deflation; drop the first `lag` rows. `(s - s.rolling(w).mean()) / s.rolling(w).std(ddof=1)`. `surprise_z` raises if std ≤ 0. Inner-join returns with regimes, then `groupby` mean.

**Content requirements (Block 2):**
- Macro data that moves markets: GDP, payrolls/unemployment, CPI, PMIs, retail sales; release calendar; revisions.
- The business cycle and growth/inflation regimes; which assets tend to do well in each (with the caveat that sample sizes are small).
- The central-bank reaction function (Taylor rule as a sketch); "markets price the path, not the level".
- "Priced in" and surprises: price moves = actual − expected; consensus surveys; the 2022 example where hot CPI prints crushed equities.
- NBER recession dating; Sahm rule as one indicator.
- Worked example: the regime table from the lab.
- ≥5 exercises.
- Anti-patterns: trading headlines; treating regime tables as forecasts; ignoring revisions.
- **Verify (as of 2026-10):** the latest NBER business-cycle dates; current Sahm-rule reading (approximate, cited).

**Steps:**
- [ ] D1 write `labs/day11/test_lab.py` (above)
- [ ] D2 write `labs/day11/lab.py` (stubs: all four)
- [ ] D3 `uv run pytest day11` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day11/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day11` → pass; `uv run python -m day11.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day11.md`
- [ ] D8 `uv run python tools/verify_labs.py day11 && uv run python tools/check_content.py day11`
- [ ] D9 controller commit `WIP: task 14 day11 (scratch)`

---

### Task 15: Day 12 — Integration: Fed meeting day

**Files:** `content/day12.md`, `labs/day12/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `implied_rate(futures_price: float) -> float` (percent); `meeting_adjusted_implied(month_avg: float, current: float, meeting_day: int, days_in_month: int) -> float`; `move_probability(current: float, implied: float, step: float = 0.25) -> float` (signed, clipped to [−1, 1]; negative = cut); `surprise_bp(actual_bp: float, probability: float, step_bp: float = 25.0) -> float`; `asset_reaction_pct(surprise_bp: float, sensitivity_pct_per_bp: float) -> float`

**test_lab.py:**
```python
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_implied_rate():
    assert m.implied_rate(95.75) == pytest.approx(4.25)


def test_meeting_adjustment_recovers_post_meeting_rate():
    # 15 days at 4.50 then 15 days at 4.25 average to 4.375
    assert m.meeting_adjusted_implied(4.375, 4.50, 16, 30) == pytest.approx(4.25)


def test_move_probability():
    assert m.move_probability(4.50, 4.3125) == pytest.approx(-0.75)
    assert m.move_probability(4.50, 4.50) == pytest.approx(0.0)
    assert m.move_probability(4.50, 4.00) == pytest.approx(-1.0)  # clipped
    assert m.move_probability(4.50, 4.625) == pytest.approx(0.5)


def test_surprise():
    assert m.surprise_bp(-25, -0.75) == pytest.approx(-6.25)
    assert m.surprise_bp(-25, -1.0) == pytest.approx(0.0)  # fully priced in
    assert m.surprise_bp(0, -0.75) == pytest.approx(18.75)  # a "hawkish hold"


def test_reaction():
    assert m.asset_reaction_pct(-6.25, -0.1) == pytest.approx(0.625)


def test_meeting_day_bounds():
    with pytest.raises(ValueError):
        m.meeting_adjusted_implied(4.4, 4.5, 31, 30)
```

**Given code:** a `SCENARIOS` list of 3 hypothetical meetings (futures price, current rate, meeting day, actual decision, plus per-asset sensitivities for SPY, TLT, DXY and BTC). `main()` runs each scenario and prints a "meeting-day tape" table.
**Learner stubs:** all five.
**Solution notes:** `100 - price`; `(avg*D - current*(day-1)) / (D-day+1)`, raising unless `1 <= day <= D`; `clip((implied-current)/step, -1, 1)`; `actual - prob*step_bp`; product.

**Content requirements (integration day):**
- Recap map of Days 7–11: rates → bond prices → discounting → market mechanics → portfolio → regimes.
- How FOMC meetings work: statement, dot plot, press conference, minutes. Reading the CME FedWatch idea (computed by this lab) without naming it as a data source used by the lab.
- `## Worked example`: walk through a real past FOMC day (choose one from 2024–2025, verified) showing pre-meeting pricing, the decision, and next-day moves in 2y, 10y, SPY and DXY.
- `## Exercises` (≥3 case drills): run each scenario; explain a "hawkish cut"; predict the 2y vs 10y reaction to a dot-plot shift.
- `## Checkpoint quiz` (12–15 questions over Days 7–11) + `## Answer key`.
- Journal: 3 claims about the next FOMC decision with probabilities.
- **Verify (as of 2026-10):** the FOMC 2026 meeting calendar (the remaining meetings); the chosen real FOMC day's numbers.

**Steps:**
- [ ] D1 write `labs/day12/test_lab.py` (above)
- [ ] D2 write `labs/day12/lab.py` (scenarios + stubs: all five)
- [ ] D3 `uv run pytest day12` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day12/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day12` → pass; `uv run python -m day12.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day12.md` (integration headings)
- [ ] D8 `uv run python tools/verify_labs.py day12 && uv run python tools/check_content.py day12`
- [ ] D9 controller commit `WIP: task 15 day12 (scratch)`

---

### Task 16: Day 13 — FX mechanics: forwards, interest parity, carry

**Files:** `content/day13.md`, `labs/day13/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Convention: `spot` is quote-currency units per 1 base-currency unit (USD/VND = 25,000 means 1 USD = 25,000 VND). Rates are simple annual decimals; `t` is in years.
- Produces: `forward_rate(spot, r_quote, r_base, t) -> float`; `forward_points(spot, r_quote, r_base, t) -> float`; `cip_deviation_bp(spot, forward, r_quote, r_base, t) -> float`; `carry_trade_return(spot_start, spot_end, r_invest, r_fund, t) -> float` (per 1 unit of funding currency; spot = invest-currency per funding-currency); `fx_return(spot_start, spot_end) -> float` (return of holding the base currency, in quote terms)

**test_lab.py:**
```python
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_forward_rate_cip():
    assert m.forward_rate(25000, 0.05, 0.04, 1.0) == pytest.approx(25000 * 1.05 / 1.04)
    assert m.forward_rate(25000, 0.05, 0.04, 0.25) == pytest.approx(
        25000 * 1.0125 / 1.01)


def test_forward_points_sign():
    assert m.forward_points(25000, 0.05, 0.04, 1.0) > 0   # higher quote rate → forward premium
    assert m.forward_points(25000, 0.03, 0.04, 1.0) < 0


def test_cip_deviation():
    fair = m.forward_rate(25000, 0.05, 0.04, 1.0)
    assert m.cip_deviation_bp(25000, fair, 0.05, 0.04, 1.0) == pytest.approx(0.0)
    assert m.cip_deviation_bp(25000, fair * 1.001, 0.05, 0.04, 1.0) == pytest.approx(10.0)


def test_carry_trade():
    assert m.carry_trade_return(25000, 25000, 0.05, 0.04, 1.0) == pytest.approx(0.01)
    # target currency depreciates 5% (25,000 → 26,250 per USD): carry wiped out
    assert m.carry_trade_return(25000, 26250, 0.05, 0.04, 1.0) == pytest.approx(-0.04)


def test_fx_return():
    assert m.fx_return(25000, 26250) == pytest.approx(0.05)


def test_bad_time():
    with pytest.raises(ValueError):
        m.forward_rate(25000, 0.05, 0.04, -1)
```

**Given code:** `main()` loads `VND=X` (USD/VND) and computes the 1-year forward under assumed rates (a constant table of VND and USD 12m deposit rates, verified in content). It prints the forward points vs spot, the realized 1y change since 2015 compared with what the forward "predicted" (UIP failure), and plots both.
**Learner stubs:** all five.
**Solution notes:** `S*(1+r_q t)/(1+r_b t)`, raising if t ≤ 0; points = F − S; `(F/F_fair - 1)*1e4`; `S0*(1+ri t)/S1 - (1+rf t)`; `S1/S0 - 1`.

**Content requirements (Block 3):**
- Quote conventions (base/quote, pips, direct vs indirect); the "which currency am I long?" drill.
- Spot vs forward vs swap; covered interest parity as a no-arbitrage identity, with a T-account of the arbitrage; CIP deviations post-2008 as a dollar-funding-cost signal.
- Uncovered interest parity and why it fails (forward premium puzzle); the carry trade = "picking up nickels in front of a steamroller"; JPY carry unwind August 2024.
- FX market structure: OTC, dealers, the size of the market (BIS Triennial Survey).
- Worked example: a VND/USD forward from deposit rates.
- ≥5 exercises.
- Anti-patterns: mixing up quote direction; treating the forward as a forecast; ignoring crash risk in carry.
- **Verify (as of 2026-10):** USD/VND spot; Vietnamese 12-month deposit rates at major banks; USD 12m rate; the BIS Triennial Survey daily turnover figure (2025 survey).

**Steps:**
- [ ] D1 write `labs/day13/test_lab.py` (above)
- [ ] D2 write `labs/day13/lab.py` (stubs: all five)
- [ ] D3 `uv run pytest day13` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day13/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day13` → pass; `uv run python -m day13.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day13.md`
- [ ] D8 `uv run python tools/verify_labs.py day13 && uv run python tools/check_content.py day13`
- [ ] D9 controller commit `WIP: task 16 day13 (scratch)`

---

### Task 17: Day 14 — The dollar system

**Files:** `content/day14.md`, `labs/day14/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `event_window(series: pd.Series, events: list, before: int, after: int) -> pd.DataFrame` (index = relative day `-before..after`, one column per kept event Timestamp, values = `series[pos+k]/series[pos] - 1`); `average_path(window: pd.DataFrame) -> pd.Series`; `dollar_beta(em_returns: pd.DataFrame, usd_returns: pd.Series) -> pd.Series`

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
S = pd.Series(np.arange(100.0, 120.0), index=pd.date_range("2024-01-01", periods=20, freq="D"))


def test_event_window_values():
    w = m.event_window(S, [pd.Timestamp("2024-01-06")], before=2, after=2)
    assert list(w.index) == [-2, -1, 0, 1, 2]
    assert list(w.columns) == [pd.Timestamp("2024-01-06")]
    assert w.iloc[:, 0].tolist() == pytest.approx(
        [103 / 105 - 1, 104 / 105 - 1, 0.0, 106 / 105 - 1, 107 / 105 - 1])


def test_events_out_of_range_or_missing_are_skipped():
    w = m.event_window(S, [pd.Timestamp("2024-01-01"), pd.Timestamp("2025-01-01"),
                           pd.Timestamp("2024-01-10")], before=2, after=2)
    assert list(w.columns) == [pd.Timestamp("2024-01-10")]


def test_average_path():
    w = m.event_window(S, [pd.Timestamp("2024-01-06"), pd.Timestamp("2024-01-10")], 1, 1)
    avg = m.average_path(w)
    assert avg.loc[0] == 0.0
    assert avg.loc[1] == pytest.approx(((106 / 105 - 1) + (110 / 109 - 1)) / 2)


def test_dollar_beta():
    rng = np.random.default_rng(1)
    usd = pd.Series(rng.normal(0, 0.005, 300))
    em = pd.DataFrame({"a": 1.5 * usd, "b": -0.5 * usd})
    assert m.dollar_beta(em, usd).tolist() == pytest.approx([1.5, -0.5])
```

**Given code:** `main()` loads `DTWEXBGS` (broad dollar) and the EM FX series (`DEXKOUS`, `DEXBZUS`, `DEXINUS`, `DEXTHUS`, `DEXMXUS`, all local per USD). It prints each currency's dollar beta on daily changes and the average 20-day path of the broad dollar around FOMC-hike dates in 2022 (a constant list of 2022 FOMC decision dates, verified), and plots the average path.
**Learner stubs:** all three.
**Solution notes:** position via `series.index.get_loc(ts)` inside try/except KeyError; skip if `pos-before < 0` or `pos+after >= len`; build the columns dict in event order. `mean(axis=1)`; per column `cov/var` with ddof=1.

**Content requirements (Block 3):**
- Why the dollar is the reserve currency: invoicing, debt, reserves, deep Treasury market; the "exorbitant privilege".
- Eurodollars and offshore dollar credit; the global dollar funding structure; Fed swap lines (who has standing lines) and the FIMA repo facility.
- The dollar smile; strong-dollar cycles and EM stress (1980s, 1997, 2013 taper tantrum, 2022).
- Dollar indices: DXY (EUR-heavy) vs broad trade-weighted (`DTWEXBGS`).
- Event studies as a method (this lab); pitfalls (overlapping events, look-ahead).
- Worked example: 2022 hikes and the broad dollar.
- ≥5 exercises.
- Anti-patterns: treating DXY as "the dollar"; ignoring offshore dollar debt; cherry-picking event dates.
- **Verify (as of 2026-10):** the list of standing Fed swap-line central banks; dollar share of global FX reserves (IMF COFER latest); 2022 FOMC decision dates.

**Steps:**
- [ ] D1 write `labs/day14/test_lab.py` (above)
- [ ] D2 write `labs/day14/lab.py` (stubs: all three)
- [ ] D3 `uv run pytest day14` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day14/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day14` → pass; `uv run python -m day14.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day14.md`
- [ ] D8 `uv run python tools/verify_labs.py day14 && uv run python tools/check_content.py day14`
- [ ] D9 controller commit `WIP: task 17 day14 (scratch)`

---

### Task 18: Day 15 — Exchange-rate regimes, the impossible trinity, currency crises

**Files:** `content/day15.md`, `labs/day15/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `trinity_violation(fixed_fx: bool, open_capital: bool, independent_policy: bool) -> bool`; `defend_peg(reserves: float, outflows: list[float], floor: float) -> tuple[int | None, list[float]]`; `rate_to_defend(r_foreign: float, expected_depreciation: float) -> float`; `import_cover_months(reserves: float, monthly_imports: float) -> float`

**test_lab.py:**
```python
import itertools

import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_trinity_only_all_three_violates():
    for combo in itertools.product([True, False], repeat=3):
        assert m.trinity_violation(*combo) == all(combo)


def test_peg_breaks_when_reserves_would_cross_floor():
    assert m.defend_peg(100.0, [30.0, 30.0, 30.0], floor=20.0) == (3, [70.0, 40.0])


def test_peg_survives():
    assert m.defend_peg(100.0, [10.0, 10.0], floor=20.0) == (None, [90.0, 80.0])


def test_inflows_rebuild_reserves():
    assert m.defend_peg(50.0, [-20.0, 40.0], floor=20.0) == (None, [70.0, 30.0])


def test_rate_to_defend_uip():
    assert m.rate_to_defend(0.05, 0.20) == pytest.approx(0.26)


def test_import_cover():
    assert m.import_cover_months(90.0, 30.0) == pytest.approx(3.0)
    with pytest.raises(ValueError):
        m.import_cover_months(90.0, 0.0)
```

**Given code:** `main()` runs three stylized crisis scenarios (Thailand 1997, Argentina, Turkey) defined as constants: starting reserves, an outflow path and a floor. It prints the break step, the rate needed to hold the peg, and import cover, and plots the reserve paths. The scenario numbers are labeled "stylized, not historical data" in comments.
**Learner stubs:** all four.
**Solution notes:** `all(...)`; iterate: if `reserves - out < floor` → return `(step, path)` with step 1-indexed, else update and append; `(1+rf)*(1+d)-1`; raise if imports ≤ 0.

**Content requirements (Block 3):**
- Regimes: free float, managed float, crawling peg/band, hard peg, currency board, dollarization, monetary union.
- The impossible trinity with real examples: HK (peg + open, no independent policy), China (managed + capital controls), US (float), Vietnam (managed band + partial controls), previewing Day 16.
- Reserves, sterilization, why pegs break (first-, second- and third-generation crisis models in plain English).
- Case studies: Asia 1997 (Thailand), Argentina (convertibility and recent regimes), Turkey (unorthodox rates and lira collapse).
- IMF reserve-adequacy rules of thumb (3 months of import cover, Greenspan–Guidotti).
- Worked example: the Thailand-style scenario in the lab.
- ≥5 exercises.
- Anti-patterns: "a peg is stable until it isn't" ignored; ignoring short-term external debt; believing high rates always defend a peg.
- **Verify (as of 2026-10):** Argentina's current FX regime; Turkey's policy rate and regime; HKD band (7.75–7.85).

**Steps:**
- [ ] D1 write `labs/day15/test_lab.py` (above)
- [ ] D2 write `labs/day15/lab.py` (stubs: all four)
- [ ] D3 `uv run pytest day15` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day15/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day15` → pass; `uv run python -m day15.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day15.md`
- [ ] D8 `uv run python tools/verify_labs.py day15 && uv run python tools/check_content.py day15`
- [ ] D9 controller commit `WIP: task 18 day15 (scratch)`

---

### Task 19: Day 16 — Vietnam: SBV, the VND band, and the stock market

**Files:** `content/day16.md`, `labs/day16/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `sbv_band(central_rate: float, band: float = 0.05) -> tuple[float, float]`; `within_band(market: pd.Series, central: pd.Series, band: float = 0.05) -> pd.Series`; `hose_tick(price: float) -> int`; `price_limits(ref_price: float, exchange: str) -> tuple[int, int]` (floor, ceiling); `flag_limit_moves(close: pd.Series, exchange: str) -> pd.Series`; `foreign_room(cap_pct: float, foreign_shares: float, total_shares: float) -> float`

**test_lab.py:**
```python
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_sbv_band():
    assert m.sbv_band(25000) == pytest.approx((23750.0, 26250.0))


def test_within_band():
    idx = pd.date_range("2024-01-01", periods=3, freq="D")
    central = pd.Series([24000.0] * 3, idx)
    market = pd.Series([24500.0, 25300.0, 22700.0], idx)
    assert m.within_band(market, central).tolist() == [True, False, False]


@pytest.mark.parametrize("price,tick", [(9_990, 10), (10_000, 50), (49_950, 50), (50_000, 100)])
def test_hose_tick(price, tick):
    assert m.hose_tick(price) == tick


@pytest.mark.parametrize("ref,exchange,expected", [
    (25_000, "HOSE", (23_250, 26_750)),
    (10_250, "HOSE", (9_540, 10_950)),
    (10_250, "HNX", (9_300, 11_200)),
    (10_000, "UPCOM", (8_500, 11_500)),
])
def test_price_limits(ref, exchange, expected):
    assert m.price_limits(ref, exchange) == expected


def test_unknown_exchange():
    with pytest.raises(ValueError):
        m.price_limits(10_000, "NYSE")


def test_flag_limit_moves():
    close = pd.Series([25_000.0, 26_750.0, 27_000.0, 25_150.0])
    assert m.flag_limit_moves(close, "HOSE").tolist() == [False, True, False, True]


def test_foreign_room():
    assert m.foreign_room(0.49, 400, 1000) == pytest.approx(90)
    assert m.foreign_room(0.30, 300, 1000) == pytest.approx(0)
```

**Given code:** `main()` loads `VNINDEX`, `FPT`, `HPG`, `VCB` and `VND=X`. It prints VN-Index CAGR and max drawdown in points, counts limit-hit days per stock (HOSE), shows USD/VND against a ±5% band around a smoothed proxy for the central rate (a 60-day rolling mean, labeled "proxy" in output and comments, because SBV central-rate history is not in the snapshot), and plots VN-Index against USD/VND.
**Learner stubs:** all six.
**Solution notes:**
- HOSE ±7% with `hose_tick`; HNX ±10% and UPCOM ±15%, both tick 100. Exchange names are case-insensitive. Any other exchange raises.
- Compute `raw = round(ref*(1±limit), 6)` to kill float noise. Ceiling = `floor(raw_up / tick(raw_up)) * tick(raw_up)`; floor = `ceil(raw_dn / tick(raw_dn)) * tick(raw_dn)`. Return ints.
- `flag_limit_moves`: element 0 is False; for t ≥ 1, close equals the floor or ceiling computed from close[t-1].
- `foreign_room = max(0, cap*total - foreign)`.
- `within_band`: `abs(market/central - 1) <= band`.

**Content requirements (Block 3):**
- SBV mandate and tools: refinancing/rediscount rates, OMO, reserve requirements, credit growth quotas, FX intervention, gold market management.
- The VND regime: daily central rate + ±5% trading band, the managed crawl, dollarization history, FX reserves and import cover.
- Gold in Vietnam: SJC premium, the 2024–2025 reforms; why gold matters for household savings and the balance of payments.
- Capital flows: FDI, remittances, the trade surplus; why the trinity binds (Day 15).
- The stock market: HOSE/HNX/UPCoM; VN-Index and VN30; lot size and sessions; daily price limits and ticks; foreign ownership limits (the 49%/30% defaults and sector caps); ETFs; the dominance of retail investors and margin lending; the market classification upgrade status.
- Investing access for a Vietnamese resident: domestic brokers; restrictions on outward investment (keep it factual and cite sources; no advice).
- Worked example: price limits for a HOSE stock across a 3-day limit-down streak.
- ≥5 exercises.
- Anti-patterns: ignoring limit-locked days in backtests (you can't trade them); treating VN-Index like the S&P 500 (concentration, state-owned weight); ignoring FOL "room" premiums.
- **Verify (as of 2026-10):** SBV band width and the current central rate; SBV refinancing rate; HOSE/HNX/UPCoM limits and tick sizes; settlement cycle; foreign-ownership rules; the FTSE Russell / MSCI classification status and effective dates; deposit insurance limit; gold market rules.

**Steps:**
- [ ] D1 write `labs/day16/test_lab.py` (above)
- [ ] D2 write `labs/day16/lab.py` (stubs: all six)
- [ ] D3 `uv run pytest day16` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day16/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day16` → pass; `uv run python -m day16.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day16.md`
- [ ] D8 `uv run python tools/verify_labs.py day16 && uv run python tools/check_content.py day16`
- [ ] D9 controller commit `WIP: task 19 day16 (scratch)`

---

### Task 20: Day 17 — Investing across currencies

**Files:** `content/day17.md`, `labs/day17/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `home_return(asset_ret: float, fx_ret: float) -> float`; `hedged_return(asset_ret: float, r_home: float, r_foreign: float, t: float = 1.0) -> float`; `vnd_returns(usd_prices: pd.Series, usdvnd: pd.Series) -> pd.Series` (named `"vnd_return"`); `net_return(gross: float, fee_bps: float, fx_spread_bps: float) -> float`

**test_lab.py:**
```python
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_home_return_compounds():
    assert m.home_return(0.10, 0.05) == pytest.approx(0.155)
    assert m.home_return(0.10, -0.10) == pytest.approx(-0.01)


def test_hedged_return():
    assert m.hedged_return(0.10, 0.05, 0.04) == pytest.approx(1.10 * 1.05 / 1.04 - 1)


def test_vnd_returns():
    idx = pd.to_datetime(["2024-01-02", "2024-01-03"])
    r = m.vnd_returns(pd.Series([100.0, 110.0], idx), pd.Series([25000.0, 25500.0], idx))
    assert r.name == "vnd_return"
    assert r.tolist() == pytest.approx([1.1 * 1.02 - 1])


def test_vnd_returns_forward_fills_fx_holidays():
    idx = pd.to_datetime(["2024-01-02", "2024-01-03", "2024-01-04"])
    fx = pd.Series([25000.0, 25500.0], pd.to_datetime(["2024-01-02", "2024-01-03"]))
    r = m.vnd_returns(pd.Series([100.0, 110.0, 121.0], idx), fx)
    assert len(r) == 2
    assert r.iloc[-1] == pytest.approx(0.10)


def test_net_return():
    expected = 1.10 * (1 - 0.0020) * (1 - 0.0050) ** 2 - 1
    assert m.net_return(0.10, 20, 50) == pytest.approx(expected)
```

**Given code:** `main()` loads SPY, EEM, VNM and `VND=X`. It prints the USD vs VND CAGR of SPY since 2010 and the contribution of the FX move, compares SPY in VND with VN-Index (`load_vn`), and plots all in VND, rebased to 100.
**Learner stubs:** all four.
**Solution notes:** `(1+a)(1+f)-1`; `(1+a)*(1+r_home t)/(1+r_foreign t) - 1`; `fx.reindex(prices.index).ffill()`, then `(p*fx).pct_change().dropna()`; `(1+g)*(1-fee/1e4)*(1-spread/1e4)**2 - 1`.

**Content requirements (Block 3):**
- Your return = asset return × currency return; the VND-based investor's view of US assets.
- Hedging: what a hedge costs or pays (the interest differential from Day 13); when hedging is worth it (bonds usually yes, equities debatable).
- Costs that compound: FX spreads, brokerage, custody, withholding taxes on US dividends for non-residents (general description, cite IRS), Vietnamese tax on securities transactions (0.1% of sale value, verify).
- Home bias and diversification across currencies; correlation of VND with risk assets.
- Worked example: SPY 2015–2025 in USD vs VND.
- ≥5 exercises.
- Anti-patterns: comparing returns in different currencies; ignoring FX conversion spreads on every round trip; assuming hedging is free.
- **Verify (as of 2026-10):** the VN personal income tax rate on securities sales; US dividend withholding for non-resident aliens (30% default; whether a US–Vietnam tax treaty is in force); current VND–USD rate differential.

**Steps:**
- [ ] D1 write `labs/day17/test_lab.py` (above)
- [ ] D2 write `labs/day17/lab.py` (stubs: all four)
- [ ] D3 `uv run pytest day17` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day17/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day17` → pass; `uv run python -m day17.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day17.md`
- [ ] D8 `uv run python tools/verify_labs.py day17 && uv run python tools/check_content.py day17`
- [ ] D9 controller commit `WIP: task 20 day17 (scratch)`

---

### Task 21: Day 18 — Integration: the cross-currency scorecard

**Files:** `content/day18.md`, `labs/day18/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Consumes: `common.quant.cagr`, `annualize_vol`, `sharpe`, `max_drawdown`, `simple_returns`
- Produces: `to_vnd_prices(usd_prices: pd.Series, usdvnd: pd.Series) -> pd.Series`; `scorecard(prices: dict[str, pd.Series]) -> pd.DataFrame` (index = names in input order; columns `["cagr", "vol", "sharpe", "max_drawdown"]`); `hedge_decision(expected_depreciation: float, hedge_cost: float) -> str` (`"hedge"` or `"stay unhedged"`)

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common import quant
from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.bdate_range("2020-01-01", periods=800)


def series(seed):
    rng = np.random.default_rng(seed)
    return pd.Series(100 * np.exp(np.cumsum(rng.normal(0.0003, 0.01, len(IDX)))), IDX)


def test_to_vnd_prices():
    p = pd.Series([100.0, 110.0], IDX[:2])
    fx = pd.Series([25000.0], IDX[:1])
    assert m.to_vnd_prices(p, fx).tolist() == [2_500_000.0, 2_750_000.0]


def test_scorecard_matches_reference_helpers():
    a, b = series(1), series(2)
    sc = m.scorecard({"a": a, "b": b})
    assert list(sc.index) == ["a", "b"]
    assert list(sc.columns) == ["cagr", "vol", "sharpe", "max_drawdown"]
    r = quant.simple_returns(a)
    assert sc.loc["a", "cagr"] == pytest.approx(quant.cagr(a))
    assert sc.loc["a", "vol"] == pytest.approx(quant.annualize_vol(r))
    assert sc.loc["a", "sharpe"] == pytest.approx(quant.sharpe(r))
    assert sc.loc["a", "max_drawdown"] == pytest.approx(quant.max_drawdown(a))


@pytest.mark.parametrize("dep,cost,expected", [(0.04, 0.01, "hedge"),
                                               (0.01, 0.03, "stay unhedged"),
                                               (0.02, 0.02, "stay unhedged")])
def test_hedge_decision(dep, cost, expected):
    assert m.hedge_decision(dep, cost) == expected
```

**Given code:** `main()` builds the scorecard for SPY (in USD), SPY (in VND), VNM (in VND), VN-Index (points), GLD (in VND) and BTC-USD (in VND) since 2015 on the common date range, and prints it sorted by Sharpe.
**Learner stubs:** all three.
**Solution notes:** `p * fx.reindex(p.index).ffill()`; per name, apply the `common.quant` helpers on `simple_returns`; hedge if `expected_depreciation > hedge_cost` (strict).

**Content requirements (integration day):**
- Recap map of Days 13–17: quotes → parity → dollar system → regimes → Vietnam → cross-currency returns.
- `## Worked example`: a full walkthrough of the scorecard on the snapshot and what it does *not* tell you (survivorship of the chosen assets, the period chosen).
- `## Exercises` (≥3 case drills): (a) a VND depreciation scenario's effect on a VN investor holding SPY, hedged vs not; (b) explain why USD/VND rarely leaves the band, and what would make it; (c) a mock news item ("SBV raises refinancing rate 50 bp") → predicted effect on VND, VN-Index, and deposit rates, with reasoning.
- `## Checkpoint quiz` (12–15 questions over Days 13–17) + `## Answer key`.
- **Verify (as of 2026-10):** any current numbers in quiz items.

**Steps:**
- [ ] D1 write `labs/day18/test_lab.py` (above)
- [ ] D2 write `labs/day18/lab.py` (stubs: all three)
- [ ] D3 `uv run pytest day18` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day18/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day18` → pass; `uv run python -m day18.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day18.md` (integration headings)
- [ ] D8 `uv run python tools/verify_labs.py day18 && uv run python tools/check_content.py day18`
- [ ] D9 controller commit `WIP: task 21 day18 (scratch)`

---

### Task 22: Day 19 — Bitcoin: UTXOs, proof of work, monetary policy as code

**Files:** `content/day19.md`, `labs/day19/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces (amounts in satoshis, `int`): `block_subsidy(height: int) -> int`; `total_supply(height: int) -> int` (sum of subsidies for heights `0..height-1`); `mine(header: str, difficulty: int) -> tuple[int, str]`; given `TxOut(address: str, amount: int)`, `Tx(inputs: tuple[tuple[str, int], ...], outputs: tuple[TxOut, ...])` with `txid() -> str`, `InvalidTx(ValueError)`; `class Chain(difficulty: int = 2)` with `utxos: dict[tuple[str, int], TxOut]`, `blocks: list[dict]`, `add_block(txs: list[Tx], miner: str) -> dict`, `balance(address: str) -> int`

**test_lab.py:**
```python
import hashlib

import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
BTC = 100_000_000


def test_subsidy_schedule():
    assert m.block_subsidy(0) == 50 * BTC
    assert m.block_subsidy(209_999) == 50 * BTC
    assert m.block_subsidy(210_000) == 25 * BTC
    assert m.block_subsidy(840_000) == 312_500_000
    assert m.block_subsidy(64 * 210_000) == 0


def test_supply_cap():
    assert m.total_supply(210_000) == 210_000 * 50 * BTC
    assert m.total_supply(64 * 210_000) == 2_099_999_997_690_000
    assert m.total_supply(10 ** 8) == 2_099_999_997_690_000


def test_mine():
    nonce, h = m.mine("hdr", 3)
    assert h.startswith("000")
    assert h == hashlib.sha256(f"hdr{nonce}".encode()).hexdigest()


def spend(chain, txid, to, amount, change_to, change):
    return m.Tx(inputs=((txid, 0),), outputs=(m.TxOut(to, amount), m.TxOut(change_to, change)))


def test_genesis_pays_miner():
    c = m.Chain()
    b = c.add_block([], "alice")
    assert c.balance("alice") == 50 * BTC
    assert b["height"] == 0 and b["prev_hash"] == "0" * 64 and b["hash"].startswith("00")


def test_spend_with_fee_and_linking():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    tx = spend(c, cb, "bob", 10 * BTC, "alice", 39 * BTC)
    b1 = c.add_block([tx], "miner")
    assert c.balance("bob") == 10 * BTC
    assert c.balance("alice") == 39 * BTC
    assert c.balance("miner") == 51 * BTC
    assert b1["prev_hash"] == c.blocks[0]["hash"]


def test_double_spend_across_blocks_rejected_atomically():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    c.add_block([spend(c, cb, "bob", 10 * BTC, "alice", 40 * BTC)], "miner")
    with pytest.raises(m.InvalidTx):
        c.add_block([spend(c, cb, "carol", 10 * BTC, "alice", 40 * BTC)], "miner")
    assert len(c.blocks) == 2 and c.balance("carol") == 0


def test_double_spend_within_block_rejected():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    t1 = spend(c, cb, "bob", 10 * BTC, "alice", 40 * BTC)
    t2 = spend(c, cb, "carol", 10 * BTC, "alice", 40 * BTC)
    with pytest.raises(m.InvalidTx):
        c.add_block([t1, t2], "miner")
    assert len(c.blocks) == 1


def test_overspend_rejected():
    c = m.Chain()
    cb = c.add_block([], "alice")["txids"][0]
    with pytest.raises(m.InvalidTx):
        c.add_block([spend(c, cb, "bob", 45 * BTC, "alice", 10 * BTC)], "miner")
```

**Given code:**
```python
@dataclass(frozen=True)
class TxOut:
    address: str
    amount: int


@dataclass(frozen=True)
class Tx:
    inputs: tuple[tuple[str, int], ...]
    outputs: tuple[TxOut, ...]

    def txid(self) -> str:
        body = {"in": [list(i) for i in self.inputs],
                "out": [[o.address, o.amount] for o in self.outputs]}
        return hashlib.sha256(json.dumps(body, sort_keys=True).encode()).hexdigest()


class InvalidTx(ValueError):
    pass


class Chain:
    def __init__(self, difficulty: int = 2):
        self.difficulty = difficulty
        self.utxos: dict[tuple[str, int], TxOut] = {}
        self.blocks: list[dict] = []
```
`main()` prints the issuance schedule by era (height, subsidy, cumulative supply, % of cap), the mining time at difficulty 1–5 (timed), and plots the supply curve. The module docstring states: toy model, no signatures or scripts, no difficulty adjustment.
**Learner stubs:** `block_subsidy`, `total_supply`, `mine`, `Chain.add_block`, `Chain.balance`.
**Solution notes:**
- `subsidy = (50*BTC) >> (height // 210_000)` and 0 when halvings ≥ 64. `total_supply` sums per era in closed form (don't loop over 13M heights).
- `mine`: nonce from 0 upward until the hex digest has the prefix.
- `add_block`: validate all txs against current `utxos` with a block-local `spent` set. Inputs must exist and be unspent; Σin ≥ Σout. No spending of outputs created in the same block. Raise `InvalidTx` before mutating. Then fees = Σ(in−out); coinbase `Tx(inputs=(("coinbase", height),), outputs=(TxOut(miner, subsidy+fees),))` goes first. Apply: remove spent outpoints and add `(txid, i)` outputs. `header = f"{height}|{prev_hash}|{','.join(txids)}"`; mine; append and return `{"height", "prev_hash", "txids", "nonce", "hash"}`.
- `balance`: sum the UTXO amounts for the address.

**Content requirements (Block 4):**
- The problem Bitcoin solves (double-spend without a trusted ledger keeper); a hash function as a fingerprint; blocks and chaining.
- UTXO vs account model; transactions, fees, change outputs; signatures (explained, not implemented in the lab).
- Proof of work, difficulty adjustment every 2016 blocks, the longest-/most-work chain rule, 51% attacks, finality as probability.
- Monetary policy as code: halvings, the 21M cap, issuance vs fees long-term (the security budget question).
- Bitcoin as money: hierarchy-of-money placement (Day 1), volatility, custody (keys), spot ETFs as a bridge (preview of Day 23).
- Worked example: walk the lab's genesis + spend + fee.
- ≥5 exercises.
- Anti-patterns: "Bitcoin is anonymous"; "the cap makes price go up"; confusing a wallet with an account.
- **Verify (as of 2026-10):** current block height, the subsidy (3.125 BTC since April 2024; next halving estimate), circulating supply, hashrate order of magnitude.

**Steps:**
- [ ] D1 write `labs/day19/test_lab.py` (above)
- [ ] D2 write `labs/day19/lab.py` (given code + stubs `block_subsidy`, `total_supply`, `mine`, `Chain.add_block`, `Chain.balance`)
- [ ] D3 `uv run pytest day19` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day19/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day19` → pass; `uv run python -m day19.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day19.md`
- [ ] D8 `uv run python tools/verify_labs.py day19 && uv run python tools/check_content.py day19`
- [ ] D9 controller commit `WIP: task 22 day19 (scratch)`

---

### Task 23: Day 20 — Ethereum: accounts, gas, EIP-1559, staking

**Files:** `content/day20.md`, `labs/day20/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Consumes: `common.data.load_json`
- Produces: `hex_to_int(h: str) -> int`; `parse_block(raw: dict) -> dict` (keys `number`, `timestamp` (tz-aware UTC `datetime`), `base_fee_gwei`, `gas_used`, `gas_limit`, `tx_count`, `utilization`); `next_base_fee(base_fee_wei: int, gas_used: int, gas_limit: int) -> int`; `tx_fee_eth(receipt: dict) -> float`; `burned_eth(raw_block: dict) -> float`; `priority_fee_eth(receipt: dict, base_fee_wei: int) -> float`

**test_lab.py:**
```python
import pytest

from common.data import load_json
from common.labimpl import load_impl

m = load_impl(__file__)
RAW = {"number": "0x10", "timestamp": "0x65000000", "baseFeePerGas": hex(20 * 10 ** 9),
       "gasUsed": hex(15_000_000), "gasLimit": hex(30_000_000), "transactions": ["0xa", "0xb"]}
RECEIPT = {"gasUsed": hex(21_000), "effectiveGasPrice": hex(30 * 10 ** 9)}


def test_hex_to_int():
    assert m.hex_to_int("0x1a") == 26 and m.hex_to_int("0x0") == 0


def test_parse_block():
    b = m.parse_block(RAW)
    assert b["number"] == 16 and b["tx_count"] == 2
    assert b["timestamp"].timestamp() == 1_694_498_816
    assert b["timestamp"].tzinfo is not None
    assert b["base_fee_gwei"] == pytest.approx(20.0)
    assert b["utilization"] == pytest.approx(0.5)


@pytest.mark.parametrize("used,expected", [(30_000_000, 1_125_000_000),
                                           (0, 875_000_000),
                                           (15_000_000, 1_000_000_000)])
def test_eip1559_base_fee(used, expected):
    assert m.next_base_fee(10 ** 9, used, 30_000_000) == expected


def test_fees_and_burn():
    assert m.tx_fee_eth(RECEIPT) == pytest.approx(0.00063)
    assert m.burned_eth(RAW) == pytest.approx(0.3)
    assert m.priority_fee_eth(RECEIPT, 20 * 10 ** 9) == pytest.approx(21_000 * 10 * 10 ** 9 / 1e18)


def test_real_fixture_parses():
    b = m.parse_block(load_json("eth/block.json"))
    assert b["number"] > 20_000_000 and 0 <= b["utilization"] <= 1.0
```

**Given code:** `main()` parses the fixture block and receipt and prints a block summary, the receipt's fee split (burned vs priority), and the next base fee. It then simulates base-fee dynamics over 50 blocks of 100% utilization and 50 of 0%, and plots them.
**Learner stubs:** all six.
**Solution notes:**
- `int(h, 16)`. The timestamp uses `datetime.fromtimestamp(ts, tz=timezone.utc)`. Utilization = used/limit.
- EIP-1559 integer math: `target = gas_limit // 2`. If used == target, keep base. If above: `base + max(base*(used-target)//target//8, 1)`. Else: `base - base*(target-used)//target//8`.
- Fee = gasUsed·effectiveGasPrice/1e18; burn = baseFee·gasUsed/1e18; priority = gasUsed·(effective−base)/1e18.

**Content requirements (Block 4):**
- Account model vs UTXO; EOAs vs contracts; the EVM as a deterministic state machine; gas as metered compute.
- EIP-1559 (base fee burned + priority tip); ETH supply dynamics (issuance vs burn; "ultrasound money" debate).
- Proof of stake: validators, staking yield sources, slashing, finality; liquid staking tokens (stETH) as shadow-bank-like claims.
- Layer 2s (rollups) and why fees moved there; blob transactions (EIP-4844).
- Reading the chain: JSON-RPC and block explorers; the lab's raw-data approach.
- Worked example: decode the fixture block's fee economics.
- ≥5 exercises.
- Anti-patterns: "gas price = fee"; treating staking yield as risk-free; ignoring smart-contract risk.
- **Verify (as of 2026-10):** current block gas limit (raised in 2025; confirm the value), staking APR range, ETH supply trend, the latest hard fork name and date.

**Steps:**
- [ ] D1 write `labs/day20/test_lab.py` (above)
- [ ] D2 write `labs/day20/lab.py` (stubs: all six)
- [ ] D3 `uv run pytest day20` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day20/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day20` → pass; `uv run python -m day20.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day20.md`
- [ ] D8 `uv run python tools/verify_labs.py day20 && uv run python tools/check_content.py day20`
- [ ] D9 controller commit `WIP: task 23 day20 (scratch)`

---

### Task 24: Day 21 — Stablecoins: three designs and how they die

**Files:** `content/day21.md`, `labs/day21/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `max_mint(collateral_value: float, min_ratio: float) -> float`; `liquidation_price(collateral_amount: float, debt: float, min_ratio: float) -> float`; `liquidations(vaults: list[dict], prices: list[float], min_ratio: float) -> list[tuple[int, int]]` (each vault dict has `amount`, `debt`; returns `(price_step, vault_index)` in order); `terra_spiral(ust_supply: float, luna_supply: float, luna_price: float, redemption_fracs: list[float]) -> list[dict]`; `reserve_coverage(reserves: float, supply: float) -> float`

**test_lab.py:**
```python
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_cdp_math():
    assert m.max_mint(150.0, 1.5) == pytest.approx(100.0)
    assert m.liquidation_price(1.0, 1000.0, 1.5) == pytest.approx(1500.0)


def test_liquidations_each_vault_once():
    vaults = [{"amount": 1.0, "debt": 1000.0}, {"amount": 1.0, "debt": 500.0}]
    assert m.liquidations(vaults, [2000.0, 1400.0, 700.0, 600.0], 1.5) == [(1, 0), (2, 1)]


def test_terra_step():
    s = m.terra_spiral(100.0, 10.0, 50.0, [0.5])
    assert len(s) == 1
    assert s[0]["step"] == 1 and s[0]["status"] == "ok"
    assert s[0]["ust_supply"] == pytest.approx(50.0)
    assert s[0]["luna_supply"] == pytest.approx(11.0)
    assert s[0]["luna_price"] == pytest.approx(450.0 / 11.0)


def test_terra_collapse_stops():
    s = m.terra_spiral(100.0, 10.0, 5.0, [0.6, 0.5])
    assert len(s) == 1 and s[0]["status"] == "collapsed" and s[0]["luna_price"] == 0.0


def test_spiral_accelerates():
    s = m.terra_spiral(1000.0, 10.0, 60.0, [0.2] * 5)
    prices = [x["luna_price"] for x in s]
    assert all(b < a for a, b in zip(prices, prices[1:]))


def test_reserve_coverage():
    assert m.reserve_coverage(98.0, 100.0) == pytest.approx(0.98)
    with pytest.raises(ValueError):
        m.reserve_coverage(1.0, 0.0)
```

**Given code:** `main()` runs (a) a CDP vault book against the ETH price path from the snapshot (`load_crypto_ohlcv("ETH/USDT")` closes for 2022-05-01..2022-07-01), printing the liquidation timeline, and (b) a Terra-like spiral with stylized parameters, plotting LUNA price and supply.
**Learner stubs:** all five.
**Solution notes:**
- `collateral_value/min_ratio`; `debt*min_ratio/amount`.
- Liquidation happens at the first step where `amount*price/debt < min_ratio`, once per vault, ordered by step then index.
- Terra step: `R = frac*ust`; `mcap_after = price*luna - R`. If `mcap_after <= 0`, record `status="collapsed"` with price 0, `ust -= R` and stop. Otherwise `minted = R/price`, `luna += minted`, `price = mcap_after/luna`, `ust -= R`, `status="ok"`.
- Coverage raises if supply ≤ 0.

**Content requirements (Block 4):**
- Stablecoins as money-market-fund-like or narrow-bank-like liabilities (Day 5 link); T-accounts of a USDC/USDT mint and redemption.
- Fiat-backed (reserves composition, attestations vs audits, the USDC/SVB depeg in March 2023); crypto-collateralized (DAI/USDS overcollateralization, liquidations, Black Thursday 2020); algorithmic (Terra/LUNA May 2022, the reflexive death spiral).
- Where stablecoin yield comes from (T-bill income kept by the issuer; DeFi lending demand).
- Regulation: the US GENIUS Act (2025) and its reserve rules; EU MiCA; Vietnam's stance on crypto assets (pilot framework, verify).
- Stablecoins as dollarization pressure on EM currencies (a link to Day 16).
- Worked example: the lab's Terra step by step.
- ≥5 exercises.
- Anti-patterns: "1 stablecoin = 1 dollar always"; ignoring redemption gates and who can redeem; yield without asking its source.
- **Verify (as of 2026-10):** GENIUS Act status and key provisions; MiCA stablecoin rules in force; USDT and USDC market caps; Vietnam's legal framework for crypto assets (Law on Digital Technology Industry 2025 and any pilot resolution).

**Steps:**
- [ ] D1 write `labs/day21/test_lab.py` (above)
- [ ] D2 write `labs/day21/lab.py` (stubs: all five)
- [ ] D3 `uv run pytest day21` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day21/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day21` → pass; `uv run python -m day21.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day21.md`
- [ ] D8 `uv run python tools/verify_labs.py day21 && uv run python tools/check_content.py day21`
- [ ] D9 controller commit `WIP: task 24 day21 (scratch)`

---

### Task 25: Day 22 — DeFi: AMMs, impermanent loss, lending, MEV

**Files:** `content/day22.md`, `labs/day22/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `class ConstantProductPool(x: float, y: float, fee: float = 0.003)` with `price() -> float` (y per x), `k() -> float`, `swap_x_for_y(dx: float) -> float`, `swap_y_for_x(dy: float) -> float`; `impermanent_loss(price_ratio: float) -> float`; `lp_vs_hold(x0: float, y0: float, new_price: float) -> tuple[float, float]` (LP value, hold value, in y units, fee-free); `sandwich(x: float, y: float, fee: float, victim_dx: float, attacker_dx: float) -> dict` (keys `attacker_profit_x`, `victim_dy`, `victim_dy_no_attack`)

**test_lab.py:**
```python
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_swap_no_fee():
    p = m.ConstantProductPool(100.0, 10_000.0, fee=0.0)
    assert p.price() == pytest.approx(100.0)
    dy = p.swap_x_for_y(10.0)
    assert dy == pytest.approx(10_000 - 1_000_000 / 110)
    assert (p.x, p.y) == (pytest.approx(110.0), pytest.approx(1_000_000 / 110))
    assert p.k() == pytest.approx(1_000_000)


def test_fee_grows_k_and_reverse_swap():
    p = m.ConstantProductPool(100.0, 10_000.0)
    k0 = p.k()
    p.swap_x_for_y(10.0)
    assert p.k() > k0
    dx = p.swap_y_for_x(500.0)
    assert dx > 0 and p.k() > k0


def test_invalid_swaps():
    p = m.ConstantProductPool(100.0, 10_000.0)
    with pytest.raises(ValueError):
        p.swap_x_for_y(0.0)
    with pytest.raises(ValueError):
        p.swap_y_for_x(-1.0)


@pytest.mark.parametrize("r,il", [(1.0, 0.0), (4.0, -0.2), (0.25, -0.2)])
def test_impermanent_loss(r, il):
    assert m.impermanent_loss(r) == pytest.approx(il)


def test_lp_vs_hold():
    lp, hold = m.lp_vs_hold(100.0, 10_000.0, 400.0)
    assert hold == pytest.approx(50_000.0) and lp == pytest.approx(40_000.0)


def test_sandwich_profits_without_fees_and_hurts_victim():
    r = m.sandwich(100.0, 10_000.0, 0.0, victim_dx=10.0, attacker_dx=5.0)
    assert r["attacker_profit_x"] > 0
    assert r["victim_dy"] < r["victim_dy_no_attack"]


def test_sandwich_unprofitable_for_tiny_victim_with_fees():
    r = m.sandwich(100.0, 10_000.0, 0.003, victim_dx=0.01, attacker_dx=5.0)
    assert r["attacker_profit_x"] < 0
```

**Given code:** `main()` uses the ETH/USDT snapshot (2021-01-01 onward): it opens an LP at the first price, tracks LP vs hold value over time with `lp_vs_hold`, prints the final IL and the breakeven fee APR needed to offset it, and plots both.
**Learner stubs:** `price`, `k`, `swap_x_for_y`, `swap_y_for_x`, `impermanent_loss`, `lp_vs_hold`, `sandwich`.
**Solution notes:**
- Swap: raise if the input ≤ 0; `eff = dx*(1-fee)`; `dy = y*eff/(x+eff)`; then `x += dx` (the full amount stays in the pool, so k grows); `y -= dy`.
- `IL = 2*sqrt(r)/(1+r) - 1`.
- LP: `k = x0*y0`, `x1 = sqrt(k/p)`, `y1 = sqrt(k*p)`, value = `x1*p + y1`; hold = `x0*p + y0`.
- Sandwich: baseline = a fresh pool and the victim swap. Attack = fresh pool; the attacker swaps x→y (`got_y`); the victim swaps; the attacker swaps `got_y` back y→x (`back_x`); profit = `back_x - attacker_dx`.

**Content requirements (Block 4):**
- AMMs vs order books (Day 9 link); x·y=k derivation; price impact; LP fees; concentrated liquidity (Uniswap v3) in one paragraph.
- Impermanent loss derivation and intuition (LPs sell volatility).
- Lending protocols (Aave/Compound): over-collateralized loans, utilization-based rates, liquidations; the link to Day 21.
- MEV: front-running, sandwiching, arbitrage bots; private orderflow; why "slippage tolerance" settings matter.
- Where DeFi yield really comes from (trading fees, borrowing demand, token emissions = dilution) and DeFi risk (smart contracts, oracles, bridges, governance).
- Worked example: the lab's sandwich, numerically.
- ≥5 exercises.
- Anti-patterns: APY screenshots without a source of yield; ignoring IL; max slippage tolerance.
- **Verify (as of 2026-10):** Uniswap's current version (v4 launch) and default fee tiers; total value locked order of magnitude (cite a dashboard).

**Steps:**
- [ ] D1 write `labs/day22/test_lab.py` (above)
- [ ] D2 write `labs/day22/lab.py` (stubs listed above)
- [ ] D3 `uv run pytest day22` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day22/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day22` → pass; `uv run python -m day22.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day22.md`
- [ ] D8 `uv run python tools/verify_labs.py day22 && uv run python tools/check_content.py day22`
- [ ] D9 controller commit `WIP: task 25 day22 (scratch)`

---

### Task 26: Day 23 — Crypto market structure: exchanges, custody, perps, funding, basis

**Files:** `content/day23.md`, `labs/day23/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Consumes: `common.data.load_funding`, `load_crypto_ohlcv`
- Produces: `annualized_funding(rates: pd.Series, periods_per_day: int = 3) -> float`; `basis_pct(spot: float, future: float) -> float`; `annualized_basis(spot: float, future: float, days: float) -> float`; `cash_and_carry_pnl(spot_entry, fut_entry, spot_exit, fut_exit, qty) -> float`; `funding_pnl(notional: float, rates: list[float], side: str) -> float`

**test_lab.py:**
```python
import math

import pandas as pd
import pytest

from common.data import load_funding
from common.labimpl import load_impl

m = load_impl(__file__)


def test_annualized_funding():
    assert m.annualized_funding(pd.Series([0.0001] * 9)) == pytest.approx(0.0001 * 3 * 365)


def test_basis():
    assert m.basis_pct(100.0, 102.0) == pytest.approx(0.02)
    assert m.annualized_basis(100.0, 102.0, 90) == pytest.approx(0.02 * 365 / 90)
    with pytest.raises(ValueError):
        m.annualized_basis(100.0, 102.0, 0)


def test_cash_and_carry_locks_basis_at_convergence():
    assert m.cash_and_carry_pnl(100.0, 102.0, 110.0, 110.0, 1.0) == pytest.approx(2.0)
    assert m.cash_and_carry_pnl(100.0, 102.0, 80.0, 80.0, 2.0) == pytest.approx(4.0)


def test_funding_pnl():
    rates = [0.0001, -0.00005, 0.0002]
    assert m.funding_pnl(10_000.0, rates, "short") == pytest.approx(2.5)
    assert m.funding_pnl(10_000.0, rates, "long") == pytest.approx(-2.5)
    with pytest.raises(ValueError):
        m.funding_pnl(10_000.0, rates, "flat")


def test_snapshot_funding_is_sane():
    v = m.annualized_funding(load_funding())
    assert math.isfinite(v) and -1.0 < v < 2.0
```

**Given code:** `main()` loads BTC funding and the spot/perp daily closes. It prints the annualized funding by calendar year, the share of periods with negative funding, and the perp−spot daily basis distribution, simulates a "short perp + long spot" carry from 2021 onward collecting funding (ignoring fees, stated), and plots the cumulative carry vs BTC.
**Learner stubs:** all five.
**Solution notes:** `mean*ppd*365`; `(F-S)/S`; `× 365/days`, raising if days ≤ 0; `qty*((spot_exit-spot_entry) - (fut_exit-fut_entry))`; short receives `+Σ notional·rate`, long pays it.

**Content requirements (Block 4):**
- CEX vs DEX; custody (exchange IOUs = Day 1 hierarchy again); proof of reserves vs proof of solvency; FTX (Nov 2022) as a balance-sheet failure.
- Perpetual futures: mark price, funding mechanism, leverage, liquation engines and auto-deleveraging; dated futures and the CME.
- The basis trade (cash-and-carry); why funding is usually positive (leveraged long demand); the 2021 peak and 2022 negative stretches.
- Spot BTC/ETH ETFs (US, January 2024 / July 2024): creation in cash/in-kind, and their effect on market structure.
- Crypto for a Vietnam-based investor: the legal status of exchanges and the pilot framework (verify; no advice).
- Worked example: one quarter of a cash-and-carry with numbers from the snapshot.
- ≥5 exercises.
- Anti-patterns: leverage as a strategy; "funding is free money" (exchange counterparty risk, liquidation of the short leg); keeping assets on exchanges.
- **Verify (as of 2026-10):** spot crypto ETF approvals and in-kind status; Binance/OKX funding interval (8h default, exceptions); Vietnam's crypto licensing pilot status.

**Steps:**
- [ ] D1 write `labs/day23/test_lab.py` (above)
- [ ] D2 write `labs/day23/lab.py` (stubs: all five)
- [ ] D3 `uv run pytest day23` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day23/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day23` → pass; `uv run python -m day23.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day23.md`
- [ ] D8 `uv run python tools/verify_labs.py day23 && uv run python tools/check_content.py day23`
- [ ] D9 controller commit `WIP: task 26 day23 (scratch)`

---

### Task 27: Day 24 — Integration: crypto vs fiat as monetary systems

**Files:** `content/day24.md`, `labs/day24/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: `btc_supply(height: int) -> int` (sats; same definition as Day 19's `total_supply`); `btc_annual_inflation(height: int, blocks_per_year: int = 52_560) -> float`; `m2_growth(m2: pd.Series) -> pd.Series` (YoY); `compare_issuance(year_heights: dict[int, int], m2: pd.Series) -> pd.DataFrame` (index = year; columns `["btc_inflation", "m2_growth"]`; M2 growth = the December YoY of that year)

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
BTC = 100_000_000


def test_btc_supply_at_halvings():
    assert m.btc_supply(840_000) == 19_687_500 * BTC
    assert m.btc_supply(630_000) == 18_375_000 * BTC


def test_btc_inflation():
    assert m.btc_annual_inflation(840_000) == pytest.approx(52_560 * 3.125 / 19_687_500)
    assert m.btc_annual_inflation(630_000) == pytest.approx(52_560 * 6.25 / 18_375_000)


def m2_series():
    idx = pd.date_range("2019-01-01", periods=36, freq="MS")
    return pd.Series(100 * 1.06 ** (np.arange(36) / 12), idx)


def test_m2_growth():
    g = m.m2_growth(m2_series())
    assert len(g) == 24 and g.tolist() == pytest.approx([0.06] * 24)


def test_compare_issuance():
    df = m.compare_issuance({2020: 630_000, 2021: 680_000}, m2_series())
    assert list(df.columns) == ["btc_inflation", "m2_growth"]
    assert list(df.index) == [2020, 2021]
    assert df.loc[2020, "m2_growth"] == pytest.approx(0.06)
    assert df.loc[2020, "btc_inflation"] == pytest.approx(52_560 * 6.25 / 18_375_000)
```

**Given code:** `YEAR_HEIGHTS`, an approximate block height at each 1 January for 2013–2026 (verified from a block explorer in content, cited). `main()` prints the comparison table against `M2SL` and plots BTC inflation vs M2 growth.
**Learner stubs:** all four.
**Solution notes:** reuse Day 19's closed form; `(supply(h+bpy) - supply(h))/supply(h)`; `pct_change(12, fill_method=None).dropna()`; for each year, take the growth value at the last month of that year.

**Content requirements (integration day):**
- Recap map of Days 19–23: native asset → programmable platform → stablecoins → DeFi → market structure.
- A side-by-side table: fiat (central bank + banks) vs Bitcoin vs Ethereum vs fiat-backed stablecoins, compared on issuer, supply rule, lender of last resort, settlement finality, censorship resistance, failure modes, and who holds the risk.
- `## Worked example`: 2020–2022 as a natural experiment: M2 surge, BTC rally, then rate hikes, the crypto deleveraging (Terra, Celsius, FTX).
- `## Exercises` (≥3 case drills), e.g. "a fiat-backed stablecoin's bank fails, trace it through the T-accounts"; "argue for and against 'BTC is an inflation hedge' with the snapshot data".
- `## Checkpoint quiz` (12–15 over Days 19–23) + `## Answer key`.
- **Verify (as of 2026-10):** the block heights in `YEAR_HEIGHTS` (±1,000 blocks is acceptable; cite the explorer) and the M2 latest value.

**Steps:**
- [ ] D1 write `labs/day24/test_lab.py` (above)
- [ ] D2 write `labs/day24/lab.py` (stubs: all four)
- [ ] D3 `uv run pytest day24` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day24/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day24` → pass; `uv run python -m day24.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day24.md` (integration headings)
- [ ] D8 `uv run python tools/verify_labs.py day24 && uv run python tools/check_content.py day24`
- [ ] D9 controller commit `WIP: task 27 day24 (scratch)`

---

### Task 28: Day 25 — A backtester from scratch (+ `common/backtest.py`)

**Files:** `content/day25.md`, `labs/day25/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`, `labs/common/backtest.py`, `labs/common/tests/test_backtest.py`

**Interfaces:**
- Produces (lab and `common.backtest`, identical signatures): `momentum_signal(prices: pd.Series, lookback: int) -> pd.Series` (1.0 if the trailing return > 0 else 0.0; NaN → 0.0); `backtest(prices: pd.Series, signal: pd.Series, cost_bps: float = 0.0) -> pd.DataFrame` with columns `["asset_ret", "position", "turnover", "cost", "strat_ret", "equity"]`
- Contract: `position = signal.shift(1).fillna(0)`; `asset_ret = pct_change().fillna(0)`; `turnover = position.diff().abs()` with the first row = `abs(position[0])`; `cost = turnover*cost_bps/1e4`; `strat_ret = position*asset_ret - cost`; `equity = (1+strat_ret).cumprod()`

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.bdate_range("2024-01-01", periods=3)


def test_always_long_matches_buy_and_hold():
    p = pd.Series([100.0, 101.0, 102.0], IDX)
    bt = m.backtest(p, pd.Series(1.0, IDX))
    assert list(bt.columns) == ["asset_ret", "position", "turnover", "cost", "strat_ret", "equity"]
    assert bt["position"].tolist() == [0.0, 1.0, 1.0]
    assert bt["equity"].iloc[-1] == pytest.approx(1.02)


def test_costs_charged_on_turnover():
    p = pd.Series([100.0, 101.0, 102.0], IDX)
    bt = m.backtest(p, pd.Series(1.0, IDX), cost_bps=10)
    assert bt["turnover"].tolist() == [0.0, 1.0, 0.0]
    assert bt["equity"].iloc[-1] == pytest.approx((1 + 0.01 - 0.001) * (102 / 101))


def test_flat_signal():
    p = pd.Series([100.0, 90.0, 120.0], IDX)
    assert m.backtest(p, pd.Series(0.0, IDX))["equity"].tolist() == [1.0, 1.0, 1.0]


def test_no_lookahead():
    rng = np.random.default_rng(0)
    idx = pd.bdate_range("2020-01-01", periods=300)
    p = pd.Series(100 * np.exp(np.cumsum(rng.normal(0, 0.01, 300))), idx)
    pos = m.backtest(p, m.momentum_signal(p, 20))["position"]
    p2 = p.copy()
    p2.iloc[200:] *= 0.5
    pos2 = m.backtest(p2, m.momentum_signal(p2, 20))["position"]
    assert pos.iloc[:201].equals(pos2.iloc[:201])


def test_momentum_signal():
    p = pd.Series([1.0, 2.0, 3.0, 2.0, 1.0])
    assert m.momentum_signal(p, 2).tolist() == [0.0, 0.0, 1.0, 0.0, 0.0]
```

`labs/common/tests/test_backtest.py`:
```python
import pandas as pd
import pytest

from common.backtest import backtest, momentum_signal


def test_reference_backtest():
    idx = pd.bdate_range("2024-01-01", periods=3)
    p = pd.Series([100.0, 101.0, 102.0], idx)
    assert backtest(p, pd.Series(1.0, idx), 10)["equity"].iloc[-1] == pytest.approx(
        1.009 * 102 / 101)
    assert momentum_signal(pd.Series([1.0, 2.0, 3.0]), 1).tolist() == [0.0, 1.0, 1.0]
```

**Given code:** `main()` runs 200-day momentum on SPY and BTC-USD (snapshot) with 0 and 10 bps costs, and prints `common.quant` metrics vs buy-and-hold. If `vectorbt` is importable, it cross-checks the final equity with `vbt.Portfolio.from_signals` (entries/exits from the same lagged position, fees = cost_bps/1e4) and prints the difference. Otherwise it prints a skip line.
**Learner stubs:** `momentum_signal`, `backtest`.
**Solution notes:** implement the contract above. Momentum = `(p/p.shift(lb) - 1 > 0).astype(float)`, NaN → 0. Then copy both functions verbatim (with docstrings) into `labs/common/backtest.py` and run `uv run pytest common/tests/test_backtest.py` → pass.

**Content requirements (Block 5):**
- The research workflow: hypothesis (why should this work? who is on the other side?) → data → signal → position → P&L → evaluation → kill or keep. Writing the hypothesis *before* looking at results.
- Backtest anatomy, vectorized vs event-driven; the one-bar lag; signals vs positions vs weights; turnover.
- Metrics: CAGR, vol, Sharpe, max drawdown, turnover, hit rate; benchmark = buy-and-hold.
- Time-series momentum: the economic story (under-reaction, risk premia) and the evidence (Moskowitz, Ooi & Pedersen 2012).
- The engineer trap: building a platform before an edge; use vectorbt and pandas, and keep it small.
- Worked example: SPY 200-day momentum vs buy-and-hold.
- ≥5 exercises.
- Anti-patterns: same-bar execution; optimizing the lookback on the full sample; no benchmark.
- **Verify (as of 2026-10):** the vectorbt version installed and that `Portfolio.from_signals` arguments match.

**Steps:**
- [ ] D1 write `labs/day25/test_lab.py` and `labs/common/tests/test_backtest.py` (above)
- [ ] D2 write `labs/day25/lab.py` (stubs: `momentum_signal`, `backtest`)
- [ ] D3 `uv run pytest day25 common/tests/test_backtest.py` → day25 FAIL with NotImplementedError; test_backtest FAIL with ModuleNotFoundError
- [ ] D4 write `labs/day25/solution.py` and `labs/common/backtest.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day25 common` → pass; `uv run python -m day25.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day25.md`
- [ ] D8 `uv run python tools/verify_labs.py day25 && uv run python tools/check_content.py day25`
- [ ] D9 controller commit `WIP: task 28 day25 (scratch)`

---

### Task 29: Day 26 — How backtests lie (+ `common/stats.py`)

**Files:** `content/day26.md`, `labs/day26/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`, `labs/common/stats.py`, `labs/common/tests/test_stats.py`

**Interfaces:**
- Consumes: `common.backtest.backtest`, `momentum_signal`; `common.quant.sharpe`
- Produces (lab; the first three are also in `common.stats` with identical signatures): `probabilistic_sharpe_ratio(sr: float, sr_benchmark: float, n_obs: int, skew: float = 0.0, kurtosis: float = 3.0) -> float`; `expected_max_sharpe(n_trials: int, sr_variance: float) -> float`; `deflated_sharpe_ratio(sr: float, n_trials: int, sr_variance: float, n_obs: int, skew: float = 0.0, kurtosis: float = 3.0) -> float`; `p_hacking_demo(n_strategies: int, n_days: int, seed: int) -> dict` (keys `best_in_sample_sharpe`, `its_out_of_sample_sharpe`, annualized); `walk_forward(prices: pd.Series, lookbacks: list[int], train: int, test: int) -> tuple[pd.Series, list[int]]`
- All Sharpe inputs to PSR/DSR are **per-period** (not annualized).

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_psr_basics():
    assert m.probabilistic_sharpe_ratio(0.0, 0.0, 100) == pytest.approx(0.5)
    assert m.probabilistic_sharpe_ratio(0.1, 0.0, 100) < m.probabilistic_sharpe_ratio(0.1, 0.0, 1000)


def test_expected_max_sharpe():
    assert m.expected_max_sharpe(100, 1.0) == pytest.approx(2.53, abs=0.01)
    assert m.expected_max_sharpe(1, 1.0) == 0.0


def test_dsr_penalizes_more_trials():
    few = m.deflated_sharpe_ratio(0.1, 10, 0.001, 1000)
    many = m.deflated_sharpe_ratio(0.1, 1000, 0.001, 1000)
    assert 0 <= many < few <= 1


def test_p_hacking():
    r = m.p_hacking_demo(200, 1000, seed=0)
    assert r["best_in_sample_sharpe"] > 1.0
    assert r["its_out_of_sample_sharpe"] < r["best_in_sample_sharpe"]


def _prices(n=600, seed=3):
    rng = np.random.default_rng(seed)
    idx = pd.bdate_range("2018-01-01", periods=n)
    return pd.Series(100 * np.exp(np.cumsum(rng.normal(0.0002, 0.01, n))), idx)


def test_walk_forward_shape():
    oos, choices = m.walk_forward(_prices(), [20, 60], train=250, test=50)
    assert len(choices) == 7 and set(choices) <= {20, 60}
    assert len(oos) == 350 and oos.index[0] == _prices().index[250]


def test_walk_forward_has_no_leakage():
    p = _prices()
    _, c1 = m.walk_forward(p, [20, 60], 250, 50)
    p2 = p.copy()
    p2.iloc[550:] *= 1.5
    _, c2 = m.walk_forward(p2, [20, 60], 250, 50)
    assert c1 == c2
```

`labs/common/tests/test_stats.py`:
```python
import pytest

from common.stats import deflated_sharpe_ratio, expected_max_sharpe, probabilistic_sharpe_ratio


def test_reference_stats():
    assert probabilistic_sharpe_ratio(0.0, 0.0, 50) == pytest.approx(0.5)
    assert expected_max_sharpe(100, 1.0) == pytest.approx(2.53, abs=0.01)
    assert deflated_sharpe_ratio(0.1, 1, 0.001, 1000) == pytest.approx(
        probabilistic_sharpe_ratio(0.1, 0.0, 1000))
```

**Given code:** `main()` runs `p_hacking_demo` for 10, 100 and 1000 strategies; runs walk-forward momentum on SPY with lookbacks [20, 60, 120, 200, 250] (train 756, test 126), printing the OOS Sharpe vs the best full-sample Sharpe; and prints the DSR of the best full-sample strategy given 5 trials.
**Learner stubs:** all five.
**Solution notes:**
- Use `statistics.NormalDist()` for Φ and Φ⁻¹ (no scipy). PSR = `Φ((sr - sr_b)*sqrt(n-1) / sqrt(1 - skew*sr + (kurtosis-1)/4*sr**2))`. E[max SR] = `sqrt(var)*((1-γ)Φ⁻¹(1-1/N) + γΦ⁻¹(1-1/(N·e)))` with γ = 0.5772156649, and 0.0 when N == 1. DSR = PSR(sr, E[max SR], ...).
- p-hacking: `rng.normal(0, 0.01, (n_days, n_strategies))`, split in half, `common.quant.sharpe` per column on the first half, pick the argmax, report both halves' Sharpe for that column.
- Walk-forward: windows `i = train, train+test, ...` while `i+test <= len(p)`. Choose the lookback maximizing the Sharpe of `backtest(p.iloc[i-train:i], momentum_signal(...))["strat_ret"]` (NaN → −inf; ties → first). OOS = `backtest(p.iloc[:i+test], momentum_signal(p.iloc[:i+test], lb))["strat_ret"].iloc[i:i+test]`. Concatenate.
- Copy the three PSR/DSR functions into `labs/common/stats.py`.

**Content requirements (Block 5):**
- The bias zoo: look-ahead (Day 25 test), survivorship (delisted stocks; the snapshot's tickers are survivors), selection/multiple testing, data snooping, overfitting via parameters, regime dependence, unrealistic fills (Day 9), and ignoring limit-locked days (Day 16).
- PSR and DSR intuition: "how many things did you try?"; Bailey & López de Prado (2014), linked.
- Train/test, walk-forward, and why k-fold CV leaks in time series (purging/embargo, in one paragraph).
- "Most published factors don't replicate" (Harvey, Liu & Zhu 2016; Hou, Xue & Zhang 2020), in plain English.
- A personal research log: record every variant tried (the n_trials honesty rule).
- Worked example: the p-hacking demo output explained.
- ≥5 exercises.
- Anti-patterns: tuning on the test set; reporting only the best variant; survivorship-biased universes.
- **Verify (as of 2026-10):** citations (titles, years, journals) for the papers above.

**Steps:**
- [ ] D1 write `labs/day26/test_lab.py` and `labs/common/tests/test_stats.py` (above)
- [ ] D2 write `labs/day26/lab.py` (stubs: all five)
- [ ] D3 `uv run pytest day26` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day26/solution.py` and `labs/common/stats.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day26 common` → pass; `uv run python -m day26.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day26.md`
- [ ] D8 `uv run python tools/verify_labs.py day26 && uv run python tools/check_content.py day26`
- [ ] D9 controller commit `WIP: task 29 day26 (scratch)`

---

### Task 30: Day 27 — Costs, sizing and risk (+ `common/risk.py`)

**Files:** `content/day27.md`, `labs/day27/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`, `labs/common/risk.py`, `labs/common/tests/test_risk.py`

**Interfaces:**
- Produces (lab; `vol_target_weights` and `breakeven_cost_bps` also in `common.risk`): `kelly_fraction(mu: float, sigma: float) -> float`; `fractional_kelly(mu: float, sigma: float, fraction: float = 0.5) -> float`; `vol_target_weights(returns: pd.Series, target_vol: float, window: int, max_leverage: float, periods: int = 252) -> pd.Series`; `breakeven_cost_bps(gross_returns: pd.Series, turnover: pd.Series) -> float`; `drawdown_brake(equity: pd.Series, threshold: float = 0.2, reduced: float = 0.5) -> pd.Series`

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def test_kelly():
    assert m.kelly_fraction(0.08, 0.2) == pytest.approx(2.0)
    assert m.fractional_kelly(0.08, 0.2) == pytest.approx(1.0)
    with pytest.raises(ValueError):
        m.kelly_fraction(0.08, 0.0)


def test_vol_target_weights():
    r = pd.Series([0.01, -0.01] * 30)
    w = m.vol_target_weights(r, 0.10, 20, 2.0)
    expected = (0.10 / (r.rolling(20).std() * np.sqrt(252))).shift(1).clip(0, 2.0).fillna(0.0)
    pd.testing.assert_series_equal(w, expected, check_names=False)
    assert w.iloc[:20].eq(0).all()


def test_vol_target_caps_leverage():
    r = pd.Series([1e-6, -1e-6] * 30)
    assert m.vol_target_weights(r, 0.10, 20, 2.0).iloc[-1] == pytest.approx(2.0)


def test_breakeven_cost():
    gross = pd.Series([0.01, 0.0, 0.02])
    turnover = pd.Series([1.0, 0.0, 2.0])
    assert m.breakeven_cost_bps(gross, turnover) == pytest.approx(100.0)
    assert m.breakeven_cost_bps(gross, pd.Series([0.0, 0.0, 0.0])) == float("inf")


def test_drawdown_brake_is_lagged():
    eq = pd.Series([1.0, 1.2, 0.9, 0.95, 1.3])
    assert m.drawdown_brake(eq).tolist() == [1.0, 1.0, 1.0, 0.5, 0.5]
```

`labs/common/tests/test_risk.py`:
```python
import pandas as pd
import pytest

from common.risk import breakeven_cost_bps, vol_target_weights


def test_reference_risk():
    assert breakeven_cost_bps(pd.Series([0.01, 0.02]), pd.Series([1.0, 2.0])) == pytest.approx(100.0)
    assert vol_target_weights(pd.Series([1e-6, -1e-6] * 30), 0.1, 20, 2.0).iloc[-1] == 2.0
```

**Given code:** `main()` runs SPY 200-day momentum (`common.backtest`), then (a) adds costs of 0, 5, 20 and 50 bps, (b) prints `breakeven_cost_bps`, (c) applies vol targeting at 10% and compares Sharpe and max drawdown, and (d) applies the drawdown brake. It prints one comparison table.
**Learner stubs:** all five.
**Solution notes:** `mu/sigma**2` (raise if σ ≤ 0); fraction × Kelly; formula as in the test; `gross.sum()/turnover.sum()*1e4` (inf if the turnover sum is 0); `dd = eq/eq.cummax()-1`, `raw = np.where(dd < -threshold, reduced, 1.0)`, then `pd.Series(raw, eq.index).shift(1).fillna(1.0)`. Copy the two shared functions into `labs/common/risk.py`.

**Content requirements (Block 5):**
- The cost stack: commissions, spread (Day 9), slippage/impact, borrow, funding (Day 23), FX (Day 17), taxes; the breakeven-cost test as the first filter.
- Position sizing: fixed fractional, vol targeting, Kelly and why full Kelly is reckless (estimation error); risk of ruin; leverage.
- Drawdown control and the psychology of drawdowns; "survive first" (Strategy move 5).
- Portfolio-level risk limits that Day 29's bot will enforce.
- Worked example: a strategy that looks great gross and dies at 20 bps.
- ≥5 exercises.
- Anti-patterns: Sharpe without costs; full Kelly; martingale averaging down.
- **Verify (as of 2026-10):** typical commissions at an international broker (IBKR tiered US equities) and a Vietnamese broker (cite), plus typical spot crypto taker fees.

**Steps:**
- [ ] D1 write `labs/day27/test_lab.py` and `labs/common/tests/test_risk.py` (above)
- [ ] D2 write `labs/day27/lab.py` (stubs: all five)
- [ ] D3 `uv run pytest day27` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day27/solution.py` and `labs/common/risk.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day27 common` → pass; `uv run python -m day27.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day27.md`
- [ ] D8 `uv run python tools/verify_labs.py day27 && uv run python tools/check_content.py day27`
- [ ] D9 controller commit `WIP: task 30 day27 (scratch)`

---

### Task 31: Day 28 — Strategy families

**Files:** `content/day28.md`, `labs/day28/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Contract: every function returns signals or weights using information up to and *including* row t. The caller (`common.backtest`) lags them.
- Produces: `trend_signal(prices: pd.DataFrame, lookback: int) -> pd.DataFrame` (sign of the trailing return: −1/0/1; NaN → 0); `mean_reversion_signal(prices: pd.Series, window: int, z_entry: float) -> pd.Series` (−1 if z > z_entry, +1 if z < −z_entry, else 0; NaN → 0); `inverse_vol_weights(returns: pd.DataFrame, window: int) -> pd.DataFrame` (rows sum to 1; leading rows without a full window dropped); `cross_sectional_momentum(prices: pd.DataFrame, lookback: int, top_n: int) -> pd.DataFrame` (1/top_n on the top_n trailing performers, ties broken by column order; rows without history all 0); `combine_strategies(returns: pd.DataFrame, weights: dict[str, float]) -> pd.Series`

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
IDX = pd.bdate_range("2024-01-01", periods=30)
PRICES = pd.DataFrame({"up": 100 * 1.01 ** np.arange(30), "flat": [100.0] * 30,
                       "down": 100 * 0.99 ** np.arange(30)}, index=IDX)


def test_trend_signal():
    s = m.trend_signal(PRICES, 10)
    assert s.iloc[:10].eq(0).all().all()
    assert s.iloc[20].tolist() == [1, 0, -1]


def test_mean_reversion_signal():
    p = pd.Series([10.0] * 19 + [12.0])
    s = m.mean_reversion_signal(p, 20, 2.0)
    assert s.iloc[-1] == -1
    assert s.iloc[:-1].eq(0).all()
    assert m.mean_reversion_signal(pd.Series([10.0] * 19 + [8.0]), 20, 2.0).iloc[-1] == 1


def test_inverse_vol_weights():
    rets = pd.DataFrame({"a": [0.02, -0.02] * 15, "b": [0.01, -0.01] * 15}, index=IDX)
    w = m.inverse_vol_weights(rets, 10)
    assert w.index[0] == IDX[9]
    assert w.iloc[-1].tolist() == pytest.approx([1 / 3, 2 / 3])
    assert w.sum(axis=1).tolist() == pytest.approx([1.0] * len(w))


def test_cross_sectional_momentum():
    w = m.cross_sectional_momentum(PRICES, 5, 1)
    assert w.iloc[:5].eq(0).all().all()
    assert w.iloc[10].tolist() == [1.0, 0.0, 0.0]
    w2 = m.cross_sectional_momentum(PRICES, 5, 2)
    assert w2.iloc[10].tolist() == [0.5, 0.5, 0.0]


def test_combine_strategies():
    r = pd.DataFrame({"trend": [0.01, 0.02], "carry": [0.0, -0.01]})
    assert m.combine_strategies(r, {"trend": 0.5, "carry": 0.5}).tolist() == pytest.approx(
        [0.005, 0.005])
    with pytest.raises(ValueError):
        m.combine_strategies(r, {"value": 1.0})
```

**Given code:** `main()` builds a multi-asset universe from the snapshot (SPY, EFA, EEM, TLT, IEF, GLD, BTC-USD on common dates). It runs (a) trend per asset with inverse-vol weights, (b) cross-sectional momentum top 3, and (c) a 50/50 blend. It backtests with `common.backtest` per asset (position = lagged weight), prints `common.quant` metrics vs equal-weight buy-and-hold, and plots the equity curves.
**Learner stubs:** all five.
**Solution notes:**
- Trend: `np.sign(p/p.shift(lb)-1).fillna(0)`.
- Mean reversion: z with rolling mean/std (ddof 1); std == 0 → NaN → 0.
- Inverse vol: `inv = 1/returns.rolling(w).std()`, `w = inv.div(inv.sum(axis=1), axis=0).dropna()`.
- Cross-sectional: trailing return; per row with no NaN, rank descending with `method="first"` and set 1/top_n where rank ≤ top_n.
- Combine: raise if any key is not a column; `sum(returns[k]*v)`.

**Content requirements (Block 5):**
- Trend/time-series momentum, mean reversion, carry (FX Day 13 and crypto funding Day 23), value, cross-sectional momentum, risk parity: each with the economic rationale ("who pays you and why"), typical failure regime, and capacity.
- Diversifying across strategies vs across assets; correlation of strategy returns.
- Why simple, robust rules beat complex ones for individuals; the role of rebalancing frequency and costs.
- Which families suit a learner with US, VN and crypto access (e.g. limit rules and FOL in VN constrain mean reversion; crypto carry has exchange risk).
- Worked example: the blend vs its parts.
- ≥5 exercises.
- Anti-patterns: mixing families without measuring correlation; mean reversion with leverage; ignoring capacity.
- **Verify (as of 2026-10):** citations for each family's canonical paper (e.g. Asness, Moskowitz & Pedersen 2013 "Value and Momentum Everywhere").

**Steps:**
- [ ] D1 write `labs/day28/test_lab.py` (above)
- [ ] D2 write `labs/day28/lab.py` (stubs: all five)
- [ ] D3 `uv run pytest day28` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day28/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day28` → pass; `uv run python -m day28.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day28.md`
- [ ] D8 `uv run python tools/verify_labs.py day28 && uv run python tools/check_content.py day28`
- [ ] D9 controller commit `WIP: task 31 day28 (scratch)`

---

### Task 32: Day 29 — A paper-trading bot with a kill switch

**Files:** `content/day29.md`, `labs/day29/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md}`

**Interfaces:**
- Produces: a `Broker` Protocol (`get_price(symbol) -> float`, `get_position(symbol) -> float`, `get_equity() -> float`, `submit_order(symbol: str, side: str, qty: float) -> str`); `FakeBroker(cash: float, prices: dict[str, float])` (given; public `prices`, `orders`); `@dataclass RiskLimits(max_position_notional: float = inf, max_order_notional: float = inf, max_daily_loss: float = 0.05, min_order_notional: float = 10.0)`; `class Bot(broker, strategy: Callable[[list[float]], float], limits: RiskLimits, log_path: Path, kill_file: Path)` with attributes `killed: bool`, `strategy` (reassignable), and methods `step(symbol: str, history: list[float]) -> dict` (keys `action` in `{"order", "hold", "killed"}`, `side`, `qty`) and `new_day() -> None`; `CcxtBroker(exchange)` and `AlpacaBroker(api_key, secret_key, client_factory=None)` (given, paper/sandbox enforced)

**test_lab.py:**
```python
import json

import pytest

from common.labimpl import load_impl

m = load_impl(__file__)


def make(tmp_path, weight=0.5, **limits):
    broker = m.FakeBroker(10_000.0, {"X": 100.0})
    bot = m.Bot(broker, lambda h: weight, m.RiskLimits(**limits),
                tmp_path / "log.jsonl", tmp_path / "KILL")
    return broker, bot


def test_buys_to_target_weight(tmp_path):
    b, bot = make(tmp_path)
    r = bot.step("X", [100.0])
    assert (r["action"], r["side"], r["qty"]) == ("order", "buy", pytest.approx(50.0))
    assert b.get_position("X") == pytest.approx(50.0)


def test_weight_is_clipped_to_unit_interval(tmp_path):
    b, bot = make(tmp_path, weight=1.7)
    bot.step("X", [100.0])
    assert b.get_position("X") == pytest.approx(100.0)


def test_position_cap(tmp_path):
    b, bot = make(tmp_path, max_position_notional=2_000.0)
    bot.step("X", [100.0])
    assert b.get_position("X") == pytest.approx(20.0)


def test_order_cap_spreads_over_steps(tmp_path):
    b, bot = make(tmp_path, max_order_notional=1_000.0)
    bot.step("X", [100.0])
    bot.step("X", [100.0])
    assert b.get_position("X") == pytest.approx(20.0)


def test_hold_when_at_target(tmp_path):
    _, bot = make(tmp_path)
    bot.step("X", [100.0])
    assert bot.step("X", [100.0])["action"] == "hold"


def test_sells_when_target_drops(tmp_path):
    b, bot = make(tmp_path)
    bot.step("X", [100.0])
    bot.strategy = lambda h: 0.0
    r = bot.step("X", [100.0])
    assert (r["side"], r["qty"]) == ("sell", pytest.approx(50.0))
    assert b.get_position("X") == pytest.approx(0.0)


def test_daily_loss_kill_switch_flattens_and_stays_off(tmp_path):
    b, bot = make(tmp_path, max_daily_loss=0.2)
    bot.step("X", [100.0])
    b.prices["X"] = 50.0  # equity 7,500 < 8,000 floor
    assert bot.step("X", [100.0, 50.0])["action"] == "killed"
    assert b.get_position("X") == pytest.approx(0.0) and bot.killed
    assert bot.step("X", [100.0, 50.0, 50.0])["action"] == "killed"
    assert len(b.orders) == 2


def test_kill_file(tmp_path):
    b, bot = make(tmp_path)
    bot.step("X", [100.0])
    (tmp_path / "KILL").touch()
    assert bot.step("X", [100.0])["action"] == "killed"
    assert b.get_position("X") == pytest.approx(0.0)


def test_log_lines_are_json(tmp_path):
    _, bot = make(tmp_path)
    bot.step("X", [100.0])
    bot.step("X", [100.0])
    lines = (tmp_path / "log.jsonl").read_text().splitlines()
    assert len(lines) == 2
    for line in lines:
        rec = json.loads(line)
        assert {"ts", "symbol", "action", "side", "qty", "price", "equity"} <= rec.keys()


def test_ccxt_adapter_forces_sandbox():
    class FakeExchange:
        def __init__(self):
            self.calls = []

        def set_sandbox_mode(self, enabled):
            self.calls.append(enabled)

    ex = FakeExchange()
    m.CcxtBroker(ex)
    assert ex.calls == [True]


def test_alpaca_adapter_forces_paper():
    seen = {}

    def factory(**kwargs):
        seen.update(kwargs)
        return object()

    m.AlpacaBroker("key", "secret", client_factory=factory)
    assert seen["paper"] is True
```

**Given code (complete in lab.py):**
```python
class FakeBroker:
    def __init__(self, cash: float, prices: dict[str, float]):
        self.cash = cash
        self.prices = dict(prices)
        self.positions: dict[str, float] = {}
        self.orders: list[tuple[str, str, str, float, float]] = []

    def get_price(self, symbol):
        return self.prices[symbol]

    def get_position(self, symbol):
        return self.positions.get(symbol, 0.0)

    def get_equity(self):
        return self.cash + sum(q * self.prices[s] for s, q in self.positions.items())

    def submit_order(self, symbol, side, qty):
        if qty <= 0 or side not in ("buy", "sell"):
            raise ValueError(f"bad order {side} {qty}")
        px = self.prices[symbol]
        signed = qty if side == "buy" else -qty
        self.positions[symbol] = self.get_position(symbol) + signed
        self.cash -= signed * px
        oid = f"fake-{len(self.orders) + 1}"
        self.orders.append((oid, symbol, side, qty, px))
        return oid


class CcxtBroker:
    """Crypto exchange adapter. ALWAYS sandbox/testnet in Phase 1."""

    def __init__(self, exchange):
        exchange.set_sandbox_mode(True)  # never remove: Phase 1 is testnet-only
        self.ex = exchange

    def get_price(self, symbol):
        return float(self.ex.fetch_ticker(symbol)["last"])

    def get_position(self, symbol):
        base = symbol.split("/")[0]
        return float(self.ex.fetch_balance()["total"].get(base, 0.0))

    def get_equity(self):
        raise NotImplementedError("Equity across assets is exchange-specific; "
                                  "the bot uses quote balance + position value via main().")

    def submit_order(self, symbol, side, qty):
        return self.ex.create_order(symbol, "market", side, qty)["id"]


class AlpacaBroker:
    """US equities adapter. ALWAYS paper in Phase 1."""

    def __init__(self, api_key, secret_key, client_factory=None):
        if client_factory is None:
            from alpaca.trading.client import TradingClient as client_factory
        self.client = client_factory(api_key=api_key, secret_key=secret_key, paper=True)
        self._keys = (api_key, secret_key)

    def get_price(self, symbol):
        from alpaca.data.historical import StockHistoricalDataClient
        from alpaca.data.requests import StockLatestTradeRequest
        data = StockHistoricalDataClient(*self._keys)
        return float(data.get_stock_latest_trade(
            StockLatestTradeRequest(symbol_or_symbols=symbol))[symbol].price)

    def get_position(self, symbol):
        try:
            return float(self.client.get_open_position(symbol).qty)
        except Exception:  # no open position
            return 0.0

    def get_equity(self):
        return float(self.client.get_account().equity)

    def submit_order(self, symbol, side, qty):
        from alpaca.trading.enums import OrderSide, TimeInForce
        from alpaca.trading.requests import MarketOrderRequest
        req = MarketOrderRequest(symbol=symbol, qty=qty, time_in_force=TimeInForce.DAY,
                                 side=OrderSide.BUY if side == "buy" else OrderSide.SELL)
        return str(self.client.submit_order(req).id)
```
Also given: `RiskLimits`, `Bot.__init__` (stores args, `killed=False`, `day_start_equity = broker.get_equity()`), `Bot.new_day()` (resets `day_start_equity`), and `main()`. With no CLI args, `main()` replays the BTC snapshot through `FakeBroker` with a 50-day momentum strategy (weight 1/0), printing a trade log summary. `--venue ccxt|alpaca` loads `.env` via python-dotenv and builds the matching adapter. The ccxt route uses `ccxt.binance({"apiKey":…, "secret":…})`, wrapped in `CcxtBroker`, and the README warns to run only after reading the safety section. Do NOT run `--venue` during authoring.
**Learner stubs:** `Bot.step`, `Bot._flatten(symbol: str, price: float) -> None`, `Bot._log(record: dict) -> None`.
**Solution notes (`step` order):**
1. If `killed`, or `kill_file.exists()` while not killed: flatten if a position exists, set `killed=True`, log, return `{"action": "killed", "side": None, "qty": 0.0}`.
2. `equity = broker.get_equity()`. If `equity < day_start_equity*(1-max_daily_loss)`: same kill path.
3. Otherwise `w = min(max(strategy(history), 0), 1)`; `target_qty = min(w*equity, max_position_notional)/price`; `delta = target_qty - position`. If `abs(delta)*price < min_order_notional`, it's a hold. Otherwise clip `abs(delta)` to `max_order_notional/price` and submit.
4. Log every step as a JSON line with an ISO `ts` and keys `symbol, action, side, qty, price, equity`.

**Content requirements (Block 5):**
- `## Why this matters` opens with the one-paragraph "Not financial advice / paper only in Phase 1" note.
- Bot architecture: data → signal → target → risk checks → orders → reconciliation → logs; idempotency and restarts; clock and timezone issues (US market hours vs ICT); the broker abstraction and why tests use a fake.
- Safety: kill switches (file, daily loss, max position), paper vs live endpoints, secret handling (`.env`, never commit, key scopes: trade-only, no withdrawal), rate limits.
- Paper-trading limits: no market impact, optimistic fills; how long to paper trade before risking money (Phase 3 criteria).
- Setting up Alpaca paper and the Binance spot testnet (step-by-step, the learner's own accounts; availability from Vietnam, verified).
- Worked example: one replayed day of the bot log.
- ≥5 exercises.
- Anti-patterns: running untested code against live keys; keys with withdrawal permission; no reconciliation of actual vs expected positions.
- `## Teardown`: stop the bot, revoke/rotate paper and testnet keys, delete `.env` if you are done.
- **Verify (as of 2026-10):** Alpaca paper signup availability for non-US residents; the Binance spot testnet URL and ccxt sandbox support; `alpaca-py` class names used in the adapter.

**Steps:**
- [ ] D1 write `labs/day29/test_lab.py` (above)
- [ ] D2 write `labs/day29/lab.py` (given code + stubs `Bot.step`, `Bot._flatten`, `Bot._log`)
- [ ] D3 `uv run pytest day29` → Bot tests FAIL with NotImplementedError; the two adapter tests pass (that is expected and allowed)
- [ ] D4 write `labs/day29/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day29` → pass; `uv run python -m day29.solution` (no args, FakeBroker replay only) runs
- [ ] D6 write README.md (with a **Safety** section before Steps), SOLUTION.md
- [ ] D7 write `content/day29.md`
- [ ] D8 `uv run python tools/verify_labs.py day29 && uv run python tools/check_content.py day29`
- [ ] D9 controller commit `WIP: task 32 day29 (scratch)`

---

### Task 33: Day 30 — Capstone: idea → kill checklist → paper deployment

**Files:** `content/day30.md`, `labs/day30/{README.md,lab.py,test_lab.py,solution.py,SOLUTION.md,CAPSTONE.md}`

**Interfaces:**
- Consumes: `common.backtest`, `common.stats.deflated_sharpe_ratio`, `common.risk.breakeven_cost_bps`, `common.quant`
- Produces: `REQUIRED_KEYS = ("dsr", "is_sharpe", "oos_sharpe", "net_sharpe", "benchmark_sharpe", "n_trades", "max_drawdown", "breakeven_cost_bps", "assumed_cost_bps")` (given); `kill_checklist(r: dict) -> list[str]`; `verdict(r: dict) -> str` (`"paper-trade"` or `"kill"`); `run_capstone(prices: pd.Series, lookbacks: list[int], cost_bps: float, split: float = 0.6) -> dict` (contains all `REQUIRED_KEYS` plus `chosen_lookback`)

**test_lab.py:**
```python
import numpy as np
import pandas as pd
import pytest

from common.labimpl import load_impl

m = load_impl(__file__)
GOOD = dict(dsr=0.97, is_sharpe=1.0, oos_sharpe=0.8, net_sharpe=0.9, benchmark_sharpe=0.5,
            n_trades=60, max_drawdown=-0.2, breakeven_cost_bps=40.0, assumed_cost_bps=10.0)


def test_good_strategy_passes():
    assert m.kill_checklist(GOOD) == []
    assert m.verdict(GOOD) == "paper-trade"


@pytest.mark.parametrize("change,failed", [
    ({"dsr": 0.9}, "deflated_sharpe"),
    ({"oos_sharpe": 0.4}, "oos_decay"),
    ({"net_sharpe": 0.5}, "beats_benchmark"),
    ({"n_trades": 29}, "sample_size"),
    ({"max_drawdown": -0.36}, "drawdown"),
    ({"breakeven_cost_bps": 19.0}, "cost_survival"),
])
def test_each_rule(change, failed):
    r = {**GOOD, **change}
    assert m.kill_checklist(r) == [failed]
    assert m.verdict(r) == "kill"


def test_missing_keys_named():
    with pytest.raises(ValueError, match="dsr"):
        m.kill_checklist({k: v for k, v in GOOD.items() if k != "dsr"})


def test_run_capstone_produces_full_report():
    rng = np.random.default_rng(7)
    idx = pd.bdate_range("2015-01-01", periods=1500)
    p = pd.Series(100 * np.exp(np.cumsum(rng.normal(0.0003, 0.01, 1500))), idx)
    r = m.run_capstone(p, [20, 60, 120], cost_bps=10)
    assert set(m.REQUIRED_KEYS) <= r.keys()
    assert r["chosen_lookback"] in (20, 60, 120)
    assert 0.0 <= r["dsr"] <= 1.0 and r["max_drawdown"] <= 0
    assert m.verdict(r) in ("paper-trade", "kill")
```

**Given code:** `REQUIRED_KEYS`, and `main()`. `main()` runs `run_capstone` on SPY and BTC-USD with lookbacks [20, 60, 120, 200, 250] at 5 bps (SPY) and 10 bps (BTC), prints each report with failed checks and the verdict, and tells the learner to copy the report into `CAPSTONE.md`.
**Learner stubs:** `kill_checklist`, `verdict`, `run_capstone`.
**Solution notes:**
- Rules, in the order of the test's names: `dsr < 0.95`; `oos_sharpe < 0.5*is_sharpe`; `net_sharpe <= benchmark_sharpe`; `n_trades < 30`; `max_drawdown < -0.35`; `breakeven_cost_bps < 2*assumed_cost_bps`. Missing keys → `ValueError` listing them.
- `run_capstone`: split at `int(len(p)*split)`. On the IS slice, pick the lookback with the best annualized Sharpe of `backtest(...)["strat_ret"]` with no costs. Then, on the full series with the chosen lookback, run the backtest with costs and slice the OOS part (index ≥ split date) for `oos_sharpe` and `net_sharpe` (net = with costs, OOS). `is_sharpe` is gross on IS. The benchmark is the buy-and-hold Sharpe on OOS returns.
- `dsr = deflated_sharpe_ratio(sr=per-period IS Sharpe, n_trials=len(lookbacks), sr_variance=variance of per-period IS Sharpes across lookbacks (ddof=1; if NaN use 1e-6), n_obs=len(IS))`.
- `n_trades` = count of nonzero turnover rows in the full run; `max_drawdown` of the full-run equity; `breakeven_cost_bps` = `common.risk.breakeven_cost_bps(gross strat returns, turnover)` on the full run.

**`labs/day30/CAPSTONE.md`** (template the learner fills in): sections `## Hypothesis (written before testing)` with prompts "who pays me and why", "when should this fail"; `## Data & universe` (survivorship notes); `## Variants tried (all of them)`, a table that feeds n_trials; `## Report`, where the output of `run_capstone` is pasted; `## Kill checklist`, a table of 6 rules × pass/fail; `## Decision`, kill or paper-trade, with the paper-trade plan (venue, size, duration ≥ 3 months, metrics to compare against backtest, stop conditions); `## Investment Policy Statement`, with prompts for goals, horizon, liquidity needs, risk tolerance (max drawdown you can sit through), allocation ranges across US ETFs / VN equities / crypto / cash, rebalancing rule, rules you will never break, and a review date.

**Content requirements (integration day):**
- Recap map of Block 5 and of the whole course on one page (the "follow the money" chain from Day 1 to Day 29).
- `## Worked example`: run the capstone on SPY and read every line of the report.
- `## Exercises` (≥3): complete `CAPSTONE.md` for your own idea; write your IPS; resolve and score every journal entry and compute your Brier score.
- `## Checkpoint quiz` (12–15 over Days 25–29 + 3 cumulative) + `## Answer key`.
- `## Teardown`: same as Day 29, plus archiving the journal.
- "What next": a pointer to `ROADMAP.md` Phase 2–4 with entry criteria; tick PROGRESS.md.
- **Verify (as of 2026-10):** none beyond citations reused from Days 25–29.

**Steps:**
- [ ] D1 write `labs/day30/test_lab.py` (above)
- [ ] D2 write `labs/day30/lab.py` (stubs: `kill_checklist`, `verdict`, `run_capstone`) and `labs/day30/CAPSTONE.md`
- [ ] D3 `uv run pytest day30` → all FAIL with NotImplementedError
- [ ] D4 write `labs/day30/solution.py`
- [ ] D5 `LAB_IMPL=solution uv run pytest day30` → pass; `uv run python -m day30.solution` runs
- [ ] D6 write README.md, SOLUTION.md
- [ ] D7 write `content/day30.md` (integration headings)
- [ ] D8 `uv run python tools/verify_labs.py day30 && uv run python tools/check_content.py day30`
- [ ] D9 controller commit `WIP: task 33 day30 (scratch)`

---

### Task 34: Glossary, whole-course verification, and handoff

**Files:**
- Create: `content/GLOSSARY.md`
- Modify (only if checks fail): `README.md`, `PROGRESS.md`

**Interfaces:**
- Consumes: all content files and labs.

- [ ] **Step 1: Write `content/GLOSSARY.md`**

Read `content/day01.md`–`day30.md` and collect every term that appears in bold or as a section concept. Write ≥150 entries, alphabetical, each in the form:
`**Term** — plain-English definition in ≤2 sentences, no jargon not itself defined here. *(Day NN)*`
Group the entries under letter headings `## A`, `## B`, and so on. Required terms include at least: T-account, reserves, IORB, ON RRP, QE, QT, repo, haircut, duration, convexity, yield curve, inversion, CIP, UIP, carry trade, impossible trinity, central rate, trading band, foreign ownership limit, price limit, UTXO, proof of work, halving, gas, base fee, staking, stablecoin, CDP, liquidation, AMM, impermanent loss, MEV, perpetual future, funding rate, basis, look-ahead bias, survivorship bias, deflated Sharpe ratio, walk-forward, Kelly criterion, volatility targeting, kill switch, Brier score.

Run: `/usr/bin/grep -c '^\*\*' economy_monetary_mastery/content/GLOSSARY.md`
Expected: ≥ 150.

- [ ] **Step 2: Full lab verification**

Run (from `labs/`): `uv run python tools/verify_labs.py`
Expected: 30 lines `dayNN  solution:PASS  stub:FAIL-CLEAN`, then `30/30 labs OK`.
Run: `LAB_IMPL=solution uv run pytest`
Expected: all pass (common, tools, day01–day30).

- [ ] **Step 3: Full content and secret verification**

Run: `uv run python tools/check_content.py`
Expected: 30 `dayNN OK` lines, no `SECRET?` lines, exit 0.
Run: `ls -a economy_monetary_mastery/labs | /usr/bin/grep -x '.env' || echo "no .env"`
Expected: `no .env`.

- [ ] **Step 4: Cross-reference check**

Run:
```bash
cd economy_monetary_mastery && for n in $(seq -w 1 30); do
  test -f content/day$n.md && test -f labs/day$n/README.md && test -f labs/day$n/SOLUTION.md \
    || echo "missing day$n"; done; echo done
```
Expected: only `done`.
Confirm README's day index titles match each `content/dayNN.md` H1 (fix README if not).

- [ ] **Step 5: Final whole-branch review (controller)**

Dispatch one reviewer with a file manifest (not a diff), per the local skill. Focus: factual accuracy of the "as of 2026-10" items, consistency of names across days, and Review Focus items 1–5. Apply fixes, re-run Steps 2–3.

- [ ] **Step 6: Commit (controller)**

```bash
git add economy_monetary_mastery && git commit -m "WIP: task 34 glossary + verification (scratch)"
```

- [ ] **Step 7: Teardown to `feature/with_currency` (controller)**

```bash
git reset --soft feature/with_currency
git switch feature/with_currency
git reset
git branch -D authoring/economy_monetary
git status
```
Expected: `economy_monetary_mastery/` untracked; `basic_prompt.md` still modified (the learner's own edit); nothing pushed.
