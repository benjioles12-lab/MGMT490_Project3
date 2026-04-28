# 3 · DRIVER — Implement

## Codebase Summary

All application logic lives in a single file: `app.R`.

---

## File Structure

| Section | Lines (approx.) | Purpose |
|---|---|---|
| Library imports | 1–10 | Load all dependencies |
| `DEFAULT_TICKERS` | 12–21 | 50-stock universe definition |
| `cache` environment | 23–24 | Session-level API cache |
| `safe_tq_get()` | 26–33 | Cached price data fetcher |
| `safe_financials()` | 35–45 | Cached financials fetcher |
| `calc_dcf()` | 48–95 | Core DCF valuation logic |
| `compute_profile()` | 98–103 | Risk score → profile mapping |
| `optimize_portfolio()` | 106–165 | Mean-variance optimizer |
| `ui` | 168–260 | Shiny dashboard layout |
| `server` | 263–370 | Reactive server logic |

---

## Major Milestones

### Milestone 1 — Cross-Component Reactivity

The most complex engineering challenge. Implemented via Shiny's reactive graph:

- `dcf_results` is a `reactiveVal` updated only on button click (avoids uncontrolled re-runs).
- `passing()` is a standard `reactive` that depends on both `dcf_results()` and the `input$mos` slider — it re-evaluates whenever either changes.
- `opt_result` downstream depends on `passing()`, so the full cascade from WACC → intrinsic values → filter → optimizer → frontier happens automatically.

```r
# Key reactive chain:
passing <- reactive({
  df <- dcf_results()
  req(!is.null(df), nrow(df) > 0)
  df %>% filter(upside >= input$mos) %>% pull(ticker)
})
```

### Milestone 2 — API Rate Limit Mitigation (Caching)

Yahoo Finance enforces rate limits. The `cache` environment stores results keyed by `"TICKER_fromdate_todate"`. On repeated evaluations (e.g., user moves the WACC slider), `safe_tq_get()` returns the cached data frame immediately without a network call.

```r
safe_tq_get <- function(ticker, from, to) {
  key <- paste0(ticker, "_", from, "_", to)
  if (exists(key, envir = cache)) return(get(key, envir = cache))
  result <- tryCatch(tq_get(ticker, ...), error = function(e) NULL)
  if (!is.null(result)) assign(key, result, envir = cache)
  result
}
```

### Milestone 3 — Dynamic Objective Mapping

Phase 1's risk profile is immediately translated into a Phase 3 optimization objective via a reactive chain and `updateSelectInput`:

```r
objective_from_profile <- reactive({
  switch(profile(),
    "Aggressive"   = "Max Sharpe",
    "Moderate"     = "Max Sharpe",
    "Conservative" = "Min Variance",
    "Max Sharpe"
  )
})

observeEvent(profile(), {
  updateSelectInput(session, "objective", selected = objective_from_profile())
})
```

### Milestone 4 — Dual Optimization Methods

- **Max Sharpe**: Monte Carlo simulation of 500 random portfolios with the best Sharpe ratio selected. Supports the per-stock max weight constraint natively.
- **Min Variance**: Quadratic programming via `quadprog::solve.QP()`. Constraints: `sum(w)=1`, `w >= 0`, `w <= max_weight`.

### Milestone 5 — DCF Model Design

The DCF uses a simplified but defensible approach given API availability:

1. FCF estimated as `EPS × shares × 0.7` (70% free cash flow conversion proxy).
2. 5-year projection with declining growth rates: 12%, 10%, 8%, 7%, 6%.
3. Terminal value: `FCF₅ × (1 + TGR) / (WACC − TGR)`.
4. Net debt estimated as 15% of Enterprise Value (fallback when API data unavailable).
5. Intrinsic value = Equity Value / Shares Outstanding.

### Milestone 6 — Dark-Themed Dashboard

The UI uses `shinydashboard` with `skin = "black"` and custom CSS injecting `#0d0f14` / `#1a1d27` backgrounds, `#6c63ff` accent color, and consistent dark-mode typography. The `ggplot2` Efficient Frontier plot uses matching dark background colors via `theme()`.

---

## Known Limitations & Workarounds

| Limitation | Workaround |
|---|---|
| `getQuote()` may return NA for some fields | `tryCatch` wraps every field access; fallbacks used |
| `tidyquant` financial statement endpoints may fail | `NULL` return + `Filter(Negate(is.null))` before `rbind` |
| Min Variance `solve.QP()` can fail with ill-conditioned Sigma | Fallback to equal weights `rep(1/n, n)` |
| Yahoo Finance enforces session-based rate limits | Session-level `cache` environment prevents re-fetching |
