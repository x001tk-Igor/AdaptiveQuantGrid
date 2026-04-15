//+------------------------------------------------------------------+
//|                                              AQG_UI_Panel.mqh    |
//|                          Adaptive Quant Grid - Professional Panel|
//|                                         Версия: 1.02             |
//+------------------------------------------------------------------+
#property version   "1.02"
#property strict

#include <AQG/Config.mqh>
#include <AQG/Logger.mqh>

struct SAQGPanelData
{
   ENUM_AQG_MARKET_MODE mode;
   ENUM_AQG_GRID_STATE  state;
   int                  currentStep;
   int                  maxStep;
   double               atrStepPts;
   double               basketProfit;
   bool                 trailingActive;
   double               trailingPeak;
   double               trailingDropPct;
   double               lastOverlapProfit;
   double               drawdownPct;
   double               freeMargin;
};

//+------------------------------------------------------------------+
//| 🖼️ Класс информационной панели                                   |
//+------------------------------------------------------------------+
class CAQGPanel
{
private:
   string m_prefix;
   int    m_x, m_y;
   int    m_lineH;
   datetime m_lastUpdate;

   // ✅ ИСПРАВЛЕНО: Оставлена ОДНА версия SetLabel с необязательным параметром fontSize
   void CreateLabel(string name, string text, int x, int y, color clr, int fontSize);
   void SetLabel(string name, string text, color clr, int fontSize);
   
   string FormatPct(double val);
   string FormatMoney(double val);

public:
   CAQGPanel();
   ~CAQGPanel();

   void Init(string symbol);
   void Update(const SAQGPanelData &data);
   void Delete();
};

//+------------------------------------------------------------------+
//| Конструктор / Деструктор                                          |
//+------------------------------------------------------------------+
CAQGPanel::CAQGPanel() : m_lastUpdate(0) {}
CAQGPanel::~CAQGPanel() { Delete(); }

