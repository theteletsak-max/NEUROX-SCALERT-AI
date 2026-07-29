//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_APEX_86                                              |
//| SNIPER AI — APEX ONLY (PSI scoreboard)                         |
//| Comment: SNIPER AI | APEX entry only | PSI scores dashboard              |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "6.02"
#property description "SNIPER AI OK86: APEX is the only entry path"
#property description "BUILD SA_APEX_86 — one live path: APEX. PSI = scores only."

#include <Trade/Trade.mqh>

CTrade trade;

//======================== INPUTS ===================================//
input group "GENERAL"
input long   MagicNumber   = 40001;
input string TradeComment  = "SNIPER AI";

input group "APEX — ONLY LIVE ENTRY PATH"
// THE trade engine: HTF bias → pool → sweep → reclaim → displacement
input bool   EnableAPEXStrategy        = true;
input ENUM_TIMEFRAMES APEX_BiasTF      = PERIOD_H4;
input int    APEX_BiasMA_Period        = 200;
input int    APEX_SwingStrength        = 2;
input int    APEX_SwingLookback        = 40;
input int    APEX_PoolLookback         = 30;
input double APEX_EqualTolATR          = 0.12;
input int    APEX_SweepLookback        = 24;
input double APEX_MinSweepWickRatio    = 0.28;
input double APEX_MinSweepDepthATR     = 0.06;
input double APEX_DispMinBodyRatio     = 0.48;
input double APEX_DispMinATR           = 0.40;
input bool   APEX_RequireMAAlign       = true;
input bool   APEX_BiasNeedStructOrMA   = true;  // pass if structure OR MA
input bool   APEX_RequireUnmitigatedZone = false; // prefer zone, not hard-block
input bool   APEX_RelaxedEntries       = true;  // swing-sweep path if no equal pool
input bool   APEX_UseSweepSL           = true;
input double APEX_SL_BufferATR         = 0.12;
input double APEX_MaxSL_ATR            = 4.0;
input bool   APEX_GateWithPSI          = false; // keep false — APEX owns entries
input bool   APEX_LogValidation        = true;

input group "PSI SCOREBOARD (NOT an entry path)"
// OK86: PSI only scores/dashboard. It does NOT open trades unless you force it on.
input bool   EnablePSI                   = true;   // compute scores for HUD
input bool   PSI_AllowEntryFire          = false;  // OFF = APEX only entries
input int    PSI_MinConfidenceToTrade    = 70;     // only if PSI_AllowEntryFire
input bool   PSI_HardCancelFakes         = true;
input bool   PSI_LogDecisions            = false;  // quieter; APEX logs matter
input bool   PSI_EnableSelfLearn         = false;  // off — less moving parts
input double PSI_LearnStep               = 0.01;
input bool   PSI_RejectPremiumBuys       = true;
input bool   PSI_RejectDiscountSells     = true;
input double PSI_MinBOS_ATR              = 0.12;
input double PSI_MinFVG_ATR              = 0.18;
input double PSI_MinDispBodyRatio        = 0.50;
input double PSI_MinDispATR              = 0.35;
input int    PSI_StructureLookback       = 20;
input int    PSI_SwingBars               = 3;

input group "TIMEFRAMES"
input ENUM_TIMEFRAMES EntryTF     = PERIOD_CURRENT;
// Bias uses APEX_BiasTF (H4). Extra PSI bias TFs removed.

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
input double TP_ATR_Mult       = 2.5;  // single TP (sweep SL from APEX when available)
input bool   UseBreakEven      = true;
input double BE_Trigger_R      = 1.0;
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
double   g_APEX_Invalidation = 0.0;
string   g_APEX_LastDetail = "";
string   g_LastStrategyTag = "";

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
   return false; // OK86: no cross-asset SMT — APEX-only focus
}


//======================== APEX LIQUIDITY SNIPER ====================//
bool APEX_IsSwingHighTF(const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   double h = iHigh(g_Sym, tf, bar);
   for(int i=1; i<=strength; i++)
      if(iHigh(g_Sym,tf,bar-i)>=h || iHigh(g_Sym,tf,bar+i)>=h) return false;
   return true;
}
bool APEX_IsSwingLowTF(const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   double l = iLow(g_Sym, tf, bar);
   for(int i=1; i<=strength; i++)
      if(iLow(g_Sym,tf,bar-i)<=l || iLow(g_Sym,tf,bar+i)<=l) return false;
   return true;
}

