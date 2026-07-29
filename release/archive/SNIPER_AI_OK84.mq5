//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_LEAN_84                                              |
//| SNIPER AI — PRISM SIGNAL INDEX (PSI) LEAN                         |
//| Comment: SNIPER AI | Price-only PSI | No oscillators              |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "6.00"
#property description "SNIPER AI OK84 LEAN: PSI v1.0 price-only institutional EA"
#property description "BUILD SA_LEAN_84 — stripped multi-path bulk, PSI core + execution"

#include <Trade/Trade.mqh>

CTrade trade;

//======================== INPUTS ===================================//
input group "GENERAL"
input long   MagicNumber   = 40001;
input string TradeComment  = "SNIPER AI";

input group "PRISM SIGNAL INDEX (PSI) v1.0"
input bool   EnablePSI                   = true;
input int    PSI_MinConfidenceToTrade    = 50;
input int    PSI_GoodConfidence          = 70;
input int    PSI_InstantConfidence       = 90;
input bool   PSI_HardCancelFakes         = true;
input bool   PSI_SoftLowQuality          = true;   // allow 50-69
input bool   PSI_LogDecisions            = true;
input bool   PSI_EnableSelfLearn         = true;
input double PSI_LearnStep               = 0.01;
input bool   PSI_RejectPremiumBuys       = true;
input bool   PSI_RejectDiscountSells     = true;
input double PSI_MinBOS_ATR              = 0.12;
input double PSI_MinFVG_ATR              = 0.18;
input double PSI_MinDispBodyRatio        = 0.50;
input double PSI_MinDispATR              = 0.35;
input int    PSI_StructureLookback       = 20;
input int    PSI_SwingBars               = 3;
input string PSI_SMTReferenceSymbol      = "";     // blank = internal SMT only

input group "TIMEFRAMES"
input ENUM_TIMEFRAMES EntryTF     = PERIOD_CURRENT;
input ENUM_TIMEFRAMES BiasTF_H4   = PERIOD_H4;
input ENUM_TIMEFRAMES BiasTF_D1   = PERIOD_D1;
input ENUM_TIMEFRAMES BiasTF_H1   = PERIOD_H1;

input group "SIZE & RISK"
input double LotSize           = 0.01;
input bool   UseFixedLot       = true;
input double RiskPercent       = 1.0;
input double MaxLotSizeHardCap = 5.0;
input int    MaxOpenTrades     = 1;
input int    SlippagePoints    = 30;

input group "STOPS & TARGETS"
input int    ATR_Period        = 14;
input double SL_ATR_Mult       = 1.5;
input double TP1_ATR_Mult      = 1.5;
input double TP2_ATR_Mult      = 2.5;
input double TP3_ATR_Mult      = 4.0;
input bool   UseBreakEven      = true;
input double BE_Trigger_R      = 1.0;   // move SL to BE after 1R
input bool   UseTrailing       = true;
input double Trail_ATR_Mult    = 1.2;
input int    TradeCooldownSec   = 15;

input group "DASHBOARD"
input bool   EnableDashboard       = true;
input int    DashboardRefreshMillis = 1000;

//======================== STATE ====================================//
string g_Sym = "";
datetime g_LastTradeTime = 0;
long     g_LastDashMs = 0;

int    g_PSI_LastConfidence = 0;
string g_PSI_LastGrade = "NO TRADE";
string g_PSI_LastReason = "";
bool   g_PSI_LastCancelled = false;
string g_PSI_LastSignal = "NO TRADE";

double g_PSI_W_Trend=0.20, g_PSI_W_Structure=0.25, g_PSI_W_Liquidity=0.20;
double g_PSI_W_ICT=0.15, g_PSI_W_SMT=0.10, g_PSI_W_Momentum=0.05, g_PSI_W_Entry=0.05;
int    g_PSI_LearnTrades=0, g_PSI_LearnWins=0, g_PSI_LearnLosses=0;

enum PSI_RegimeClass { PSI_REG_TREND=0, PSI_REG_RANGE, PSI_REG_EXPANSION, PSI_REG_COMPRESSION };
enum PSI_BiasSide    { PSI_BIAS_BULL=0, PSI_BIAS_BEAR, PSI_BIAS_NEUTRAL };
enum PSI_SignalSide  { PSI_SIG_NONE=0, PSI_SIG_BUY, PSI_SIG_SELL };

struct PSI_Report
{
   PSI_SignalSide signal;
   int confidence;
   string grade;
   string reason;
   bool cancelled;
   string cancelReason;
   PSI_RegimeClass regime;
   int regimeScore, trendScore, structureScore, liquidityScore, ictScore, smtScore, momentumScore, entryScore;
   PSI_BiasSide bias;
   bool expansion, compression;
};

PSI_Report g_LastPSI;

