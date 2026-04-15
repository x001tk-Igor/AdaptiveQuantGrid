//+------------------------------------------------------------------+
//|                                          AQG_GridCalculator.mqh  |
//|                            Adaptive Quant Grid - Grid Calculation|
//|                                         Version: 1.15            |
//+------------------------------------------------------------------+
#property version   "1.15"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>
#include <AQG/TradeExecutor.mqh>
#include <AQG/RiskGuardian.mqh>

//+------------------------------------------------------------------+
//| 📐 Grid Calculator Class                                         |
//+------------------------------------------------------------------+
class CAQGGridCalculator
{
private:
   string   m_symbol;
   int      m_digits;
   double   m_point;
   int      m_atrHandle;
   double   m_anchorPrice;
   int      m_currentStep;
   int      m_magic;
   double   m_baseLot;
   
   ENUM_AQG_GRID_MODE m_gridMode;
   double   m_buyBaseLot;
   double   m_sellBaseLot;
   double   m_partialCloseLot;
   double   m_sellSL_Points;
   bool     m_useAsymmetricLots;

   bool     m_isInitialized;
   bool     m_initialOrdersPlaced;

   double   m_atrMultiplier;
   int      m_minStepPoints;
   int      m_maxStepPoints;
   int      m_maxDepth;

   double   m_freezeLevelPts;
   double   m_stopsLevelPts;
   
   // --- Smart Order Relocation Settings ---
   double   m_trailDistance;
   datetime m_lastTrailTime;
   bool     m_useSmartTrail;

   // --- Private Helper Methods ---
   bool CheckOrderExists(int step, bool isBuy);
   double GetSafePrice(double price, bool isBuyLimit);
   string GenerateOrderComment(int step, bool isBuy);
   double GetLotForOrder(bool isBuy, int step);

public:
   CAQGGridCalculator();
   ~CAQGGridCalculator();
   
   // --- Initialization & Core Logic ---
   bool Init(string symbol, int magic, ENUM_AQG_GRID_MODE gridMode, 
             bool useAsymLots, double buyLot, double sellLot, double partialLot,
             double baseLot, double sellSL_Points,
             int atrPeriod, ENUM_TIMEFRAMES atrTF,
             double multiplier, double minStepPoints, double maxStepPoints, int maxDepth,
             double trailDistance, bool useSmartTrail);
   
   void Deinit();
   void Reset();
   bool SetAnchorPrice(double price);

   // --- Getters ---
   double GetAnchorPrice() const { return m_anchorPrice; }
   int    GetCurrentStep() const { return m_currentStep; }
   ENUM_AQG_GRID_MODE GetGridMode() const { return m_gridMode; }
   
   // --- Calculations ---
   double CalculateDynamicStep();
   double GetLevelPrice(int step, bool belowAnchor, double stepMult = 1.0);
   
   // --- Execution ---
   bool PlaceInitialOrders(CAQGTradeExecutor &trader);
   void UpdateGrid(CAQGTradeExecutor &trader, CAQGRiskGuardian &risk, double regimeStepMult = 1.0);
   
   // --- Smart Relocation ---
   void AdjustStaleOrders(CAQGTradeExecutor &trader);

   // --- Step Synchronization (PUBLIC) ---
   void SyncCurrentStep();
   
   bool ShouldPlaceBuyLimit(int step) const;
   bool ShouldPlaceSellLimit(int step) const;
};

//+------------------------------------------------------------------+
//| Constructor / Destructor                                         |
//+------------------------------------------------------------------+
CAQGGridCalculator::CAQGGridCalculator() 
   : m_isInitialized(false), m_initialOrdersPlaced(false), m_atrHandle(INVALID_HANDLE), 
     m_gridMode(MODE_SYMMETRIC), m_useAsymmetricLots(false), m_sellSL_Points(200.0),
     m_trailDistance(300.0), m_lastTrailTime(0), m_useSmartTrail(true) {}