double APEX_BiasSMA()
{
   int p=MathMax(APEX_BiasMA_Period,10);
   if(Bars(g_Sym, APEX_BiasTF) < p+5) return 0.0;
   double s=0;
   for(int i=1;i<=p;i++) s += iClose(g_Sym, APEX_BiasTF, i);
   return s/p;
}

bool APEX_StructBull(string &detail)
{
   ENUM_TIMEFRAMES tf=APEX_BiasTF;
   int lb=MathMax(APEX_SwingLookback,20), s=MathMax(APEX_SwingStrength,1);
   int sh1=0,sh2=0,sl1=0,sl2=0;
   for(int i=s+1;i<=lb;i++)
   {
      if(sh1==0 && APEX_IsSwingHighTF(tf,i,s)) sh1=i;
      else if(sh1>0 && sh2==0 && APEX_IsSwingHighTF(tf,i,s)) sh2=i;
      if(sl1==0 && APEX_IsSwingLowTF(tf,i,s)) sl1=i;
      else if(sl1>0 && sl2==0 && APEX_IsSwingLowTF(tf,i,s)) sl2=i;
      if(sh1>0 && sh2>0 && sl1>0 && sl2>0) break;
   }
   if(sh1==0||sh2==0||sl1==0||sl2==0){ detail="APEX struct: need more BiasTF swings"; return false; }
   bool hh=iHigh(g_Sym,tf,sh1)>iHigh(g_Sym,tf,sh2);
   bool hl=iLow(g_Sym,tf,sl1)>iLow(g_Sym,tf,sl2);
   if(!(hh&&hl)){ detail="APEX struct: no HH+HL"; return false; }
   detail="APEX struct BULL HH+HL"; return true;
}
bool APEX_StructBear(string &detail)
{
   ENUM_TIMEFRAMES tf=APEX_BiasTF;
   int lb=MathMax(APEX_SwingLookback,20), s=MathMax(APEX_SwingStrength,1);
   int sh1=0,sh2=0,sl1=0,sl2=0;
   for(int i=s+1;i<=lb;i++)
   {
      if(sh1==0 && APEX_IsSwingHighTF(tf,i,s)) sh1=i;
      else if(sh1>0 && sh2==0 && APEX_IsSwingHighTF(tf,i,s)) sh2=i;
      if(sl1==0 && APEX_IsSwingLowTF(tf,i,s)) sl1=i;
      else if(sl1>0 && sl2==0 && APEX_IsSwingLowTF(tf,i,s)) sl2=i;
      if(sh1>0 && sh2>0 && sl1>0 && sl2>0) break;
   }
   if(sh1==0||sh2==0||sl1==0||sl2==0){ detail="APEX struct: need more BiasTF swings"; return false; }
   bool lh=iHigh(g_Sym,tf,sh1)<iHigh(g_Sym,tf,sh2);
   bool ll=iLow(g_Sym,tf,sl1)<iLow(g_Sym,tf,sl2);
   if(!(lh&&ll)){ detail="APEX struct: no LH+LL"; return false; }
   detail="APEX struct BEAR LH+LL"; return true;
}

bool APEX_BiasOK(const bool buy, string &detail)
{
   string sd="";
   bool structOK = buy ? APEX_StructBull(sd) : APEX_StructBear(sd);
   double sma=APEX_BiasSMA();
   double c1=iClose(g_Sym,APEX_BiasTF,1);
   bool maOK = (sma>0 && ((buy && c1>sma) || (!buy && c1<sma)));
   if(APEX_BiasNeedStructOrMA)
   {
      if(structOK || maOK){ detail = structOK ? sd : "APEX bias MA"; return true; }
      detail = "APEX bias: need structure or MA"; return false;
   }
   if(APEX_RequireMAAlign && !maOK){ detail="APEX bias: MA not aligned"; return false; }
   if(!structOK){ detail=sd; return false; }
   detail=sd; return true;
}

bool APEX_FindPool(const bool buy, double &pool)
{
   pool=0;
   ENUM_TIMEFRAMES tf=TF();
   double atr=PriceATR(14); if(atr<=0) return false;
   double tol=atr*APEX_EqualTolATR;
   int lb=MathMax(APEX_PoolLookback,10);
   if(buy)
   {
      // sell-side pool = equal lows
      double lo=iLow(g_Sym,tf,iLowest(g_Sym,tf,MODE_LOW,lb,1));
      int touches=0;
      for(int i=1;i<=lb;i++) if(MathAbs(iLow(g_Sym,tf,i)-lo)<=tol) touches++;
      if(touches>=2){ pool=lo; return true; }
   }
   else
   {
      double hi=iHigh(g_Sym,tf,iHighest(g_Sym,tf,MODE_HIGH,lb,1));
      int touches=0;
      for(int i=1;i<=lb;i++) if(MathAbs(iHigh(g_Sym,tf,i)-hi)<=tol) touches++;
      if(touches>=2){ pool=hi; return true; }
   }
   return false;
}

