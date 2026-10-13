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
          "errors during collection", "NameError", "AttributeError", "TIMEOUT")


@dataclass
class DayResult:
    name: str
    solution_ok: bool
    stub_clean: bool
    detail: str


def _run(day_dir: Path, impl: str) -> tuple[int, str]:
    env = {**os.environ, "LAB_IMPL": impl}
    # -c/--rootdir pin the labs config even when day_dir lives outside labs/ (tests use tmp dirs)
    try:
        p = subprocess.run([sys.executable, "-m", "pytest", str(day_dir), "-q",
                        "-c", str(LABS / "pyproject.toml"), "--rootdir", str(LABS),
                        "-p", "no:cacheprovider"],
                       cwd=LABS, env=env, capture_output=True, text=True, timeout=300)
    except subprocess.TimeoutExpired:
        return 124, "TIMEOUT after 300s"
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
