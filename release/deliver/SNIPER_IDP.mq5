//+------------------------------------------------------------------+
//| SNIPER_IDP.mq5                                                    |
//| SNIPER Institutional Displacement Pulse                           |
//| BUILD_ID: IDP_1                                                   |
//| The one companion indicator for SNIPER AI                         |
//| Not RSI/MACD/Stoch — structure + liquidity + displacement pulse   |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "SNIPER IDP — Institutional Displacement Pulse"
#property description "Scores BOS pressure + sweep wick + displacement + trend side into ONE pulse"
#property description "Optional visual companion. Same pulse is built into SNIPER_AI_OK74."
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

#property indicator_label1  "IDP Pulse"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "IDP Bull Strong"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrLime
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

#property indicator_label3  "IDP Bear Strong"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

#property indicator_minimum -100
#property indicator_maximum  100
#property indicator_level1   70
#property indicator_level2   45
#property indicator_level3    0
#property indicator_level4  -45
#property indicator_level5  -70
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- inputs
input group "SNIPER IDP — Institutional Displacement Pulse"
input int    ATR_Period              = 14;
input int    EMA_Period              = 50;     // trend-side reference
input int    SwingLookback           = 5;      // bars for swing high/low reference
input double SweepMinWickRatio       = 0.33;   // wick share of bar for sweep pressure
input double SweepMinDepthATR        = 0.08;   // sweep beyond prior extreme
input double DispMinBodyRatio        = 0.48;   // displacement body/range
input double DispMinATR              = 0.35;   // displacement range vs ATR
input double StrongThreshold         = 70.0;   // STRONG pulse |value|
input double QualityThreshold        = 45.0;   // QUALITY pulse |value|
input bool   ShowStrongOnlyHighlight = true;   // color strong bars lime/red
input bool   DrawSignalArrows        = true;   // arrows when pulse hits STRONG with side match

//--- buffers
double PulseBuffer[];
double BullStrongBuffer[];
double BearStrongBuffer[];
double StateBuffer[]; // internal: +1 bull strong, -1 bear strong, 0 else

int atrHandle = INVALID_HANDLE;
int emaHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, PulseBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BullStrongBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BearStrongBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, StateBuffer, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(PulseBuffer, true);
   ArraySetAsSeries(BullStrongBuffer, true);
   ArraySetAsSeries(BearStrongBuffer, true);
   ArraySetAsSeries(StateBuffer, true);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   IndicatorSetString(INDICATOR_SHORTNAME,
                      StringFormat("SNIPER IDP (ATR%d EMA%d)  STRONG±%.0f  QUALITY±%.0f",
                                   ATR_Period, EMA_Period, StrongThreshold, QualityThreshold));
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   emaHandle = iMA(_Symbol, PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   if(atrHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE)
   {
      Print("SNIPER IDP: failed to create ATR/EMA handles");
      return(INIT_FAILED);
   }

   Print("SNIPER IDP Loaded BUILD_ID=IDP_1 — Institutional Displacement Pulse");
   Print("Companion to SNIPER AI: STRONG when |pulse|>=", StrongThreshold,
         " QUALITY when |pulse|>=", QualityThreshold);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
   ObjectsDeleteAll(0, "SNIPER_IDP_");
}

//+------------------------------------------------------------------+
double SafeATR(const int shift)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(atrHandle, 0, shift, 1, buf) != 1)
      return 0.0;
   return buf[0];
}

double SafeEMA(const int shift)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(emaHandle, 0, shift, 1, buf) != 1)
      return 0.0;
   return buf[0];
}

double PriorSwingHigh(const int shift)
{
   double h = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   for(int j = shift + 2; j <= shift + 1 + SwingLookback; j++)
   {
      double v = iHigh(_Symbol, PERIOD_CURRENT, j);
      if(v > h) h = v;
   }
   return h;
}

