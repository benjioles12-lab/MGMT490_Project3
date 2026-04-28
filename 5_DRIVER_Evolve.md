# 5 · DRIVER — Evolve

## Package Dependencies

| Package | Version (min) | Role | Install Command |
|---|---|---|---|
| `shiny` | ≥ 1.7.0 | Web application framework | `install.packages("shiny")` |
| `shinydashboard` | ≥ 0.7.2 | Dashboard UI components | `install.packages("shinydashboard")` |
| `shinyjs` | ≥ 2.1.0 | JavaScript utilities (tab switching) | `install.packages("shinyjs")` |
| `tidyquant` | ≥ 1.0.6 | Yahoo Finance data via tidy API | `install.packages("tidyquant")` |
| `quantmod` | ≥ 0.4.22 | `getQuote()` for real-time quotes | `install.packages("quantmod")` |
| `dplyr` | ≥ 1.1.0 | Data manipulation pipelines | `install.packages("dplyr")` |
| `ggplot2` | ≥ 3.4.0 | Efficient Frontier visualization | `install.packages("ggplot2")` |
| `DT` | ≥ 0.27 | Interactive HTML tables | `install.packages("DT")` |
| `quadprog` | ≥ 1.5.8 | Quadratic programming solver | `install.packages("quadprog")` |

### One-liner installation:
```r
install.packages(c(
  "shiny", "shinydashboard", "shinyjs",
  "tidyquant", "quantmod",
  "dplyr", "ggplot2", "DT", "quadprog"
))
```

---

## Local Execution Instructions

### Prerequisites
- R ≥ 4.2.0 installed ([https://cran.r-project.org](https://cran.r-project.org))
- RStudio (recommended) or any R console

### Steps

1. **Clone / download** the project folder `MGMT490_Project3/`.

2. **Install dependencies** — open R or RStudio and run:
   ```r
   install.packages(c(
     "shiny", "shinydashboard", "shinyjs",
     "tidyquant", "quantmod",
     "dplyr", "ggplot2", "DT", "quadprog"
   ))
   ```

3. **Run the app** — from the project directory:
   ```r
   shiny::runApp("app.R")
   ```
   Or open `app.R` in RStudio and click **Run App**.

4. **Expected startup time**: 5–10 seconds for Shiny to initialize. The DCF screener itself takes 1–3 minutes on first run (50 API calls). Results are cached for the remainder of the session.

### Internet Connection
An active internet connection is required for Phase 2 to fetch data from Yahoo Finance. The app will not crash if individual tickers fail — they are silently excluded from results.

---

## Deployment Options

| Method | Command | Notes |
|---|---|---|
| Local | `shiny::runApp()` | Default development mode |
| shinyapps.io | `rsconnect::deployApp()` | Free tier available; requires `rsconnect` package |
| Posit Connect | Admin deploy via rsconnect | Enterprise option |
| Docker | `rocker/shiny` base image | Containerized deployment |

---

## Planned Enhancements (v2.0 Roadmap)

| Feature | Priority | Complexity |
|---|---|---|
| Multi-factor WACC (CAPM-derived beta per stock) | High | Medium |
| Persistent caching (disk-based via `memoise`) | High | Low |
| Sensitivity heatmap modal per stock | Medium | Medium |
| Monte Carlo simulation for retirement projections | Medium | High |
| PDF report export (Phase 1–3 summary) | Low | Medium |
| ESG score integration | Low | Low |
| Bond / multi-asset class support | Low | High |

---

## Version History

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-04 | Initial release — full Phase 1/2/3 pipeline |
