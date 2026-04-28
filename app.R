# ============================================================
# NovaWealth Dynamics — app.R
# ============================================================
library(shiny); library(shinydashboard); library(tidyquant)
library(quantmod); library(dplyr); library(ggplot2)
library(DT); library(quadprog); library(shinyjs)

DEFAULT_TICKERS <- c(
  # ── Technology ────────────────────────────────────────────────
  "AAPL","MSFT","GOOGL","META","NVDA","AMZN","CRM","ADBE","INTC","ORCL",
  "CSCO","IBM","QCOM","TXN","AMD","MU","AMAT","HPQ","ACN","PYPL",
  # ── Financials ───────────────────────────────────────────────
  "JPM","BAC","GS","MS","WFC","AXP","BLK","C","USB","PNC",
  "SCHW","COF","STT","BK","PRU","MET","AFL","TRV","CB","AON",
  # ── Healthcare ───────────────────────────────────────────────
  "JNJ","UNH","PFE","ABBV","MRK","TMO","ABT","DHR","CVS","AMGN",
  "MDT","ELV","CI","BSX","SYK","ISRG","HUM","VRTX","REGN","ZBH",
  # ── Energy ───────────────────────────────────────────────────
  "XOM","CVX","COP","SLB","EOG","MPC","PSX","VLO","OXY","HAL",
  "DVN","MRO","WMB","KMI","BKR","CTRA","APA","NOV","OKE","TRGP",
  # ── Consumer Discretionary ───────────────────────────────────
  "HD","MCD","NKE","SBUX","TGT","LOW","TJX","COST","DG","DLTR",
  # ── Consumer Staples ─────────────────────────────────────────
  "PG","KO","PEP","PM","MO","CL","GIS","KHC","HSY","CLX",
  # ── Industrials ──────────────────────────────────────────────
  "BA","GE","CAT","DE","MMM","HON","LMT","RTX","NOC","GD"
)

# ── Sector mapping for universe preview ──────────────────────
SECTOR_MAP <- list(
  "Technology"             = c("AAPL","MSFT","GOOGL","META","NVDA","AMZN","CRM","ADBE","INTC","ORCL","CSCO","IBM","QCOM","TXN","AMD","MU","AMAT","HPQ","ACN","PYPL"),
  "Financials"             = c("JPM","BAC","GS","MS","WFC","AXP","BLK","C","USB","PNC","SCHW","COF","STT","BK","PRU","MET","AFL","TRV","CB","AON"),
  "Healthcare"             = c("JNJ","UNH","PFE","ABBV","MRK","TMO","ABT","DHR","CVS","AMGN","MDT","ELV","CI","BSX","SYK","ISRG","HUM","VRTX","REGN","ZBH"),
  "Energy"                 = c("XOM","CVX","COP","SLB","EOG","MPC","PSX","VLO","OXY","HAL","DVN","MRO","WMB","KMI","BKR","CTRA","APA","NOV","OKE","TRGP"),
  "Consumer Discretionary" = c("HD","MCD","NKE","SBUX","TGT","LOW","TJX","COST","DG","DLTR"),
  "Consumer Staples"       = c("PG","KO","PEP","PM","MO","CL","GIS","KHC","HSY","CLX"),
  "Industrials"            = c("BA","GE","CAT","DE","MMM","HON","LMT","RTX","NOC","GD")
)

SECTOR_COLORS <- c(
  "Technology"="#6c63ff", "Financials"="#10b981", "Healthcare"="#3b82f6",
  "Energy"="#f59e0b",     "Consumer Discretionary"="#ec4899",
  "Consumer Staples"="#14b8a6", "Industrials"="#f97316"
)

cache <- new.env(parent = emptyenv())

safe_tq_get <- function(ticker, from, to) {
  key <- paste0(ticker, "_", from, "_", to)
  if (exists(key, envir = cache)) return(get(key, envir = cache))
  res <- tryCatch(tq_get(ticker, from=from, to=to, get="stock.prices"), error=function(e) NULL)
  if (!is.null(res)) assign(key, res, envir = cache)
  res
}