//======================== UTILS ====================================//
ENUM_TIMEFRAMES TF()
{
   return (EntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : EntryTF;
}

double Bid(){ return SymbolInfoDouble(g_Sym, SYMBOL_BID); }
double Ask(){ return SymbolInfoDouble(g_Sym, SYMBOL_ASK); }
int DigitsSym(){ return (int)SymbolInfoInteger(g_Sym, SYMBOL_DIGITS); }
double PointSym(){ return SymbolInfoDouble(g_Sym, SYMBOL_POINT); }

double PriceATR(const int period = 14)
{
   int p = MathMax(period, 5);
   if(Bars(g_Sym, TF()) < p + 3) return 0.0;
   double sum = 0.0;
   for(int i=1; i<=p; i++)
   {
      double h=iHigh(g_Sym,TF(),i), l=iLow(g_Sym,TF(),i), pc=iClose(g_Sym,TF(),i+1);
      double tr = MathMax(h-l, MathMax(MathAbs(h-pc), MathAbs(l-pc)));
      sum += tr;
   }
   return sum / p;
}

double AvgRange(const int fromBar, const int bars)
{
   double sum=0; int n=0;
   for(int i=fromBar; i<fromBar+bars; i++)
   {
      double r=iHigh(g_Sym,TF(),i)-iLow(g_Sym,TF(),i);
      if(r>0){ sum+=r; n++; }
   }
   return n>0 ? sum/n : 0.0;
}

double SMA_Close(const ENUM_TIMEFRAMES tf, const int period, const int shift=1)
{
   if(Bars(g_Sym, tf) < period+shift+2) return 0.0;
   double s=0;
   for(int i=shift; i<shift+period; i++) s += iClose(g_Sym, tf, i);
   return s / period;
}

bool TF_Bull(const ENUM_TIMEFRAMES tf, const int period)
{
   double ma=SMA_Close(tf, period); if(ma<=0) return false;
   return iClose(g_Sym, tf, 1) > ma;
}
bool TF_Bear(const ENUM_TIMEFRAMES tf, const int period)
{
   double ma=SMA_Close(tf, period); if(ma<=0) return false;
   return iClose(g_Sym, tf, 1) < ma;
}


bool StrongBody(const bool buy);
bool QualitySweep(const bool buy, string &fail);
//======================== SWINGS / STRUCTURE =======================//
bool IsSwingHigh(const int bar, const int strength)
{
   double h = iHigh(g_Sym, TF(), bar);
   for(int i=1; i<=strength; i++)
      if(iHigh(g_Sym,TF(),bar-i)>=h || iHigh(g_Sym,TF(),bar+i)>=h) return false;
   return true;
}
bool IsSwingLow(const int bar, const int strength)
{
   double l = iLow(g_Sym, TF(), bar);
   for(int i=1; i<=strength; i++)
      if(iLow(g_Sym,TF(),bar-i)<=l || iLow(g_Sym,TF(),bar+i)<=l) return false;
   return true;
}

double RecentSwingHigh(const int lookback)
{
   int s=MathMax(PSI_SwingBars,2);
   for(int i=s; i<=lookback; i++)
      if(IsSwingHigh(i,s)) return iHigh(g_Sym,TF(),i);
   return iHigh(g_Sym,TF(),iHighest(g_Sym,TF(),MODE_HIGH,lookback,1));
}
double RecentSwingLow(const int lookback)
{
   int s=MathMax(PSI_SwingBars,2);
   for(int i=s; i<=lookback; i++)
      if(IsSwingLow(i,s)) return iLow(g_Sym,TF(),i);
   return iLow(g_Sym,TF(),iLowest(g_Sym,TF(),MODE_LOW,lookback,1));
}

bool DetectHH()
{
   int s=MathMax(PSI_SwingBars,2); int found=0; double vals[2]={0,0};
   for(int i=s;i<=PSI_StructureLookback*2 && found<2;i++)
      if(IsSwingHigh(i,s)){ vals[found++]=iHigh(g_Sym,TF(),i); }
   if(found<2) return false;
   return vals[0] > vals[1];
}
bool DetectHL()
{
   int s=MathMax(PSI_SwingBars,2); int found=0; double vals[2]={0,0};
   for(int i=s;i<=PSI_StructureLookback*2 && found<2;i++)
      if(IsSwingLow(i,s)){ vals[found++]=iLow(g_Sym,TF(),i); }
   if(found<2) return false;
   return vals[0] > vals[1];
}
bool DetectLH()
{
   int s=MathMax(PSI_SwingBars,2); int found=0; double vals[2]={0,0};
   for(int i=s;i<=PSI_StructureLookback*2 && found<2;i++)
      if(IsSwingHigh(i,s)){ vals[found++]=iHigh(g_Sym,TF(),i); }
   if(found<2) return false;
   return vals[0] < vals[1];
}
bool DetectLL()
{
   int s=MathMax(PSI_SwingBars,2); int found=0; double vals[2]={0,0};
   for(int i=s;i<=PSI_StructureLookback*2 && found<2;i++)
      if(IsSwingLow(i,s)){ vals[found++]=iLow(g_Sym,TF(),i); }
   if(found<2) return false;
   return vals[0] < vals[1];
}

bool IsBullTrend(){ return DetectHH() && DetectHL(); }
bool IsBearTrend(){ return DetectLH() && DetectLL(); }

bool DetectBOS(const bool buy)
{
   double c1=iClose(g_Sym,TF(),1);
   if(buy)
   {
      double lvl=RecentSwingHigh(PSI_StructureLookback);
      return (lvl>0 && c1>lvl);
   }
   double lvl=RecentSwingLow(PSI_StructureLookback);
   return (lvl>0 && c1<lvl);
}

bool QualityBOS(const bool buy, string &fail)
{
   fail="";
   if(!DetectBOS(buy)){ fail="no BOS"; return false; }
   double atr=PriceATR(ATR_Period);
   double c1=iClose(g_Sym,TF(),1);
   double lvl = buy ? RecentSwingHigh(PSI_StructureLookback) : RecentSwingLow(PSI_StructureLookback);
   double pen = buy ? (c1-lvl) : (lvl-c1);
   if(atr>0 && pen < atr*PSI_MinBOS_ATR){ fail="tiny BOS"; return false; }
   // fake reclaim
   double o1=iOpen(g_Sym,TF(),1);
   if(buy && c1<o1 && DetectBOS(false)){ fail="fake BOS"; return false; }
   if(!buy && c1>o1 && DetectBOS(true)){ fail="fake BOS"; return false; }
   return true;
}

bool DetectCHoCH(const bool buy)
{
   // EMA-free: prior structure flip — bull CHoCH after LL then HL break
   if(buy) return DetectLL() && DetectBOS(true);
   return DetectHH() && DetectBOS(false);
}

bool DetectMSS(const bool buy)
{
   return DetectCHoCH(buy) && (buy ? DetectHL() : DetectLH());
}

bool MicroBOS(const bool buy)
{
   double c1=iClose(g_Sym,TF(),1);
   if(buy) return c1 > iHigh(g_Sym,TF(),2) && c1 > iHigh(g_Sym,TF(),3);
   return c1 < iLow(g_Sym,TF(),2) && c1 < iLow(g_Sym,TF(),3);
}

//======================== PREMIUM / DISCOUNT =======================//
void RangeHiLo(double &hi, double &lo)
{
   hi=iHigh(g_Sym,TF(),1); lo=iLow(g_Sym,TF(),1);
   for(int i=2;i<=PSI_StructureLookback;i++)
   {
      double h=iHigh(g_Sym,TF(),i), l=iLow(g_Sym,TF(),i);
      if(h>hi) hi=h; if(l<lo) lo=l;
   }
}
double Equilibrium()
{
   double hi,lo; RangeHiLo(hi,lo);
   if(hi<=lo) return Bid();
   return (hi+lo)*0.5;
}
bool InDiscount(){ double hi,lo; RangeHiLo(hi,lo); if(hi<=lo) return true; return Bid() <= (hi+lo)*0.5; }
bool InPremium(){ double hi,lo; RangeHiLo(hi,lo); if(hi<=lo) return true; return Bid() >= (hi+lo)*0.5; }

//======================== LIQUIDITY ================================//
bool EqualHighs()
{
   double atr=PriceATR(ATR_Period); if(atr<=0) return false;
   double tol=atr*0.12;
   double h1=iHigh(g_Sym,TF(),iHighest(g_Sym,TF(),MODE_HIGH,12,1));
   int touches=0;
   for(int i=1;i<=18;i++)
      if(MathAbs(iHigh(g_Sym,TF(),i)-h1)<=tol) touches++;
   return touches>=2;
}
bool EqualLows()
{
   double atr=PriceATR(ATR_Period); if(atr<=0) return false;
   double tol=atr*0.12;
   double l1=iLow(g_Sym,TF(),iLowest(g_Sym,TF(),MODE_LOW,12,1));
   int touches=0;
   for(int i=1;i<=18;i++)
      if(MathAbs(iLow(g_Sym,TF(),i)-l1)<=tol) touches++;
   return touches>=2;
}

bool SweepBuySide() // sweep highs (sell-side liquidity for shorts / BSL)
{
   double lvl=RecentSwingHigh(PSI_StructureLookback);
   double h1=iHigh(g_Sym,TF(),1), c1=iClose(g_Sym,TF(),1);
   return (h1>lvl && c1<lvl);
}
bool SweepSellSide() // sweep lows
{
   double lvl=RecentSwingLow(PSI_StructureLookback);
   double l1=iLow(g_Sym,TF(),1), c1=iClose(g_Sym,TF(),1);
   return (l1<lvl && c1>lvl);
}

bool DirectionalSweep(const bool buy) // buy needs sell-side (lows) swept
{
   return buy ? SweepSellSide() : SweepBuySide();
}

bool StopHunt(const bool buy) // rejection after poke
{
   double o=iOpen(g_Sym,TF(),1), c=iClose(g_Sym,TF(),1);
   double h=iHigh(g_Sym,TF(),1), l=iLow(g_Sym,TF(),1);
   double range=h-l; if(range<=0) return false;
   if(buy)
   {
      // lower wick rejection
      double lower=MathMin(o,c)-l;
      return (lower/range>=0.45 && c>o);
   }
   double upper=h-MathMax(o,c);
   return (upper/range>=0.45 && c<o);
}

bool QualitySweep(const bool buy, string &fail)
{
   fail="";
   if(!DirectionalSweep(buy)){ fail="no sweep"; return false; }
   if(!StopHunt(buy) && !StrongBody(buy))
   { fail="sweep without rejection"; return false; }
   return true;
}

//======================== ICT / MOMENTUM ===========================//
bool StrongBody(const bool buy)
{
   double o=iOpen(g_Sym,TF(),1), c=iClose(g_Sym,TF(),1);
   double h=iHigh(g_Sym,TF(),1), l=iLow(g_Sym,TF(),1);
   double range=h-l; if(range<=0) return false;
   if(MathAbs(c-o)/range < PSI_MinDispBodyRatio) return false;
   if(buy && c<=o) return false;
   if(!buy && c>=o) return false;
   double atr=PriceATR(ATR_Period);
   if(atr>0 && range < atr*PSI_MinDispATR) return false;
   return true;
}

bool IsDoji()
{
   double o=iOpen(g_Sym,TF(),1), c=iClose(g_Sym,TF(),1);
   double h=iHigh(g_Sym,TF(),1), l=iLow(g_Sym,TF(),1);
   double range=h-l; if(range<=0) return true;
   return MathAbs(c-o)/range < 0.18;
}

bool BullFVG(double &top, double &bot)
{
   // classic 3-candle FVG: low[1] > high[3]
   double low1=iLow(g_Sym,TF(),1), high3=iHigh(g_Sym,TF(),3);
   if(low1 > high3)
   { bot=high3; top=low1; return true; }
   return false;
}
bool BearFVG(double &top, double &bot)
{
   double high1=iHigh(g_Sym,TF(),1), low3=iLow(g_Sym,TF(),3);
   if(high1 < low3)
   { top=low3; bot=high1; return true; }
   return false;
}

bool ActiveFVG(const bool buy)
{
   double t,b;
   if(buy)
   {
      if(!BullFVG(t,b)) return false;
      double atr=PriceATR(ATR_Period);
      if(atr>0 && (t-b) < atr*PSI_MinFVG_ATR) return false;
      // not fully filled
      return Bid() > b;
   }
   if(!BearFVG(t,b)) return false;
   double atr=PriceATR(ATR_Period);
   if(atr>0 && (t-b) < atr*PSI_MinFVG_ATR) return false;
   return Bid() < t;
}

bool BullOB(double &top, double &bot)
{
   // bearish candle before bullish displacement
   if(!StrongBody(true)) return false;
   double o2=iOpen(g_Sym,TF(),2), c2=iClose(g_Sym,TF(),2);
   if(c2>=o2) return false;
   top=iHigh(g_Sym,TF(),2); bot=iLow(g_Sym,TF(),2);
   return top>bot;
}
bool BearOB(double &top, double &bot)
{
   if(!StrongBody(false)) return false;
   double o2=iOpen(g_Sym,TF(),2), c2=iClose(g_Sym,TF(),2);
   if(c2<=o2) return false;
   top=iHigh(g_Sym,TF(),2); bot=iLow(g_Sym,TF(),2);
   return top>bot;
}

bool ActiveOB(const bool buy)
{
   double t,b;
   if(buy)
   {
      if(!BullOB(t,b)) return false;
      // not broken
      return iClose(g_Sym,TF(),1) >= b;
   }
   if(!BearOB(t,b)) return false;
   return iClose(g_Sym,TF(),1) <= t;
}

bool NearZone(const bool buy)
{
   double t,b, atr=PriceATR(ATR_Period);
   double prox = atr>0 ? atr*1.0 : 0;
   double price = buy ? Ask() : Bid();
   if(buy && BullOB(t,b)) return (price<=t+prox && price>=b-prox);
   if(buy && BullFVG(t,b)) return (price<=t+prox && price>=b-prox);
   if(!buy && BearOB(t,b)) return (price<=t+prox && price>=b-prox);
   if(!buy && BearFVG(t,b)) return (price<=t+prox && price>=b-prox);
   return false;
}

bool DetectIFVG(const bool buy)
{
   return buy ? (ActiveFVG(false) && StrongBody(true)) : (ActiveFVG(true) && StrongBody(false));
}

bool DetectBPR()
{
   return ActiveFVG(true) && ActiveFVG(false);
}

int DisplacementScore(const bool buy)
{
   if(!StrongBody(buy)) return 0;
   double atr=PriceATR(ATR_Period);
   double range=iHigh(g_Sym,TF(),1)-iLow(g_Sym,TF(),1);
   if(atr<=0) return 5;
   double r=range/atr;
   if(r>=1.5) return 15;
   if(r>=1.0) return 10;
   if(r>=0.6) return 5;
   return 0;
}

//======================== SMT ======================================//
bool SMTInternal(const bool buy)
{
   return DirectionalSweep(buy) && (DetectCHoCH(buy) || DetectBOS(buy) || ActiveOB(buy) || ActiveFVG(buy));
}

bool SMTCross(const bool buy)
{
   if(PSI_SMTReferenceSymbol=="" || PSI_SMTReferenceSymbol==g_Sym) return false;
   if(!SymbolSelect(PSI_SMTReferenceSymbol, true)) return false;
   int lb=10;
   if(Bars(g_Sym,TF())<lb*2+2 || Bars(PSI_SMTReferenceSymbol,TF())<lb*2+2) return false;
   double pNow = buy ? iLow(g_Sym,TF(),iLowest(g_Sym,TF(),MODE_LOW,lb,1))
                     : iHigh(g_Sym,TF(),iHighest(g_Sym,TF(),MODE_HIGH,lb,1));
   double pPast= buy ? iLow(g_Sym,TF(),iLowest(g_Sym,TF(),MODE_LOW,lb,1+lb))
                     : iHigh(g_Sym,TF(),iHighest(g_Sym,TF(),MODE_HIGH,lb,1+lb));
   double rNow = buy ? iLow(PSI_SMTReferenceSymbol,TF(),iLowest(PSI_SMTReferenceSymbol,TF(),MODE_LOW,lb,1))
                     : iHigh(PSI_SMTReferenceSymbol,TF(),iHighest(PSI_SMTReferenceSymbol,TF(),MODE_HIGH,lb,1));
   double rPast= buy ? iLow(PSI_SMTReferenceSymbol,TF(),iLowest(PSI_SMTReferenceSymbol,TF(),MODE_LOW,lb,1+lb))
                     : iHigh(PSI_SMTReferenceSymbol,TF(),iHighest(PSI_SMTReferenceSymbol,TF(),MODE_HIGH,lb,1+lb));
   if(buy) return (pNow < pPast) && (rNow > rPast);
   return (pNow > pPast) && (rNow < rPast);
}

//======================== PSI ENGINE ===============================//
string RegimeStr(const PSI_RegimeClass r)
{
   if(r==PSI_REG_TREND) return "TREND";
   if(r==PSI_REG_EXPANSION) return "EXPANSION";
   if(r==PSI_REG_COMPRESSION) return "COMPRESSION";
   return "RANGE";
}
string BiasStr(const PSI_BiasSide b)
{
   if(b==PSI_BIAS_BULL) return "Bullish";
   if(b==PSI_BIAS_BEAR) return "Bearish";
   return "Neutral";
}
string GradeFromConf(const int c)
{
   if(c<50) return "NO TRADE";
   if(c<70) return "LOW QUALITY";
   if(c<80) return "GOOD";
   if(c<90) return "HIGH QUALITY";
   if(c<95) return "A+";
   return "INSTITUTIONAL SNIPER";
}

void PSI_NormalizeWeights()
{
   double s=g_PSI_W_Trend+g_PSI_W_Structure+g_PSI_W_Liquidity+g_PSI_W_ICT+g_PSI_W_SMT+g_PSI_W_Momentum+g_PSI_W_Entry;
   if(s<=0) return;
   g_PSI_W_Trend/=s; g_PSI_W_Structure/=s; g_PSI_W_Liquidity/=s; g_PSI_W_ICT/=s;
   g_PSI_W_SMT/=s; g_PSI_W_Momentum/=s; g_PSI_W_Entry/=s;
}

void PSI_Publish(const PSI_Report &r)
{
   g_LastPSI = r;
   g_PSI_LastConfidence = r.confidence;
   g_PSI_LastGrade = r.grade;
   g_PSI_LastReason = r.reason;
   g_PSI_LastCancelled = r.cancelled;
   if(r.signal==PSI_SIG_BUY) g_PSI_LastSignal="BUY";
   else if(r.signal==PSI_SIG_SELL) g_PSI_LastSignal="SELL";
   else g_PSI_LastSignal="NO TRADE";
}

int PSI_ScoreRegime(PSI_Report &r)
{
   double fast=AvgRange(1,5), slow=AvgRange(1,20);
   bool bull=IsBullTrend(), bear=IsBearTrend();
   r.expansion = (slow>0 && fast>=slow*1.25);
   r.compression = (slow>0 && fast<=slow*0.70);
   int score=3; r.regime=PSI_REG_RANGE;
   if((bull||bear) && r.expansion){ r.regime=PSI_REG_TREND; score=9; }
   else if(bull||bear){ r.regime=PSI_REG_TREND; score=6; }
   else if(r.expansion){ r.regime=PSI_REG_EXPANSION; score=8; }
   else if(r.compression){ r.regime=PSI_REG_COMPRESSION; score=5; }
   r.regimeScore=score; return score;
}

int PSI_ScoreTrend(const bool buy, PSI_Report &r)
{
   int bull=0, bear=0;
   if(TF_Bull(BiasTF_D1,20)) bull+=3; if(TF_Bear(BiasTF_D1,20)) bear+=3;
   if(TF_Bull(BiasTF_H4,50)) bull+=3; if(TF_Bear(BiasTF_H4,50)) bear+=3;
   if(TF_Bull(BiasTF_H1,50)) bull+=2; if(TF_Bear(BiasTF_H1,50)) bear+=2;
   if(IsBullTrend()) bull+=2; if(IsBearTrend()) bear+=2;
   if(DetectBOS(true)) bull+=2; if(DetectBOS(false)) bear+=2;
   if(buy && InDiscount()) bull+=2;
   if(!buy && InPremium()) bear+=2;
   if(bull>bear+1) r.bias=PSI_BIAS_BULL;
   else if(bear>bull+1) r.bias=PSI_BIAS_BEAR;
   else r.bias=PSI_BIAS_NEUTRAL;
   int score = buy ? bull : bear;
   if(buy && r.bias==PSI_BIAS_BEAR) score=MathMax(0,score-4);
   if(!buy && r.bias==PSI_BIAS_BULL) score=MathMax(0,score-4);
   if(score>15) score=15;
   r.trendScore=score; return score;
}

int PSI_ScoreStructure(const bool buy, PSI_Report &r)
{
   int score=0; string fail="";
   if(buy && DetectHH()) score+=2; if(buy && DetectHL()) score+=2;
   if(!buy && DetectLH()) score+=2; if(!buy && DetectLL()) score+=2;
   if(QualityBOS(buy, fail)) score+=6;
   else if(DetectBOS(buy)) score+=1;
   if(MicroBOS(buy)) score+=2;
   if(DetectCHoCH(buy)) score+=3;
   if(DetectMSS(buy)) score+=3;
   if((buy?IsBullTrend():IsBearTrend()) && DetectBOS(buy)) score+=2;
   if(DirectionalSweep(buy) && (DetectCHoCH(buy)||ActiveOB(buy))) score+=2;
   if(StopHunt(buy)) score+=2;
   if(score>20) score=20;
   r.structureScore=score; return score;
}

int PSI_ScoreLiquidity(const bool buy, PSI_Report &r)
{
   int score=0; string fail="";
   if(EqualHighs()) score+=3; if(EqualLows()) score+=3;
   if(buy ? EqualLows() : EqualHighs()) score+=2;
   if(QualitySweep(buy, fail)) score+=7;
   else if(DirectionalSweep(buy)) score+=2;
   if(StopHunt(buy)) score+=3;
   if(DirectionalSweep(buy) && StopHunt(buy)) score+=3;
   if((EqualHighs()||EqualLows()) && DirectionalSweep(buy)) score+=2;
   if(ActiveFVG(buy) && StrongBody(buy)) score+=2;
   if(score>20) score=20;
   r.liquidityScore=score; return score;
}

int PSI_ScoreICT(const bool buy, PSI_Report &r)
{
   int score=0;
   if(ActiveFVG(buy)) score+=5;
   if(DetectIFVG(buy)) score+=2;
   if(ActiveOB(buy)) score+=5;
   if(DetectBPR()) score+=2;
   if(StrongBody(buy) || DisplacementScore(buy)>=5) score+=3;
   if(StrongBody(buy)) score+=2;
   if(buy && InDiscount()) score+=2;
   if(!buy && InPremium()) score+=2;
   double eq=Equilibrium(), c1=iClose(g_Sym,TF(),1), c2=iClose(g_Sym,TF(),2);
   if(StrongBody(buy) && ((buy && c2<eq && c1>eq) || (!buy && c2>eq && c1<eq))) score+=2;
   if(score>20) score=20;
   r.ictScore=score; return score;
}

int PSI_ScoreSMT(const bool buy, PSI_Report &r)
{
   int score=0;
   bool inn=SMTInternal(buy), cross=SMTCross(buy);
   if(inn) score+=4; if(cross) score+=4;
   if(inn && (buy?IsBullTrend():IsBearTrend())) score+=2;
   if(inn && DetectCHoCH(buy)) score+=2;
   if(buy && TF_Bull(BiasTF_H4,50) && TF_Bull(BiasTF_H1,50)) score+=1;
   if(!buy && TF_Bear(BiasTF_H4,50) && TF_Bear(BiasTF_H1,50)) score+=1;
   if(SMTInternal(!buy) && !inn) score=MathMax(0,score-5);
   if(score>10) score=10;
   r.smtScore=score; return score;
}

int PSI_ScoreMomentum(const bool buy, PSI_Report &r)
{
   if(IsDoji()){ r.momentumScore=0; return 0; }
   int score=0;
   if(StrongBody(buy)) score+=3;
   int ds=DisplacementScore(buy);
   if(ds>=10) score+=3; else if(ds>=5) score+=2;
   int streak=0;
   for(int i=1;i<=3;i++)
   {
      double o=iOpen(g_Sym,TF(),i), c=iClose(g_Sym,TF(),i);
      if(buy && c>o) streak++;
      if(!buy && c<o) streak++;
   }
   if(streak>=3) score+=3; else if(streak==2) score+=2;
   double avg=AvgRange(2,10), r1=iHigh(g_Sym,TF(),1)-iLow(g_Sym,TF(),1);
   if(avg>0 && r1>=avg*1.3 && StrongBody(buy)) score+=2;
   if(StopHunt(buy)) score+=2;
   if(r.compression) score=MathMax(0,score-2);
   if(score>10) score=10;
   r.momentumScore=score; return score;
}

int PSI_ScoreEntry(const bool buy, PSI_Report &r)
{
   int score=0;
   double atr=PriceATR(ATR_Period);
   double ma=SMA_Close(TF(), 50);
   double price=buy?Ask():Bid();
   if(ma>0 && atr>0 && MathAbs(price-ma)<=atr*2.0 && StrongBody(buy)) score+=2;
   if(NearZone(buy)) score+=3;
   if(MicroBOS(buy)) score+=2;
   if(DetectCHoCH(buy)) score+=2;
   if(StrongBody(buy)) score+=2;
   if(DisplacementScore(buy)>=5) score+=1;
   if((buy?IsBullTrend():IsBearTrend()) && DetectBOS(buy)) score+=1;
   if(DirectionalSweep(buy) && ActiveOB(buy)) score+=1;
   if(score>10) score=10;
   r.entryScore=score; return score;
}

int PSI_AdaptiveConfidence(const PSI_Report &r)
{
   double conf =
      g_PSI_W_Trend     * (100.0 * r.trendScore / 15.0) +
      g_PSI_W_Structure * (100.0 * r.structureScore / 20.0) +
      g_PSI_W_Liquidity * (100.0 * r.liquidityScore / 20.0) +
      g_PSI_W_ICT       * (100.0 * r.ictScore / 20.0) +
      g_PSI_W_SMT       * (100.0 * r.smtScore / 10.0) +
      g_PSI_W_Momentum  * (100.0 * r.momentumScore / 10.0) +
      g_PSI_W_Entry     * (100.0 * r.entryScore / 10.0);
   int out=(int)MathRound(conf);
   if(out<0) out=0; if(out>100) out=100;
   return out;
}

bool PSI_FakeDetector(const bool buy, const PSI_Report &r, string &why)
{
   why="";
   if(buy && r.bias==PSI_BIAS_BEAR && r.trendScore<6){ why="Against HTF"; return true; }
   if(!buy && r.bias==PSI_BIAS_BULL && r.trendScore<6){ why="Against HTF"; return true; }
   if(r.structureScore<4){ why="Weak Structure"; return true; }
   string f="";
   if(DetectBOS(buy) && !QualityBOS(buy,f)){ why="Fake/Weak BOS: "+f; return true; }
   if(DetectCHoCH(!buy) && !DetectCHoCH(buy) && DetectBOS(buy)){ why="Fake CHoCH"; return true; }
   if(r.momentumScore<=1 || IsDoji()){ why="Weak Momentum"; return true; }
   double avg=AvgRange(2,12), r1=iHigh(g_Sym,TF(),1)-iLow(g_Sym,TF(),1);
   if(r.momentumScore>=5 && avg>0 && r1<avg*0.85){ why="Low Volume Expansion"; return true; }
   if(DirectionalSweep(buy) && !QualitySweep(buy,f)){ why="Weak Liquidity Sweep"; return true; }
   if(PSI_RejectPremiumBuys && buy && InPremium() && !InDiscount())
   {
      if(!(PSI_SoftLowQuality && r.structureScore>=10 && r.confidence>=PSI_GoodConfidence))
      { why="Premium Buy"; return true; }
   }
   if(PSI_RejectDiscountSells && !buy && InDiscount() && !InPremium())
   {
      if(!(PSI_SoftLowQuality && r.structureScore>=10 && r.confidence>=PSI_GoodConfidence))
      { why="Discount Sell"; return true; }
   }
   if(buy && EqualHighs() && !DirectionalSweep(true) && !StopHunt(true))
   { why="Trade Into Liquidity"; return true; }
   if(!buy && EqualLows() && !DirectionalSweep(false) && !StopHunt(false))
   { why="Trade Into Liquidity"; return true; }
   double atr=PriceATR(ATR_Period), eq=Equilibrium();
   if(eq>0 && atr>0 && MathAbs(Bid()-eq)>atr*3.5 && r.entryScore<4)
   { why="Overextended Market"; return true; }
   if(SMTInternal(!buy) && !SMTInternal(buy)){ why="Conflicting SMT"; return true; }
   if(r.confidence>0 && r.confidence<PSI_MinConfidenceToTrade){ why="Low Confidence"; return true; }
   if(NearZone(buy)==false && StrongBody(buy) && r.entryScore<3 && DetectBOS(buy))
   { why="Late Entry / Chasing"; return true; }
   return false;
}

PSI_Report PSI_Evaluate(const bool buy)
{
   PSI_Report r;
   r.signal=PSI_SIG_NONE;
   r.confidence=0;
   r.grade="NO TRADE";
   r.reason="";
   r.cancelled=false;
   r.cancelReason="";
   r.regime=PSI_REG_RANGE;
   r.regimeScore=0; r.trendScore=0; r.structureScore=0; r.liquidityScore=0;
   r.ictScore=0; r.smtScore=0; r.momentumScore=0; r.entryScore=0;
   r.bias=PSI_BIAS_NEUTRAL;
   r.expansion=false; r.compression=false;
   if(!EnablePSI){ r.reason="PSI disabled"; PSI_Publish(r); return r; }

   PSI_ScoreRegime(r);
   PSI_ScoreTrend(buy,r);
   PSI_ScoreStructure(buy,r);
   PSI_ScoreLiquidity(buy,r);
   PSI_ScoreICT(buy,r);
   PSI_ScoreSMT(buy,r);
   PSI_ScoreMomentum(buy,r);
   PSI_ScoreEntry(buy,r);
   r.confidence=PSI_AdaptiveConfidence(r);
   r.grade=GradeFromConf(r.confidence);

   string fake="";
   if(PSI_HardCancelFakes && PSI_FakeDetector(buy,r,fake))
   {
      r.cancelled=true; r.cancelReason=fake; r.signal=PSI_SIG_NONE; r.grade="NO TRADE";
      r.reason="SIGNAL CANCELLED — "+fake+
               StringFormat(" | Conf=%d %s %s S%d L%d I%d", r.confidence, RegimeStr(r.regime), BiasStr(r.bias),
                            r.structureScore, r.liquidityScore, r.ictScore);
      PSI_Publish(r); return r;
   }

   if(r.confidence < PSI_MinConfidenceToTrade)
   {
      r.reason=StringFormat("NO TRADE Conf=%d | %s %s T%d S%d L%d I%d SMT%d M%d E%d",
                            r.confidence, RegimeStr(r.regime), BiasStr(r.bias),
                            r.trendScore,r.structureScore,r.liquidityScore,r.ictScore,
                            r.smtScore,r.momentumScore,r.entryScore);
      PSI_Publish(r); return r;
   }

   if(r.confidence < PSI_GoodConfidence && !PSI_SoftLowQuality)
   {
      r.signal=PSI_SIG_NONE; r.grade="NO TRADE";
      r.reason="LOW QUALITY blocked Conf="+IntegerToString(r.confidence);
      PSI_Publish(r); return r;
   }

   r.signal = buy ? PSI_SIG_BUY : PSI_SIG_SELL;
   r.reason=StringFormat("%s Conf=%d%% %s | %s %s | T%d S%d L%d ICT%d SMT%d M%d E%d",
                         (buy?"BUY":"SELL"), r.confidence, r.grade,
                         RegimeStr(r.regime), BiasStr(r.bias),
                         r.trendScore,r.structureScore,r.liquidityScore,r.ictScore,
                         r.smtScore,r.momentumScore,r.entryScore);
   PSI_Publish(r); return r;
}

void PSI_Learn(const bool win)
{
   if(!PSI_EnableSelfLearn) return;
   g_PSI_LearnTrades++;
   if(win) g_PSI_LearnWins++; else g_PSI_LearnLosses++;
   double step = win ? PSI_LearnStep : -PSI_LearnStep;
   g_PSI_W_Structure += step*0.35;
   g_PSI_W_Liquidity += step*0.25;
   g_PSI_W_ICT       += step*0.20;
   g_PSI_W_Trend     += step*0.10;
   g_PSI_W_SMT       += step*0.05;
   g_PSI_W_Momentum  += win ? step*0.03 : -MathAbs(step)*0.08;
   g_PSI_W_Entry     += step*0.02;
   g_PSI_W_Trend=MathMax(0.08,g_PSI_W_Trend);
   g_PSI_W_Structure=MathMax(0.12,g_PSI_W_Structure);
   g_PSI_W_Liquidity=MathMax(0.10,g_PSI_W_Liquidity);
   g_PSI_W_ICT=MathMax(0.08,g_PSI_W_ICT);
   g_PSI_W_SMT=MathMax(0.04,g_PSI_W_SMT);
   g_PSI_W_Momentum=MathMax(0.02,g_PSI_W_Momentum);
   g_PSI_W_Entry=MathMax(0.02,g_PSI_W_Entry);
   PSI_NormalizeWeights();
   if(PSI_LogDecisions)
      Print("PSI LEARN ", win?"WIN":"LOSS", " ", g_PSI_LearnWins, "/", g_PSI_LearnLosses,
            " Conf=", g_PSI_LastConfidence);
}

//======================== RISK / EXECUTION =========================//
int CountOpen()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_Sym) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      n++;
   }
   return n;
}

