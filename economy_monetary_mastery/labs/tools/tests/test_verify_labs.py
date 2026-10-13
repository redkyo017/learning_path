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
