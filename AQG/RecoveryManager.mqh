//+------------------------------------------------------------------+
//|                                      AQG_RecoveryManager.mqh     |
//|                                         Версия: 1.04 (Fixed)     |
//+------------------------------------------------------------------+
#property version   "1.04"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>
#include <AQG/GridCalculator.mqh>
#include <AQG/TradeExecutor.mqh>
#include <AQG/RiskGuardian.mqh>

class CAQGRecoveryManager
{
private:
   string m_symbol; int m_magic; double m_point; int m_digits; bool m_isRecovered;
   double ReconstructAnchorPrice();
   int FindMaxExistingStep();
   bool ValidateRecoveredState(double anchor, int step);
   void CleanupOrphanedOrders(CAQGTradeExecutor &trader);

public:
   CAQGRecoveryManager(); ~CAQGRecoveryManager();
   bool Init(string symbol, int magic);
   bool Recover(CAQGGridCalculator &grid, CAQGTradeExecutor &trader, CAQGRiskGuardian &risk);
   bool IsRecovered() const { return m_isRecovered; }
};

CAQGRecoveryManager::CAQGRecoveryManager() : m_isRecovered(false) {}
CAQGRecoveryManager::~CAQGRecoveryManager() {}

bool CAQGRecoveryManager::Init(string symbol, int magic)
{
   m_symbol = symbol; m_magic = magic;
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_isRecovered = false;
   return true;
}

bool CAQGRecoveryManager::Recover(CAQGGridCalculator &grid, CAQGTradeExecutor &trader, CAQGRiskGuardian &risk)
{
   AQG_LOG_INFO("🔄 Recovery scan started...");
   int posCount = 0, ordCount = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) if(PositionGetTicket(i)>0 && PositionGetInteger(POSITION_MAGIC)==m_magic) posCount++;
   for(int i=OrdersTotal()-1; i>=0; i--)    if(OrderGetTicket(i)>0    && OrderGetInteger(ORDER_MAGIC)==m_magic)    ordCount++;

   if(posCount == 0 && ordCount == 0) { AQG_LOG_INFO("No trades found."); return false; }

   double recAnchor = ReconstructAnchorPrice();
   int recStep = FindMaxExistingStep();
   if(recAnchor <= 0) recAnchor = SymbolInfoDouble(m_symbol, SYMBOL_BID);

   if(!ValidateRecoveredState(recAnchor, recStep))
   {
      AQG_LOG_ERROR("⚠ Recovery validation failed. Resetting.");
      trader.CloseAllPositions(); trader.DeleteAllPendingOrders();
      return false;
   }

   grid.SetAnchorPrice(recAnchor); grid.Reset(); grid.SetAnchorPrice(recAnchor);
   CleanupOrphanedOrders(trader);
   m_isRecovered = true;
   AQG_LOG_SUCCESS("✅ Recovery complete");
   return true;
}

double CAQGRecoveryManager::ReconstructAnchorPrice()
{
   double buy1 = 0, sell1 = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic)
      {
         string c = OrderGetString(ORDER_COMMENT);
         if(c == "AQG_BL_1") buy1 = OrderGetDouble(ORDER_PRICE_OPEN);
         if(c == "AQG_SL_1") sell1 = OrderGetDouble(ORDER_PRICE_OPEN);
      }
   }
   if(buy1 > 0 && sell1 > 0) return NormalizeDouble((buy1 + sell1) / 2.0, m_digits);
   if(buy1 > 0) return buy1;
   return 0;
}

int CAQGRecoveryManager::FindMaxExistingStep()
{
   int maxStep = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic)
      {
         string c = OrderGetString(ORDER_COMMENT);
         int pos = StringFind(c, "_");
         if(pos >= 0)
         {
            int step = (int)StringToInteger(StringSubstr(c, pos + 1));
            if(step > maxStep) maxStep = step;
         }
      }
   }
   return maxStep;
}

bool CAQGRecoveryManager::ValidateRecoveredState(double anchor, int step)
{
   if(anchor <= 0 || step < 0) return false;
   
   // 🔹 ИСПРАВЛЕНО: Используем InpMaxStepPoints
   // 1.5 - коэффициент запаса
   double maxDist = step * InpMaxStepPoints * m_point * 1.5; 
   
   if(MathAbs(SymbolInfoDouble(m_symbol, SYMBOL_BID) - anchor) > maxDist)
   {
      AQG_LOG_WARNING("Price drift too large.");
      return false;
   }
   return true;
}

void CAQGRecoveryManager::CleanupOrphanedOrders(CAQGTradeExecutor &trader)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic)
      {
         if(StringFind(OrderGetString(ORDER_COMMENT), "AQG_") != 0)
            trader.DeleteOrder(ticket);
      }
   }
}