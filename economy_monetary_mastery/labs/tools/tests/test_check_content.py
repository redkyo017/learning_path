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
    fake = "AKIA" + "ABCDEFGHIJKLMNOP" + "1234"  # built at runtime: no literal key in the repo
    (tmp_path / "leak.py").write_text(f'API_KEY = "{fake}"\n')
    (tmp_path / ".env").write_text(f"KEY={fake}\n")  # learner's own gitignored file: not reported
    hits = scan_secrets(tmp_path)
    assert len(hits) == 1 and "leak.py" in hits[0]
