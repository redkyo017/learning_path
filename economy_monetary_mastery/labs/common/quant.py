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
