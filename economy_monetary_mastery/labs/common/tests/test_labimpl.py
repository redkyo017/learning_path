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