//+------------------------------------------------------------------+
//| Инициализация панели                                              |
//+------------------------------------------------------------------+
void CAQGPanel::Init(string symbol)
{
   m_prefix = "AQG_UI_" + symbol + "_";
   m_x = 15; m_y = 20; m_lineH = 18;
   Delete();

   // Фон
   ObjectCreate(0, m_prefix+"BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_XDISTANCE, m_x-10);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_YDISTANCE, m_y-5);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_XSIZE, 240);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_YSIZE, 310);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_BACK, true);
   ObjectSetInteger(0, m_prefix+"BG", OBJPROP_SELECTABLE, false);

   // Заголовок
   CreateLabel("TITLE", "AQG PRO v1.07", m_x, m_y, clrGold, 11);
   m_y += 22;
   CreateLabel("SEP1", "──────────────────────────", m_x, m_y, clrGray, 9); m_y += m_lineH;

   // Секция 1: Режим и Сетка
   CreateLabel("MODE_LBL", "Regime:", m_x, m_y, clrWhite, 9);
   CreateLabel("MODE_VAL", "SCANNING", m_x+80, m_y, clrYellow, 9);
   m_y += m_lineH;

   CreateLabel("GRID_LBL", "Grid Step:", m_x, m_y, clrWhite, 9);
   CreateLabel("GRID_VAL", "0 / 12", m_x+80, m_y, clrWhite, 9);
   m_y += m_lineH;

   CreateLabel("ATR_LBL", "ATR Dist:", m_x, m_y, clrWhite, 9);
   CreateLabel("ATR_VAL", "--- pts", m_x+80, m_y, clrWhite, 9);
   m_y += m_lineH;
   CreateLabel("SEP2", "──────────────────────────", m_x, m_y, clrGray, 9); m_y += m_lineH;

   // Секция 2: Производительность
   CreateLabel("PL_LBL", "Basket P/L:", m_x, m_y, clrWhite, 9);
   CreateLabel("PL_VAL", "$0.00", m_x+85, m_y, clrLime, 9);
   m_y += m_lineH;

   CreateLabel("TRAIL_LBL", "Trailing:", m_x, m_y, clrWhite, 9);
   CreateLabel("TRAIL_VAL", "Inactive", m_x+85, m_y, clrGray, 9);
   m_y += m_lineH;

   CreateLabel("OVLAP_LBL", "Last Overlap:", m_x, m_y, clrWhite, 9);
   CreateLabel("OVLAP_VAL", "---", m_x+85, m_y, clrGray, 9);
   m_y += m_lineH;
   CreateLabel("SEP3", "──────────────────────────", m_x, m_y, clrGray, 9); m_y += m_lineH;

   // Секция 3: Риск
   CreateLabel("DD_LBL", "Drawdown:", m_x, m_y, clrWhite, 9);
   CreateLabel("DD_VAL", "0.0%", m_x+85, m_y, clrLime, 9);
   m_y += m_lineH;

   CreateLabel("MARGIN_LBL", "Free Margin:", m_x, m_y, clrWhite, 9);
   CreateLabel("MARGIN_VAL", "$0.00", m_x+85, m_y, clrWhite, 9);
   m_y += m_lineH;

   CreateLabel("STATUS_LBL", "Status:", m_x, m_y, clrWhite, 9);
   CreateLabel("STATUS_VAL", "READY", m_x+85, m_y, clrLime, 10);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Обновление значений                                               |
//+------------------------------------------------------------------+
void CAQGPanel::Update(const SAQGPanelData &data)
{
   if(TimeCurrent() - m_lastUpdate < 0.25) return;
   m_lastUpdate = TimeCurrent();

   // Режим
   color modeClr = (data.mode==MODE_FLAT) ? clrLimeGreen : (data.mode==MODE_TREND_UP ? clrDeepSkyBlue : clrOrangeRed);
   string modeTxt = (data.mode==MODE_FLAT) ? "FLAT" : (data.mode==MODE_TREND_UP ? "TREND ↑" : "TREND ↓");
   SetLabel("MODE_VAL", modeTxt, modeClr, 9);

   // Сетка
   string gridTxt = IntegerToString(data.currentStep) + " / " + IntegerToString(data.maxStep);
   color gridClr = (data.currentStep >= data.maxStep * 0.8) ? clrRed : clrWhite;
   SetLabel("GRID_VAL", gridTxt, gridClr, 9);
   SetLabel("ATR_VAL", DoubleToString(data.atrStepPts,1) + " pts", clrWhite, 9);

   // Прибыль
   SetLabel("PL_VAL", FormatMoney(data.basketProfit), data.basketProfit >= 0 ? clrLime : clrRed, 9);

   // Трейлинг
   if(data.trailingActive)
   {
      string trailTxt = "Peak $" + DoubleToString(data.trailingPeak,0);
      SetLabel("TRAIL_VAL", trailTxt, clrOrange, 9);
   }
   else
   {
      SetLabel("TRAIL_VAL", "Inactive", clrGray, 9);
   }

   // Оверлап
   if(data.lastOverlapProfit > 0)
      SetLabel("OVLAP_VAL", "+$" + DoubleToString(data.lastOverlapProfit,2), clrGold, 9);
   else
      SetLabel("OVLAP_VAL", "---", clrGray, 9);

   // Просадка
   SetLabel("DD_VAL", FormatPct(data.drawdownPct), data.drawdownPct < 10.0 ? clrLime : (data.drawdownPct < 15.0 ? clrOrange : clrRed), 9);

   // Маржа
   SetLabel("MARGIN_VAL", FormatMoney(data.freeMargin), clrWhite, 9);

   // Статус
   string stTxt = "ACTIVE";
   color stClr = clrLimeGreen;
   if(data.state == STATE_IDLE) { stTxt = "WAITING"; stClr = clrYellow; }
   if(data.state == STATE_EMERGENCY) { stTxt = "EMERGENCY"; stClr = clrRed; }
   SetLabel("STATUS_VAL", stTxt, stClr, 10);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Удаление панели                                                   |
//+------------------------------------------------------------------+
void CAQGPanel::Delete()
{
   int total = ObjectsTotal(0);
   for(int i=total-1; i>=0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, m_prefix) >= 0)
         ObjectDelete(0, name);
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Внутренние утилиты (ИСПРАВЛЕНО: единая сигнатура)                |
//+------------------------------------------------------------------+
void CAQGPanel::CreateLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   string obj = m_prefix + name;
   if(ObjectFind(0, obj) < 0)
   {
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj, OBJPROP_BACK, false);
      ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, obj, OBJPROP_FONT, "Consolas");
   }
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
}

// ✅ ИСПРАВЛЕНО: Одна функция с 4 параметрами, вызовы всегда передают все 4
void CAQGPanel::SetLabel(string name, string text, color clr, int fontSize)
{
   string obj = m_prefix + name;
   if(ObjectFind(0, obj) >= 0)
   {
      ObjectSetString(0, obj, OBJPROP_TEXT, text);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, fontSize);
   }
}

string CAQGPanel::FormatPct(double val) { return DoubleToString(val,1) + "%"; }
string CAQGPanel::FormatMoney(double val)
{
   return (val >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(val),2);
}