CAQGGridCalculator::~CAQGGridCalculator() { Deinit(); }

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CAQGGridCalculator::Init(string symbol, int magic, ENUM_AQG_GRID_MODE gridMode,
                              bool useAsymLots, double buyLot, double sellLot, double partialLot,
                              double baseLot, double sellSL_Points,
                              int atrPeriod, ENUM_TIMEFRAMES atrTF,
                              double multiplier, double minStepPoints, double maxStepPoints, int maxDepth,
                              double trailDistance, bool useSmartTrail)
{
   m_symbol              = symbol;
   m_magic               = magic;
   m_gridMode            = gridMode;
   m_useAsymmetricLots   = useAsymLots && (gridMode == MODE_LEGACY);
   m_buyBaseLot          = MathMax(0.01, buyLot);
   m_sellBaseLot         = MathMax(0.01, sellLot);
   m_partialCloseLot     = MathMax(0.01, partialLot);
   m_sellSL_Points       = MathMax(10.0, sellSL_Points);
   m_baseLot             = MathMax(0.01, baseLot);
   
   m_digits              = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_point               = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_atrMultiplier       = multiplier;
   m_minStepPoints       = (int)MathMax(1.0, minStepPoints);
   m_maxStepPoints       = (int)MathMax(m_minStepPoints, maxStepPoints);
   m_maxDepth            = maxDepth;
   
   m_trailDistance       = MathMax(50.0, trailDistance);
   m_useSmartTrail       = useSmartTrail;
   m_lastTrailTime       = 0;
   
   m_currentStep         = 0;
   m_anchorPrice         = 0;
   m_initialOrdersPlaced = false;

   m_freezeLevelPts = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   m_stopsLevelPts  = (double)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);

   m_atrHandle = iATR(m_symbol, atrTF, atrPeriod);
   if(m_atrHandle == INVALID_HANDLE)
   {
      AQG_LOG_ERROR("Failed to create ATR handle.");
      return false;
   }

   m_isInitialized = true;
   AQG_LOG_INFO("GridCalculator init | Mode: " + (gridMode==MODE_LEGACY?"LEGACY":"SYMMETRIC") + 
                " | MinStep: " + IntegerToString(m_minStepPoints) + " pts | Trail: " + (useSmartTrail?"ON":"OFF"));
   return true;
}

void CAQGGridCalculator::Deinit()
{
   if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
   m_isInitialized = false;
}

void CAQGGridCalculator::Reset()
{
   m_anchorPrice = 0;
   m_currentStep = 0;
   m_initialOrdersPlaced = false;
   m_lastTrailTime = 0;
}

bool CAQGGridCalculator::SetAnchorPrice(double price)
{
   if(price <= 0) return false;
   m_anchorPrice = NormalizeDouble(price, m_digits);
   return true;
}

//+------------------------------------------------------------------+
//| 🔢 Dynamic Step Calculation                                      |
//+------------------------------------------------------------------+
double CAQGGridCalculator::CalculateDynamicStep()
{
   if(!m_isInitialized) return m_minStepPoints;
   double atr[];
   if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) < 1) return m_minStepPoints;
   
   double stepPoints = (atr[0] / m_point) * m_atrMultiplier;
   return MathMax(m_minStepPoints, MathMin(m_maxStepPoints, stepPoints));
}

//+------------------------------------------------------------------+
//| 📏 Grid Level Price Calculation                                  |
//+------------------------------------------------------------------+
double CAQGGridCalculator::GetLevelPrice(int step, bool belowAnchor, double stepMult = 1.0)
{
   if(m_anchorPrice <= 0) return 0;
   double baseStepPts = CalculateDynamicStep();
   double effectiveStepPts = baseStepPts * stepMult;
   
   double price = belowAnchor ? m_anchorPrice - (effectiveStepPts * step * m_point) 
                              : m_anchorPrice + (effectiveStepPts * step * m_point);
   return NormalizeDouble(price, m_digits);
}

