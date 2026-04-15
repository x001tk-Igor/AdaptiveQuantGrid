# 🏗️ Architecture Documentation

## System Overview

AdaptiveQuantGrid (AQG) is a modular Expert Advisor built for MetaTrader 5. It implements an adaptive grid trading strategy with intelligent market regime detection, dynamic risk management, and advanced position optimization.

---

## Module Structure

```
AdaptiveQuantGrid.mq5  (Main Controller)
├── Config.mqh          — Configuration, enums, input parameters
├── Logger.mqh          — Logging with levels and throttling
├── TradeExecutor.mqh   — Order execution via CTrade
├── RiskGuardian.mqh    — Risk management
├── GridCalculator.mqh  — Grid level calculation, ATR step, order placement
├── RegimeDetector.mqh  — Market regime detection (ADX + EMA)
├── GridDirectionEngine.mqh — Directional logic (MODE_LEGACY)
├── RecoveryManager.mqh — State recovery after restart
├── OverlapEngine.mqh   — Smart overlap optimization
├── EquityTrailer.mqh   — Basket equity trailing
└── UI_Panel.mqh        — Information panel on chart
```

---

## Module Details

### 1. Config.mqh

**Purpose:** Central configuration hub.

**Contents:**
- Magic number base (`AQG_MAGIC_BASE = 202401`)
- Enumerations:
  - `ENUM_AQG_GRID_MODE` — SYMMETRIC / LEGACY
  - `ENUM_AQG_MARKET_MODE` — UNKNOWN / FLAT / TREND_UP / TREND_DOWN
  - `ENUM_AQG_RISK_PROFILE` — CONSERVATIVE / BALANCED / AGGRESSIVE
  - `ENUM_AQG_GRID_STATE` — IDLE / ACTIVE / OVERLAPPING / TRAILING / EMERGENCY
- All `input` parameters grouped by category
- `CAQGConfig` helper class with static methods for lot/drawdown/depth calculations

**Key Constants:**
```mql5
#define AQG_MAGIC_BASE          202401
#define AQG_MAX_RETRIES         3
#define AQG_RETRY_DELAY_MS      500
#define AQG_MIN_TICKS_BETWEEN   1000
```

---

### 2. Logger.mqh

**Purpose:** Centralized logging with levels, colors, and throttling.

**Log Levels:**
| Level | Name | Description |
|-------|------|-------------|
| 0 | OFF | No logging |
| 1 | ERROR | Errors only |
| 2 | INFO | Errors + info |
| 3 | DEBUG | Everything + debug |

**Features:**
- Static methods: `Error()`, `Info()`, `Debug()`, `Success()`, `Warning()`
- Message throttling: max 5 messages per second
- Prefix: `[SYMBOL:TF]`
- Push notifications on critical events

**Macros:**
```mql5
#define AQG_LOG_ERROR(msg)    CAQGLogger::Error(msg, GetLastError())
#define AQG_LOG_INFO(msg)     CAQGLogger::Info(msg)
#define AQG_LOG_DEBUG(msg)    CAQGLogger::Debug(msg)
#define AQG_LOG_SUCCESS(msg)  CAQGLogger::Success(msg)
#define AQG_LOG_WARNING(msg)  CAQGLogger::Warning(msg)
```

---

### 3. TradeExecutor.mqh

**Purpose:** Safe order execution via `CTrade` wrapper.

**Methods:**
- `MarketBuy()`, `MarketSell()` — Market orders
- `BuyLimit()`, `SellLimit()` — Pending orders
- `ClosePosition()`, `ClosePartial()` — Position closure
- `DeleteOrder()`, `DeleteAllPendingOrders()`, `DeleteAllPendingOrdersForce()` — Order deletion
- `CloseAllPositions()` — Bulk closure

**Safety:**
- Margin check before execution
- Lot normalization (min/max/step)
- Deviation tolerance: 10 points

---

### 4. RiskGuardian.mqh

**Purpose:** Risk management and protection.

**Initialized with:** Risk profile (CONSERVATIVE / BALANCED / AGGRESSIVE)