bool APEX_SweepPool(const bool buy, const double pool, int &sweepBar, double &sweepExt)
{
   sweepBar=0; sweepExt=0;
   ENUM_TIMEFRAMES tf=TF();
   double atr=PriceATR(14);
   double minDepth=(atr>0)?atr*APEX_MinSweepDepthATR:0;
   int lb=MathMax(APEX_SweepLookback,3);
   for(int i=1;i<=lb;i++)
   {
      double h=iHigh(g_Sym,tf,i), l=iLow(g_Sym,tf,i), c=iClose(g_Sym,tf,i);
      double range=h-l; if(range<=0) continue;
      if(buy)
      {
         if(l < pool-minDepth && c > pool)
         {
            double wick=MathMin(c,pool)-l;
            if(wick/range >= APEX_MinSweepWickRatio){ sweepBar=i; sweepExt=l; return true; }
         }
      }
      else
      {
         if(h > pool+minDepth && c < pool)
         {
            double wick=h-MathMax(c,pool);
            if(wick/range >= APEX_MinSweepWickRatio){ sweepBar=i; sweepExt=h; return true; }
         }
      }
   }
   return false;
}

bool APEX_SwingSweep(const bool buy, double &pool, int &sweepBar, double &sweepExt)
{
   ENUM_TIMEFRAMES tf=TF();
   double atr=PriceATR(14);
   double minDepth=(atr>0)?atr*APEX_MinSweepDepthATR:0;
   int lb=MathMax(APEX_SweepLookback,3);
   for(int i=1;i<=lb;i++)
   {
      double h=iHigh(g_Sym,tf,i), l=iLow(g_Sym,tf,i), c=iClose(g_Sym,tf,i);
      double range=h-l; if(range<=0) continue;
      if(buy)
      {
         double prior=iLow(g_Sym,tf,i+1);
         for(int j=i+2;j<=i+6;j++){ double x=iLow(g_Sym,tf,j); if(x>0&&x<prior) prior=x; }
         if(l<prior-minDepth && c>prior)
         {
            double wick=MathMin(c,prior)-l;
            if(wick/range>=APEX_MinSweepWickRatio){ sweepBar=i; sweepExt=l; pool=prior; return true; }
         }
      }
      else
      {
         double prior=iHigh(g_Sym,tf,i+1);
         for(int j=i+2;j<=i+6;j++){ double x=iHigh(g_Sym,tf,j); if(x>prior) prior=x; }
         if(h>prior+minDepth && c<prior)
         {
            double wick=h-MathMax(c,prior);
            if(wick/range>=APEX_MinSweepWickRatio){ sweepBar=i; sweepExt=h; pool=prior; return true; }
         }
      }
   }
   return false;
}

bool APEX_HasReclaim(const bool buy, const double pool)
{
   double c1=iClose(g_Sym,TF(),1);
   return buy ? (c1 > pool) : (c1 < pool);
}

bool APEX_HasDisplacement(const bool buy)
{
   double o=iOpen(g_Sym,TF(),1), c=iClose(g_Sym,TF(),1);
   double h=iHigh(g_Sym,TF(),1), l=iLow(g_Sym,TF(),1);
   double range=h-l; if(range<=0) return false;
   if(MathAbs(c-o)/range < APEX_DispMinBodyRatio) return false;
   if(buy && c<=o) return false;
   if(!buy && c>=o) return false;
   double atr=PriceATR(14);
   if(atr>0 && range < atr*APEX_DispMinATR) return false;
   return true;
}