double CalcLot(const double slDistance)
{
   if(UseFixedLot) return MathMin(LotSize, MaxLotSizeHardCap);
   if(slDistance<=0) return LotSize;
   double tickVal=SymbolInfoDouble(g_Sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize=SymbolInfoDouble(g_Sym, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal<=0 || tickSize<=0) return LotSize;
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double lossPerLot = (slDistance / tickSize) * tickVal;
   if(lossPerLot<=0) return LotSize;
   double lots = riskMoney / lossPerLot;
   double step=SymbolInfoDouble(g_Sym, SYMBOL_VOLUME_STEP);
   double amin=SymbolInfoDouble(g_Sym, SYMBOL_VOLUME_MIN);
   double amax=SymbolInfoDouble(g_Sym, SYMBOL_VOLUME_MAX);
   if(step<=0) step=0.01;
   lots = MathFloor(lots/step)*step;
   if(lots<amin) lots=amin;
   if(lots>amax) lots=amax;
   if(lots>MaxLotSizeHardCap) lots=MaxLotSizeHardCap;
   return lots;
}

bool OpenMarket(const bool buy, const PSI_Report &r)
{
   if(CountOpen() >= MaxOpenTrades) return false;
   if(TimeCurrent() - g_LastTradeTime < TradeCooldownSec) return false;

   double atr=PriceATR(ATR_Period);
   if(atr<=0){ Print("PSI exec: ATR not ready"); return false; }

   double slDist=atr*SL_ATR_Mult;
   double tpDist=atr*TP2_ATR_Mult;
   double price = buy ? Ask() : Bid();
   double sl = buy ? price - slDist : price + slDist;
   double tp = buy ? price + tpDist : price - tpDist;
   double lots=CalcLot(slDist);

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(g_Sym);

   string cmt = TradeComment;
   bool ok=false;
   for(int attempt=0; attempt<3 && !ok; attempt++)
   {
      if(buy) ok = trade.Buy(lots, g_Sym, 0, sl, tp, cmt);
      else    ok = trade.Sell(lots, g_Sym, 0, sl, tp, cmt);
      if(!ok)
         Print("PSI order fail attempt ", attempt+1, " ret=", trade.ResultRetcode(),
               " ", trade.ResultRetcodeDescription());
   }
   if(ok)
   {
      g_LastTradeTime = TimeCurrent();
      Print("PSI FIRE ", (buy?"BUY":"SELL"), " lots=", lots,
            " Conf=", r.confidence, "% ", r.grade, " — ", r.reason);
   }
   return ok;
}

void ManagePositions()
{
   double atr=PriceATR(ATR_Period);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=g_Sym) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;

      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      long type=PositionGetInteger(POSITION_TYPE);
      double vol=PositionGetDouble(POSITION_VOLUME);
      double price = (type==POSITION_TYPE_BUY) ? Bid() : Ask();
      double risk = MathAbs(open - sl);
      if(risk<=0 && atr>0) risk=atr*SL_ATR_Mult;

      // Break-even
      if(UseBreakEven && risk>0)
      {
         if(type==POSITION_TYPE_BUY && price >= open + risk*BE_Trigger_R && (sl<open || sl==0))
            trade.PositionModify(ticket, open, tp);
         if(type==POSITION_TYPE_SELL && price <= open - risk*BE_Trigger_R && (sl>open || sl==0))
            trade.PositionModify(ticket, open, tp);
      }

      // Trail
      if(UseTrailing && atr>0)
      {
         double trail=atr*Trail_ATR_Mult;
         if(type==POSITION_TYPE_BUY)
         {
            double nsl=price-trail;
            if(nsl>sl && nsl<price) trade.PositionModify(ticket, nsl, tp);
         }
         else
         {
            double nsl=price+trail;
            if((sl==0 || nsl<sl) && nsl>price) trade.PositionModify(ticket, nsl, tp);
         }
      }
   }
}

