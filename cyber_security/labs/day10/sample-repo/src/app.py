"""Tiny stand-in app for the Day 10 supply-chain lab.

Not meant to actually run against a real queue -- it exists so this repo has
real application code (not just config), and so requirements.txt's planted
CVEs (see requirements.txt's header comment) are dependencies of something,
the way a real vulnerable transitive dependency would be. Reads its config
the *right* way (os.environ, not a hardcoded literal) -- the app code itself
isn't the vulnerability here; config/fake_srts.yml and .env are.
"""
import os

import yaml  # PyYAML 5.1 -- see requirements.txt, CVE-2020-1747


def load_config(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as fh:
        # yaml.load() without Loader= on an old PyYAML is exactly
        # CVE-2020-1747's shape: if `path` ever became attacker-influenced,
        # this line is arbitrary code execution, not just a parse.
        return yaml.load(fh, Loader=yaml.Loader)


def main() -> None:
    db_url = os.environ.get("DATABASE_URL", "")
    cfg = load_config(os.path.join(os.path.dirname(__file__), "..", "config", "secrets.yml"))
    print(f"payment-notifier starting, db configured: {bool(db_url)}, "
          f"stripe key configured: {'stripe' in cfg}")


if __name__ == "__main__":
    main()