//+------------------------------------------------------------------+
//| ✅ Price Safety Validation                                       |
//+------------------------------------------------------------------+
double CAQGGridCalculator::GetSafePrice(double price, bool isBuyLimit)
{
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double safeDist = MathMax(m_stopsLevelPts, m_freezeLevelPts) + 3.0; 
   return isBuyLimit ? MathMin(price, bid - (safeDist * m_point)) : MathMax(price, ask + (safeDist * m_point));
}

//+------------------------------------------------------------------+
//| 🔍 Check if Order Exists                                         |
//+------------------------------------------------------------------+
bool CAQGGridCalculator::CheckOrderExists(int step, bool isBuy)
{
   string comment = GenerateOrderComment(step, isBuy);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && OrderGetString(ORDER_SYMBOL) == m_symbol)
      {
         if(OrderGetString(ORDER_COMMENT) == comment) return true;
      }
   }
   return false;
}

string CAQGGridCalculator::GenerateOrderComment(int step, bool isBuy)
{
   string prefix = (m_gridMode == MODE_LEGACY) ? "AQG_LGCY_" : "AQG_";
   return isBuy ? prefix + "BL_" + IntegerToString(step) : prefix + "SL_" + IntegerToString(step);
}

//+------------------------------------------------------------------+
//| 🔄 Step Synchronization (FIXED - v1.15)                          |
//| ИСПРАВЛЕНО: Считает только ОТКРЫТЫЕ ПОЗИЦИИ, а не ордера         |
//+------------------------------------------------------------------+
void CAQGGridCalculator::SyncCurrentStep()
{
   int maxFound = 0;
   
   // 🔹 СКАНИРУЕМ ТОЛЬКО ОТКРЫТЫЕ ПОЗИЦИИ (PositionsTotal)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && 
         PositionGetInteger(POSITION_MAGIC) == m_magic && 
         PositionGetString(POSITION_SYMBOL) == m_symbol)
      {
         string comment = PositionGetString(POSITION_COMMENT);
         if(StringFind(comment, "AQG_") == 0)
         {
            // Find the LAST underscore to correctly extract the step number
            int lastPos = -1;
            for(int k = 0; k < StringLen(comment); k++)
            {
               if(StringGetCharacter(comment, k) == '_') lastPos = k;
            }
            
            if(lastPos > 0)
            {
               int step = (int)StringToInteger(StringSubstr(comment, lastPos + 1));
               if(step > maxFound) maxFound = step;
            }
         }
      }
   }
   
   if(maxFound > m_currentStep) m_currentStep = maxFound;
}

//+------------------------------------------------------------------+
//| 📐 Lot Size Calculation                                          |
//+------------------------------------------------------------------+
double CAQGGridCalculator::GetLotForOrder(bool isBuy, int step)
{
   if(m_useAsymmetricLots && m_gridMode == MODE_LEGACY)
      return CAQGConfig::GetLotForDirection(isBuy, m_gridMode, m_buyBaseLot, m_sellBaseLot, m_baseLot);
   return m_baseLot;
}

bool CAQGGridCalculator::ShouldPlaceBuyLimit(int step) const { return true; }
bool CAQGGridCalculator::ShouldPlaceSellLimit(int step) const { return m_gridMode != MODE_LEGACY; }