void UpdateDashboard()
{
   if(!EnableDashboard) return;
   long now=(long)GetTickCount();
   if(now - g_LastDashMs < DashboardRefreshMillis) return;
   g_LastDashMs=now;

   Comment(
      "======= SNIPER AI PSI LEAN =======\n",
      "Symbol: ", g_Sym, " | TF: ", EnumToString(TF()), "\n",
      "Signal: ", g_PSI_LastSignal,
      " | Conf: ", IntegerToString(g_PSI_LastConfidence), "%\n",
      "Grade: ", g_PSI_LastGrade, "\n",
      "Regime: ", RegimeStr(g_LastPSI.regime),
      " | Bias: ", BiasStr(g_LastPSI.bias), "\n",
      "S/L/ICT/SMT: ",
      IntegerToString(g_LastPSI.structureScore), "/",
      IntegerToString(g_LastPSI.liquidityScore), "/",
      IntegerToString(g_LastPSI.ictScore), "/",
      IntegerToString(g_LastPSI.smtScore), "\n",
      "Open: ", IntegerToString(CountOpen()),
      " | Learn W/L: ", IntegerToString(g_PSI_LearnWins), "/", IntegerToString(g_PSI_LearnLosses), "\n",
      "Reason: ", (g_PSI_LastReason=="" ? "-" : StringSubstr(g_PSI_LastReason,0,90)), "\n",
      "Comment: SNIPER AI | BUILD SA_LEAN_84\n",
      "=================================="
   );
}

