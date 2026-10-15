import os


def pytest_report_header(config):
    return f"LAB_IMPL={os.environ.get('LAB_IMPL', 'lab')}"