bool APEX_SetupOK(const bool buy, string &detail, double &invalidation)
{
   detail=""; invalidation=0; g_APEX_Invalidation=0;
   if(!EnableAPEXStrategy){ detail="APEX disabled"; return false; }
   if(Bars(g_Sym,APEX_BiasTF) < APEX_BiasMA_Period+10){ detail="APEX: BiasTF history"; return false; }
   if(Bars(g_Sym,TF()) < APEX_PoolLookback+10){ detail="APEX: EntryTF history"; return false; }

   string bd="";
   if(!APEX_BiasOK(buy, bd)){ detail=bd; return false; }

   double pool=0;
   int sweepBar=0; double sweepExt=0;
   bool havePool=APEX_FindPool(buy, pool);
   bool swept=false;
   if(havePool) swept=APEX_SweepPool(buy, pool, sweepBar, sweepExt);
   if(!swept && APEX_RelaxedEntries)
      swept=APEX_SwingSweep(buy, pool, sweepBar, sweepExt);
   if(!swept)
   {
      detail = buy ? "APEX: waiting sell-side sweep (lows)" : "APEX: waiting buy-side sweep (highs)";
      return false;
   }
   if(!APEX_HasReclaim(buy, pool)){ detail="APEX: need reclaim beyond pool"; return false; }
   if(!APEX_HasDisplacement(buy)){ detail="APEX: need displacement"; return false; }

   bool zone = ActiveFVG(buy) || ActiveOB(buy);
   if(APEX_RequireUnmitigatedZone && !zone){ detail="APEX: need FVG/OB zone"; return false; }

   double atr=PriceATR(14);
   double buf=(atr>0)?atr*APEX_SL_BufferATR:0;
   invalidation = buy ? (sweepExt - buf) : (sweepExt + buf);
   double px = buy ? Ask() : Bid();
   if(px>0 && atr>0 && APEX_MaxSL_ATR>0 && MathAbs(px-invalidation) > atr*APEX_MaxSL_ATR)
   { detail="APEX: sweep SL too wide"; return false; }

   detail=StringFormat("APEX OK %s pool=%s sweep@%d zone=%s inv=%s | %s",
                       buy?"BUY":"SELL",
                       DoubleToString(pool, DigitsSym()),
                       sweepBar, zone?"Y":"N",
                       DoubleToString(invalidation, DigitsSym()), bd);
   g_APEX_LastDetail=detail;
   g_APEX_Invalidation=invalidation;
   return true;
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
   if(TF_Bull(APEX_BiasTF,20)) bull+=3; if(TF_Bear(APEX_BiasTF,20)) bear+=3;
   if(TF_Bull(APEX_BiasTF,50)) bull+=3; if(TF_Bear(APEX_BiasTF,50)) bear+=3;
   if(TF_Bull(TF(),50)) bull+=2; if(TF_Bear(TF(),50)) bear+=2;
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
   if(buy && TF_Bull(APEX_BiasTF,50) && TF_Bull(TF(),50)) score+=1;
   if(!buy && TF_Bear(APEX_BiasTF,50) && TF_Bear(TF(),50)) score+=1;
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
   { why="Premium Buy"; return true; }
   if(PSI_RejectDiscountSells && !buy && InDiscount() && !InPremium())
   { why="Discount Sell"; return true; }
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

   if(r.confidence < PSI_MinConfidenceToTrade && !false)
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

bool OpenMarket(const bool buy, const string tag, const string reason,
                const double invSL=0.0, const int conf=0, const string grade="")
{
   if(CountOpen() >= MaxOpenTrades) return false;
   if(TimeCurrent() - g_LastTradeTime < TradeCooldownSec) return false;

   double atr=PriceATR(ATR_Period);
   if(atr<=0){ Print("exec: ATR not ready"); return false; }

   double slDist=atr*SL_ATR_Mult;
   double tpDist=atr*TP_ATR_Mult;
   double price = buy ? Ask() : Bid();
   double sl = buy ? price - slDist : price + slDist;
   double tp = buy ? price + tpDist : price - tpDist;

   // APEX sweep invalidation SL when safer/wider than ATR floor
   if(APEX_UseSweepSL && invSL > 0.0)
   {
      if(buy && invSL < price && (sl==0 || invSL < sl)) sl = invSL;
      if(!buy && invSL > price && (sl==0 || invSL > sl)) sl = invSL;
      slDist = MathAbs(price - sl);
   }

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
         Print(tag, " order fail attempt ", attempt+1, " ret=", trade.ResultRetcode(),
               " ", trade.ResultRetcodeDescription());
   }
   if(ok)
   {
      g_LastTradeTime = TimeCurrent();
      g_LastStrategyTag = tag;
      Print(tag, " FIRE ", (buy?"BUY":"SELL"), " lots=", lots,
            (conf>0 ? StringFormat(" Conf=%d%% %s", conf, grade) : ""),
            " — ", reason);
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
      "======= SNIPER AI APEX =======\n",
      "Symbol: ", g_Sym, " | TF: ", EnumToString(TF()), "\n",
      "Entry: APEX ONLY",
      " | PSI fire: ", (PSI_AllowEntryFire ? "ON" : "OFF"), "\n",
      "LastTag: ", (g_LastStrategyTag=="" ? "-" : g_LastStrategyTag), "\n",
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
      "Comment: SNIPER AI | BUILD SA_APEX_86\n",
      "=================================="
   );
}

