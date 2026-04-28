# 2 · DRIVER — Represent

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   NovaWealth Dynamics                       │
│                     R / Shiny App                           │
├──────────────┬──────────────────────────┬───────────────────┤
│  Node 1      │  Node 2                  │  Node 3           │
│  Client      │  DCF Valuation           │  Portfolio        │
│  Onboarding  │  Screener                │  Optimizer        │
│              │                          │                   │
│  Inputs:     │  Inputs:                 │  Inputs:          │
│  Age         │  50-stock universe       │  Filtered tickers │
│  Income      │  Custom tickers          │  from Node 2      │
│  Occupation  │  WACC slider             │  Objective from   │
│  Risk slider │  TGR slider              │  Node 1           │
│              │  MoS slider              │  Max weight       │
│  Output:     │                          │                   │
│  Risk Profile│  Output:                 │  Output:          │
│  → Objective │  DCF table               │  Weights          │
│    assignment│  Passing ticker list     │  Return / Risk    │
│              │  → feeds Node 3          │  Efficient Front. │
└──────────────┴──────────────────────────┴───────────────────┘
```

---

## Technology Stack

| Layer | Technology | Role |
|---|---|---|
| App Framework | `shiny` + `shinydashboard` | Reactive UI and routing |
| Data Fetching | `tidyquant`, `quantmod` | Yahoo Finance API wrapper |
| Data Wrangling | `dplyr` | Pipeline transformations |
| Visualization | `ggplot2` | Efficient Frontier plot |
| Tables | `DT` | Interactive data display |
| Optimization | `quadprog` | Quadratic programming (Min Variance) |
| UI Utilities | `shinyjs` | Tab navigation |

---

## Data Flow

### Flow A — Risk Profile → Optimizer Objective
```
[Phase 1 Inputs] → compute_profile() → profile string
                → objective_from_profile() → "Max Sharpe" | "Min Variance"
                → updateSelectInput("objective") in Phase 3
```
The user may manually override the objective after seeing their profile.

### Flow B — WACC/TGR → DCF Values → Filter → Optimizer
```
[WACC slider] ──────────────────────────────────────────┐
[TGR slider] ────────────────────────────────────────┐   │
                                                     ▼   ▼
                                              calc_dcf(ticker, wacc, tgr)
                                                     │
                                              dcf_results (reactiveVal)
                                                     │
                                              passing() reactive ←── [MoS slider]
                                                     │
                                              optimize_portfolio(passing(), ...)
                                                     │
                                              opt_result (reactiveVal)
                                                     │
                                              frontier_plot re-renders
```

### Caching Strategy
- `cache` environment is module-level (persists for session lifetime).
- `safe_tq_get()` checks `cache` before making API calls.
- `safe_financials()` similarly caches income/balance/cash-flow statements.
- On repeated WACC slider adjustments, the DCF recalculation uses already-cached price data, so only the math re-runs, not the network calls.

---

## Reactive Dependency Graph

```
input$age ──┐
input$income┤
input$occ.  ├─► profile() ──► objective_from_profile() ──► selectInput
input$risk  ┘

input$wacc ─┐
input$tgr   ├─► [run_screener click] ──► dcf_results() ──► dcf_table
input$mos   ─────────────────────────────────────────────► passing()
                                                              │
                                                              ▼
input$obj. ─┬──────────────────────────────────────────► [run_optimizer]
input$maxw  ┘                                                 │
                                                              ▼
                                                         opt_result()
                                                         vbox_ret / risk / sr
                                                         frontier_plot
```

---

## Module Boundaries

| Function | Inputs | Outputs | Side Effects |
|---|---|---|---|
| `compute_profile()` | age, income, occ, risk_score | character profile | None |
| `calc_dcf()` | ticker, wacc, tgr | named list or NULL | Writes to `cache` |
| `safe_tq_get()` | ticker, from, to | price data frame | Writes to `cache` |
| `optimize_portfolio()` | tickers, objective, max_weight | named list | None |