# ── DCF: anchored to P/E earnings yield, NOT market cap ──────
# Key fix: mktcap*4% always gives ~0% upside because mktcap = fair value.
# Using EPS/P/E creates real spread: cheap stocks (low P/E) → undervalued;
# expensive stocks (high P/E) → overvalued, as expected from DCF theory.
calc_dcf <- function(ticker, wacc, tgr) {
  tryCatch({
    px <- safe_tq_get(ticker, Sys.Date()-365*10, Sys.Date())
    if (is.null(px) || nrow(px)==0) return(NULL)
    price <- tail(px$close, 1)

    qval <- function(q, col) {
      v <- tryCatch(q[[col]], error=function(e) NA)
      if (is.null(v)||length(v)==0) return(NA_real_)
      suppressWarnings(as.numeric(v[1]))
    }

    q <- tryCatch(
      getQuote(ticker, what=yahooQF(c(
        "Market Capitalization","Shares Outstanding",
        "EPS (TTM)","P/E Ratio","EPS Forward","Forward P/E"
      ))), error=function(e) NULL)

    mktcap   <- if (!is.null(q)) qval(q,"Market Capitalization") else NA_real_
    shares_q <- if (!is.null(q)) qval(q,"Shares Outstanding")   else NA_real_
    eps_ttm  <- if (!is.null(q)) qval(q,"EPS (TTM)")            else NA_real_
    pe_r     <- if (!is.null(q)) qval(q,"P/E Ratio")            else NA_real_
    eps_fwd  <- if (!is.null(q)) qval(q,"EPS Forward")          else NA_real_
    fwd_pe   <- if (!is.null(q)) qval(q,"Forward P/E")          else NA_real_

    # Share count in raw units
    shares <- if (!is.na(shares_q) && shares_q > 1e5) shares_q
              else if (!is.na(mktcap) && mktcap>0) mktcap/price
              else 1e9

    mktcap_est <- if (!is.na(mktcap)&&mktcap>0) mktcap else price*shares

    # EPS: direct TTM → P/E implied → sector-median P/E=20 fallback
    eps_use <- if (!is.na(eps_ttm) && eps_ttm > 0) eps_ttm
               else if (!is.na(pe_r) && pe_r>0 && pe_r<200) price/pe_r
               else price/20

    # FCF anchored to earnings, not market cap → creates valuation spread
    fcf <- eps_use * shares * 0.70
    fcf <- max(fcf, mktcap_est * 0.005)

    # ── Growth Rate: three-tier priority ────────────────────────────────────
    # Tier 1: Direct EPS Forward field (most explicit)
    consensus_g <- if (!is.na(eps_ttm) && eps_ttm > 0 &&
                       !is.na(eps_fwd)  && eps_fwd  > eps_ttm) {
      min((eps_fwd/eps_ttm) - 1, 0.40)
    } else NA_real_

    # Tier 2: Forward P/E implied growth (price/fwdPE = forward EPS)
    # More reliably returned by Yahoo than "EPS Forward" field directly
    fwd_pe_g <- if (!is.na(eps_ttm) && eps_ttm > 0 &&
                    !is.na(fwd_pe)  && fwd_pe > 0 && fwd_pe < pe_r) {
      fwd_eps_implied <- price / fwd_pe
      min(max((fwd_eps_implied/eps_ttm) - 1, 0), 0.40)
    } else NA_real_

    # Use the best available growth estimate
    consensus_g <- if (!is.na(consensus_g) && consensus_g > 0.03) consensus_g
                   else if (!is.na(fwd_pe_g) && fwd_pe_g > 0.03) fwd_pe_g
                   else NA_real_

    # Tier 3: Historical price CAGR (noisiest — 2022 crashes hurt tech here)
    yrs    <- max(as.numeric(diff(range(px$date)))/365, 0.5)
    hist_g <- min(max((price/px$close[1])^(1/yrs)-1, 0.03), 0.25)

    # ── Sector-specific parameters ───────────────────────────────────────────
    # Tech: FCF margin > net income (Apple FCF ~$100B on ~$94B NI; MSFT similar)
    #       and lower systematic risk → 1% WACC discount vs global assumption.
    # Energy: capital-intensive, FCF well below earnings → 0.55 conversion.
    # Others: standard 0.70 EPS-to-FCF conversion.
    energy_tickers <- c("XOM","CVX","COP","SLB","EOG","MPC","PSX","VLO",
                        "OXY","HAL","DVN","MRO","WMB","KMI","BKR","CTRA",
                        "APA","NOV","OKE","TRGP")
    tech_tickers   <- c("AAPL","MSFT","GOOGL","META","NVDA","AMZN","CRM",
                        "ADBE","INTC","ORCL","CSCO","IBM","QCOM","TXN",
                        "AMD","MU","AMAT","HPQ","ACN","PYPL")

    is_tech   <- ticker %in% tech_tickers
    is_energy <- ticker %in% energy_tickers

    fcf_conv   <- if (is_tech) 0.85 else if (is_energy) 0.55 else 0.70
    eff_wacc   <- if (is_tech) max(wacc - 0.01, 0.055) else wacc
    sector_floor <- if (is_tech) 0.10 else 0.06

    # Rebuild FCF with sector-appropriate conversion
    fcf <- eps_use * shares * fcf_conv
    fcf <- max(fcf, mktcap_est * 0.005)

    base_g <- if (!is.na(consensus_g)) consensus_g
              else max(hist_g, sector_floor)

    g_vec <- base_g * c(1, 0.90, 0.80, 0.70, 0.60)

    pv_fcfs <- sum(vapply(seq_along(g_vec), function(i)
      fcf*prod(1+g_vec[1:i])/(1+eff_wacc)^i, numeric(1)))
    fcf5  <- fcf*prod(1+g_vec)
    pv_tv <- (fcf5*(1+tgr)/(eff_wacc-tgr))/(1+eff_wacc)^5

    ev     <- pv_fcfs + pv_tv
    eq_val <- ev * 0.90
    intrinsic <- max(eq_val/shares, 0.01)
    upside    <- round((intrinsic-price)/price*100, 1)

    list(ticker=ticker, current_price=round(price,2),
         enterprise_value=round(ev/1e9,2), equity_value=round(eq_val/1e9,2),
         intrinsic=round(intrinsic,2), upside=upside)
  }, error=function(e) NULL)
}

