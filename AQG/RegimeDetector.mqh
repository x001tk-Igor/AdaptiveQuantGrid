//+------------------------------------------------------------------+
//|                                        AQG_RegimeDetector.mqh    |
//|                          Adaptive Quant Grid - Market Regime Filter|
//|                                         Версия: 1.00             |
//+------------------------------------------------------------------+
#property version   "1.00"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>

//+------------------------------------------------------------------+
//| 🧭 Класс определителя рыночного режима                           |
//+------------------------------------------------------------------+
class CAQGRegimeDetector
{
private:
   string   m_symbol;
   int      m_adxHandle;
   int      m_emaHandle;
   int      m_adxPeriod;
   int      m_emaPeriod;
   double   m_adxThreshold;
   int      m_hysteresisBars;
   
   ENUM_AQG_MARKET_MODE m_currentMode;
   ENUM_AQG_MARKET_MODE m_pendingMode;
   int                  m_stableCount;
   datetime             m_lastBarTime;

   double m_flatStepMult;
   double m_trendStepMult;

public:
   CAQGRegimeDetector();
   ~CAQGRegimeDetector();

   //--- Инициализация
   bool Init(string symbol, int adxPeriod, int emaPeriod, double adxThreshold, 
             int hysteresisBars, double flatMult = 0.7, double trendMult = 1.3);
   void Deinit();

   //--- Обновление состояния (вызывать раз в бар)
   void Update();

   //--- Геттеры
   ENUM_AQG_MARKET_MODE GetMode()          const { return m_currentMode; }
   bool                 IsBuyAllowed()     const { return m_currentMode == MODE_FLAT || m_currentMode == MODE_TREND_UP; }
   bool                 IsSellAllowed()    const { return m_currentMode == MODE_FLAT || m_currentMode == MODE_TREND_DOWN; }
   double               GetStepMultiplier() const { return (m_currentMode == MODE_FLAT) ? m_flatStepMult : m_trendStepMult; }
};

//+------------------------------------------------------------------+
//| Конструктор / Деструктор                                          |
//+------------------------------------------------------------------+
CAQGRegimeDetector::CAQGRegimeDetector() 
   : m_adxHandle(INVALID_HANDLE), m_emaHandle(INVALID_HANDLE), 
     m_currentMode(MODE_UNKNOWN), m_pendingMode(MODE_UNKNOWN), m_stableCount(0) {}

CAQGRegimeDetector::~CAQGRegimeDetector() { Deinit(); }

//+------------------------------------------------------------------+
//| Инициализация индикаторов и параметров                           |
//+------------------------------------------------------------------+
bool CAQGRegimeDetector::Init(string symbol, int adxPeriod, int emaPeriod, 
                              double adxThreshold, int hysteresisBars, 
                              double flatMult, double trendMult)
{
   m_symbol         = symbol;
   m_adxPeriod      = adxPeriod;
   m_emaPeriod      = emaPeriod;
   m_adxThreshold   = adxThreshold;
   m_hysteresisBars = hysteresisBars;
   m_flatStepMult   = flatMult;
   m_trendStepMult  = trendMult;

   m_adxHandle = iADX(symbol, PERIOD_H1, adxPeriod);
   m_emaHandle = iMA(symbol, PERIOD_H1, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(m_adxHandle == INVALID_HANDLE || m_emaHandle == INVALID_HANDLE)
   {
      AQG_LOG_ERROR("RegimeDetector: Failed to create indicator handles.");
      return false;
   }

   AQG_LOG_INFO("RegimeDetector initialized | ADX Thresh: " + DoubleToString(adxThreshold,1) + 
                " | Hyst: " + IntegerToString(hysteresisBars) + " bars | Flat×" + DoubleToString(flatMult,1) + " | Trend×" + DoubleToString(trendMult,1));
   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация                                                   |
//+------------------------------------------------------------------+
void CAQGRegimeDetector::Deinit()
{
   if(m_adxHandle != INVALID_HANDLE) IndicatorRelease(m_adxHandle);
   if(m_emaHandle != INVALID_HANDLE) IndicatorRelease(m_emaHandle);
   m_adxHandle = INVALID_HANDLE;
   m_emaHandle = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Обновление режима (вызывать на каждом баре H1)                   |
//+------------------------------------------------------------------+
void CAQGRegimeDetector::Update()
{
   datetime currentBarTime = iTime(m_symbol, PERIOD_H1, 0);
   if(currentBarTime == m_lastBarTime) return; // Пропускаем внутри бара
   m_lastBarTime = currentBarTime;

   double adx[], ema[];
   if(CopyBuffer(m_adxHandle, 0, 0, 1, adx) < 1 || CopyBuffer(m_emaHandle, 0, 0, 1, ema) < 1)
   {
      AQG_LOG_WARNING("RegimeDetector: Indicator buffer copy failed.");
      return;
   }

   double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   ENUM_AQG_MARKET_MODE rawMode;

   // Определение сырого режима
   if(adx[0] < m_adxThreshold)
      rawMode = MODE_FLAT;
   else
      rawMode = (price > ema[0]) ? MODE_TREND_UP : MODE_TREND_DOWN;

   // Логика гистерезиса: ждем подтверждения N баров
   if(rawMode != m_pendingMode)
   {
      m_pendingMode = rawMode;
      m_stableCount = 0;
   }
   else
   {
      m_stableCount++;
   }

   // Переключение режима только после стабильного подтверждения
   if(m_stableCount >= m_hysteresisBars && rawMode != m_currentMode)
   {
      AQG_LOG_INFO("🌍 Market regime changed: " + EnumToString(m_currentMode) + " -> " + EnumToString(rawMode));
      m_currentMode = rawMode;
   }
}