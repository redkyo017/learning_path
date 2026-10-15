# Data snapshots

Frozen copies of public data so every lab test is offline and deterministic.
Tests never fetch. To explore fresher data, call a loader with `live=True` — results go to
`labs/.cache/`, never here. Re-create everything with `uv run python data/snapshot.py`
(the old files are overwritten; tests may then need their data-dependent assertions re-checked).

Units: FRED rates are **percent** (5.33 = 5.33%); WALCL is **millions USD**; WRESBAL is
**millions USD**; VND=X is VND per USD; VN stock prices are VND; VN indices are points.


## Snapshot run 2026-10-11 (cut-off 2026-09-30)

| File | Source | Size | Range |
|---|---|---|---|
| `fred/WALCL.csv` | FRED WALCL | 1242 rows | 2002-12-18 → 2026-09-30 |
| `fred/WRESBAL.csv` | FRED WRESBAL (millions USD) | 1242 rows | 2002-12-18 → 2026-09-30 |
| `fred/DFF.csv` | FRED DFF | 26390 rows | 1954-07-01 → 2026-09-30 |
| `fred/IORB.csv` | FRED IORB | 1890 rows | 2021-07-29 → 2026-09-30 |
| `fred/RRPONTSYD.csv` | FRED RRPONTSYD | 3337 rows | 2003-02-07 → 2026-09-30 |
| `fred/CPIAUCSL.csv` | FRED CPIAUCSL | 955 rows | 1947-01-01 → 2026-08-01 |
| `fred/DGS3MO.csv` | FRED DGS3MO | 11270 rows | 1981-09-01 → 2026-09-30 |
| `fred/DGS2.csv` | FRED DGS2 | 12580 rows | 1976-06-01 → 2026-09-30 |
| `fred/DGS10.csv` | FRED DGS10 | 16172 rows | 1962-01-02 → 2026-09-30 |
| `fred/T10Y2Y.csv` | FRED T10Y2Y | 12580 rows | 1976-06-01 → 2026-09-30 |
| `fred/T5YIE.csv` | FRED T5YIE | 5941 rows | 2003-01-02 → 2026-09-30 |
| `fred/UNRATE.csv` | FRED UNRATE | 944 rows | 1948-01-01 → 2026-09-01 |
| `fred/INDPRO.csv` | FRED INDPRO | 1292 rows | 1919-01-01 → 2026-08-01 |
| `fred/M2SL.csv` | FRED M2SL | 812 rows | 1959-01-01 → 2026-08-01 |
| `fred/DTWEXBGS.csv` | FRED DTWEXBGS | 5201 rows | 2006-01-02 → 2026-09-30 |
| `fred/DEXKOUS.csv` | FRED DEXKOUS | 11365 rows | 1981-04-13 → 2026-09-30 |
| `fred/DEXBZUS.csv` | FRED DEXBZUS | 7962 rows | 1995-01-02 → 2026-09-30 |
| `fred/DEXINUS.csv` | FRED DEXINUS | 13471 rows | 1973-01-02 → 2026-09-30 |
| `fred/DEXTHUS.csv` | FRED DEXTHUS | 11398 rows | 1981-01-02 → 2026-09-30 |
| `fred/DEXMXUS.csv` | FRED DEXMXUS | 8247 rows | 1993-11-08 → 2026-09-30 |
| `prices/SPY.csv` | Yahoo Finance SPY (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/QQQ.csv` | Yahoo Finance QQQ (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/IWF.csv` | Yahoo Finance IWF (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/IWD.csv` | Yahoo Finance IWD (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/TLT.csv` | Yahoo Finance TLT (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/IEF.csv` | Yahoo Finance IEF (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/AGG.csv` | Yahoo Finance AGG (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/GLD.csv` | Yahoo Finance GLD (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/EFA.csv` | Yahoo Finance EFA (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/EEM.csv` | Yahoo Finance EEM (adj. close) | 5469 rows | 2005-01-03 → 2026-09-29 |
| `prices/VNM.csv` | Yahoo Finance VNM (adj. close) | 4307 rows | 2009-08-14 → 2026-09-29 |
| `prices/VND_X.csv` | Yahoo Finance VND=X (adj. close) | 5664 rows | 2005-01-03 → 2026-09-29 |
| `prices/DX-Y.NYB.csv` | Yahoo Finance DX-Y.NYB (adj. close) | 5475 rows | 2005-01-03 → 2026-09-29 |
| `prices/BTC-USD.csv` | Yahoo Finance BTC-USD (adj. close) | 4396 rows | 2014-09-17 → 2026-09-29 |
| `prices/ETH-USD.csv` | Yahoo Finance ETH-USD (adj. close) | 3247 rows | 2017-11-09 → 2026-09-29 |
| `crypto/binance_BTC_USDT_1d.csv` | Binance BTC/USDT 1d | 2830 rows | 2019-01-01 → 2026-09-30 |
| `crypto/binance_ETH_USDT_1d.csv` | Binance ETH/USDT 1d | 2830 rows | 2019-01-01 → 2026-09-30 |
| `crypto/binance_BTC_USDT_USDT_1d.csv` | Binance BTC/USDT:USDT 1d | 2580 rows | 2019-09-08 → 2026-09-30 |
| `crypto/binance_BTC_USDT_USDT_funding.csv` | Binance BTC/USDT perp funding | 7393 rows | 2020-01-01 → 2026-09-30 |
| `vn/VNINDEX.csv` | Vietcap (VCI) chart API VNINDEX | 4175 rows | 2010-01-04 → 2026-09-30 |
| `vn/VN30.csv` | Vietcap (VCI) chart API VN30 | 3655 rows | 2012-02-06 → 2026-09-30 |
| `vn/FPT.csv` | Vietcap (VCI) chart API FPT | 4175 rows | 2010-01-04 → 2026-09-30 |
| `vn/HPG.csv` | Vietcap (VCI) chart API HPG | 4175 rows | 2010-01-04 → 2026-09-30 |
| `vn/VCB.csv` | Vietcap (VCI) chart API VCB | 4175 rows | 2010-01-04 → 2026-09-30 |
| `eth/block.json` | publicnode eth_getBlockByNumber finalized | block 26167253 | — |
| `eth/receipt.json` | publicnode eth_getTransactionReceipt | 1 tx | — |
