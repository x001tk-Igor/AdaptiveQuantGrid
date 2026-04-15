//+------------------------------------------------------------------+
//|                                        AQG_EquityTrailer.mqh     |
//|                          Adaptive Quant Grid - Basket Equity Trailing
//|                                         Версия: 1.02             |
//+------------------------------------------------------------------+
#property version   "1.02"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>
#include <AQG/TradeExecutor.mqh>
#include <AQG/GridCalculator.mqh>

//+------------------------------------------------------------------+
//| 📈 Класс трейлинга по корзине позиций                             |
//+------------------------------------------------------------------+
class CAQGEquityTrailer
{
private:
   string   m_symbol;
   int      m_magic;
   double   m_activationProfit;
   double   m_trailingDropPercent;
   int      m_checkIntervalSec;
   datetime m_lastCheckTime;

   bool     m_isActive;
   double   m_maxProfit;
   double   m_lastOverlapProfit;

   double GetBasketProfit() const;
   bool   HasOpenPositions() const;

public:
   CAQGEquityTrailer();
   ~CAQGEquityTrailer();

   void Init(string symbol, int magic, double actProfit, double dropPct, int checkSec);
   bool Update(CAQGTradeExecutor &trader, CAQGGridCalculator &grid, ENUM_AQG_GRID_STATE &gridState);
   void Reset();
   
   //--- Геттеры для UI
   bool   IsActive() const              { return m_isActive; }
   double GetMaxProfit() const          { return m_maxProfit; }
   double GetActivationProfit() const   { return m_activationProfit; }
   double GetDropPercent() const        { return m_trailingDropPercent; }
   double GetCurrentProfit() const      { return GetBasketProfit(); }
   double GetLastOverlapProfit() const  { return m_lastOverlapProfit; }
   
   //--- Сеттер для истории оверлапов
   void SetLastOverlapProfit(double profit);
};

//+------------------------------------------------------------------+
//| Конструктор / Деструктор                                          |
//+------------------------------------------------------------------+
CAQGEquityTrailer::CAQGEquityTrailer() 
   : m_isActive(false), m_maxProfit(0.0), m_lastCheckTime(0), m_lastOverlapProfit(0.0) {}

CAQGEquityTrailer::~CAQGEquityTrailer() {}

//+------------------------------------------------------------------+
//| Инициализация                                                     |
//+------------------------------------------------------------------+
void CAQGEquityTrailer::Init(string symbol, int magic, double actProfit, double dropPct, int checkSec)
{
   m_symbol              = symbol;
   m_magic               = magic;
   m_activationProfit    = MathMax(0.1, actProfit);
   m_trailingDropPercent = MathMax(1.0, MathMin(99.0, dropPct));
   m_checkIntervalSec    = MathMax(1, checkSec);
   Reset();

   AQG_LOG_INFO("EquityTrailer initialized | Act: $" + DoubleToString(m_activationProfit,2) + 
                " | Drop: " + DoubleToString(m_trailingDropPercent,1) + "% | Check: " + IntegerToString(m_checkIntervalSec) + "s");
}

//+------------------------------------------------------------------+
//| 📊 Расчёт суммарной прибыли корзины                              |
//+------------------------------------------------------------------+
double CAQGEquityTrailer::GetBasketProfit() const
{
   double total = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && 
         PositionGetInteger(POSITION_MAGIC) == m_magic && 
         PositionGetString(POSITION_SYMBOL) == m_symbol)
      {
         // ✅ ИСПРАВЛЕНО: POSITION_COMMISSION устарел, прибыль уже включает своп и комиссию
         total += PositionGetDouble(POSITION_PROFIT);
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| 🔍 Проверка наличия открытых позиций                             |
//+------------------------------------------------------------------+
bool CAQGEquityTrailer::HasOpenPositions() const
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && 
         PositionGetInteger(POSITION_MAGIC) == m_magic && 
         PositionGetString(POSITION_SYMBOL) == m_symbol)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| 🔄 Основной цикл трейлинга                                       |
//+------------------------------------------------------------------+
bool CAQGEquityTrailer::Update(CAQGTradeExecutor &trader, CAQGGridCalculator &grid, ENUM_AQG_GRID_STATE &gridState)
{
   if(TimeCurrent() - m_lastCheckTime < m_checkIntervalSec) 
      return false;
   m_lastCheckTime = TimeCurrent();

   if(!HasOpenPositions())
   {
      if(m_isActive)
      {
         AQG_LOG_INFO("📈 Trailing reset: no open positions");
         Reset();
      }
      return false;
   }

   double currentProfit = GetBasketProfit();

   if(!m_isActive)
   {
      if(currentProfit >= m_activationProfit)
      {
         m_isActive   = true;
         m_maxProfit  = currentProfit;
         AQG_LOG_INFO("📈 TRAILING ACTIVATED | Peak: $" + DoubleToString(m_maxProfit,2));
      }
      return false;
   }

   if(currentProfit > m_maxProfit)
      m_maxProfit = currentProfit;

   double dropPct = 0.0;
   if(m_maxProfit > 0.01)
      dropPct = ((m_maxProfit - currentProfit) / m_maxProfit) * 100.0;

   bool shouldClose = false;
   string closeReason = "";

   if(currentProfit <= 0.0)
   {
      shouldClose = true;
      closeReason = "Profit turned negative";
   }
   else if(dropPct >= m_trailingDropPercent)
   {
      shouldClose = true;
      closeReason = "Retracement " + DoubleToString(dropPct,1) + "% >= " + DoubleToString(m_trailingDropPercent,1) + "%";
   }

   if(shouldClose)
   {
      AQG_LOG_SUCCESS("🔒 EQUITY TRAIL EXIT | " + closeReason + 
                      " | Peak: $" + DoubleToString(m_maxProfit,2) + 
                      " | Final: $" + DoubleToString(currentProfit,2));
      
      trader.CloseAllPositions();
      trader.DeleteAllPendingOrders();
      grid.Reset();
      gridState = STATE_IDLE;
      Reset();
      
      if(InpEnablePushNotify)
         SendNotification("✅ AQG Cycle Closed | P/L: $" + DoubleToString(currentProfit,2) + " | " + _Symbol);
      
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| 🧹 Сброс состояния трейлера                                      |
//+------------------------------------------------------------------+
void CAQGEquityTrailer::Reset()
{
   m_isActive      = false;
   m_maxProfit     = 0.0;
   m_lastCheckTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| 📝 Установка последнего профита оверлапа (для UI)                |
//+------------------------------------------------------------------+
void CAQGEquityTrailer::SetLastOverlapProfit(double profit)
{
   m_lastOverlapProfit = profit;
}