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
