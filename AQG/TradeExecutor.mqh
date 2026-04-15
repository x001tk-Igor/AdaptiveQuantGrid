//+------------------------------------------------------------------+
//|                                          AQG_TradeExecutor.mqh   |
//|                            Adaptive Quant Grid - Trade Execution |
//|                                         Версия: 1.03 (Fixed)     |
//+------------------------------------------------------------------+
#property version   "1.03"
#property strict

#include <Trade\Trade.mqh>
#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>

//+------------------------------------------------------------------+
//| 🛠️ Класс исполнителя ордеров                                     |
//+------------------------------------------------------------------+
class CAQGTradeExecutor
{
private:
   CTrade m_trade;
   int    m_magic;
   string m_symbol;
   int    m_digits;
   double m_point;
   double m_lotStep;
   double m_minLot;
   double m_maxLot;

   bool CheckMargin(double volume);
   double NormalizeLot(double volume);

public:
   CAQGTradeExecutor();
   ~CAQGTradeExecutor();
   
   void Init(int magic, string symbol);
   
   bool MarketBuy(double volume, double sl, double tp, string comment);
   bool MarketSell(double volume, double sl, double tp, string comment);
   bool BuyLimit(double volume, double price, double sl, double tp, string comment, ENUM_ORDER_TYPE_TIME timeMode = ORDER_TIME_GTC);
   bool SellLimit(double volume, double price, double sl, double tp, string comment, ENUM_ORDER_TYPE_TIME timeMode = ORDER_TIME_GTC);
   
   bool ClosePosition(ulong ticket);
   bool ClosePartial(ulong ticket, double volume);
   bool DeleteOrder(ulong ticket);
   bool CloseAllPositions();
   bool DeleteAllPendingOrders();
   bool DeleteAllPendingOrdersForce();
   
   string GetLastResultComment() const { return m_trade.ResultComment(); }
   uint   GetLastRetCode() const       { return m_trade.ResultRetcode(); }
};

//+------------------------------------------------------------------+
//| Конструктор / Деструктор                                          |
//+------------------------------------------------------------------+
CAQGTradeExecutor::CAQGTradeExecutor() {}
CAQGTradeExecutor::~CAQGTradeExecutor() {}

//+------------------------------------------------------------------+
//| Инициализация                                                     |
//+------------------------------------------------------------------+
void CAQGTradeExecutor::Init(int magic, string symbol)
{
   m_magic = magic;
   m_symbol = symbol;
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_point  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_lotStep = MathMax(0.001, SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP));
   m_minLot = MathMax(0.01, SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN));
   m_maxLot = MathMin(100.0, SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX));
   
   m_trade.SetExpertMagicNumber(m_magic);
   m_trade.SetDeviationInPoints(10);
   
   AQG_LOG_INFO("TradeExecutor initialized for " + m_symbol + " | Magic: " + IntegerToString(m_magic));
}

//+------------------------------------------------------------------+
//| Рыночный BUY                                                      |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::MarketBuy(double volume, double sl, double tp, string comment)
{
   if(!CheckMargin(volume)) return false;
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   sl = (sl > 0) ? NormalizeDouble(sl, m_digits) : 0;
   tp = (tp > 0) ? NormalizeDouble(tp, m_digits) : 0;
   
   bool res = m_trade.Buy(NormalizeLot(volume), m_symbol, ask, sl, tp, comment);
   if(res)
      AQG_LOG_SUCCESS("Market BUY executed | Vol: " + DoubleToString(volume,2) + " @ " + DoubleToString(ask, m_digits));
   else
      AQG_LOG_ERROR("Market BUY failed | Code: " + IntegerToString(GetLastRetCode()));
   return res;
}

//+------------------------------------------------------------------+
//| Рыночный SELL                                                     |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::MarketSell(double volume, double sl, double tp, string comment)
{
   if(!CheckMargin(volume)) return false;
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   sl = (sl > 0) ? NormalizeDouble(sl, m_digits) : 0;
   tp = (tp > 0) ? NormalizeDouble(tp, m_digits) : 0;
   
   bool res = m_trade.Sell(NormalizeLot(volume), m_symbol, bid, sl, tp, comment);
   if(res)
      AQG_LOG_SUCCESS("Market SELL executed | Vol: " + DoubleToString(volume,2) + " @ " + DoubleToString(bid, m_digits));
   else
      AQG_LOG_ERROR("Market SELL failed | Code: " + IntegerToString(GetLastRetCode()));
   return res;
}

//+------------------------------------------------------------------+
//| Buy Limit                                                         |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::BuyLimit(double volume, double price, double sl, double tp, string comment, ENUM_ORDER_TYPE_TIME timeMode)
{
   price = NormalizeDouble(price, m_digits);
   sl = (sl > 0) ? NormalizeDouble(sl, m_digits) : 0;
   tp = (tp > 0) ? NormalizeDouble(tp, m_digits) : 0;
   
   bool res = m_trade.BuyLimit(NormalizeLot(volume), price, m_symbol, sl, tp, timeMode, 0, comment);
   if(res)
      AQG_LOG_SUCCESS("Buy Limit placed @ " + DoubleToString(price, m_digits));
   else
      AQG_LOG_ERROR("Buy Limit failed | Code: " + IntegerToString(GetLastRetCode()));
   return res;
}

