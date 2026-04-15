//+------------------------------------------------------------------+
//|                                          AQG_OverlapEngine.mqh   |
//|                          Adaptive Quant Grid - Smart Partial Overlap
//|                                         Версия: 1.01             |
//+------------------------------------------------------------------+
#property version   "1.01"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>
#include <AQG/TradeExecutor.mqh>

//+------------------------------------------------------------------+
//| 🔥 Класс умного перекрытия убытков                                |
//+------------------------------------------------------------------+
class CAQGOverlapEngine
{
private:
   string   m_symbol;
   int      m_magic;
   double   m_targetProfit;
   int      m_cooldownSec;
   datetime m_lastOverlapTime;

public:
   CAQGOverlapEngine();
   ~CAQGOverlapEngine();

   //--- Инициализация
   void Init(string symbol, int magic, double targetProfit, int cooldownMin);
   
   //--- Основной процесс поиска и закрытия пар
   bool ProcessOverlap(CAQGTradeExecutor &trader);
};

//+------------------------------------------------------------------+
//| Конструктор / Деструктор                                          |
//+------------------------------------------------------------------+
CAQGOverlapEngine::CAQGOverlapEngine() : m_lastOverlapTime(0) {}
CAQGOverlapEngine::~CAQGOverlapEngine() {}

//+------------------------------------------------------------------+
//| Инициализация                                                     |
//+------------------------------------------------------------------+
void CAQGOverlapEngine::Init(string symbol, int magic, double targetProfit, int cooldownMin)
{
   m_symbol        = symbol;
   m_magic         = magic;
   m_targetProfit  = targetProfit;
   m_cooldownSec   = cooldownMin * 60;
   m_lastOverlapTime = 0;

   AQG_LOG_INFO("OverlapEngine initialized | Target: $" + DoubleToString(targetProfit,2) + 
                " | Cooldown: " + IntegerToString(cooldownMin) + " min");
}

//+------------------------------------------------------------------+
//| 🔍 Поиск и исполнение перекрытия                                 |
//+------------------------------------------------------------------+
bool CAQGOverlapEngine::ProcessOverlap(CAQGTradeExecutor &trader)
{
   // 1. Проверка кулдауна
   if(TimeCurrent() - m_lastOverlapTime < m_cooldownSec) return false;

   // 2. Сбор лучших/худших позиций
   ulong bestBuy=0, worstBuy=0, bestSell=0, worstSell=0;
   double bestBuyP=0, worstBuyP=0, bestSellP=0, worstSellP=0;
   bool hasBB=false, hasBW=false, hasBS=false, hasWS=false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic || 
         PositionGetString(POSITION_SYMBOL) != m_symbol) continue;

      double p = PositionGetDouble(POSITION_PROFIT); // Net profit (вкл. своп/комиссию)
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         if(!hasBB || p > bestBuyP) { hasBB=true; bestBuy=t; bestBuyP=p; }
         if(!hasBW || p < worstBuyP) { hasBW=true; worstBuy=t; worstBuyP=p; }
      }
      else // SELL
      {
         if(!hasBS || p > bestSellP) { hasBS=true; bestSell=t; bestSellP=p; }
         if(!hasWS || p < worstSellP) { hasWS=true; worstSell=t; worstSellP=p; }
      }
   }

   // 3. Попытка пары №1: Лучший Buy + Худший Sell
   if(hasBB && hasWS)
   {
      double net = bestBuyP + worstSellP;
      if(net >= m_targetProfit)
      {
         if(trader.ClosePosition(bestBuy) && trader.ClosePosition(worstSell))
         {
            m_lastOverlapTime = TimeCurrent();
            AQG_LOG_SUCCESS("🔥 OVERLAP #1 | Buy#" + IntegerToString(bestBuy) + "($" + DoubleToString(bestBuyP,2) + ") + " +
                            "Sell#" + IntegerToString(worstSell) + "($" + DoubleToString(worstSellP,2) + ") = Net: $" + DoubleToString(net,2));
            return true;
         }
      }
   }

   // 4. Попытка пары №2: Лучший Sell + Худший Buy
   if(hasBS && hasBW)
   {
      double net = bestSellP + worstBuyP;
      if(net >= m_targetProfit)
      {
         if(trader.ClosePosition(bestSell) && trader.ClosePosition(worstBuy))
         {
            m_lastOverlapTime = TimeCurrent();
            AQG_LOG_SUCCESS("🔥 OVERLAP #2 | Sell#" + IntegerToString(bestSell) + "($" + DoubleToString(bestSellP,2) + ") + " +
                            "Buy#" + IntegerToString(worstBuy) + "($" + DoubleToString(worstBuyP,2) + ") = Net: $" + DoubleToString(net,2));
            return true;
         }
      }
   }

   return false;
}