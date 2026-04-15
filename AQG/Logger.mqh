//+------------------------------------------------------------------+
//|                                              AQG_Logger.mqh      |
//|                                   Adaptive Quant Grid - Logger   |
//|                                         Версия: 1.00             |
//+------------------------------------------------------------------+
#property version   "1.00"
#property strict

#include <AQG/Config.mqh>

//+------------------------------------------------------------------+
//| 📊 Уровни логирования                                             |
//+------------------------------------------------------------------+
enum ENUM_AQG_LOG_LEVEL
{
   LOG_OFF    = 0,   // Отключено
   LOG_ERROR  = 1,   // Только ошибки
   LOG_INFO   = 2,   // Ошибки + информация
   LOG_DEBUG  = 3    // Всё + отладочные сообщения
};

//+------------------------------------------------------------------+
//| 🎨 Цвета для разных уровней (для печати в журнал)                 |
//+------------------------------------------------------------------+
class CAQGLogger
{
private:
   static string   m_Prefix;           // Префикс для логов (символ + таймфрейм)
   static int      m_LogLevel;         // Текущий уровень логирования
   static datetime m_LastMessageTime;  // Время последнего сообщения (для троттлинга)
   static int      m_MessageCount;     // Счётчик сообщений за интервал
   
public:
   //--- Инициализация логгера
   static void Init(string symbol, int timeframe, int logLevel)
   {
      m_Prefix = "[" + symbol + ":" + TimeframeToString(timeframe) + "]";
      m_LogLevel = logLevel;
      m_LastMessageTime = 0;
      m_MessageCount = 0;
      
      Info("Logger initialized. Level: " + EnumToString((ENUM_AQG_LOG_LEVEL)logLevel));
   }
   
   //--- 🔴 Ошибка (всегда пишется)
   static void Error(string message, int errorCode = 0)
   {
      string fullMsg = m_Prefix + " 🔴 ERROR: " + message;
      if(errorCode > 0) fullMsg += " | Code: " + IntegerToString(errorCode);
      
      Print(fullMsg);
      SendNotification(fullMsg);  // Опционально: пуш-уведомление
   }
   
   //--- 🟡 Информация (если уровень >= INFO)
   static void Info(string message)
   {
      if(m_LogLevel < LOG_INFO) return;
      if(ShouldThrottle()) return;
      
      Print(m_Prefix + " 🟡 INFO: " + message);
   }
   
   //--- 🔵 Отладка (если уровень >= DEBUG)
   static void Debug(string message)
   {
      if(m_LogLevel < LOG_DEBUG) return;
      if(ShouldThrottle()) return;
      
      Print(m_Prefix + " 🔵 DEBUG: " + message);
   }
   
   //--- 🟢 Успех / важное событие
   static void Success(string message)
   {
      if(m_LogLevel < LOG_INFO) return;
      
      Print(m_Prefix + " 🟢 SUCCESS: " + message);
      if(InpEnablePushNotify) SendNotification(m_Prefix + " ✅ " + message);
   }
   
   //--- ⚠️ Предупреждение
   static void Warning(string message)
   {
      if(m_LogLevel < LOG_INFO) return;
      
      Print(m_Prefix + " ⚠️ WARNING: " + message);
   }
   
   //--- 🔄 Троттлинг: не более N сообщений в секунду (защита от спама)
   private:
   static bool ShouldThrottle()
   {
      datetime now = TimeCurrent();
      if(now == m_LastMessageTime)
      {
         m_MessageCount++;
         if(m_MessageCount > 5) return true;  // Макс. 5 сообщений в секунду
      }
      else
      {
         m_LastMessageTime = now;
         m_MessageCount = 1;
      }
      return false;
   }
   
   //--- Вспомогательная: таймфрейм в строку
   static string TimeframeToString(int tf)
   {
      switch(tf)
      {
         case PERIOD_M1:  return "M1";
         case PERIOD_M5:  return "M5";
         case PERIOD_M15: return "M15";
         case PERIOD_H1:  return "H1";
         case PERIOD_H4:  return "H4";
         case PERIOD_D1:  return "D1";
         default:         return "Unknown";
      }
   }
};

//--- Глобальные переменные класса
string   CAQGLogger::m_Prefix = "";
int      CAQGLogger::m_LogLevel = LOG_INFO;
datetime CAQGLogger::m_LastMessageTime = 0;
int      CAQGLogger::m_MessageCount = 0;

//+------------------------------------------------------------------+
//| 📦 Макросы для удобного вызова (опционально)                     |
//+------------------------------------------------------------------+
#define AQG_LOG_ERROR(msg)    CAQGLogger::Error(msg, GetLastError())
#define AQG_LOG_INFO(msg)     CAQGLogger::Info(msg)
#define AQG_LOG_DEBUG(msg)    CAQGLogger::Debug(msg)
#define AQG_LOG_SUCCESS(msg)  CAQGLogger::Success(msg)
#define AQG_LOG_WARNING(msg)  CAQGLogger::Warning(msg)