compute_profile <- function(age, income, occupation, risk_score, retire_age, dependents) {
  a <- ifelse(age<35, 3, ifelse(age<55, 2, 1))
  i <- ifelse(income>150000, 3, ifelse(income>75000, 2, 1))
  o <- switch(occupation, "Employed"=2, "Self-Employed"=3, "Retired"=1, "Student"=2, 2)
  # Time horizon score: longer runway = more aggressive
  yrs <- max(retire_age - age, 0)
  h   <- ifelse(yrs > 20, 3, ifelse(yrs > 10, 2, 1))
  # Dependents reduce risk capacity
  dep <- ifelse(dependents >= 3, -2, ifelse(dependents >= 1, -1, 0))
  t   <- a + i + o + h + risk_score + dep
  if (t >= 20) "Aggressive" else if (t >= 13) "Moderate" else "Conservative"
}

compute_retirement <- function(age, retire_age, bal_401k, bal_ira, bal_brokerage,
                               monthly_contrib, retire_income, ss_monthly) {
  yrs          <- max(retire_age - age, 1)
  total_assets <- bal_401k + bal_ira + bal_brokerage
  ss_annual    <- ss_monthly * 12
  net_needed   <- max(retire_income - ss_annual, 0)
  corpus_needed <- net_needed / 0.04   # 4% safe withdrawal rule
  annual_contrib <- monthly_contrib * 12

  # Projected FV at generic 7% (used only for Phase 1 preview)
  r7 <- 0.07
  proj_fv <- total_assets * (1+r7)^yrs +
             annual_contrib * ((1+r7)^yrs - 1) / r7

  gap <- corpus_needed - proj_fv

  # Required annual return to hit corpus: solve FV equation numerically
  req_r <- tryCatch({
    if (corpus_needed <= 0) 0
    else {
      f <- function(r) {
        if (abs(r) < 1e-8) total_assets + annual_contrib * yrs
        else total_assets*(1+r)^yrs + annual_contrib*((1+r)^yrs-1)/r
      }
      uniroot(function(r) f(r) - corpus_needed, c(-0.05, 0.40),
              tol=1e-6)$root
    }
  }, error=function(e) 0.07)

  list(yrs=yrs, total_assets=total_assets, corpus_needed=corpus_needed,
       proj_fv=proj_fv, gap=gap, req_r=round(req_r*100, 2))
}

