//+------------------------------------------------------------------+
//|                                              AQG_Config.mqh      |
//|                                   Adaptive Quant Grid - Config   |
//|                                         Version: 1.09            |
//+------------------------------------------------------------------+
#property version   "1.09"
#property strict

#define AQG_MAGIC_BASE          202401
#define AQG_MAX_RETRIES         3
#define AQG_RETRY_DELAY_MS      500
#define AQG_MIN_TICKS_BETWEEN   1000

//+------------------------------------------------------------------+
//| 📊 Enumerations                                                   |
//+------------------------------------------------------------------+
enum ENUM_AQG_GRID_MODE
{
   MODE_SYMMETRIC = 0,  // Symmetric Grid (Bidirectional)
   MODE_LEGACY    = 1   // Asymmetric Directional (Legacy)
};

enum ENUM_AQG_MARKET_MODE
{
   MODE_UNKNOWN   = 0,  // Unknown / Initializing
   MODE_FLAT      = 1,  // Ranging Market
   MODE_TREND_UP  = 2,  // Uptrend
   MODE_TREND_DOWN= 3   // Downtrend
};

enum ENUM_AQG_RISK_PROFILE
{
   PROFILE_CONSERVATIVE = 0,  // Conservative
   PROFILE_BALANCED     = 1,  // Balanced
   PROFILE_AGGRESSIVE   = 2   // Aggressive
};

enum ENUM_AQG_GRID_STATE
{
   STATE_IDLE         = 0,  // Idle / Waiting
   STATE_ACTIVE       = 1,  // Active Trading
   STATE_OVERLAPPING  = 2,  // Executing Overlap
   STATE_TRAILING     = 3,  // Equity Trailing Active
   STATE_EMERGENCY    = 4   // Emergency Stop Triggered
};

//+------------------------------------------------------------------+
//| ⚙️ CORE SETTINGS                                                 |
//+------------------------------------------------------------------+
input group "=== 🎯 Core Settings ==="
input ENUM_AQG_GRID_MODE InpGridMode           = MODE_LEGACY;   // Trading Mode
input double   InpGridAnchorOffset             = 0.0;           // Anchor Offset (points)
input int      InpATRPeriod                    = 14;            // ATR Period
input ENUM_TIMEFRAMES InpATRTF                 = PERIOD_H1;     // ATR Timeframe
input double   InpATRMultiplier                = 1.4;           // ATR Multiplier
input double   InpMinStepPoints                = 150.0;         // Min Grid Step (points)
input double   InpMaxStepPoints                = 350.0;         // Max Grid Step (points)
input int      InpMaxGridDepth                 = 10;            // Max Grid Levels

//+------------------------------------------------------------------+
//| ⚙️ LOT MANAGEMENT                                                |
//+------------------------------------------------------------------+
input group "=== 📦 Lot Management ==="
input bool     InpUseAsymmetricLots            = true;          // Asymmetric Lots
input double   InpBuyBaseLot                   = 0.03;          // Base Buy Lot
input double   InpSellBaseLot                  = 0.01;          // Base Sell Lot
input double   InpPartialCloseLot              = 0.02;          // Partial Close Lot
input double   InpSellSL_Points                = 250.0;         // Market Sell SL (points)
input double   InpMinLotSize                   = 0.01;          // Minimum Lot
input double   InpMaxLotSize                   = 0.50;          // Maximum Lot

//+------------------------------------------------------------------+
//| ⚙️ RISK MANAGEMENT                                               |
//+------------------------------------------------------------------+
input group "=== 🛡️ Risk Management ==="
input ENUM_AQG_RISK_PROFILE InpRiskProfile     = PROFILE_BALANCED; // Risk Profile
input double   InpRiskPerTradePercent          = 0.35;          // Risk Per Trade (%)
input double   InpMaxEquityDrawdownPercent     = 20.0;          // Max Drawdown (%)
input bool     InpUseDynamicLot                = false;         // Dynamic Lot Sizing

//+------------------------------------------------------------------+
//| ⚙️ MARKET REGIME FILTER                                          |
//+------------------------------------------------------------------+
input group "=== 🧭 Market Regime Filter ==="
input bool     InpUseRegimeFilter              = true;          // Enable Regime Filter
input int      InpADXPeriod                    = 14;            // ADX Period
input double   InpADXThreshold                 = 25.0;          // ADX Threshold
input int      InpEMAPeriod                    = 50;            // EMA Period
input int      InpRegimeHysteresis             = 3;             // Hysteresis (bars)