double PriorSwingLow(const int shift)
{
   double l = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   for(int j = shift + 2; j <= shift + 1 + SwingLookback; j++)
   {
      double v = iLow(_Symbol, PERIOD_CURRENT, j);
      if(v > 0.0 && v < l) l = v;
   }
   return l;
}

// Sweep pressure: + for sell-side taken (bullish fuel), - for buy-side taken (bearish fuel)
double SweepScore(const int shift, const double atr)
{
   double hi = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double lo = iLow(_Symbol, PERIOD_CURRENT, shift);
   double cl = iClose(_Symbol, PERIOD_CURRENT, shift);
   double range = hi - lo;
   if(range <= 0.0 || atr <= 0.0)
      return 0.0;

   double priorHigh = PriorSwingHigh(shift);
   double priorLow  = PriorSwingLow(shift);
   double minDepth  = atr * SweepMinDepthATR;
   double score = 0.0;

   // sell-side liquidity taken (lows swept, close back above) → bullish pulse
   if(lo < priorLow - minDepth && cl > priorLow)
   {
      double wick = MathMin(cl, priorLow) - lo;
      double ratio = wick / range;
      if(ratio >= SweepMinWickRatio)
         score += 25.0 * MathMin(ratio / 0.6, 1.5);
   }

   // buy-side liquidity taken (highs swept, close back below) → bearish pulse
   if(hi > priorHigh + minDepth && cl < priorHigh)
   {
      double wick = hi - MathMax(cl, priorHigh);
      double ratio = wick / range;
      if(ratio >= SweepMinWickRatio)
         score -= 25.0 * MathMin(ratio / 0.6, 1.5);
   }
   return score;
}

// Displacement impulse along close direction
double DisplacementScore(const int shift, const double atr)
{
   double o = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double c = iClose(_Symbol, PERIOD_CURRENT, shift);
   double h = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double l = iLow(_Symbol, PERIOD_CURRENT, shift);
   double range = h - l;
   if(range <= 0.0)
      return 0.0;

   double body = MathAbs(c - o);
   double bodyRatio = body / range;
   if(bodyRatio < DispMinBodyRatio)
      return 0.0;
   if(atr > 0.0 && range < atr * DispMinATR)
      return 0.0;

   double mag = 35.0 * MathMin(bodyRatio / 0.7, 1.4);
   if(atr > 0.0)
      mag *= MathMin(range / (atr * 0.8), 1.5);

   return (c > o) ? mag : -mag;
}

// Directional BOS-style pressure vs prior swing
double BosScore(const int shift, const double atr)
{
   double c1 = iClose(_Symbol, PERIOD_CURRENT, shift);
   double c2 = iClose(_Symbol, PERIOD_CURRENT, shift + 1);
   double swingHigh = PriorSwingHigh(shift);
   double swingLow  = PriorSwingLow(shift);
   double margin = (atr > 0.0) ? (atr * 0.10) : 0.0;

   if(c2 <= swingHigh && c1 > swingHigh + margin)
      return 20.0;
   if(c2 >= swingLow && c1 < swingLow - margin)
      return -20.0;
   return 0.0;
}

// Trend-side continuity vs EMA
double TrendSideScore(const int shift)
{
   double ema = SafeEMA(shift);
   double c = iClose(_Symbol, PERIOD_CURRENT, shift);
   if(ema <= 0.0 || c <= 0.0)
      return 0.0;
   if(c > ema) return 10.0;
   if(c < ema) return -10.0;
   return 0.0;
}

// Optional body expansion vs previous bar (continuation fuel)
double ExpansionScore(const int shift)
{
   double r0 = iHigh(_Symbol, PERIOD_CURRENT, shift) - iLow(_Symbol, PERIOD_CURRENT, shift);
   double r1 = iHigh(_Symbol, PERIOD_CURRENT, shift + 1) - iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   if(r1 <= 0.0 || r0 <= 0.0)
      return 0.0;
   if(r0 < r1 * 1.15)
      return 0.0;
   double c = iClose(_Symbol, PERIOD_CURRENT, shift);
   double o = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double boost = 10.0 * MathMin(r0 / r1, 2.0);
   return (c > o) ? boost : -boost;
}

