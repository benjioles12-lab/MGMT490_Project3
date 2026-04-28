# 4 · DRIVER — Validate

## Testing Strategy

Validation covers three layers: **unit-level logic**, **reactive cascade integration**, and **edge-case robustness**.

---

## Test Suite

### TC-01 · Risk Profile Mapping (Unit)

**Purpose**: Verify `compute_profile()` correctly maps input combinations to risk profiles.

| Age | Income | Occupation | Risk Score | Expected Profile |
|---|---|---|---|---|
| 65 | 50,000 | Retired | 2 | Conservative |
| 28 | 120,000 | Employed | 8 | Aggressive |
| 45 | 85,000 | Self-Employed | 5 | Moderate |
| 22 | 30,000 | Student | 3 | Conservative |

**Test code:**
```r
stopifnot(compute_profile(65, 50000, "Retired",   2) == "Conservative")
stopifnot(compute_profile(28, 120000, "Employed", 8) == "Aggressive")
stopifnot(compute_profile(45, 85000, "Self-Employed", 5) == "Moderate")
```

**Pass Criteria**: All assertions pass without error.

---

### TC-02 · Objective Assignment from Profile (Integration)

**Purpose**: Confirm that `objective_from_profile()` correctly maps each profile to an optimization strategy.

| Profile | Expected Objective |
|---|---|
| Conservative | Min Variance |
| Moderate | Max Sharpe |
| Aggressive | Max Sharpe |

**Manual verification**: Set Phase 1 inputs to produce "Conservative" profile. Navigate to Phase 3. Confirm the Objective dropdown shows "Min Variance" before the user touches it.

---

### TC-03 · WACC Slider → Intrinsic Value Change (Integration)

**Purpose**: Confirm that increasing WACC lowers intrinsic values.

**Steps**:
1. Run Phase 2 screener with WACC = 8%, TGR = 2.5%.
2. Record intrinsic values in the DCF table.
3. Move WACC slider to 15%.
4. Re-run screener.
5. Confirm intrinsic values decreased for all stocks.

**Pass Criteria**: `intrinsic(WACC=15%) < intrinsic(WACC=8%)` for ≥ 90% of stocks in the universe.

---

### TC-04 · WACC Shift → Fewer Passing Stocks (Integration)

**Purpose**: Confirm that higher WACC causes fewer stocks to pass the Margin of Safety filter.

**Steps**:
1. Set MoS = 20%, run screener at WACC = 8%. Record `N₁ = |passing()|`.
2. Move WACC to 15%, re-run screener. Record `N₂ = |passing()|`.
3. Assert `N₂ ≤ N₁`.

**Pass Criteria**: Assertion holds, and `passing_tickers` output text updates automatically.

---

### TC-05 · End-to-End Cascade → Efficient Frontier Shift (Capstone)

**Purpose**: Confirm the full reactive pipeline works: WACC change → filter change → optimizer re-runs → Efficient Frontier shifts.

**Steps**:
1. Complete Phase 1 (any profile). Run Phase 2 at WACC=8%. Run Phase 3 optimizer.
2. Screenshot / note the Efficient Frontier position of the optimal portfolio point (yellow diamond).
3. Move WACC slider to 15%, re-run screener, re-run optimizer.
4. Confirm: (a) fewer stocks in active ticker list; (b) Efficient Frontier point has shifted position; (c) Expected Return and Risk values in value boxes changed.

**Pass Criteria**: All three sub-checks satisfied.

---

### TC-06 · Custom Ticker Passes MoS Hurdle (Integration)

**Purpose**: Confirm custom tickers are subject to the same DCF screening as default tickers.

**Steps**:
1. Enter "TSLA" in the custom tickers field.
2. Run screener at MoS = 50%.
3. Check whether TSLA appears in passing tickers.
4. Lower MoS to 0%. Confirm TSLA now passes.

**Pass Criteria**: TSLA is excluded at high MoS and included at MoS=0%.

---

### TC-07 · Optimizer Handles Small Universe (Edge Case)

**Purpose**: Confirm graceful handling when <2 stocks pass the filter.

**Steps**:
1. Set MoS = 50%, WACC = 18%. Run screener (expect 0–1 stocks passing).
2. Navigate to Phase 3. Click "Run Optimizer".
3. Confirm the app does not crash; instead shows "No tickers from Phase 2 yet" or an informative message.

**Pass Criteria**: App remains interactive with no R error dialog.

---

### TC-08 · Max Weight Constraint Respected (Unit)

**Purpose**: Confirm optimizer output weights honor the per-stock cap.

**Steps**:
1. Set Max Weight = 15%. Run optimizer.
2. Inspect weights table. Confirm no weight exceeds 15%.

**Pass Criteria**: `max(weights) ≤ 0.15`.

---

## Summary Matrix

| Test | Type | Component | Status |
|---|---|---|---|
| TC-01 | Unit | Phase 1 Logic | ✅ Manual |
| TC-02 | Integration | Phase 1 → Phase 3 | ✅ Manual |
| TC-03 | Integration | Phase 2 DCF | ✅ Manual |
| TC-04 | Integration | Phase 2 Filter | ✅ Manual |
| TC-05 | E2E Capstone | Full Pipeline | ✅ Manual |
| TC-06 | Integration | Custom Ticker | ✅ Manual |
| TC-07 | Edge Case | Phase 3 | ✅ Manual |
| TC-08 | Unit | Phase 3 Optimizer | ✅ Manual |
