//+------------------------------------------------------------------+
//|                                  AdaptiveQuantGrid.mq5           |
//|                      Adaptive Quant Grid EA - Main Controller    |
//|                                         Version: 1.24            |
//+------------------------------------------------------------------+
#property strict
#property version   "1.24"
#property description "Adaptive Quant Grid: Professional Grid System"
#property link      "Vlladimir Kuzmin"

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>
#include <AQG/TradeExecutor.mqh>
#include <AQG/RiskGuardian.mqh>
#include <AQG/GridCalculator.mqh>
#include <AQG/RegimeDetector.mqh>
#include <AQG/RecoveryManager.mqh>
#include <AQG/OverlapEngine.mqh>
#include <AQG/EquityTrailer.mqh>
#include <AQG/UI_Panel.mqh>
#include <AQG/GridDirectionEngine.mqh>

//--- Global Module Instances
CAQGTradeExecutor      g_Trader;
CAQGRiskGuardian       g_RiskManager;
CAQGGridCalculator     g_GridCalc;
CAQGRegimeDetector     g_Regime;
CAQGRecoveryManager    g_Recovery;
CAQGOverlapEngine      g_Overlap;
CAQGEquityTrailer      g_EquityTrailer;
CAQGPanel              g_Panel;
CAQGDirectionEngine    g_Direction;