**Profile Effects:**
| Profile | Lot Multiplier | Max Drawdown | Max Depth |
|---------|---------------|--------------|-----------|
| CONSERVATIVE | ×0.5 | 20% | 8 |
| BALANCED | ×1.0 | 40% | 10 |
| AGGRESSIVE | ×2.0 | 60% | 14 |

**Methods:**
- `CheckEquityDrawdown()` — Returns true if drawdown >= limit
- `CheckMaxGridDepth(step)` — Returns true if step >= max depth
- `UpdateState()` — Updates starting balance (high-water mark)

---

### 5. GridCalculator.mqh

**Purpose:** Core grid logic — levels, steps, order placement.

**Key Features:**
- **Dynamic Step Calculation:**
  ```
  step = (ATR / Point) × ATRMultiplier
  step = clamp(step, MinStepPoints, MaxStepPoints)
  ```
- **Level Price:**
  ```
  belowAnchor: anchor - (step × level × point)
  aboveAnchor: anchor + (step × level × point)
  ```
- **Price Safety:** Ensures orders are placed outside freeze/stops levels + 3 points buffer

**Smart Order Relocation:**
- Triggered when `|Price - Anchor| > TrailDistance`
- **Does NOT relocate** if price is approaching nearest limit (< 50% of trigger distance)
- Deletes all pending orders, resets anchor, allows new placement

**Initial Orders Placement:**
- `MODE_LEGACY`: Market Buy + Market Sell (with SL) + Buy Limit
- `MODE_SYMMETRIC`: Buy Limit + Sell Limit

**Protection:** `PlaceInitialOrders()` **BLOCKS** if positions with same Magic already exist.

---

### 6. RegimeDetector.mqh

**Purpose:** Market regime detection using ADX and EMA.

**Indicators:**
- ADX (H1, configurable period) — Measures trend strength
- EMA (H1, configurable period) — Measures trend direction

**Logic:**
```
if ADX < Threshold:
    regime = FLAT
else if Price > EMA:
    regime = TREND_UP
else:
    regime = TREND_DOWN
```

**Hysteresis:**
- Regime switches only after `HysteresisBars` consecutive confirmations
- Prevents false regime changes on noisy data

**Step Multipliers:**
- FLAT: `×0.7` — Narrows grid step (more frequent orders)
- TREND: `×1.3` — Widens grid step (less frequent orders)

**Direction Filters:**
- `IsBuyAllowed()`: FLAT or TREND_UP
- `IsSellAllowed()`: FLAT or TREND_DOWN

---

### 7. GridDirectionEngine.mqh

**Purpose:** Directional logic for `MODE_LEGACY`.

**Events (from OnTradeTransaction):**

**DOWNWARD (Buy Limit triggered):**
```
1. Increment step
2. Close largest Sell ticket (if exists)
3. Open new Market Sell below
4. Place Buy Limit at next level
```

**UPWARD (Market Sell SL triggered):**
```
1. Decrement step
2. Partially close best Buy position
3. Place small Buy Limit at current level
4. Open new Market Sell at current price
5. Cancel old Buy Limit at higher level
```

**Memory:** Stores last Market Sell price to enforce minimum step distance between consecutive sells.

---

### 8. RecoveryManager.mqh

**Purpose:** State recovery after terminal restart.

**Recovery Process:**
1. Scan positions and orders with EA's Magic
2. If none found → return false (clean start)
3. Reconstruct anchor price:
   - Average of `BL_1` and `SL_1` order prices (if both exist)
   - Otherwise use `BL_1` price
4. Find max existing step from order comments
5. Validate: `|CurrentPrice - Anchor| <= MaxStep × step × 1.5`
6. If validation fails → Close all → Reset
7. If validation passes → Set anchor, sync step, cleanup orphans

**Orphan Cleanup:**
- Deletes orders with EA's Magic but without `AQG_` prefix in comment

---

### 9. OverlapEngine.mqh

**Purpose:** Intelligent position pair closure for profit extraction.

