# 1 · DRIVER — Define

## Product Vision

**NovaWealth Dynamics** bridges three pillars of modern financial planning into a single, reactive pipeline:

1. **Client Onboarding (Phase 1)** — Quantify an investor's risk tolerance from demographic and self-reported data, producing a concrete risk profile that automatically drives downstream decisions.
2. **Fundamental Valuation (Phase 2)** — Apply a Discounted Cash Flow (DCF) model across a 50-stock universe to identify genuinely undervalued securities, enforcing a margin-of-safety hurdle before any stock reaches the optimizer.
3. **Portfolio Optimization (Phase 3)** — Construct an efficient portfolio from only the screened, undervalued assets, using an optimization objective (Maximize Sharpe Ratio or Minimum Variance) pre-assigned by Phase 1.

The core thesis is that **valuation discipline** (Phase 2) and **risk-appropriate objectives** (Phase 1) together constrain the optimizer to a higher-quality, personalized opportunity set.

---

## Stakeholders

| Role | Need |
|---|---|
| Retail Investor | Personalized, explainable investment recommendations |
| Financial Advisor | Rapid client risk profiling + screened asset list |
| Analyst | Adjustable DCF assumptions with sensitivity output |
| Professor / Evaluator | End-to-end integration of Project 1 & 2 methodologies |

---

## Core Requirements

### Phase 1 — Risk Profiler
- Collect Age, Income, Occupation, and self-reported Risk Tolerance (slider 1–10).
- Compute a composite score mapping to **Conservative / Moderate / Aggressive**.
- Automatically pre-select the Phase 3 optimization objective:
  - Aggressive → **Maximize Sharpe Ratio**
  - Moderate → **Maximize Sharpe Ratio**
  - Conservative → **Minimum Variance**

### Phase 2 — DCF Screener
- Default universe: 50 individual equities spanning Tech, Financials, Healthcare, Energy, and Consumer sectors (no ETFs).
- Fetch live data from Yahoo Finance via `tidyquant`/`quantmod`.
- Implement startup caching to prevent API rate-limit crashes.
- Calculate and display Enterprise Value, Equity Value, and Per-Share Intrinsic Value.
- Expose global sliders for WACC (5–20%) and Terminal Growth Rate (1–5%).
- Apply a user-defined **Margin of Safety** filter; only passing stocks advance to Phase 3.
- Allow custom ticker entry that also faces the MoS hurdle.

### Phase 3 — Portfolio Optimizer
- Receive the filtered ticker list from Phase 2 automatically.
- Compute expected returns and covariance matrix from 3 years of daily price history.
- Support **Max Sharpe** (Monte Carlo) and **Min Variance** (quadratic programming) objectives.
- Enforce a per-stock maximum weight constraint.
- Display optimal weights, expected portfolio return, risk, and Sharpe Ratio.
- Plot an Efficient Frontier.

### Cross-Component Reactivity (Capstone Requirement)
- Adjusting Phase 2's WACC → changes intrinsic values → fewer stocks pass MoS → Phase 3 re-optimizes with restricted universe → Efficient Frontier visibly shifts.
- This full cascade must occur without manual intervention.

---

## Out of Scope (v1.0)
- Real-time intraday pricing
- Transaction cost modeling
- Tax optimization
- Multi-asset class expansion (bonds, commodities)
