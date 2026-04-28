# 6 · DRIVER — Reflect

## Technical Learnings

### 1. Managing Reactive Cascades in Shiny

The most significant technical challenge was designing the reactive graph so that changes in Phase 2 (WACC slider) automatically propagate through to Phase 3 (Efficient Frontier) without triggering unwanted re-runs or race conditions.

**Key insight**: Shiny's reactive system distinguishes between `reactive()` (lazy, re-evaluates on dependency change) and `reactiveVal()` (imperative, only updates when explicitly set). The solution used a hybrid approach:

- `dcf_results` is a `reactiveVal` — it only updates when the user explicitly clicks "Run DCF Screener." This prevents the optimizer from re-running every time the user moves a slider mid-thought.
- `passing()` is a `reactive()` — it depends on both `dcf_results()` and `input$mos`, so adjusting the Margin of Safety slider immediately updates the filtered list without re-fetching API data.
- The Efficient Frontier re-renders automatically whenever `opt_result()` changes via `renderPlot`.

This architecture balances **responsiveness** (slider changes are instant) with **stability** (expensive API calls are gated behind button clicks).

**Pitfall encountered**: An early prototype made `dcf_results` a `reactive()` dependent on `input$wacc`. This caused the screener to fire on every slider tick, instantly exceeding Yahoo Finance rate limits and crashing the app. The `reactiveVal` + button-click pattern solved this.

### 2. API Rate Limit Mitigation via Session Cache

Yahoo Finance's unofficial API enforces per-IP, per-session rate limits. With 50 default tickers, a naive implementation makes ~150 API calls (prices, income statement, balance sheet). The `cache` environment pattern reduced repeat calls to zero within a session:

```r
cache <- new.env(parent = emptyenv())
```

Using `new.env(parent = emptyenv())` is intentional — it prevents accidental variable lookup propagating to the global environment, making the cache a true isolated namespace.

### 3. Graceful Degradation with `tryCatch`

Yahoo Finance data quality is inconsistent. EPS, market cap, and shares outstanding fields return `NA` for many smaller tickers. Every numeric extraction is wrapped in `tryCatch`, with fallback heuristics (e.g., net debt = 15% of EV). This prevents one bad ticker from crashing the entire screener batch.

---

## Financial Modeling Learnings

### 1. The DCF–MPT Tension

The deepest intellectual friction in this project is the conflict between **DCF valuation discipline** and **Modern Portfolio Theory (MPT)**.

DCF analysis is fundamentally about **intrinsic value** — it argues that a stock is worth owning only when its price is below a calculated fundamental value. It is a stock-picking, conviction-based framework rooted in Graham & Dodd-style value investing.

MPT, by contrast, is **agnostic about value**. It cares only about expected returns, variances, and correlations. A purely MPT portfolio might overweight an overvalued but low-volatility stock simply because it reduces portfolio variance.

**The integration creates an interesting emergent property**: by forcing the optimizer to work only from a DCF-screened universe, we are injecting a Graham-style "margin of safety" into what is otherwise a purely statistical optimization. The resulting portfolio is theoretically both *mean-variance efficient within the screened set* and *composed only of undervalued assets* by DCF criteria.

However, this also introduces a limitation: if the DCF model is too conservative (high WACC), the screened universe shrinks dramatically. With fewer assets, diversification benefits decrease and the optimizer may produce a concentrated, suboptimal portfolio despite being "efficient" within its restricted set. This is the classic **selectivity-diversification tradeoff**.

### 2. DCF Sensitivity to WACC

A 1% increase in WACC has a non-linear (convex) effect on intrinsic value due to the compounding structure of DCF discounting and the terminal value formula `TV = FCF × (1+g) / (WACC−g)`. Near the denominator's zero (when WACC ≈ TGR), small WACC changes produce enormous TV swings. This models real-world behavior but also exposes a modeling fragility — the DCF is highly sensitive to the spread `(WACC − TGR)`.

**Practical implication**: The Margin of Safety slider serves not only as a value-investing hurdle but also as a robustness buffer against DCF model uncertainty.

### 3. Growth Rate Decay as Realism Mechanism

Early versions of the DCF used a single, flat growth rate derived from historical EPS growth. For high-growth companies (e.g., Nvidia), historical EPS growth exceeded 100%, producing absurd intrinsic values. The solution was a hard-coded declining growth schedule (12%, 10%, 8%, 7%, 6%) that forces mean-reversion and produces more conservative, defensible valuations — consistent with how professional analysts model "growth fading to GDP."

---

## What We Would Do Differently

| Area | Issue | Improvement |
|---|---|---|
| Data sourcing | Yahoo Finance unofficial API is fragile | Use a paid API (Alpha Vantage, Financial Modeling Prep) |
| DCF model | Static growth rate schedule | CAPM-derived beta for stock-specific growth expectations |
| Caching | Session-only (lost on restart) | Disk-based cache via `memoise` package |
| Optimizer | Random Monte Carlo for Max Sharpe | Proper convex optimization (e.g., `CVXR` package) |
| UI | Single-page dashboard | Module-based Shiny architecture for maintainability |