double ClampPulse(const double v)
{
   if(v > 100.0) return 100.0;
   if(v < -100.0) return -100.0;
   return v;
}

void ClearArrow(const int shift)
{
   string up = "SNIPER_IDP_UP_" + IntegerToString(shift);
   string dn = "SNIPER_IDP_DN_" + IntegerToString(shift);
   ObjectDelete(0, up);
   ObjectDelete(0, dn);
}

void DrawArrow(const int shift, const bool bull)
{
   if(!DrawSignalArrows)
      return;
   datetime t = iTime(_Symbol, PERIOD_CURRENT, shift);
   if(t <= 0) return;

   string name = bull ? ("SNIPER_IDP_UP_" + IntegerToString((int)t))
                      : ("SNIPER_IDP_DN_" + IntegerToString((int)t));
   if(ObjectFind(0, name) >= 0)
      return;

   double price = bull ? iLow(_Symbol, PERIOD_CURRENT, shift)
                       : iHigh(_Symbol, PERIOD_CURRENT, shift);
   ObjectCreate(0, name, bull ? OBJ_ARROW_UP : OBJ_ARROW_DOWN, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bull ? clrLime : clrOrangeRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < ATR_Period + SwingLookback + 10)
      return 0;

   int limit;
   if(prev_calculated == 0)
   {
      ArrayInitialize(PulseBuffer, 0.0);
      ArrayInitialize(BullStrongBuffer, 0.0);
      ArrayInitialize(BearStrongBuffer, 0.0);
      ArrayInitialize(StateBuffer, 0.0);
      limit = rates_total - (ATR_Period + SwingLookback + 3);
   }
   else
      limit = rates_total - prev_calculated + 2;

   if(limit > rates_total - 3)
      limit = rates_total - 3;
   if(limit < 1)
      limit = 1;

   for(int i = limit; i >= 1; i--) // skip forming bar 0 for stable pulse
   {
      double atr = SafeATR(i);
      double pulse = 0.0;
      pulse += SweepScore(i, atr);
      pulse += DisplacementScore(i, atr);
      pulse += BosScore(i, atr);
      pulse += TrendSideScore(i);
      pulse += ExpansionScore(i);
      pulse = ClampPulse(pulse);

      PulseBuffer[i] = pulse;
      BullStrongBuffer[i] = 0.0;
      BearStrongBuffer[i] = 0.0;
      StateBuffer[i] = 0.0;

      if(ShowStrongOnlyHighlight)
      {
         if(pulse >= StrongThreshold)
         {
            BullStrongBuffer[i] = pulse;
            PulseBuffer[i] = 0.0; // avoid double-draw
            StateBuffer[i] = 1.0;
            DrawArrow(i, true);
         }
         else if(pulse <= -StrongThreshold)
         {
            BearStrongBuffer[i] = pulse;
            PulseBuffer[i] = 0.0;
            StateBuffer[i] = -1.0;
            DrawArrow(i, false);
         }
      }
   }

   // Live forming bar — lighter update, no arrow spam
   double atr0 = SafeATR(0);
   double live = ClampPulse(SweepScore(0, atr0) + DisplacementScore(0, atr0) +
                            BosScore(0, atr0) + TrendSideScore(0) + ExpansionScore(0));
   PulseBuffer[0] = live;
   BullStrongBuffer[0] = 0.0;
   BearStrongBuffer[0] = 0.0;
   if(ShowStrongOnlyHighlight)
   {
      if(live >= StrongThreshold) { BullStrongBuffer[0] = live; PulseBuffer[0] = 0.0; }
      else if(live <= -StrongThreshold) { BearStrongBuffer[0] = live; PulseBuffer[0] = 0.0; }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
