# 🤖 AdaptiveQuantGrid (AQG)

> **Professional Adaptive Grid Trading System for MetaTrader 5**

[![Version](https://img.shields.io/badge/version-1.24-blue.svg)](https://github.com/yourusername/AdaptiveQuantGrid/releases)
[![MT5](https://img.shields.io/badge/platform-MT5-orange.svg)](https://www.metatrader5.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Language](https://img.shields.io/badge/language-MQL5-lightgrey.svg)](https://www.mql5.com/)

---

## 📋 Overview

**AdaptiveQuantGrid (AQG)** is a professional-grade adaptive grid trading system built for MetaTrader 5. It features dynamic grid spacing based on market volatility, market regime detection, intelligent risk management, and advanced position overlap optimization.

### ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🔄 **Adaptive Grid** | Grid step automatically adjusts to volatility via ATR indicator |
| 🧭 **Market Regime Filter** | ADX + EMA detect: ranging, uptrend, or downtrend markets |
| 🛡️ **Multi-Level Risk Management** | Drawdown protection, grid depth limits, risk profiles, margin control |
| 🔥 **Smart Overlap Engine** | Automatic profitable pair closure (best Buy + worst Sell) |
| 📈 **Equity Trailing** | Basket profit trailing with peak fixation |
| 💾 **State Recovery** | Automatic state restoration after terminal restart |
| 🔄 **Smart Order Trail** | Automatic grid relocation on significant price deviation |
| 📊 **UI Panel** | Real-time informational panel on chart |

---

## 🚀 Quick Start

### Installation

1. **Copy files** to your MT5 terminal:
   ```
   MQL5/Experts/AdaptiveQuantGrid/
   ├── AdaptiveQuantGrid.mq5
   └── AQG/
       ├── Config.mqh
       ├── Logger.mqh
       ├── TradeExecutor.mqh
       ├── RiskGuardian.mqh
       ├── GridCalculator.mqh
       ├── RegimeDetector.mqh
       ├── GridDirectionEngine.mqh
       ├── RecoveryManager.mqh
       ├── OverlapEngine.mqh
       ├── EquityTrailer.mqh
       └── UI_Panel.mqh
   ```

2. **Compile** in MetaEditor (press `F7`) or use the pre-compiled `.ex5` file

3. **Attach** to a chart and configure parameters

4. **Start trading!**

### Default Configuration

The EA works out-of-the-box with default settings. Recommended starting parameters:

```
Grid Mode:          MODE_LEGACY
ATR Period:         14
ATR Multiplier:     1.4
Min Step:           150 points
Max Step:           350 points
Max Depth:          10 levels
Risk Profile:       BALANCED
Target Profit:      $60
```

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [📖 User Manual](MANUAL.md) | **Complete user guide with all parameters** (Russian) |
| [🏗️ Architecture](docs/ARCHITECTURE.md) | Technical architecture and module design |
| [📝 Changelog](CHANGELOG.md) | Version history and changes |

---

## 🎯 Trading Modes

### MODE_SYMMETRIC — Symmetric Grid

- Places **both** Buy Limit and Sell Limit at each level
- Non-directional — works in both directions
- Best for **ranging** markets

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

### MODE_LEGACY — Asymmetric Directional

- Initial: **Market Buy + Market Sell + Buy Limit**
- **Downward move** (Buy Limit triggers):
  - Closes current Market Sell
  - Opens new Market Sell lower
  - Places Buy Limit at next level
- **Upward move** (Market Sell SL triggers):
  - Partially closes best Buy
  - Opens new Market Sell
  - Places smaller Buy Limit

---

## ⚙️ Parameters

### Core Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpGridMode` | MODE_LEGACY | Trading mode: SYMMETRIC or LEGACY |
| `InpATRPeriod` | 14 | ATR period for dynamic step calculation |
| `InpATRTF` | PERIOD_H1 | ATR timeframe |
| `InpATRMultiplier` | 1.4 | ATR multiplier for grid step |
| `InpMinStepPoints` | 150.0 | Minimum grid step in points |
| `InpMaxStepPoints` | 350.0 | Maximum grid step in points |
| `InpMaxGridDepth` | 10 | Maximum grid levels |

### Lot Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseAsymmetricLots` | true | Use different lots for Buy/Sell (LEGACY mode) |
| `InpBuyBaseLot` | 0.03 | Base lot size for Buy positions |
| `InpSellBaseLot` | 0.01 | Base lot size for Sell positions |
| `InpPartialCloseLot` | 0.02 | Partial close lot size |
| `InpSellSL_Points` | 250.0 | Stop Loss for Market Sell (points) |

### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpRiskProfile` | PROFILE_BALANCED | Risk profile: CONSERVATIVE, BALANCED, AGGRESSIVE |
| `InpRiskPerTradePercent` | 0.35 | Risk per trade (% of balance) |
| `InpMaxEquityDrawdownPercent` | 20.0 | Maximum equity drawdown (%) |

### Market Regime Filter

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseRegimeFilter` | true | Enable market regime detection |
| `InpADXPeriod` | 14 | ADX period |
| `InpADXThreshold` | 25.0 | ADX threshold (below = FLAT, above = TREND) |
| `InpEMAPeriod` | 50 | EMA period for trend direction |
| `InpRegimeHysteresis` | 3 | Hysteresis bars before regime switch |

### Exit Strategy

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseLegacyExit` | true | Fixed profit target exit |
| `InpTargetProfit` | 60.0 | Target profit in dollars |
| `InpUseEquityTrailing` | false | Enable basket equity trailing |
| `InpTrailingActivationProfit` | 45.0 | Trailing activation profit ($) |
| `InpTrailingDropPercent` | 22.0 | Drop threshold (%) |

### Smart Overlap

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseSmartOverlap` | true | Enable overlap engine |
| `InpOverlapProfitTarget` | 25.0 | Target profit for overlap ($) |
| `InpOverlapCooldownMin` | 5 | Cooldown between overlaps (minutes) |

### Smart Order Trail

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpUseSmartOrderTrail` | true | Enable order relocation |
| `InpOrderTrailDistance` | 450.0 | Trigger distance for relocation (points) |

### State Recovery

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpSaveStateToFile` | true | Save state on shutdown |
| `InpEnablePushNotify` | false | Push notifications on emergency stop |

### Interface

| Parameter | Default | Description |
|-----------|---------|-------------|
| `InpShowPanel` | true | Display info panel on chart |
| `InpLogLevel` | 2 | Log level: 0=OFF, 1=ERROR, 2=INFO, 3=DEBUG |

---

## 🏗️ Architecture

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

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed technical documentation.

---

## 🛡️ Risk Warning

> ⚠️ **WARNING:** Trading on financial markets involves a high risk of losing capital. This Expert Advisor is provided **"AS IS"** without any profit guarantees.

- Past results do not guarantee future performance
- Always test on a demo account before using real funds
- Never risk capital you cannot afford to lose
- The developer is not responsible for any financial losses
- Use at your own risk

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to submit pull requests, report issues, or request features.

---

## 👤 Author

**Vlladimir Kuzmin**

---

## 📊 Version

**Current:** v1.24  
**Release Date:** April 2026