**Algorithm:**
```
1. Check cooldown (seconds since last overlap)
2. Collect:
   - Best Buy (highest profit)
   - Worst Buy (lowest profit)
   - Best Sell (highest profit)
   - Worst Sell (lowest profit)
3. Try Pair #1: Best Buy + Worst Sell
   - If sum >= Target → Close both → Success
4. Try Pair #2: Best Sell + Worst Buy
   - If sum >= Target → Close both → Success
5. Return false if no pair qualified
```

**Profit Calculation:**
- Uses `POSITION_PROFIT` (includes swap + commission)

---

### 10. EquityTrailer.mqh

**Purpose:** Basket equity trailing stop.

**Lifecycle:**
```
Inactive → Check Interval → Has Positions? → Profit >= Activation?
    ↓
Active → Track Peak → Check Drop% → Drop >= Threshold?
    ↓
Close All → Reset → Back to Inactive
```

**Exit Conditions:**
- Profit turns negative
- Drop from peak >= `TrailingDropPercent`

**Check Interval:** Configurable (default 12 seconds)

---

### 11. UI_Panel.mqh

**Purpose:** Real-time informational panel on chart.

**Sections:**
1. **Header:** "AQG PRO v1.07"
2. **Mode & Grid:** Regime, Grid Step, ATR Distance
3. **Performance:** Basket P/L, Trailing status, Last Overlap
4. **Risk:** Drawdown %, Free Margin
5. **Status:** ACTIVE / WAITING / EMERGENCY

**Color Coding:**
- Green: Positive, safe
- Yellow: Warning, waiting
- Red: Negative, critical
- Blue/Orange: Trend direction

**Update Rate:** ~4 times per second (throttled)

---

## Data Flow

```
[OnInit]
   ↓
Validate Environment
   ↓
Initialize All Modules
   ↓
Scan Positions
   ├── Positions exist → STATE_ACTIVE, Recover Anchor
   └── No positions → STATE_IDLE
   ↓
[OnTick] (every tick)
   ├── Emergency Stop Check
   ├── Risk Update
   ├── Legacy Exit Check (every 60s)
   └── Heavy Calc (every 2s):
       ├── Place Initial Orders (if IDLE)
       ├── Regime Update
       ├── Grid Update (new levels)
       ├── Smart Order Trail
       ├── Overlap Process
       └── Equity Trailing
   ↓
[OnTradeTransaction]
   └── Direction Engine (LEGACY mode only)
   ↓
[OnDeinit]
   └── Save State to File
```

---

## State Machine

```
STATE_IDLE
   ↓ (PlaceInitialOrders success)
STATE_ACTIVE
   ↓ (Overlap triggered)
STATE_OVERLAPPING
   ↓ (Overlap complete)
STATE_ACTIVE
   ↓ (Trailing activated)
STATE_TRAILING
   ↓ (Trailing exit)
STATE_IDLE
   ↓ (Emergency Stop)
STATE_EMERGENCY
   ↓ (Manual restart required)
[STOPPED]
```

---

## Magic Number Generation

```mql5
Magic = AQG_MAGIC_BASE + Sum of first 4 chars of Symbol
Example: EURUSD = 202401 + 69 + 85 + 82 + 83 = 202720
```

This ensures unique Magic numbers per symbol when running multiple instances.

---

## Error Handling

### Emergency Stop Triggers
1. Equity drawdown >= `InpMaxEquityDrawdownPercent`
2. Terminal disconnected
3. Trading disabled on account

### Actions
- Close ALL positions with EA's Magic
- Delete ALL pending orders
- Send push notification (if enabled)
- Set `g_EmergencyStop = true`
- EA stops functioning until manual restart

### Recovery After Emergency
- Positions are already closed
- EA restarts from `STATE_IDLE`
- Previous state file is ignored (emergency flag)

---

## Design Principles

1. **Modularity:** Each module is self-contained with clear interface
2. **Safety First:** Multiple layers of protection (margin, drawdown, depth, price validation)
3. **State Consistency:** State is tied to REAL positions, not files
4. **Recovery:** Automatic state restoration with validation
5. **Adaptivity:** Grid adjusts to market conditions (ATR, Regime)
6. **Profit Optimization:** Overlap and trailing for maximum profit extraction
