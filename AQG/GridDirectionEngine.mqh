//+------------------------------------------------------------------+
//|                                      AQG_GridDirectionEngine.mqh |
//|                          Adaptive Quant Grid - Directional Logic  |
//|                                         Версия: 1.05 (MemFix)    |
//+------------------------------------------------------------------+
#property version   "1.05"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>
#include <AQG/TradeExecutor.mqh>
#include <AQG/GridCalculator.mqh>
#include <AQG/RiskGuardian.mqh>

class CAQGDirectionEngine
{
private:
   string   m_symbol;
   int      m_magic;
   ENUM_AQG_GRID_MODE m_mode;
   double   m_buyBaseLot, m_sellBaseLot, m_partialCloseLot;
   double   m_sellSL_Points;
   double   m_point;
   int      m_digits;
   ulong    m_lastProcessedDeal;
   int      m_currentStep;
   double   m_anchorPrice;
   string   m_lastDirection;
   double   m_minStepPoints;
   
   // 🔹 НОВОЕ: Храним цену последнего Market Sell (даже если он закрыт!)
   double   m_lastMarketSellPrice; 

   ulong    FindLargestSellTicket();
   bool     ClosePartialBestBuy(double lots, CAQGTradeExecutor &trader);
   bool     CancelBuyLimitAtStep(int step, CAQGTradeExecutor &trader);
   double   CalcGridPrice(int step, bool isBelowAnchor, CAQGGridCalculator &grid);
   double   GetSafePrice(double price, bool isBuy);

public:
   CAQGDirectionEngine();
   ~CAQGDirectionEngine();
   void Init(string symbol, int magic, ENUM_AQG_GRID_MODE mode, double buyLot, double sellLot, double partialLot, double slPoints, double minStepPoints);
   void SyncState(int step, double anchor, const string &direction);
   bool ProcessDeal(const MqlTradeTransaction &trans, CAQGTradeExecutor &trader, CAQGRiskGuardian &risk, CAQGGridCalculator &grid);
   
   int    GetCurrentStep()    const { return m_currentStep; }
   double GetAnchorPrice()    const { return m_anchorPrice; }
   string GetLastDirection()  const { return m_lastDirection; }

private:
   void HandleDownwardMove(CAQGTradeExecutor &trader, CAQGRiskGuardian &risk, CAQGGridCalculator &grid);
   void HandleUpwardMove(CAQGTradeExecutor &trader, CAQGRiskGuardian &risk, CAQGGridCalculator &grid);
};

CAQGDirectionEngine::CAQGDirectionEngine() : m_lastProcessedDeal(0), m_currentStep(0), m_anchorPrice(0), m_lastMarketSellPrice(0) {}
CAQGDirectionEngine::~CAQGDirectionEngine() {}

void CAQGDirectionEngine::Init(string symbol, int magic, ENUM_AQG_GRID_MODE mode,
                               double buyLot, double sellLot, double partialLot, double slPoints, double minStepPoints)
{
   m_symbol = symbol; m_magic = magic; m_mode = mode;
   m_buyBaseLot = MathMax(0.01, buyLot);
   m_sellBaseLot = MathMax(0.01, sellLot);
   m_partialCloseLot = MathMax(0.01, partialLot);
   m_sellSL_Points = MathMax(10.0, slPoints);
   m_minStepPoints = MathMax(10.0, minStepPoints);
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_lastMarketSellPrice = 0; // Сброс
   AQG_LOG_INFO("DirectionEngine init | MinStep: " + DoubleToString(m_minStepPoints,0) + " pts");
}

void CAQGDirectionEngine::SyncState(int step, double anchor, const string &direction)
{
   m_currentStep = step; m_anchorPrice = anchor; m_lastDirection = direction;
   m_lastProcessedDeal = 0;
   // При синхронизации (рестарт) можно не сбрасывать цену, если хотим сохранить историю, 
   // но при полном ресете (Reset) она сбросится в конструкторе или явно.
   if(direction == "RESET") m_lastMarketSellPrice = 0;
}