optimize_portfolio <- function(tickers, objective="Max Sharpe", max_weight=0.3) {
  prices <- lapply(tickers, function(t) safe_tq_get(t, Sys.Date()-365*10, Sys.Date()))
  valid  <- !sapply(prices, is.null)
  tickers <- tickers[valid]; prices <- prices[valid]
  if (length(tickers) < 2) return(NULL)

  pdf <- lapply(seq_along(tickers), function(i)
    prices[[i]] %>% select(date,close) %>% rename(!!tickers[i]:=close)) %>%
    Reduce(function(a,b) inner_join(a,b,by="date"), .)

  ret <- pdf %>% select(-date) %>%
    mutate(across(everything(),~log(.x/lag(.x)))) %>% na.omit()

  n   <- ncol(ret)
  Sg  <- cov(ret) * 252
  rf  <- 0.03
  erp <- 0.055

  # ── Compute betas ONCE; reuse for CAPM mu and display ──────────────────
  # Previously this data-join was done twice (for mu + for betas display),
  # doubling the most expensive part of the function.
  spy     <- safe_tq_get("SPY", Sys.Date()-365*10, Sys.Date())
  betas   <- rep(1.0, n)
  names(betas) <- tickers

  if (!is.null(spy) && nrow(spy) > 50) {
    spy_log <- spy %>%
      select(date, close) %>%
      mutate(mkt = log(close/lag(close))) %>%
      na.omit() %>% select(date, mkt)

    pdf_log <- pdf %>%
      mutate(across(-date, ~log(.x/lag(.x)))) %>% na.omit()

    joined  <- inner_join(pdf_log, spy_log, by="date")
    mkt_v   <- joined$mkt
    var_mkt <- var(mkt_v)

    betas <- vapply(tickers, function(tk) {
      b <- cov(joined[[tk]], mkt_v) / var_mkt
      round(min(max(b, 0.1), 3.0), 2)
    }, numeric(1))
  }

  # Historical annualized expected returns based on the 10-year lookback
  raw_mu <- exp(colMeans(ret) * 252) - 1
  # Cap extreme outliers (e.g., NVDA at 60%+) to prevent optimizer instability, and floor at 2%
  mu <- pmin(pmax(raw_mu, 0.02), 0.40)

  # ── Optimisation ────────────────────────────────────────────────────────
  w <- tryCatch({
    if (objective == "Min Variance") {
      solve.QP(2*Sg, rep(0,n),
               cbind(rep(1,n), diag(n), -diag(n)),
               c(1, rep(0,n), rep(-max_weight,n)), meq=1)$solution
    } else {
      # Max Sharpe via Monte Carlo — 250 iterations (was 600)
      bw <- rep(1/n, n); bs <- -Inf
      for (k in 1:250) {
        wr <- runif(n)
        wr <- pmin(wr/sum(wr), max_weight)
        wr <- wr / sum(wr)
        sr <- (sum(wr*mu) - rf) / sqrt(t(wr) %*% Sg %*% wr)
        if (sr > bs) { bs <- sr; bw <- wr }
      }
      bw
    }
  }, error=function(e) rep(1/n, n))

  pr <- sum(w*mu)
  pk <- sqrt(t(w) %*% Sg %*% w)[1,1]

  # Efficient frontier cloud — 120 simulations (was 300)
  ef <- do.call(rbind, lapply(1:120, function(k) {
    wr <- runif(n); wr <- pmin(wr/sum(wr), max_weight); wr <- wr/sum(wr)
    data.frame(Risk   = sqrt(t(wr) %*% Sg %*% wr)[1,1] * 100,
               Return = sum(wr*mu) * 100)
  }))

  list(weights   = round(w, 4),
       tickers   = tickers,
       betas     = betas,
       port_ret  = round(pr*100, 2),
       port_risk = round(pk*100, 2),
       sharpe    = round((pr-rf)/pk, 2),
       port_beta = round(sum(w*betas), 2),
       frontier  = ef)
}

# ── UI ────────────────────────────────────────────────────────

