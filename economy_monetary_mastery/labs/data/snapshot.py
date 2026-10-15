"""Create the frozen snapshots in labs/data/. Run once during authoring (needs network):

    uv run python data/snapshot.py            # everything
    uv run python data/snapshot.py fred vn    # subsets: fred prices crypto vn eth
"""
import json
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common import fetch  # noqa: E402
from common.data import DATA_DIR, _safe  # noqa: E402

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
    for sym in VN:  # VCI already returns VND / index points: no scaling
        _save("vn", sym, fetch.vn(sym).rename("close"), f"Vietcap (VCI) chart API {sym}")


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
        print("snapshot:", name, flush=True)
        STEPS[name]()
    with (DATA_DIR / "MANIFEST.md").open("a") as f:
        f.write(f"\n## Snapshot run {date.today()} (cut-off {END})\n\n"
                "| File | Source | Size | Range |\n|---|---|---|---|\n")
        f.write("\n".join(manifest) + "\n")