bool CAQGDirectionEngine::ProcessDeal(const MqlTradeTransaction &trans, CAQGTradeExecutor &trader,
                                      CAQGRiskGuardian &risk, CAQGGridCalculator &grid)
{
   if(m_mode != MODE_LEGACY) return false;
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return false;
   if(trans.deal == m_lastProcessedDeal) return false;

   if(!HistoryDealSelect(trans.deal)) return false;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != m_magic) return false;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != m_symbol) return false;

   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ENUM_DEAL_REASON dealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON);
   string comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);

   bool isDownward = (dealType == DEAL_TYPE_BUY && dealEntry == DEAL_ENTRY_IN && StringFind(comment, "BL_") >= 0);
   bool isUpward   = (dealType == DEAL_TYPE_BUY && dealEntry == DEAL_ENTRY_OUT && dealReason == DEAL_REASON_SL);

   if(!isDownward && !isUpward) return false;

   m_lastProcessedDeal = trans.deal;

   if(isDownward)
   {
      AQG_LOG_INFO("🔽 DOWNWARD EVENT | Step: " + IntegerToString(m_currentStep) + " → " + IntegerToString(m_currentStep+1));
      m_lastDirection = "DOWN";
      HandleDownwardMove(trader, risk, grid);
   }
   else if(isUpward)
   {
      AQG_LOG_INFO("🔼 UPWARD EVENT | Step: " + IntegerToString(m_currentStep) + " → " + IntegerToString(m_currentStep-1));
      m_lastDirection = "UP";
      HandleUpwardMove(trader, risk, grid);
   }

   SyncState(m_currentStep, grid.GetAnchorPrice(), m_lastDirection);
   return true;
}

void CAQGDirectionEngine::HandleDownwardMove(CAQGTradeExecutor &trader, CAQGRiskGuardian &risk, CAQGGridCalculator &grid)
{
   if(risk.CheckMaxGridDepth(m_currentStep + 1))
   {
      AQG_LOG_WARNING("Max depth reached. Stopping expansion.");
      return;
   }

   // 🔹 ПРОВЕРКА ДИСТАНЦИИ (ИСПОЛЬЗУЕМ ПАМЯТЬ!)
   double currentBid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   
   // Используем сохраненную цену, а не поиск по позициям
   double lastSellPrice = m_lastMarketSellPrice; 
   
   bool skipCheck = false;
   if(lastSellPrice > 0)
   {
      double distancePoints = MathAbs(currentBid - lastSellPrice) / m_point;
      
      if(distancePoints < m_minStepPoints)
      {
         AQG_LOG_INFO("⏳ Skipping Market Sell | Dist: " + DoubleToString(distancePoints,0) + 
                      " pts < Min: " + DoubleToString(m_minStepPoints,0) + " pts");
         return; // ПРОПУСКАЕМ ОТКРЫТИЕ!
      }
   }
   else
   {
      // Если lastSellPrice == 0 (самый первый шаг или после сброса), 
      // мы разрешаем открытие, но только если это действительно начало.
      // Но лучше перестраховаться: если шаг > 1, а цены нет — это подозрительно.
      // Для простоты: если цены нет, разрешаем (первый запуск).
      AQG_LOG_DEBUG("No last Sell price found (First run?). Allowing open.");
   }
   
   m_currentStep++;

   // 1. Закрываем Sell с наибольшим тикетом (если есть открытые)
   ulong sellTicket = FindLargestSellTicket();
   if(sellTicket > 0)
   {
      AQG_LOG_INFO("Closing Sell #" + IntegerToString(sellTicket));
      trader.ClosePosition(sellTicket);
   }

   // 2. Открываем НОВЫЙ Market Sell
   double sl  = NormalizeDouble(currentBid + m_sellSL_Points * m_point, m_digits);
   string comment = "LGCY_MS_" + IntegerToString(m_currentStep);
   
   if(!trader.MarketSell(m_sellBaseLot, sl, 0, comment))
   {
      AQG_LOG_ERROR("❌ Failed to place Market Sell!");
   }
   else
   {
      AQG_LOG_SUCCESS("✅ Market Sell placed @ " + DoubleToString(currentBid, m_digits));
      // 🔹 ЗАПОМИНАЕМ ЦЕНУ!
      m_lastMarketSellPrice = currentBid; 
   }

   // 3. Выставляем Buy Limit
   double blPrice = GetSafePrice(CalcGridPrice(m_currentStep + 1, true, grid), true);
   if(blPrice > 0)
   {
      trader.BuyLimit(m_buyBaseLot, blPrice, 0, 0, "AQG_LGCY_BL_" + IntegerToString(m_currentStep + 1));
   }
}