ui <- dashboardPage(skin="black",
  dashboardHeader(title=span("💎 NovaWealth Dynamics",style="font-weight:700")),
  dashboardSidebar(
    sidebarMenu(id="tabs",
      menuItem("Phase 1 · Onboarding",   tabName="onboarding", icon=icon("user")),
      menuItem("Phase 2 · DCF Screener", tabName="screener",   icon=icon("chart-line")),
      menuItem("Phase 3 · Optimizer",    tabName="optimizer",  icon=icon("sliders"))
    ), hr(),
    div(style="padding:8px 16px;color:#aaa;font-size:11px;","Global assumptions:"),
    sliderInput("wacc","WACC (%)",     min=5, max=20,value=8,  step=0.5, post="%"),
    sliderInput("tgr", "Terminal Growth (%)",min=1,max=5,value=2.5,step=0.25,post="%"),
    sliderInput("mos", "Margin of Safety (%)",min=-30,max=50,value=5,step=5,post="%"),
    uiOutput("mos_hint")
  ),
  dashboardBody(useShinyjs(),
    tags$head(tags$style(HTML("
      body,.wrapper{background:#0d0f14!important}
      .content-wrapper,.main-sidebar{background:#13161e!important}
      .box{background:#1a1d27;border-top-color:#6c63ff;color:#e0e0e0}
      .box-title{color:#e0e0e0} h4{color:#a78bfa}
      .skin-black .main-header .navbar{background:#6c63ff!important}
      .skin-black .main-header .logo{background:#5b52e0!important}
      .value-box .inner p{font-size:22px!important}
    "))),
    tabItems(
      tabItem("onboarding",
        fluidRow(
          # ── Left: Personal Info ─────────────────────────────────────────────
          box(width=6, title="👤 Personal Information", solidHeader=TRUE, status="primary",
            fluidRow(
              column(6, numericInput("age",   "Current Age",  35, 18, 90)),
              column(6, numericInput("income","Annual Income ($)", 100000, 0))
            ),
            selectInput("occupation","Occupation",
                        c("Employed","Self-Employed","Retired","Student")),
            sliderInput("risk_score","Self-Reported Risk Tolerance (1 = Very Conservative, 10 = Very Aggressive)",
                        1, 10, 5),
            numericInput("dependents","Number of Dependents", 0, 0, 20)
          ),
          # ── Right: Retirement Timeline ─────────────────────────────────────
          box(width=6, title="📅 Retirement Timeline & Goal", solidHeader=TRUE, status="warning",
            sliderInput("retire_age","Target Retirement Age", 50, 80, 65),
            selectInput("invest_goal","Primary Investment Goal",
                        c("Retirement","Wealth Building","Income Generation","Education Fund")),
            numericInput("retire_income","Desired Annual Retirement Income ($)", 80000, 0),
            numericInput("ss_monthly",  "Expected Social Security ($/month)",   1500,  0)
          )
        ),
        fluidRow(
          # ── Left: Wealth Snapshot ────────────────────────────────────────────
          box(width=6, title="💰 Current Wealth Snapshot", solidHeader=TRUE, status="info",
            numericInput("bal_401k",    "401(k) / 403(b) Balance ($)",  50000, 0),
            numericInput("bal_ira",     "IRA / Roth IRA Balance ($)",   20000, 0),
            numericInput("bal_brokerage","Taxable Brokerage Balance ($)",10000, 0),
            numericInput("monthly_contrib","Monthly Investment Contribution ($)", 500, 0),
            br(),
            actionButton("go_phase2","Proceed to Phase 2 → DCF Screener",
                         class="btn-primary btn-lg", width="100%")
          ),
          # ── Right: Retirement Dashboard ───────────────────────────────────
          box(width=6, title="📊 Your Retirement Dashboard", solidHeader=TRUE, status="success",
            uiOutput("retirement_dashboard")
          )
        )
      ),
      tabItem("screener",
        fluidRow(
          box(width=12, title="Universe Preview — Stocks by Sector",
              solidHeader=TRUE, collapsible=TRUE, collapsed=FALSE,
            uiOutput("universe_preview")
          )
        ),
        fluidRow(
          box(width=12,title="Run Screener & Add Custom Tickers",solidHeader=TRUE,
            uiOutput("phase2_hint"),
            textInput("custom_tickers","Add custom tickers (comma-separated)",placeholder="e.g. TSLA, NFLX"),
            actionButton("run_screener","Run DCF Screener",class="btn-warning btn-lg"),
            span(" Takes 3–4 minutes for 100 stocks.",style="color:#aaa")
          )
        ),
        fluidRow(box(width=12,title="DCF Valuation Results",solidHeader=TRUE, DTOutput("dcf_table"))),
        fluidRow(box(width=12,title="Stocks Passing Margin of Safety Filter",solidHeader=TRUE,status="success",
          verbatimTextOutput("passing_tickers"),
          actionButton("go_phase3","Send to Phase 3 Optimizer →",class="btn-success btn-lg")
        ))
      ),
      tabItem("optimizer", fluidRow(
        box(width=4,title="Optimizer Controls",solidHeader=TRUE,
          verbatimTextOutput("active_tickers_display"),
          selectInput("objective","Optimization Objective",c("Max Sharpe","Min Variance")),
          sliderInput("max_weight","Max Weight per Stock (%)",5,100,30,5,post="%"),
          actionButton("run_optimizer","Run Optimizer",class="btn-primary btn-lg",width="100%")
        ),
        box(width=8,title="Portfolio Results",solidHeader=TRUE,
          fluidRow(
            valueBoxOutput("vbox_ret",  width=3),
            valueBoxOutput("vbox_risk", width=3),
            valueBoxOutput("vbox_sr",   width=3),
            valueBoxOutput("vbox_beta", width=3)
          ),
          DTOutput("weights_table")
        )),
        fluidRow(
          box(width=6, title="Sector Allocation", solidHeader=TRUE,
            DTOutput("sector_table")
          ),
          box(width=6, title="Efficient Frontier", solidHeader=TRUE,
            plotOutput("frontier_plot", height="320px")
          )
        ),
        fluidRow(
          box(width=12, title="🎯 Retirement Projection", solidHeader=TRUE, status="success",
            plotOutput("retirement_plot", height="340px")
          )
        )
      )
    )
  )
)

# ── SERVER ────────────────────────────────────────────────────
server <- function(input, output, session) {

  profile <- reactive(
    compute_profile(input$age, input$income, input$occupation, input$risk_score,
                    input$retire_age, input$dependents)
  )

  ret_metrics <- reactive(
    compute_retirement(input$age, input$retire_age,
                       input$bal_401k, input$bal_ira, input$bal_brokerage,
                       input$monthly_contrib, input$retire_income, input$ss_monthly)
  )

  obj_from_profile <- reactive({
    m <- ret_metrics()
    # Required return drives objective: high need = Max Sharpe, low = Min Variance
    if (m$req_r > 9) "Max Sharpe"
    else if (m$req_r <= 7) "Min Variance"
    else switch(profile(), "Aggressive"="Max Sharpe", "Moderate"="Max Sharpe",
                "Conservative"="Min Variance", "Max Sharpe")
  })

  output$profile_output   <- renderText(profile())
  output$objective_output <- renderText(paste0(obj_from_profile(),
    " (Required return: ", ret_metrics()$req_r, "%)" ))
  observeEvent(profile(), updateSelectInput(session,"objective",selected=obj_from_profile()))

  output$mos_hint <- renderUI({
    yrs <- ret_metrics()$yrs
    suggested_mos <- if (yrs > 20) -10 else if (yrs > 10) 0 else 15
    HTML(paste0(
      "<div style='padding:4px 16px 8px;color:#888;font-size:10px;line-height:1.3;'>",
      "Negative MoS = accept stocks trading above DCF fair value.<br><br>",
      "<span style='color:#f59e0b;font-weight:bold;'>💡 Recommendation:</span> ",
      "Based on your horizon (", yrs, " yrs), a Margin of Safety around <b>", suggested_mos, "%</b> is suggested.",
      "</div>"
    ))
  })

  output$phase2_hint <- renderUI({
    if (input$invest_goal == "Income Generation") {
      tags$div(style="margin-bottom:15px; padding:10px; background-color:#1a1d27; border-left:4px solid #f59e0b; color:#e0e0e0;",
               icon("lightbulb", style="color:#f59e0b; margin-right:5px;"),
               "For an Income Generation goal, consider adding dividend-paying staples like ",
               tags$b("PG, KO, JNJ"), " to your custom tickers.")
    } else {
      NULL
    }
  })

  observeEvent(input$go_phase2, {
    updateTabItems(session, "tabs", "screener")
  })

  # ── Retirement Dashboard (Phase 1 output panel) ─────────────────────────
  output$retirement_dashboard <- renderUI({
    m  <- ret_metrics()
    fmt <- function(x) paste0("$", format(round(x), big.mark=","))
    gap_color <- if (m$gap > 0) "#ef4444" else "#10b981"
    gap_label <- if (m$gap > 0)
      paste0("Gap: ", fmt(m$gap), " shortfall")
    else
      paste0("Surplus: ", fmt(abs(m$gap)))

    metric <- function(label, value, color="#e0e0e0") {
      tags$div(style="margin-bottom:10px;",
        tags$div(style="color:#888;font-size:11px;text-transform:uppercase;letter-spacing:1px;", label),
        tags$div(style=paste0("color:",color,";font-size:20px;font-weight:700;"), value)
      )
    }
    tags$div(style="padding:8px;",
      metric("Years to Retirement", paste0(m$yrs, " years")),
      metric("Total Current Assets", fmt(m$total_assets), "#a78bfa"),
      metric("Required Corpus (4% Rule)", fmt(m$corpus_needed), "#f59e0b"),
      metric("Projected Portfolio @ 7%", fmt(m$proj_fv), "#3b82f6"),
      metric("Retirement Gap / Surplus", gap_label, gap_color),
      metric("Required Annual Return", paste0(m$req_r, "%"),
             if (m$req_r > 10) "#ef4444" else if (m$req_r > 8) "#f59e0b" else "#10b981"),
      tags$hr(style="border-color:#2a2d3a;"),
      tags$div(style="color:#888;font-size:11px;margin-top:6px;",
        "Risk Profile: ", tags$strong(style="color:#a78bfa;", profile()),
        " | Strategy: ", tags$strong(style="color:#6c63ff;", obj_from_profile())
      )
    )
  })

  # Universe preview: sector-by-sector badge display
  output$universe_preview <- renderUI({
    all_t <- all_tickers()
    sector_rows <- lapply(names(SECTOR_MAP), function(sec) {
      tks <- SECTOR_MAP[[sec]]
      custom_extra <- setdiff(all_t, unlist(SECTOR_MAP))
      if (sec == names(SECTOR_MAP)[length(SECTOR_MAP)] && length(custom_extra) > 0)
        tks <- c(tks, custom_extra)
      col <- SECTOR_COLORS[[sec]]
      badges <- lapply(tks, function(t)
        tags$span(t, style=paste0(
          "display:inline-block;margin:3px;padding:3px 8px;border-radius:12px;",
          "font-size:11px;font-weight:600;background:",col,"22;",
          "color:",col,";border:1px solid ",col,"55;"
        ))
      )
      tags$div(
        tags$div(style="color:#aaa;font-size:11px;margin:8px 0 4px;font-weight:700;",
          paste0(sec, " (", length(tks), " stocks)")),
        tags$div(badges)
      )
    })
    tags$div(
      tags$p(style="color:#888;font-size:12px;margin-bottom:8px;",
        paste(length(all_t), "stocks in universe. Add custom tickers below to expand.")),
      sector_rows
    )
  })

  dcf_results <- reactiveVal(NULL)

  all_tickers <- reactive({
    base <- DEFAULT_TICKERS
    custom <- if (nchar(trimws(input$custom_tickers))>0)
      toupper(trimws(strsplit(input$custom_tickers,",")[[1]])) else character(0)
    unique(c(base,custom))
  })

  observeEvent(input$run_screener, {
    tickers <- all_tickers()
    wv <- input$wacc/100; tv <- input$tgr/100
    withProgress(message="Running DCF valuation…",value=0,{
      res <- lapply(seq_along(tickers), function(i){
        incProgress(1/length(tickers), detail=tickers[i])
        calc_dcf(tickers[i], wv, tv)
      })
    })
    valid <- Filter(Negate(is.null), res)
    if (length(valid)==0) { dcf_results(NULL); return() }
    dcf_results(do.call(rbind, lapply(valid, as.data.frame)))
  })

  passing <- reactive({
    df <- dcf_results(); req(!is.null(df), nrow(df)>0)
    df %>% filter(upside >= input$mos) %>% pull(ticker)
  })

  output$dcf_table <- renderDT({
    df <- dcf_results(); req(!is.null(df))
    df %>%
      mutate(pass=ifelse(upside>=input$mos,"\u2705","\u274c"),
             upside=paste0(upside,"%")) %>%
      rename(Ticker=ticker, Price=current_price, `EV ($B)`=enterprise_value,
             `Equity ($B)`=equity_value, Intrinsic=intrinsic, Upside=upside, Pass=pass) %>%
      datatable(options=list(pageLength=15,scrollX=TRUE),rownames=FALSE,class="table-dark compact")
  })

  output$passing_tickers <- renderText({
    p <- tryCatch(passing(), error=function(e) character(0))
    if (length(p)==0) "No stocks pass. Try lowering the Margin of Safety slider."
    else paste(length(p),"stocks pass:", paste(p,collapse=", "))
  })

  observeEvent(input$go_phase3, {
    if (ret_metrics()$yrs < 10) {
      updateSliderInput(session, "max_weight", value=20)
    }
    updateTabItems(session,"tabs","optimizer")
  })

  opt_result <- reactiveVal(NULL)
  observe({
    p <- tryCatch(passing(), error=function(e) NULL)
    if (!is.null(p)&&length(p)>=2) updateSelectInput(session,"objective",selected=obj_from_profile())
  })

  output$active_tickers_display <- renderText({
    p <- tryCatch(passing(), error=function(e) character(0))
    if (length(p)==0) "No tickers from Phase 2 yet."
    else paste("Active:", paste(p,collapse=", "))
  })

  observeEvent(input$run_optimizer, {
    p <- tryCatch(passing(), error=function(e) NULL)
    req(!is.null(p), length(p)>=2)
    withProgress(message="Optimizing portfolio…",value=0.5,{
      result <- optimize_portfolio(p, input$objective, input$max_weight/100)
    })
    opt_result(result)
  })

  output$vbox_ret  <- renderValueBox({ r<-opt_result();req(!is.null(r)); valueBox(paste0(r$port_ret,"%"),"Expected Return",icon=icon("arrow-up"),color="green") })
  output$vbox_risk <- renderValueBox({ r<-opt_result();req(!is.null(r)); valueBox(paste0(r$port_risk,"%"),"Expected Risk",icon=icon("exclamation"),color="yellow") })
  output$vbox_sr   <- renderValueBox({ r<-opt_result();req(!is.null(r)); valueBox(r$sharpe,"Sharpe Ratio",icon=icon("star"),color="purple") })
  output$vbox_beta <- renderValueBox({ r<-opt_result();req(!is.null(r)); valueBox(r$port_beta,"Portfolio Beta",icon=icon("chart-bar"),color="blue") })

  output$weights_table <- renderDT({
    r <- opt_result(); req(!is.null(r))
    m <- ret_metrics()
    # Map each ticker to its sector
    sector_lookup <- function(tk) {
      for (sec in names(SECTOR_MAP)) if (tk %in% SECTOR_MAP[[sec]]) return(sec)
      "Other"
    }
    data.frame(
      Ticker = r$tickers,
      Sector = sapply(r$tickers, sector_lookup),
      Weight = paste0(round(r$weights*100,1),"%"),
      `Allocation` = paste0("$", format(round(m$total_assets * r$weights), big.mark=",")),
      Beta   = r$betas
    ) %>%
      arrange(desc(r$weights)) %>%
      datatable(rownames=FALSE, class="table-dark compact",
                options=list(pageLength=15, scrollX=TRUE))
  })

  output$sector_table <- renderDT({
    r <- opt_result(); req(!is.null(r))
    sector_lookup <- function(tk) {
      for (sec in names(SECTOR_MAP)) if (tk %in% SECTOR_MAP[[sec]]) return(sec)
      "Other"
    }
    sectors <- sapply(r$tickers, sector_lookup)
    df <- data.frame(ticker=r$tickers, sector=sectors, weight=r$weights, beta=r$betas) %>%
      group_by(sector) %>%
      summarise(
        Holdings = n(),
        `Weight (%)` = round(sum(weight)*100, 1),
        `Avg Beta`   = round(weighted.mean(beta, weight), 2),
        .groups = "drop"
      ) %>%
      arrange(desc(`Weight (%)`))
    datatable(df, rownames=FALSE, class="table-dark compact",
              options=list(pageLength=10, dom="t")) %>%
      formatStyle("Weight (%)",
        background = styleColorBar(range(df$`Weight (%)`), "#6c63ff44"),
        backgroundSize = "100% 80%", backgroundRepeat = "no-repeat",
        backgroundPosition = "center")
  })

  output$frontier_plot <- renderPlot({
    r <- opt_result(); req(!is.null(r))
    ggplot(r$frontier, aes(x=Risk,y=Return)) +
      geom_point(color="#6c63ff",alpha=0.4,size=2) +
      geom_point(aes(x=r$port_risk,y=r$port_ret),color="#f59e0b",size=6,shape=18) +
      annotate("text",x=r$port_risk,y=r$port_ret+0.5,label="Optimal Portfolio",color="#f59e0b",size=4,fontface="bold") +
      labs(title="Efficient Frontier",x="Risk (%)",y="Return (%)") +
      theme_minimal(base_size=13) +
      theme(plot.background=element_rect(fill="#1a1d27",color=NA),
            panel.background=element_rect(fill="#1a1d27",color=NA),
            text=element_text(color="#e0e0e0"), axis.text=element_text(color="#aaa"),
            panel.grid=element_line(color="#2a2d3a"))
  }, bg="#1a1d27")

  # ── Retirement Projection Chart (Phase 3) ─────────────────────────────────
  # Uses the optimizer's ACTUAL expected return (not the generic 7% from Phase 1)
  # to show a personalised compound growth trajectory vs. the client's corpus target.
  output$retirement_plot <- renderPlot({
    r <- opt_result(); req(!is.null(r))
    m <- ret_metrics()
    port_r <- r$port_ret / 100
    yrs    <- m$yrs
    assets <- m$total_assets
    annual_contrib <- input$monthly_contrib * 12

    # Year-by-year portfolio value using optimizer's actual return
    year_seq <- 0:yrs
    pv_seq   <- vapply(year_seq, function(y) {
      if (abs(port_r) < 1e-8) assets + annual_contrib * y
      else assets*(1+port_r)^y + annual_contrib*((1+port_r)^y - 1)/port_r
    }, numeric(1))

    df_proj <- data.frame(Year=year_seq + input$age, Value=pv_seq/1e6)
    target  <- m$corpus_needed / 1e6
    final   <- tail(pv_seq,1)
    on_track <- final >= m$corpus_needed
    status_label <- if (on_track)
      paste0("✅ On Track — Projected: $", format(round(final/1e6,1),nsmall=1), "M vs. Target: $",
             round(target,1), "M")
    else
      paste0("⚠️ Gap: $", format(round((m$corpus_needed-final)/1e6,1),nsmall=1),
             "M — Projected: $", format(round(final/1e6,1),nsmall=1),
             "M vs. Target: $", round(target,1), "M")

    ggplot(df_proj, aes(x=Year, y=Value)) +
      geom_area(fill="#6c63ff", alpha=0.15) +
      geom_line(color="#6c63ff", linewidth=1.5) +
      geom_hline(yintercept=target, linetype="dashed",
                 color=if (on_track) "#10b981" else "#ef4444", linewidth=1) +
      annotate("text", x=min(df_proj$Year)+1, y=target*1.06,
               label=paste0("Target Corpus: $", round(target,1), "M"),
               color=if (on_track) "#10b981" else "#ef4444",
               size=3.5, hjust=0, fontface="bold") +
      geom_point(data=tail(df_proj,1), aes(x=Year,y=Value),
                 color="#f59e0b", size=5, shape=18) +
      labs(
        title=paste0("Portfolio Growth Trajectory at ", r$port_ret, "% Expected Annual Return"),
        subtitle=status_label,
        x="Age", y="Portfolio Value ($M)"
      ) +
      scale_y_continuous(labels=function(x) paste0("$",x,"M")) +
      theme_minimal(base_size=13) +
      theme(
        plot.background  = element_rect(fill="#1a1d27", color=NA),
        panel.background = element_rect(fill="#1a1d27", color=NA),
        text             = element_text(color="#e0e0e0"),
        axis.text        = element_text(color="#aaa"),
        panel.grid       = element_line(color="#2a2d3a"),
        plot.title       = element_text(color="#a78bfa", face="bold"),
        plot.subtitle    = element_text(color=if (on_track) "#10b981" else "#f59e0b", size=11)
      )
  }, bg="#1a1d27")
}

shinyApp(ui, server)