//--- EA State Variables
int                 g_MagicNumber;
ENUM_AQG_MARKET_MODE g_CurrentMode = MODE_UNKNOWN;
ENUM_AQG_GRID_STATE  g_GridState  = STATE_IDLE;
datetime            g_LastTickTime = 0;
datetime            g_LastHeavyCalc = 0;
datetime            g_LastLogTime = 0;
bool                g_IsInitialized = false;
bool                g_EmergencyStop = false;
bool                g_IsFirstTick   = true;
double              g_LastOverlapProfit = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("\n=== AQG EA INITIALIZATION STARTED ===");

   g_MagicNumber = AQG_MAGIC_BASE;
   for(int i = 0; i < MathMin(4, StringLen(_Symbol)); i++) g_MagicNumber += (int)_Symbol[i];

   CAQGLogger::Init(_Symbol, _Period, InpLogLevel);
   if(!ValidateEnvironment()) return INIT_FAILED;

   g_Trader.Init(g_MagicNumber, _Symbol);
   g_RiskManager.Init(InpRiskProfile); g_RiskManager.UpdateState();
   if(g_RiskManager.CheckEquityDrawdown()) { g_EmergencyStop=true; return INIT_FAILED; }

   if(!g_GridCalc.Init(_Symbol, g_MagicNumber, 
                       InpGridMode, InpUseAsymmetricLots, 
                       InpBuyBaseLot, InpSellBaseLot, InpPartialCloseLot, InpMinLotSize,
                       InpSellSL_Points,
                       InpATRPeriod, InpATRTF, InpATRMultiplier, 
                       InpMinStepPoints, InpMaxStepPoints, InpMaxGridDepth,
                       InpOrderTrailDistance, InpUseSmartOrderTrail))
      return INIT_FAILED;

   if(!g_Regime.Init(_Symbol, InpADXPeriod, InpEMAPeriod, InpADXThreshold, InpRegimeHysteresis))
      return INIT_FAILED;

   g_Recovery.Init(_Symbol, g_MagicNumber);
   g_Overlap.Init(_Symbol, g_MagicNumber, InpOverlapProfitTarget, InpOverlapCooldownMin);
   g_EquityTrailer.Init(_Symbol, g_MagicNumber, InpTrailingActivationProfit, InpTrailingDropPercent, InpTrailingCheckSec);
   g_Direction.Init(_Symbol, g_MagicNumber, InpGridMode, 
                    InpBuyBaseLot, InpSellBaseLot, InpPartialCloseLot, InpSellSL_Points, InpMinStepPoints);

   if(InpShowPanel) g_Panel.Init(_Symbol);

   //+------------------------------------------------------------------+
   //| 🔹 КРИТИЧЕСКИЙ ФИКС: Состояние привязывается к РЕАЛЬНЫМ позициям |
   //+------------------------------------------------------------------+
   
   // 1. СКАНИРУЕМ ТЕРМИНАЛ: есть ли наши позиции прямо сейчас?
   bool hasPositions = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && 
         PositionGetInteger(POSITION_MAGIC) == g_MagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         hasPositions = true;
         break;
      }
   }

   // 2. Пытаемся восстановить состояние (файл или память), но НЕ зависим от результата
   bool stateRestored = false;
   if(InpSaveStateToFile) stateRestored = LoadStateFromFile();
   if(!stateRestored) stateRestored = g_Recovery.Recover(g_GridCalc, g_Trader, g_RiskManager);

   // 3. Синхронизируем шаг сетки по ордерам
   g_GridCalc.SyncCurrentStep();

   // 4. ЖЕСТКОЕ УПРАВЛЕНИЕ СОСТОЯНИЕМ
   if(hasPositions)
   {
      // Если позиции есть -> сразу ACTIVE. PlaceInitialOrders в OnTick НЕ вызовется.
      g_GridState = STATE_ACTIVE;
      
      // Если якорь потерялся, восстанавливаем по текущей цене
      if(g_GridCalc.GetAnchorPrice() <= 0)
         g_GridCalc.SetAnchorPrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
         
      g_Direction.SyncState(g_GridCalc.GetCurrentStep(), g_GridCalc.GetAnchorPrice(), "RECOVERED");
      AQG_LOG_SUCCESS("✅ Positions detected. State forced to ACTIVE | Step: " + IntegerToString(g_GridCalc.GetCurrentStep()));
   }
   else
   {
      // Позиций нет -> IDLE. OnTick сам запустит PlaceInitialOrders.
      g_GridState = STATE_IDLE;
      AQG_LOG_INFO("🆕 No positions found. State set to IDLE.");
   }

   g_IsInitialized = true; 
   AQG_LOG_SUCCESS("=== AQG EA v1.24 INITIALIZED SUCCESSFULLY ===");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   g_GridCalc.Deinit(); g_Regime.Deinit();
   if(g_IsInitialized && InpSaveStateToFile) SaveStateToFile();
   if(InpShowPanel) g_Panel.Delete();
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(g_EmergencyStop || !g_IsInitialized) {
      if(g_IsFirstTick && !g_EmergencyStop) g_Recovery.Recover(g_GridCalc, g_Trader, g_RiskManager);
      return;
   }

   datetime now = TimeCurrent();
   if(now == g_LastTickTime) return;
   g_LastTickTime = now; g_IsFirstTick = false;
   g_RiskManager.UpdateState();
   if(CheckEmergencyStop()) return;

   // Cycle Exit Check
   if(InpUseLegacyExit)
   {
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double anchor = g_GridCalc.GetAnchorPrice();
      double profit = GetBasketProfit();
      
      if(now - g_LastLogTime >= 60)
      {
         AQG_LOG_INFO("📊 Exit Check | Anchor: " + DoubleToString(anchor, _Digits) + 
                      " | Price: " + DoubleToString(currentBid, _Digits) + 
                      " | Profit: $" + DoubleToString(profit,2) + 
                      " | Target: $" + DoubleToString(InpTargetProfit,2));
         g_LastLogTime = now;
      }
      
      if(anchor > 0 && profit >= InpTargetProfit)
      {
         AQG_LOG_SUCCESS("🔒 LEGACY EXIT TRIGGERED | Profit: $" + DoubleToString(profit,2));
         g_Trader.CloseAllPositions();
         g_Trader.DeleteAllPendingOrdersForce();
         g_GridCalc.Reset(); g_Direction.SyncState(0,0,"RESET"); g_GridState = STATE_IDLE;
         
         AQG_LOG_INFO("🔄 Starting NEW cycle...");
         Sleep(100);
         g_GridCalc.SetAnchorPrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));
         
         if(g_GridCalc.PlaceInitialOrders(g_Trader))
         {
            g_GridState = STATE_ACTIVE;
            g_Direction.SyncState(g_GridCalc.GetCurrentStep(), g_GridCalc.GetAnchorPrice(), "");
            AQG_LOG_SUCCESS("✅ New cycle started!");
         }
         return;
      }
   }

   if((now - g_LastHeavyCalc) >= 2)
   {
      g_LastHeavyCalc = now;
      if(g_GridCalc.GetAnchorPrice() <= 0) g_GridCalc.SetAnchorPrice(SymbolInfoDouble(_Symbol, SYMBOL_BID));

      // 🔒 ТОЛЬКО если STATE_IDLE и НЕТ позиций -> ставим начальные ордера
      if(g_GridState == STATE_IDLE)
      {
         if(g_GridCalc.PlaceInitialOrders(g_Trader))
         {
            g_GridState = STATE_ACTIVE;
            g_Direction.SyncState(g_GridCalc.GetCurrentStep(), g_GridCalc.GetAnchorPrice(), "");
         }
      }

      g_Regime.Update(); g_CurrentMode = g_Regime.GetMode();
      double stepMult = g_Regime.GetStepMultiplier();
      if(g_Regime.IsBuyAllowed() || g_Regime.IsSellAllowed())
         g_GridCalc.UpdateGrid(g_Trader, g_RiskManager, stepMult);

      // Smart Order Relocation
      if(InpUseSmartOrderTrail)
         g_GridCalc.AdjustStaleOrders(g_Trader);

      if(InpUseSmartOverlap)
      {
         if(g_Overlap.ProcessOverlap(g_Trader))
         {
            g_LastOverlapProfit = InpOverlapProfitTarget;
            g_EquityTrailer.SetLastOverlapProfit(InpOverlapProfitTarget);
         }
      }

      if(InpUseEquityTrailing && !InpUseLegacyExit)
         g_EquityTrailer.Update(g_Trader, g_GridCalc, g_GridState);
   }

   if(InpShowPanel) UpdatePanel();
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(!g_IsInitialized) return;
   if(g_Direction.ProcessDeal(trans, g_Trader, g_RiskManager, g_GridCalc)) g_LastOverlapProfit = 0.0;
}

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+
bool ValidateEnvironment() { return TerminalInfoInteger(TERMINAL_CONNECTED) && AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE); }