void CAQGDirectionEngine::HandleUpwardMove(CAQGTradeExecutor &trader, CAQGRiskGuardian &risk, CAQGGridCalculator &grid)
{
   if(m_currentStep <= 0) return;
   m_currentStep--;

   ClosePartialBestBuy(m_partialCloseLot, trader);

   double smallBlPrice = GetSafePrice(CalcGridPrice(m_currentStep + 1, true, grid), true);
   if(smallBlPrice > 0)
      trader.BuyLimit(m_partialCloseLot, smallBlPrice, 0, 0, "AQG_LGCY_BL_SMALL_" + IntegerToString(m_currentStep + 1));

   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double sl  = NormalizeDouble(bid + m_sellSL_Points * m_point, m_digits);
   
   // Открываем новый Sell при движении вверх
   if(trader.MarketSell(m_sellBaseLot, sl, 0, "LGCY_MS_" + IntegerToString(m_currentStep)))
   {
       // 🔹 ЗАПОМИНАЕМ ЦЕНУ И ЗДЕСЬ!
       m_lastMarketSellPrice = bid;
   }

   CancelBuyLimitAtStep(m_currentStep + 2, trader);
}

ulong CAQGDirectionEngine::FindLargestSellTicket()
{
   ulong largest = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t>0 && PositionGetInteger(POSITION_MAGIC)==m_magic && 
         PositionGetString(POSITION_SYMBOL)==m_symbol &&
         PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
      {
         if(t > largest) largest = t;
      }
   }
   return largest;
}

bool CAQGDirectionEngine::ClosePartialBestBuy(double lots, CAQGTradeExecutor &trader)
{
   ulong bestTicket = 0; double bestProfit = -1e9;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t>0 && PositionGetInteger(POSITION_MAGIC)==m_magic && 
         PositionGetString(POSITION_SYMBOL)==m_symbol &&
         PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
      {
         double vol = PositionGetDouble(POSITION_VOLUME);
         double prof = PositionGetDouble(POSITION_PROFIT);
         if(prof > bestProfit && vol >= lots) { bestProfit = prof; bestTicket = t; }
      }
   }
   return bestTicket > 0 ? trader.ClosePartial(bestTicket, lots) : false;
}

bool CAQGDirectionEngine::CancelBuyLimitAtStep(int step, CAQGTradeExecutor &trader)
{
   string target = "AQG_LGCY_BL_" + IntegerToString(step);
   bool cancelled = false;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t>0 && OrderGetInteger(ORDER_MAGIC)==m_magic && 
         OrderGetString(ORDER_SYMBOL)==m_symbol &&
         OrderGetInteger(ORDER_TYPE)==ORDER_TYPE_BUY_LIMIT &&
         StringFind(OrderGetString(ORDER_COMMENT), target) >= 0)
      {
         if(trader.DeleteOrder(t)) cancelled = true;
      }
   }
   return cancelled;
}

double CAQGDirectionEngine::CalcGridPrice(int step, bool isBelowAnchor, CAQGGridCalculator &grid)
{
   double anchor = grid.GetAnchorPrice();
   if(anchor <= 0) return 0;
   double stepPts = grid.CalculateDynamicStep();
   return isBelowAnchor ? anchor - (stepPts * step * m_point) : anchor + (stepPts * step * m_point);
}

double CAQGDirectionEngine::GetSafePrice(double price, bool isBuy)
{
   if(price <= 0) return 0;
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double buffer = 3.0 * m_point;
   return isBuy ? MathMin(price, bid - buffer) : MathMax(price, ask + buffer);
}