//+------------------------------------------------------------------+
//| 🚀 Place Initial Orders                                          |
//| 🔥 ИСПРАВЛЕНО: Жесткая проверка на наличие позиций перед стартом |
//+------------------------------------------------------------------+
bool CAQGGridCalculator::PlaceInitialOrders(CAQGTradeExecutor &trader)
{
   // 🔹 АБСОЛЮТНАЯ ЗАЩИТА: Если уже есть позиции с нашим Magic — НИКОГДА не ставим начальные ордера!
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && 
         PositionGetInteger(POSITION_MAGIC) == m_magic && 
         PositionGetString(POSITION_SYMBOL) == m_symbol)
      {
         AQG_LOG_DEBUG("🛑 PlaceInitialOrders BLOCKED: Existing positions found for Magic " + IntegerToString(m_magic));
         m_initialOrdersPlaced = true;
         return true;
      }
   }

   // Если позиций нет, продолжаем стандартную логику
   if(m_anchorPrice <= 0 || m_initialOrdersPlaced) return true;
   
   double buyLot = GetLotForOrder(true, 1);
   double sellLot = GetLotForOrder(false, 1);
   bool ok = false;

   if(m_gridMode == MODE_LEGACY)
   {
      // LEGACY: Market Buy + Market Sell (Hedge) + Buy Limit
      if(trader.MarketBuy(buyLot, 0, 0, "AQG_LGCY_MB_0")) ok = true;
      
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double sl = NormalizeDouble(bid + m_sellSL_Points * m_point, m_digits);
      if(trader.MarketSell(sellLot, sl, 0, "AQG_LGCY_MS_0")) ok = true;
      
      double bl = GetSafePrice(GetLevelPrice(1, true, 1.0), true);
      if(trader.BuyLimit(buyLot, bl, 0, 0, GenerateOrderComment(1, true))) ok = true;
   }
   else
   {
      // SYMMETRIC: Buy Limit + Sell Limit
      double bl = GetSafePrice(GetLevelPrice(1, true, 1.0), true);
      if(trader.BuyLimit(buyLot, bl, 0, 0, GenerateOrderComment(1, true))) ok = true;
      
      if(ShouldPlaceSellLimit(1))
      {
         double sl = GetSafePrice(GetLevelPrice(1, false, 1.0), false);
         if(trader.SellLimit(sellLot, sl, 0, 0, GenerateOrderComment(1, false))) ok = true;
      }
   }

   if(ok) { m_initialOrdersPlaced = true; m_currentStep = 1; }
   return ok;
}

//+------------------------------------------------------------------+
//| 🔄 Update Grid Logic                                             |
//+------------------------------------------------------------------+
void CAQGGridCalculator::UpdateGrid(CAQGTradeExecutor &trader, CAQGRiskGuardian &risk, double regimeStepMult = 1.0)
{
   if(!m_isInitialized || m_anchorPrice <= 0) return;
   if(risk.CheckEquityDrawdown()) return;

   // Sync step based on existing orders
   SyncCurrentStep();
   
   int nextStep = m_currentStep + 1;
   if(risk.CheckMaxGridDepth(nextStep)) return;

   // Place Buy Limits
   if(ShouldPlaceBuyLimit(nextStep) && !CheckOrderExists(nextStep, true))
   {
      double price = GetSafePrice(GetLevelPrice(nextStep, true, regimeStepMult), true);
      if(price > 0) trader.BuyLimit(GetLotForOrder(true, nextStep), price, 0, 0, GenerateOrderComment(nextStep, true));
   }

   // Place Sell Limits (Symmetric only)
   if(ShouldPlaceSellLimit(nextStep) && !CheckOrderExists(nextStep, false))
   {
      double price = GetSafePrice(GetLevelPrice(nextStep, false, regimeStepMult), false);
      if(price > 0) trader.SellLimit(GetLotForOrder(false, nextStep), price, 0, 0, GenerateOrderComment(nextStep, false));
   }
}

