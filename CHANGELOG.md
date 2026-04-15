# 📝 Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.24] — 2026-04-15

### 🎉 Initial Public Release

#### Added
- **Adaptive Grid System** with ATR-based dynamic step calculation
- **Market Regime Detection** using ADX + EMA with hysteresis
- **Two Trading Modes:**
  - `MODE_SYMMETRIC` — Bidirectional grid with Buy/Sell limits
  - `MODE_LEGACY` — Asymmetric directional trading with market orders
- **Multi-Level Risk Management:**
  - Equity drawdown protection with emergency stop
  - Grid depth limits
  - Risk profiles (Conservative, Balanced, Aggressive)
  - Margin control before order placement
- **Smart Overlap Engine:**
  - Automatic detection of profitable position pairs
  - Closes best Buy + worst Sell (or vice versa)
  - Configurable cooldown between overlaps
- **Equity Trailing:**
  - Basket profit tracking with peak fixation
  - Configurable activation profit and drop percentage
  - Alternative to fixed profit target exit
- **Smart Order Relocation:**
  - Automatic grid relocation on significant price deviation
  - Intelligent skip detection — doesn't relocate when price approaches limits
- **State Recovery System:**
  - Automatic state save on shutdown
  - Recovery from terminal positions/orders scan
  - Anchor price reconstruction
  - Validation before applying recovered state
- **Information Panel:**
  - Real-time display of market regime, grid step, P/L, drawdown
  - Color-coded status indicators
  - Configurable appearance
- **Comprehensive Logging:**
  - 4 log levels (OFF, ERROR, INFO, DEBUG)
  - Message throttling to prevent spam
  - Emoji-coded messages for easy reading

#### Fixed
- Grid step synchronization based on real positions (not orders)
- Protection against duplicate initial orders
- Correct state management on restart (positions → ACTIVE, no positions → IDLE)
- Safe price validation for order placement
- Order deletion using CTrade methods

#### Technical
- Modular architecture with 11 separate modules
- Clean separation of concerns
- Extensive inline documentation
- Emergency stop with push notifications

---

## [Unreleased]

### Planned
- News filter integration (currently reserved)
- Backtesting framework
- Performance statistics tracking
- Multi-symbol support enhancement
- Custom regime detection parameters per symbol

---

## Version History Summary

| Version | Release Date | Key Changes |
|---------|--------------|-------------|
| 1.24 | 2026-04-15 | Initial public release |

---

[1.24]: https://github.com/yourusername/AdaptiveQuantGrid/releases/tag/v1.24
