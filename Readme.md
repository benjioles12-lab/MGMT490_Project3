# NovaWealth Dynamics

> **A fully integrated, three-phase investment pipeline built in R Shiny.**  
> Client onboarding → DCF valuation screening → Modern Portfolio Theory optimization.

---

## Project Description

NovaWealth Dynamics is a capstone financial engineering application developed for MGMT 490. It unifies three previously separate analytical workflows into a single, reactive R Shiny dashboard:

| Phase | Name | Description |
|---|---|---|
| **1** | Client Onboarding | Collects demographic and preference data to compute a personalized risk profile (Conservative / Moderate / Aggressive), which automatically sets the portfolio optimization objective. |
| **2** | DCF Screener | Fetches live financial data from Yahoo Finance to calculate Discounted Cash Flow (DCF) intrinsic values for a 50-stock universe. Applies a user-defined Margin of Safety filter. Only undervalued stocks advance. |
| **3** | Portfolio Optimizer | Constructs an optimal portfolio from the Phase 2 filtered assets using either Maximum Sharpe Ratio (Monte Carlo) or Minimum Variance (quadratic programming) optimization. Visualizes the Efficient Frontier. |

The application is **fully reactive**: adjusting the WACC slider in Phase 2 automatically cascades through intrinsic value recalculations, filter updates, and re-optimization — visibly shifting the Efficient Frontier in Phase 3.

---

## Project Goals

1. Integrate DCF-based fundamental analysis with Modern Portfolio Theory in a single interactive tool.
2. Demonstrate how client risk profiling can drive downstream quantitative decisions.
3. Build a production-quality, dark-themed Shiny dashboard with real-time Yahoo Finance data.
4. Apply software engineering best practices (caching, graceful error handling, reactive dependency management) to a financial data pipeline.

---

## Running the Application

### Requirements
- R ≥ 4.2.0 — [https://cran.r-project.org](https://cran.r-project.org)
- RStudio (recommended) — [https://posit.co/download/rstudio-desktop/](https://posit.co/download/rstudio-desktop/)
- Active internet connection (for Yahoo Finance API calls)

### Step 1 — Install Dependencies

Open R or RStudio and run:

```r
install.packages(c(
  "shiny", "shinydashboard", "shinyjs",
  "tidyquant", "quantmod",
  "dplyr", "ggplot2", "DT", "quadprog"
))
```

### Step 2 — Run the App

```r
shiny::runApp("path/to/MGMT490_Project3/app.R")
```

Or open `app.R` in RStudio and click the **Run App** button.

### Step 3 — Using the App

1. **Phase 1**: Enter your age, income, occupation, and risk tolerance. Click "Proceed to Phase 2."
2. **Phase 2**: Optionally add custom tickers. Adjust WACC, Terminal Growth Rate, and Margin of Safety using the left-panel sliders. Click "Run DCF Screener" (takes 1–3 minutes). Click "Send to Phase 3."
3. **Phase 3**: Review the pre-selected optimization objective. Adjust Max Weight if desired. Click "Run Optimizer." View results and Efficient Frontier.

> **Note**: Phase 2 caches all API responses for the session. After the first run, changing sliders and re-running is near-instant.

---

## File Structure

```
MGMT490_Project3/
├── app.R                    # Full Shiny application
├── 1_DRIVER_Define.md       # Product vision and requirements
├── 2_DRIVER_Represent.md    # System architecture and data flow
├── 3_DRIVER_Implement.md    # Codebase summary and milestones
├── 4_DRIVER_Validate.md     # Test cases and validation matrix
├── 5_DRIVER_Evolve.md       # Dependencies and roadmap
├── 6_DRIVER_Reflect.md      # Technical and financial learnings
└── Readme.md                # This file
```

---

## AI Usage Disclosure

Artificial intelligence tools, specifically Google's Antigravity (powered by Claude Sonnet), were used in the development of this project. AI assistance was employed to help scaffold the initial application architecture, generate boilerplate Shiny UI and server code, draft documentation structure, and suggest error-handling patterns for the Yahoo Finance API integration. All financial modeling logic (DCF methodology, growth rate assumptions, optimization constraints), reactive architecture design decisions, and final code review were performed or verified by the project author. The AI served as a collaborative coding assistant, not as the sole author of the work.

---

## Course Information

- **Course**: MGMT 490 — Financial Engineering & Analytics
- **Project**: Project 3 (Capstone Integration)
- **Term**: Spring 2026