void EvaluateAndTrade()
{
   if(Bars(g_Sym, TF()) < PSI_StructureLookback + 30) return;

   PSI_Report b = PSI_Evaluate(true);
   PSI_Report s = PSI_Evaluate(false);

   bool bFire = (!b.cancelled && b.signal==PSI_SIG_BUY && b.confidence>=PSI_GoodConfidence);
   bool sFire = (!s.cancelled && s.signal==PSI_SIG_SELL && s.confidence>=PSI_GoodConfidence);

   // Prefer instant-grade; else best good+
   if(bFire && sFire)
   {
      if(b.confidence >= s.confidence) sFire=false;
      else bFire=false;
   }

   // Soft low quality only if enabled and no good side
   if(!bFire && !sFire && PSI_SoftLowQuality)
   {
      if(!b.cancelled && b.signal==PSI_SIG_BUY && b.confidence>=PSI_MinConfidenceToTrade) bFire=true;
      else if(!s.cancelled && s.signal==PSI_SIG_SELL && s.confidence>=PSI_MinConfidenceToTrade) sFire=true;
      if(bFire && sFire)
      {
         if(b.confidence>=s.confidence) sFire=false; else bFire=false;
      }
   }

   if(bFire)
   {
      // Instant path: >=90 always; good path also executes (aggressive lean)
      if(PSI_LogDecisions) Print("PSI DECISION BUY ", b.reason);
      OpenMarket(true, b);
      return;
   }
   if(sFire)
   {
      if(PSI_LogDecisions) Print("PSI DECISION SELL ", s.reason);
      OpenMarket(false, s);
      return;
   }

   if(PSI_LogDecisions)
   {
      static datetime lastBar=0;
      datetime bt=iTime(g_Sym,TF(),0);
      if(bt!=lastBar)
      {
         lastBar=bt;
         Print("PSI wait BUY[", b.reason, "] SELL[", s.reason, "]");
      }
   }
}

//======================== EVENTS ===================================//
int OnInit()
{
   g_Sym = _Symbol;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(g_Sym);

   Print("SNIPER AI Loaded BUILD_ID=SA_LEAN_84 — PSI LEAN");
   Print("PSI Min=", PSI_MinConfidenceToTrade,
         " Good=", PSI_GoodConfidence,
         " Instant=", PSI_InstantConfidence,
         " SoftLow=", PSI_SoftLowQuality);
   Print("CRITICAL: SOURCE SNIPER_AI_OK84 BUILD SA_LEAN_84 | Comment=", TradeComment);
   UpdateDashboard();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Comment("");
}

void OnTick()
{
   ManagePositions();
   EvaluateAndTrade();
   UpdateDashboard();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != MagicNumber) return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != g_Sym) return;
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                 + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                 + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   PSI_Learn(profit >= 0.0);
}
//+------------------------------------------------------------------+