bool CheckEmergencyStop()
{
   if(g_RiskManager.CheckEquityDrawdown())
   {
      g_GridState=STATE_EMERGENCY; g_EmergencyStop=true;
      g_Trader.CloseAllPositions(); g_Trader.DeleteAllPendingOrders();
      if(InpEnablePushNotify) SendNotification("🚨 AQG EMERGENCY STOP | Drawdown Limit Breached");
      return true;
   }
   return false;
}

void UpdatePanel()
{
   SAQGPanelData data;
   data.mode=g_CurrentMode; data.state=g_GridState; data.currentStep=g_Direction.GetCurrentStep();
   data.maxStep=InpMaxGridDepth; data.atrStepPts=g_GridCalc.CalculateDynamicStep(); data.basketProfit=GetBasketProfit();
   data.trailingActive=g_EquityTrailer.IsActive(); data.trailingPeak=g_EquityTrailer.GetMaxProfit();
   data.trailingDropPct=g_EquityTrailer.GetDropPercent(); data.lastOverlapProfit=g_LastOverlapProfit;
   double bal=AccountInfoDouble(ACCOUNT_BALANCE), eq=AccountInfoDouble(ACCOUNT_EQUITY);
   data.drawdownPct=(bal>0)?((bal-eq)/bal*100.0):0.0; data.freeMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_Panel.Update(data);
}

double GetBasketProfit()
{
   double total=0.0;
   for(int i=PositionsTotal()-1; i>=0; i--) { ulong t=PositionGetTicket(i); if(t>0 && PositionGetInteger(POSITION_MAGIC)==g_MagicNumber && PositionGetString(POSITION_SYMBOL)==_Symbol) total+=PositionGetDouble(POSITION_PROFIT); }
   return total;
}

void SaveStateToFile()
{
   if(!InpSaveStateToFile) return;
   string fn="AQG_State_"+_Symbol+"_"+IntegerToString(g_MagicNumber)+".dat";
   int h=FileOpen(fn,FILE_WRITE|FILE_BIN|FILE_COMMON); if(h==INVALID_HANDLE) return;
   FileWriteInteger(h,(int)g_CurrentMode); FileWriteInteger(h,(int)g_GridState);
   FileWriteDouble(h,g_GridCalc.GetAnchorPrice()); FileWriteInteger(h,g_MagicNumber); FileClose(h);
}

bool LoadStateFromFile()
{
   if(!InpSaveStateToFile) return false;
   string fn="AQG_State_"+_Symbol+"_"+IntegerToString(g_MagicNumber)+".dat";
   int h=FileOpen(fn,FILE_READ|FILE_BIN|FILE_COMMON); if(h==INVALID_HANDLE) return false;
   int m=FileReadInteger(h), s=FileReadInteger(h); double a=FileReadDouble(h); int mg=FileReadInteger(h); FileClose(h);
   if(mg!=g_MagicNumber) return false;
   g_CurrentMode=(ENUM_AQG_MARKET_MODE)m; g_GridState=(ENUM_AQG_GRID_STATE)s;
   if(a>0) g_GridCalc.SetAnchorPrice(a);
   return true;
}