//+------------------------------------------------------------------+
//| Sell Limit                                                        |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::SellLimit(double volume, double price, double sl, double tp, string comment, ENUM_ORDER_TYPE_TIME timeMode)
{
   price = NormalizeDouble(price, m_digits);
   sl = (sl > 0) ? NormalizeDouble(sl, m_digits) : 0;
   tp = (tp > 0) ? NormalizeDouble(tp, m_digits) : 0;
   
   bool res = m_trade.SellLimit(NormalizeLot(volume), price, m_symbol, sl, tp, timeMode, 0, comment);
   if(res)
      AQG_LOG_SUCCESS("Sell Limit placed @ " + DoubleToString(price, m_digits));
   else
      AQG_LOG_ERROR("Sell Limit failed | Code: " + IntegerToString(GetLastRetCode()));
   return res;
}

//+------------------------------------------------------------------+
//| Закрытие позиции                                                  |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::ClosePosition(ulong ticket)
{
   bool res = m_trade.PositionClose(ticket);
   if(res) AQG_LOG_SUCCESS("Position closed | Ticket: " + IntegerToString(ticket));
   else AQG_LOG_ERROR("Close failed | Ticket: " + IntegerToString(ticket));
   return res;
}

//+------------------------------------------------------------------+
//| Частичное закрытие                                                |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::ClosePartial(ulong ticket, double volume)
{
   bool res = m_trade.PositionClosePartial(ticket, NormalizeLot(volume));
   if(res) AQG_LOG_SUCCESS("Partial close | Ticket: " + IntegerToString(ticket));
   else AQG_LOG_ERROR("Partial close failed | Ticket: " + IntegerToString(ticket));
   return res;
}

//+------------------------------------------------------------------+
//| Удаление ордера (ИСПРАВЛЕНО: используем m_trade.OrderDelete)     |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::DeleteOrder(ulong ticket)
{
   // ✅ ИСПРАВЛЕНО: Используем метод класса CTrade
   bool res = m_trade.OrderDelete(ticket);
   if(res) 
      AQG_LOG_SUCCESS("Order deleted | Ticket: " + IntegerToString(ticket));
   else 
      AQG_LOG_ERROR("Delete failed | Ticket: " + IntegerToString(ticket) + " | Code: " + IntegerToString(GetLastRetCode()));
   return res;
}

//+------------------------------------------------------------------+
//| Закрытие всех позиций                                             |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::CloseAllPositions()
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == m_magic && 
         PositionGetString(POSITION_SYMBOL) == m_symbol)
      {
         if(ClosePosition(ticket)) closed++;
      }
   }
   AQG_LOG_INFO("CloseAllPositions completed. Closed: " + IntegerToString(closed));
   return closed > 0;
}

//+------------------------------------------------------------------+
//| Удаление всех ордеров по Magic (ИСПРАВЛЕНО)                      |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::DeleteAllPendingOrders()
{
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetInteger(ORDER_MAGIC) == m_magic && 
         OrderGetString(ORDER_SYMBOL) == m_symbol)
      {
         // ✅ ИСПРАВЛЕНО: Используем m_trade.OrderDelete()
         if(m_trade.OrderDelete(ticket)) 
            deleted++;
      }
   }
   AQG_LOG_INFO("DeleteAllPendingOrders completed. Deleted: " + IntegerToString(deleted));
   return deleted > 0;
}

//+------------------------------------------------------------------+
//| 🔥 Принудительное удаление ВСЕХ ордеров (ИСПРАВЛЕНО)             |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::DeleteAllPendingOrdersForce()
{
   int deleted = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == m_symbol)
      {
         // ✅ ИСПРАВЛЕНО: Используем m_trade.OrderDelete()
         if(m_trade.OrderDelete(ticket)) 
            deleted++;
      }
   }
   AQG_LOG_SUCCESS("Force delete completed. Deleted: " + IntegerToString(deleted));
   return deleted > 0;
}

//+------------------------------------------------------------------+
//| 🔒 Внутренние методы                                             |
//+------------------------------------------------------------------+
bool CAQGTradeExecutor::CheckMargin(double volume)
{
   double marginRequired = SymbolInfoDouble(m_symbol, SYMBOL_MARGIN_INITIAL);
   if(marginRequired <= 0)
   {
      AQG_LOG_WARNING("⚠️ Unable to check margin for " + m_symbol);
      return true;
   }
   
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double estimatedMargin = marginRequired * volume;
   
   if(freeMargin < estimatedMargin * 1.5)
   {
      AQG_LOG_WARNING("Insufficient margin. Est: $" + DoubleToString(estimatedMargin,2) + 
                      " | Free: $" + DoubleToString(freeMargin,2));
      return false;
   }
   return true;
}

double CAQGTradeExecutor::NormalizeLot(double volume)
{
   volume = MathMax(m_minLot, MathMin(m_maxLot, volume));
   if(m_lotStep > 0) volume = MathFloor(volume / m_lotStep) * m_lotStep;
   return NormalizeDouble(volume, 2);
}