//+------------------------------------------------------------------+
//| ⚙️ CYCLE EXIT STRATEGY                                           |
//+------------------------------------------------------------------+
input group "=== 💰 Cycle Exit Strategy ==="
input bool     InpUseLegacyExit                = true;          // Enable Profit Exit
input double   InpTargetProfit                 = 60.0;          // Profit Target ($)
input bool     InpUseEquityTrailing            = false;         // Enable Trailing
input double   InpTrailingActivationProfit     = 45.0;          // Activation Profit ($)
input double   InpTrailingDropPercent          = 22.0;          // Drop Threshold (%)
input int      InpTrailingCheckSec             = 12;            // Check Interval (sec)

//+------------------------------------------------------------------+
//| ⚙️ SMART OVERLAP ENGINE                                          |
//+------------------------------------------------------------------+
input group "=== 🔥 Smart Overlap Engine ==="
input bool     InpUseSmartOverlap              = true;          // Enable Overlap
input double   InpOverlapProfitTarget          = 25.0;          // Target Profit ($)
input int      InpOverlapCooldownMin           = 5;             // Cooldown (minutes)

//+------------------------------------------------------------------+
//| ⚙️ SMART ORDER RELOCATION                                        |
//+------------------------------------------------------------------+
input group "=== 🔄 Smart Order Relocation ==="
input bool     InpUseSmartOrderTrail           = true;          // Enable Relocation
input double   InpOrderTrailDistance           = 450.0;         // Trigger Distance (points)

//+------------------------------------------------------------------+
//| ⚙️ STATE RECOVERY & PROTECTION                                   |
//+------------------------------------------------------------------+
input group "=== 💾 State Recovery & Protection ==="
input bool     InpUseNewsFilter                = true;          // Enable News Filter
input int      InpNewsFilterMinutes            = 30;            // Filter Window (minutes)
input bool     InpSaveStateToFile              = true;          // Save State on Restart
input string   InpStateFileName                = "AQG_State.dat"; // State File Name
input bool     InpEnablePushNotify             = false;         // Push Notifications

//+------------------------------------------------------------------+
//| ⚙️ INTERFACE & DEBUGGING                                         |
//+------------------------------------------------------------------+
input group "=== 📊 Interface & Debugging ==="
input bool     InpShowPanel                    = true;          // Display Panel
input color    InpPanelBgColor                 = clrDarkSlateGray; // Background Color
input color    InpPanelTextColor               = clrWhite;      // Text Color
input int      InpPanelFontSize                = 9;             // Font Size
input bool     InpDebugMode                    = false;         // Debug Mode
input int      InpLogLevel                     = 2;             // Log Level (0-3)

//+------------------------------------------------------------------+
//| 🧮 Helper Class                                                  |
//+------------------------------------------------------------------+
class CAQGConfig
{
public:
   static double GetLotMultiplier(ENUM_AQG_RISK_PROFILE profile)
   {
      switch(profile) {
         case PROFILE_CONSERVATIVE: return 0.5;
         case PROFILE_BALANCED:     return 1.0;
         case PROFILE_AGGRESSIVE:   return 2.0;
         default:                   return 1.0;
      }
   }
   
   static double GetMaxDrawdown(ENUM_AQG_RISK_PROFILE profile)
   {
      switch(profile) {
         case PROFILE_CONSERVATIVE: return 20.0;
         case PROFILE_BALANCED:     return 40.0;
         case PROFILE_AGGRESSIVE:   return 60.0;
         default:                   return 40.0;
      }
   }
   
   static int GetMaxDepth(ENUM_AQG_RISK_PROFILE profile)
   {
      switch(profile) {
         case PROFILE_CONSERVATIVE: return 8;
         case PROFILE_BALANCED:     return 10;
         case PROFILE_AGGRESSIVE:   return 14;
         default:                   return 10;
      }
   }
   
   static double GetLotForDirection(bool isBuy, ENUM_AQG_GRID_MODE mode, 
                                    double buyLot, double sellLot, double baseLot)
   {
      if(mode == MODE_LEGACY) return isBuy ? buyLot : sellLot;
      return baseLot;
   }
};