void EvaluateAndTrade()
{
   if(Bars(g_Sym, TF()) < PSI_StructureLookback + 30) return;

   // PSI scoreboard only (updates HUD) — does not trade unless forced on
   if(EnablePSI)
   {
      PSI_Report b = PSI_Evaluate(true);
      PSI_Report s = PSI_Evaluate(false);
      // keep best side on dashboard
      if(s.confidence > b.confidence) g_LastPSI = s;
      else g_LastPSI = b;
   }

   // ===== ONLY LIVE ENTRY: APEX =====
   if(!EnableAPEXStrategy)
      return;

   string adB="", adS="";
   double invB=0, invS=0;
   bool aBuy=APEX_SetupOK(true, adB, invB);
   bool aSell=APEX_SetupOK(false, adS, invS);

   if(aBuy && aSell)
   {
      if(TF_Bull(APEX_BiasTF, 50) && !TF_Bear(APEX_BiasTF, 50)) aSell=false;
      else if(TF_Bear(APEX_BiasTF, 50) && !TF_Bull(APEX_BiasTF, 50)) aBuy=false;
      else { aBuy=false; aSell=false; }
   }

   if(!(aBuy || aSell))
   {
      if(APEX_LogValidation)
      {
         static datetime lastApexBar=0;
         datetime bt=iTime(g_Sym,TF(),0);
         if(bt!=lastApexBar)
         {
            lastApexBar=bt;
            Print("APEX wait BUY[", adB, "] SELL[", adS, "]");
         }
      }
      // Optional: PSI entry only if user explicitly enables it
      if(PSI_AllowEntryFire && EnablePSI)
      {
         PSI_Report b = PSI_Evaluate(true);
         PSI_Report s = PSI_Evaluate(false);
         bool bFire = (!b.cancelled && b.signal==PSI_SIG_BUY && b.confidence>=PSI_MinConfidenceToTrade);
         bool sFire = (!s.cancelled && s.signal==PSI_SIG_SELL && s.confidence>=PSI_MinConfidenceToTrade);
         if(bFire && sFire){ if(b.confidence>=s.confidence) sFire=false; else bFire=false; }
         if(bFire){ OpenMarket(true, "PSI", b.reason, 0.0, b.confidence, b.grade); return; }
         if(sFire){ OpenMarket(false, "PSI", s.reason, 0.0, s.confidence, s.grade); return; }
      }
      return;
   }

   bool sideBuy=aBuy;
   string detail = sideBuy ? adB : adS;
   double inv = sideBuy ? invB : invS;

   if(APEX_GateWithPSI && EnablePSI)
   {
      PSI_Report pr=PSI_Evaluate(sideBuy);
      if(pr.cancelled || pr.confidence < PSI_MinConfidenceToTrade)
      {
         if(APEX_LogValidation) Print("APEX held by PSI scoreboard: ", pr.reason);
         return;
      }
      if(APEX_LogValidation) Print("APEX DECISION ", detail, " | PSI Conf=", pr.confidence);
      OpenMarket(sideBuy, "APEX", detail, inv, pr.confidence, pr.grade);
      return;
   }

   if(APEX_LogValidation) Print("APEX DECISION ", detail);
   OpenMarket(sideBuy, "APEX", detail, inv);
}

//======================== EVENTS ===================================//
int OnInit()
{
   g_Sym = _Symbol;
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(g_Sym);

   Print("SNIPER AI Loaded BUILD_ID=SA_APEX_86 — APEX ONLY ENTRY");
   Print("LIVE ENTRY = APEX | BiasTF=", EnumToString(APEX_BiasTF),
         " | PSI scoreboard=", EnablePSI,
         " | PSI_AllowEntryFire=", PSI_AllowEntryFire, " (keep false)");
   Print("CRITICAL: SOURCE SNIPER_AI_OK86 BUILD SA_APEX_86 | Comment=", TradeComment);
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
