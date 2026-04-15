# 📖 AdaptiveQuantGrid (AQG) — User Manual

> Version: 1.24 | Platform: MetaTrader 5 | Language: MQL5

---

## 📋 Table of Contents

1. [Introduction](#1-introduction)
2. [System Architecture](#2-system-architecture)
3. [Installation](#3-installation)
4. [Trading Modes](#4-trading-modes)
5. [Detailed Parameter Reference](#5-detailed-parameter-reference)
6. [How the EA Works](#6-how-the-ea-works)
7. [Risk Management](#7-risk-management)
8. [State Recovery System](#8-state-recovery-system)
9. [Information Panel](#9-information-panel)
10. [Logging](#10-logging)
11. [Recommended Settings](#11-recommended-settings)
12. [Frequently Asked Questions](#12-frequently-asked-questions)
13. [Disclaimer](#13-disclaimer)

---

## 1. Introduction

**AdaptiveQuantGrid (AQG)** is a professional adaptive grid trading system for MetaTrader 5.

### Key Features

| Feature | Description |
|---------|-------------|
| 🔄 **Adaptive Grid** | Grid step automatically adjusts to volatility via ATR |
| 🧭 **Market Regime Filter** | ADX + EMA detect: ranging, uptrend, or downtrend |
| 🛡️ **Multi-Level Risk** | Drawdown, grid depth, risk profile, margin control |
| 🔥 **Smart Overlap** | Automatic profitable pair closure (best Buy + worst Sell) |
| 📈 **Equity Trailing** | Basket profit trailing with peak fixation |
| 💾 **Recovery System** | State restoration after terminal restart |
| 🔄 **Smart Order Trail** | Automatic grid relocation on price deviation |
| 📊 **UI Panel** | Real-time informational panel on chart |

---

## 2. System Architecture

The EA is built on a modular architecture. Each module handles a specific subsystem:

```
AdaptiveQuantGrid.mq5  (Main Controller)
├── Config.mqh          — Configuration, enums, input parameters
├── Logger.mqh          — Logging with levels and throttling
├── TradeExecutor.mqh   — Order execution via CTrade
├── RiskGuardian.mqh    — Risk management
├── GridCalculator.mqh  — Grid levels, ATR step, order placement
├── RegimeDetector.mqh  — Market regime detection (ADX + EMA)
├── GridDirectionEngine.mqh — Directional logic (MODE_LEGACY)
├── RecoveryManager.mqh — State recovery after restart
├── OverlapEngine.mqh   — Smart overlap optimization
├── EquityTrailer.mqh   — Basket equity trailing
└── UI_Panel.mqh        — Information panel on chart
```

### EA Lifecycle

```
[OnInit] → Validate Environment → Initialize Modules → Scan Positions
     ↓
  [STATE_IDLE] → PlaceInitialOrders → [STATE_ACTIVE]
     ↓
  [OnTick] → Update Regime → Update Grid → Overlap → Trailing
     ↓
  [OnTradeTransaction] → Process Deals → DirectionEngine (LEGACY)
     ↓
  [OnDeinit] → Save State → Clean Panel
```

---

## 3. Installation

### Method 1: From Source

1. Open **MetaEditor** (F4 in terminal)
2. Copy files to: `MQL5/Experts/AdaptiveQuantGrid/`
3. Open `AdaptiveQuantGrid.mq5` and press **F7** (Compile)
4. `AdaptiveQuantGrid.ex5` will appear in `MQL5/Experts/`

### Method 2: Pre-compiled File

1. Copy `AdaptiveQuantGrid.ex5` to: `MQL5/Experts/`
2. Restart MetaTrader 5

### Launching on Chart

1. Open desired symbol and timeframe
2. Drag `AdaptiveQuantGrid` from Navigator onto chart
3. Configure parameters → **Inputs** tab
4. Click **OK**

---

## 4. Trading Modes

### 4.1 MODE_SYMMETRIC — Symmetric Grid

**How it works:**
- Places **both** Buy Limit and Sell Limit at each level
- Non-directional — grid works in both directions
- Suitable for **ranging** markets

**Diagram:**
```
Price:                    ────────────────── Anchor
                          │
Level +1:                 ├──── Sell Limit
                          │
Level +2:                 ├──── Sell Limit
                          │
Level -1:                 ├──── Buy Limit
                          │
Level -2:                 ├──── Buy Limit
```

### 4.2 MODE_LEGACY — Asymmetric Directional

**How it works:**
- On start: **Market Buy + Market Sell + Buy Limit**
- On **downward** move (Buy Limit triggers):
  - Closes current Market Sell
  - Opens new Market Sell at current level
  - Places Buy Limit at next level
- On **upward** move (Market Sell SL triggers):
  - Partially closes best Buy
  - Opens new Market Sell
  - Places smaller Buy Limit

**Diagram:**
```
Anchor: ──────────────────────────────
                              Market Buy (base)
                              Market Sell (base, with SL)
                              Buy Limit (level 1)
                                           │
                              On trigger ↓
                                           │
                              Market Sell closes
                              New Market Sell lower
                              Buy Limit at level 2
```

---

## 5. Detailed Parameter Reference

### 5.1 🎯 Core Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpGridMode` | ENUM_AQG_GRID_MODE | MODE_LEGACY | **Trading mode:** `MODE_SYMMETRIC` — symmetric grid, `MODE_LEGACY` — asymmetric directional |
| `InpGridAnchorOffset` | double | 0.0 | **Anchor offset** in points. If > 0, anchor is shifted from current price |
| `InpATRPeriod` | int | 14 | **ATR period** (Average True Range). Used for dynamic grid step calculation. Larger → smoother response |
| `InpATRTF` | ENUM_TIMEFRAMES | PERIOD_H1 | **ATR timeframe**. H1 recommended for intraday, H4 for swing trading |
| `InpATRMultiplier` | double | 1.4 | **ATR multiplier**. Grid step = ATR × multiplier. Larger → wider step → fewer triggers |
| `InpMinStepPoints` | double | 150.0 | **Minimum step** in points. Lower bound for dynamic step. Protection against too-frequent grid |
| `InpMaxStepPoints` | double | 350.0 | **Maximum step** in points. Upper bound. Protection against too-sparse grid |
| `InpMaxGridDepth` | int | 10 | **Maximum grid depth** (number of levels). No new levels added when reached |

### 5.2 📦 Lot Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseAsymmetricLots` | bool | true | **Asymmetric lots**. If true, Buy and Sell use different base volumes (MODE_LEGACY only) |
| `InpBuyBaseLot` | double | 0.03 | **Base Buy lot**. Volume for Buy positions and Buy Limit orders |
| `InpSellBaseLot` | double | 0.01 | **Base Sell lot**. Volume for Market Sell in MODE_LEGACY |
| `InpPartialCloseLot` | double | 0.02 | **Partial close lot**. Volume for partial closure on upward moves in MODE_LEGACY |
| `InpSellSL_Points` | double | 250.0 | **Stop Loss for Market Sell** in points. Distance from open price to SL |
| `InpMinLotSize` | double | 0.01 | **Minimum lot**. Lower volume bound (usually 0.01) |
| `InpMaxLotSize` | double | 0.50 | **Maximum lot**. Upper volume bound (protection against excessive growth) |

### 5.3 🛡️ Risk Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpRiskProfile` | ENUM_AQG_RISK_PROFILE | PROFILE_BALANCED | **Risk profile:** `CONSERVATIVE` — conservative (×0.5 lot, 20% DD, 8 levels), `BALANCED` — balanced (×1.0, 40% DD, 10 levels), `AGGRESSIVE` — aggressive (×2.0, 60% DD, 14 levels) |
| `InpRiskPerTradePercent` | double | 0.35 | **Risk per trade** as % of balance. Multiplied by risk profile multiplier |
| `InpMaxEquityDrawdownPercent` | double | 20.0 | **Maximum equity drawdown** in %. Emergency stop triggered when reached |
| `InpUseDynamicLot` | bool | false | **Dynamic lot sizing**. If true, lot is calculated based on available margin (reserved for future) |

### 5.4 🧭 Market Regime Filter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseRegimeFilter` | bool | true | **Enable regime filter**. If true, EA detects market regime via ADX + EMA |
| `InpADXPeriod` | int | 14 | **ADX period**. Larger → smoother but slower reaction to volatility changes |
| `InpADXThreshold` | double | 25.0 | **ADX threshold**. If ADX < threshold → FLAT, if >= → TREND |
| `InpEMAPeriod` | int | 50 | **EMA period**. Used for trend direction (price > EMA → UP, price < EMA → DOWN) |
| `InpRegimeHysteresis` | int | 3 | **Hysteresis in bars**. Number of confirmation bars before regime switch. Protection against false toggles |

**How the filter works:**
```
ADX < 25  →  MODE_FLAT      →  Grid step × 0.7  (narrows)
ADX >= 25 + Price > EMA  →  MODE_TREND_UP    →  Grid step × 1.3  (widens)
ADX >= 25 + Price < EMA  →  MODE_TREND_DOWN  →  Grid step × 1.3  (widens)
```

### 5.5 💰 Cycle Exit Strategy

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseLegacyExit` | bool | true | **Classic profit exit**. If true, when `InpTargetProfit` is reached, all positions close and cycle restarts |
| `InpTargetProfit` | double | 60.0 | **Target profit** in dollars. All positions close when reached |
| `InpUseEquityTrailing` | bool | false | **Basket trailing**. If true, trailing with peak fixation is used instead of fixed target |
| `InpTrailingActivationProfit` | double | 45.0 | **Trailing activation profit** ($). Trailing enables only when this level is reached |
| `InpTrailingDropPercent` | double | 22.0 | **Drop threshold** (%). When drop from peak reaches this % → all positions close |
| `InpTrailingCheckSec` | int | 12 | **Check interval** in seconds. How often basket state is checked |

**Recommendation:** Use **either** `InpUseLegacyExit` **or** `InpUseEquityTrailing`, not both simultaneously. Trailing is better for trending markets, Legacy Exit for ranging.

### 5.6 🔥 Smart Overlap Engine

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseSmartOverlap` | bool | true | **Enable Overlap Engine**. If true, EA periodically searches for profitable position pairs |
| `InpOverlapProfitTarget` | double | 25.0 | **Overlap profit target** ($). Pair's total profit must be >= this value |
| `InpOverlapCooldownMin` | int | 5 | **Cooldown in minutes**. Minimum time between overlaps. Protection against frequent closures |

**How Overlap works:**
```
1. Collect: Best Buy, Worst Buy, Best Sell, Worst Sell
2. Try Pair #1: Best Buy + Worst Sell → Sum >= Target? → Close both
3. Try Pair #2: Best Sell + Worst Buy → Sum >= Target? → Close both
4. 5-minute cooldown before next search
```

### 5.7 🔄 Smart Order Relocation

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseSmartOrderTrail` | bool | true | **Enable relocation**. If true, grid automatically relocates on significant price deviation |
| `InpOrderTrailDistance` | double | 450.0 | **Trigger distance** in points. When price deviates from anchor by this distance → grid relocation |

**How Smart Trail works:**
```
1. |Price - Anchor| > 450 points?
2. Price NOT approaching nearest limits? (check 50% of Trigger Distance)
3. If YES → Delete all pending orders, Anchor = current price, step = 0
4. Next OnTick places new orders from new anchor
```

### 5.8 💾 State Recovery & Protection

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseNewsFilter` | bool | true | **News filter**. If true, EA checks for important news before trading (reserved) |
| `InpNewsFilterMinutes` | int | 30 | **News filter window** in minutes. Don't trade N minutes before/after important news |
| `InpSaveStateToFile` | bool | true | **Save state**. If true, state is saved to file on deinitialization |
| `InpStateFileName` | string | AQG_State.dat | **State file name**. File stored in `MQL5/Files/` |
| `InpEnablePushNotify` | bool | false | **Push notifications**. If true, notifications sent on emergency stop and cycle close |

### 5.9 📊 Interface & Debugging

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpShowPanel` | bool | true | **Show panel**. If true, informational panel displays on chart |
| `InpPanelBgColor` | color | clrDarkSlateGray | **Panel background color** |
| `InpPanelTextColor` | color | clrWhite | **Panel text color** |
| `InpPanelFontSize` | int | 9 | **Panel font size** |
| `InpDebugMode` | bool | false | **Debug mode**. If true, additional debug messages are printed |
| `InpLogLevel` | int | 2 | **Log level:** 0 — OFF, 1 — ERROR, 2 — INFO, 3 — DEBUG |

---

## 6. How the EA Works

### 6.1 Initialization (OnInit)

```
1. Calculate Magic Number (AQG_MAGIC_BASE + symbol)
2. Initialize Logger
3. Validate environment (connection, trading allowed)
4. Initialize all modules:
   ├── TradeExecutor
   ├── RiskGuardian (risk profile, drawdown check)
   ├── GridCalculator (ATR step, limits, anchor)
   ├── RegimeDetector (ADX, EMA)
   ├── RecoveryManager
   ├── OverlapEngine
   ├── EquityTrailer
   ├── DirectionEngine (MODE_LEGACY only)
   └── UI_Panel
5. Scan open positions:
   ├── Positions exist → STATE_ACTIVE, restore anchor
   └── No positions → STATE_IDLE, wait for OnTick to place
6. Load state from file (if InpSaveStateToFile = true)
```

### 6.2 OnTick Cycle

```
Every tick:
├── Emergency Stop check
├── Drawdown check (RiskGuardian)
├── Legacy Exit Check (every 60 seconds):
│   └── BasketProfit >= TargetProfit → Close all → STATE_IDLE → New cycle

Every 2 seconds:
├── STATE_IDLE? → PlaceInitialOrders → STATE_ACTIVE
├── Update market regime (RegimeDetector)
├── Calculate step multiplier (flat ×0.7, trend ×1.3)
├── Update grid (new levels)
├── Smart Order Trail (relocation on deviation)
├── Smart Overlap (search for profitable pairs)
└── Equity Trailing (if enabled and not Legacy Exit)
```

### 6.3 Trade Processing (OnTradeTransaction)

```
MODE_LEGACY only:
├── TRADE_TRANSACTION_DEAL_ADD
├── Check Magic, Symbol
├── DOWNWARD event (Buy Limit triggered):
│   ├── Increment step +1
│   ├── Close current Market Sell
│   ├── Open new Market Sell lower
│   └── Place Buy Limit at next level
└── UPWARD event (Market Sell SL triggered):
    ├── Decrement step -1
    ├── Partially close best Buy
    ├── Open new Market Sell
    └── Place smaller Buy Limit
```

---

## 7. Risk Management

### 7.1 Risk Profiles

| Profile | Lot Multiplier | Max Drawdown | Max Depth |
|---------|---------------|--------------|-----------|
| CONSERVATIVE | ×0.5 | 20% | 8 levels |
| BALANCED | ×1.0 | 40% | 10 levels |
| AGGRESSIVE | ×2.0 | 60% | 14 levels |

**Multiplier affects:**
- `InpRiskPerTradePercent` multiplied by multiplier
- Maximum allowed drawdown
- Maximum grid depth

### 7.2 Emergency Stop

Triggers when:
- Equity drawdown >= `InpMaxEquityDrawdownPercent`
- Terminal disconnected from server
- Trading disabled on account

**Actions:**
1. `STATE_EMERGENCY`
2. Close ALL positions with EA's Magic
3. Delete ALL pending orders
4. Push notification (if enabled)
5. EA stops trading until restart

### 7.3 Margin Control

Before each position opening:
```
1. Calculate required margin
2. Check free margin
3. If FreeMargin < Margin × 1.5 → Decline trade
```

### 7.4 Grid Depth Limit

```
Current step >= Max depth → New levels NOT added
Existing positions continue working
```

---

## 8. State Recovery System

### 8.1 State Saving

On deinitialization (`OnDeinit`) saves:
- Current market regime
- Grid state (STATE_IDLE / ACTIVE / etc.)
- Anchor price
- Magic Number

**File:** `AQG_State_<Symbol>_<Magic>.dat` in `MQL5/Files/`

### 8.2 Recovery

On initialization (`OnInit`):
```
1. Load from file (if InpSaveStateToFile = true)
2. If file not found → RecoveryManager:
   ├── Scan open positions
   ├── Scan pending orders
   ├── Reconstruct anchor price (average of BL_1 and SL_1)
   ├── Determine max step
   └── Validate (price not too far from current)
3. Sync step from real positions
4. If positions exist → STATE_ACTIVE
5. If no positions → STATE_IDLE
```

### 8.3 Recovery Validation

```
|Current price - Anchor| <= Step × InpMaxStepPoints × 1.5
```

If validation fails → Positions and orders close → EA restarts from scratch.

---

## 9. Information Panel

### 9.1 Panel Structure

```
╔══════════════════════════════╗
║       AQG PRO v1.07          ║
║ ──────────────────────────   ║
║ Regime:     FLAT             ║
║ Grid Step:  3 / 10           ║
║ ATR Dist:   185.3 pts        ║
║ ──────────────────────────   ║
║ Basket P/L: +$42.50          ║
║ Trailing:   Peak $48         ║
║ Last Overlap: +$25.00        ║
║ ──────────────────────────   ║
║ Drawdown:   3.2%             ║
║ Free Margin: $1,250.00       ║
║ Status:     ACTIVE           ║
╚══════════════════════════════╝
```

### 9.2 Color Coding

| Element | Color | Meaning |
|---------|-------|---------|
| Regime: FLAT | 🟢 Green | Ranging market |
| Regime: TREND ↑ | 🔵 Blue | Uptrend |
| Regime: TREND ↓ | 🟠 Orange | Downtrend |
| Grid Step >= 80% | 🔴 Red | Approaching limit |
| Basket P/L >= 0 | 🟢 Green | Profit |
| Basket P/L < 0 | 🔴 Red | Loss |
| Drawdown < 10% | 🟢 Green | Normal |
| Drawdown 10-15% | 🟠 Orange | Warning |
| Drawdown > 15% | 🔴 Red | Critical |
| Status: WAITING | 🟡 Yellow | Waiting |
| Status: EMERGENCY | 🔴 Red | Emergency stop |

---

## 10. Logging

### 10.1 Log Levels

| Level | Value | What's logged |
|-------|-------|---------------|
| 0 — OFF | Disabled | Nothing |
| 1 — ERROR | Errors | Errors only |
| 2 — INFO | Information | Errors + info messages |
| 3 — DEBUG | Debug | Everything + debug messages |

### 10.2 Color Coding in Journal

| Prefix | Meaning | Example |
|--------|---------|---------|
| 🔴 ERROR | Error | `🔴 ERROR: Market BUY failed \| Code: 10013` |
| 🟡 INFO | Information | `🟡 INFO: GridCalculator init \| Mode: LEGACY` |
| 🔵 DEBUG | Debug | `🔵 DEBUG: Skip relocation: Price approaching Buy Limit` |
| 🟢 SUCCESS | Success | `🟢 SUCCESS: Market SELL executed \| Vol: 0.01 @ 1.08450` |
| ⚠️ WARNING | Warning | `⚠️ WARNING: Max grid depth reached: 10/10` |

### 10.3 Throttling

Max **5 messages per second**. If more, subsequent messages are skipped.

---

## 11. Recommended Settings

### 11.1 For Ranging Markets (EURUSD H1)

```
InpGridMode           = MODE_SYMMETRIC
InpATRPeriod          = 14
InpATRTF              = PERIOD_H1
InpATRMultiplier      = 1.4
InpMinStepPoints      = 150.0
InpMaxStepPoints      = 350.0
InpMaxGridDepth       = 10
InpBuyBaseLot         = 0.03
InpSellBaseLot        = 0.03
InpRiskProfile        = PROFILE_BALANCED
InpUseRegimeFilter    = true
InpUseLegacyExit      = true
InpTargetProfit       = 60.0
InpUseSmartOverlap    = true
InpOverlapProfitTarget= 25.0
```

### 11.2 For Trending Markets (GBPUSD H1)

```
InpGridMode           = MODE_LEGACY
InpATRPeriod          = 14
InpATRTF              = PERIOD_H1
InpATRMultiplier      = 1.6
InpMinStepPoints      = 200.0
InpMaxStepPoints      = 400.0
InpMaxGridDepth       = 8
InpBuyBaseLot         = 0.03
InpSellBaseLot        = 0.01
InpSellSL_Points      = 300.0
InpRiskProfile        = PROFILE_CONSERVATIVE
InpUseRegimeFilter    = true
InpUseLegacyExit      = false
InpUseEquityTrailing  = true
InpTrailingActivationProfit = 45.0
InpTrailingDropPercent= 22.0
InpUseSmartOverlap    = true
InpOverlapProfitTarget= 25.0
```

### 11.3 Aggressive Profile (High Risk)

```
InpRiskProfile        = PROFILE_AGGRESSIVE
InpMaxGridDepth       = 14
InpBuyBaseLot         = 0.06
InpSellBaseLot        = 0.02
InpMaxEquityDrawdownPercent = 40.0
InpTargetProfit       = 120.0
```

---

## 12. Frequently Asked Questions

### Q: Why isn't the EA opening positions?

**A:** Possible reasons:
1. `STATE_IDLE` — no positions, EA waiting to place initial orders
2. `STATE_EMERGENCY` — emergency stop triggered (drawdown)
3. Insufficient free margin
4. Maximum grid depth reached
5. Market regime filter blocks direction (only FLAT, TREND_UP, TREND_DOWN)

### Q: How do I reset the EA's state?

**A:**
1. Delete file `AQG_State_<Symbol>_<Magic>.dat` from `MQL5/Files/`
2. Restart EA
3. Or close all positions manually → EA automatically resets to `STATE_IDLE`

### Q: Can I use it on multiple symbols?

**A:** Yes. Magic Number is auto-generated based on symbol, so instances don't overlap.

### Q: How does Smart Order Trail work?

**A:** If price deviates from anchor by `InpOrderTrailDistance` points and is **NOT approaching** nearest limits — all pending orders are deleted, anchor moves to current price, grid rebuilds.

### Q: What to do on Emergency Stop?

**A:**
1. Check equity drawdown in journal
2. Analyze causes (deep grid, strong trend)
3. Restart EA if needed (state will reset)
4. Consider reducing `InpMaxGridDepth` or changing risk profile

### Q: What's the difference between Legacy Exit and Equity Trailing?

**A:**
- **Legacy Exit** — fixed profit target ($). When reached — ALL positions close at once.
- **Equity Trailing** — dynamic exit. Fixes profit peak, closes on X% drop. Allows "catching" larger profit in trend.

### Q: Why isn't Overlap triggering?

**A:**
1. Cooldown hasn't elapsed (`InpOverlapCooldownMin`)
2. No pairs with total profit >= `InpOverlapProfitTarget`
3. Only one side present (only Buy or only Sell)

### Q: Can I run it on VPS?

**A:** Yes. Recommended:
- Enable `InpSaveStateToFile = true`
- Ensure stable server connection
- Configure terminal auto-start on VPS

---

## 13. Disclaimer

> ⚠️ **WARNING:** Trading on financial markets involves a high risk of losing capital. This Expert Advisor is provided **"AS IS"** without any profit guarantees.

- Past results do not guarantee future performance
- Always test on a demo account before using real funds
- Never risk capital you cannot afford to lose
- The developer is not responsible for any financial losses
- Use at your own risk

---

**Document Version:** 1.24
**Last Updated:** April 2026
**Author:** Vlladimir Kuzmin
**License:** MIT
