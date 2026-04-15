//+------------------------------------------------------------------+
//|                                          AQG_RiskGuardian.mqh    |
//|                            Adaptive Quant Grid - Risk Management |
//|                                         Версия: 1.03             |
//+------------------------------------------------------------------+
#property version   "1.03"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>

//+------------------------------------------------------------------+
//| 🛡️ Класс управления рисками                                      |
//+------------------------------------------------------------------+
class CAQGRiskGuardian
{
private:
   ENUM_AQG_RISK_PROFILE m_profile;
   double m_maxDrawdownPct;
   int    m_maxAllowedDepth;
   double m_riskPerTradePct;
   double m_lotMultiplier;
   double m_startBalance;
   bool   m_isInitialized;

public:
   CAQGRiskGuardian();
   ~CAQGRiskGuardian();

   bool Init(ENUM_AQG_RISK_PROFILE profile);
   void UpdateState();
   bool CheckEquityDrawdown();
   bool CheckMaxGridDepth(int currentStep);
   double GetRiskPercent() const { return m_riskPerTradePct; }
   double GetLotMultiplier() const { return m_lotMultiplier; }
   int    GetMaxDepth() const { return m_maxAllowedDepth; }
};

//+------------------------------------------------------------------+
//| Конструктор / Деструктор                                          |
//+------------------------------------------------------------------+
CAQGRiskGuardian::CAQGRiskGuardian() : m_isInitialized(false) {}
CAQGRiskGuardian::~CAQGRiskGuardian() {}

//+------------------------------------------------------------------+
//| Инициализация (ИСПРАВЛЕНО: корректный вызов методов Config)      |
//+------------------------------------------------------------------+
bool CAQGRiskGuardian::Init(ENUM_AQG_RISK_PROFILE profile)
{
   m_profile = profile;
   m_maxDrawdownPct  = CAQGConfig::GetMaxDrawdown(profile);
   m_maxAllowedDepth = CAQGConfig::GetMaxDepth(profile);
   m_riskPerTradePct = InpRiskPerTradePercent * CAQGConfig::GetLotMultiplier(profile);
   m_lotMultiplier   = CAQGConfig::GetLotMultiplier(profile);
   m_startBalance    = AccountInfoDouble(ACCOUNT_BALANCE);
   m_isInitialized   = true;

   AQG_LOG_INFO("RiskGuardian init | Profile: " + EnumToString(profile) + 
                " | Risk: " + DoubleToString(m_riskPerTradePct,2) + "% | MaxDD: " + DoubleToString(m_maxDrawdownPct,1) + "%");
   return true;
}

//+------------------------------------------------------------------+
//| Обновление состояния                                              |
//+------------------------------------------------------------------+
void CAQGRiskGuardian::UpdateState()
{
   if(!m_isInitialized) return;
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currentBalance > m_startBalance) m_startBalance = currentBalance;
}

//+------------------------------------------------------------------+
//| Проверка просадки эквити                                          |
//+------------------------------------------------------------------+
bool CAQGRiskGuardian::CheckEquityDrawdown()
{
   if(!m_isInitialized) return false;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return false;
   
   double drawdownPct = ((balance - equity) / balance) * 100.0;
   
   if(drawdownPct >= m_maxDrawdownPct)
   {
      AQG_LOG_ERROR("🔴 Drawdown limit breached! Current: " + DoubleToString(drawdownPct,2) + "% | Limit: " + DoubleToString(m_maxDrawdownPct,1) + "%");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Проверка глубины сетки                                            |
//+------------------------------------------------------------------+
bool CAQGRiskGuardian::CheckMaxGridDepth(int currentStep)
{
   if(currentStep >= m_maxAllowedDepth)
   {
      AQG_LOG_WARNING("⚠ Max grid depth reached: " + IntegerToString(currentStep) + "/" + IntegerToString(m_maxAllowedDepth));
      return true;
   }
   return false;
}