//+------------------------------------------------------------------+
//| 🔥 Smart Order Relocation (FIXED - v1.14)                        |
//| ИСПРАВЛЕНО: Сетка НЕ переносится, если цена ИДЁТ К лимиткам      |
//+------------------------------------------------------------------+
void CAQGGridCalculator::AdjustStaleOrders(CAQGTradeExecutor &trader)
{
   if(!m_useSmartTrail || TimeCurrent() - m_lastTrailTime < 3) return;
   if(m_anchorPrice <= 0) return;

   double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double distPts = MathAbs(currentBid - m_anchorPrice) / m_point;

   // 🔹 1. СКАНИРУЕМ СТОПАН: Ищем ближайшие активные лимитники
   bool hasActiveBuyLimits = false;
   bool hasActiveSellLimits = false;
   double nearestBuyLimitPrice = 0;
   double nearestSellLimitPrice = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && 
         OrderGetInteger(ORDER_MAGIC) == m_magic && 
         OrderGetString(ORDER_SYMBOL) == m_symbol)
      {
         if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT)
         {
            hasActiveBuyLimits = true;
            double price = OrderGetDouble(ORDER_PRICE_OPEN);
            // Ищем самый верхний Buy Limit (ближайший к цене сверху)
            if(nearestBuyLimitPrice == 0 || price > nearestBuyLimitPrice)
               nearestBuyLimitPrice = price;
         }
         else if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT)
         {
            hasActiveSellLimits = true;
            double price = OrderGetDouble(ORDER_PRICE_OPEN);
            // Ищем самый нижний Sell Limit (ближайший к цене снизу)
            if(nearestSellLimitPrice == 0 || price < nearestSellLimitPrice)
               nearestSellLimitPrice = price;
         }
      }
   }

   // 🔹 2. ПРОВЕРЯЕМ: Не идет ли цена К нашим лимиткам?
   
   // Если цена ВЫШЕ якоря и есть Buy лимитки НИЖЕ
   if(currentBid > m_anchorPrice && hasActiveBuyLimits)
   {
      // Цена выше якоря, лимитки ниже. Если цена выше лимитки — она идёт к ней вниз
      if(currentBid > nearestBuyLimitPrice)
      {
         double distToLimit = (currentBid - nearestBuyLimitPrice) / m_point;
         // Если до лимитки меньше 50% от Trigger Distance — НЕ ПЕРЕНОСИМ! Ждём срабатывания.
         if(distToLimit < m_trailDistance * 0.5)
         {
            AQG_LOG_DEBUG("🛑 Skip relocation: Price approaching Buy Limit | Dist: " + 
                          DoubleToString(distToLimit,0) + " pts");
            return;
         }
      }
   }
   
   // Если цена НИЖЕ якоря и есть Sell лимитки ВЫШЕ
   if(currentBid < m_anchorPrice && hasActiveSellLimits)
   {
      // Цена ниже якоря, лимитки выше. Если цена ниже лимитки — она идёт к ней вверх
      if(currentBid < nearestSellLimitPrice)
      {
         double distToLimit = (nearestSellLimitPrice - currentBid) / m_point;
         // Если до лимитки меньше 50% от Trigger Distance — НЕ ПЕРЕНОСИМ!
         if(distToLimit < m_trailDistance * 0.5)
         {
            AQG_LOG_DEBUG("🛑 Skip relocation: Price approaching Sell Limit | Dist: " + 
                          DoubleToString(distToLimit,0) + " pts");
            return;
         }
      }
   }

   // 🔹 3. ЕСЛИ ЦЕНА ДАЛЕКО И НЕ ИДЁТ К ЛИМИТКАМ -> ПЕРЕНОСИМ СЕТКУ
   if(distPts > m_trailDistance)
   {
      string direction = (currentBid > m_anchorPrice) ? "UP" : "DOWN";
      AQG_LOG_INFO("🔄 Smart Trail Triggered | Price moved " + DoubleToString(distPts,0) + 
                   " pts " + direction + " from anchor (No limits nearby)");
      
      // Удаляем все отложенные ордера
      trader.DeleteAllPendingOrders();
      
      // Переносим якорь на текущую цену
      m_anchorPrice = currentBid;
      m_currentStep = 0;
      m_initialOrdersPlaced = false; // Сбрасываем флаг, чтобы в OnTick поставились новые лимитки
      m_lastTrailTime = TimeCurrent();
      
      AQG_LOG_SUCCESS("✅ Grid relocated to new price zone: " + DoubleToString(m_anchorPrice, m_digits));
   }
}