//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_PRIME_90                                             |
//| SNIPER AI — FULL FROM-SCRATCH PRIME STACK                         |
//| Comment: SNIPER AI                                                |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "8.00"
#property description "SNIPER AI PRIME: own engines + multi-strategy from scratch"
#property description "Structure/Liquidity/ICT/Fib/Volume + Cont/Rev/Flash/Fib/Break"

#include <Trade/Trade.mqh>
CTrade trade;

//====================================================================//
// INPUTS
//====================================================================//
input group "GENERAL"
input long   MagicNumber  = 40001;
input string TradeComment = "SNIPER AI";
input bool   EnableVerbose = true;

input group "SYMBOLS / TIMEFRAMES"
input bool   EnableMultiSymbol = false;
input string ExtraSymbols = "";
input int    MultiSymbolTimerSec = 1;
input ENUM_TIMEFRAMES EntryTF = PERIOD_CURRENT;
input ENUM_TIMEFRAMES BiasTF  = PERIOD_H4;
input ENUM_TIMEFRAMES MacroTF = PERIOD_D1;

input group "STRATEGIES (from scratch)"
input bool Enable_FlashSweep   = true;   // liquidity sweep sniper
input bool Enable_ContSniper   = true;   // trend continuation
input bool Enable_RevSniper    = true;   // reversal after sweep+CHoCH
input bool Enable_FibSniper    = true;   // fibonacci zone sniper
input bool Enable_BreakImpulse = true;   // range break + displacement
input int  MinStrategyScore    = 58;     // 0-100
input int  InstantFireScore    = 75;     // aggressive instant

input group "STRUCTURE ENGINE"
input int    SwingStrength     = 2;
input int    StructureLookback = 40;
input int    BOS_ConfirmBars   = 12;

input group "LIQUIDITY ENGINE"
input int    SweepLookback     = 20;
input double EqualTolATR       = 0.12;
input double SweepWickMin      = 0.28;
input double SweepDepthATR     = 0.06;

input group "ICT ENGINE"
input double DispBodyMin       = 0.48;
input double DispATRMin        = 0.35;
input double FVG_MinATR        = 0.12;
input bool   PreferOrderBlock  = true;

input group "FIBONACCI ENGINE"
input double FibBuyLow         = 0.50;
input double FibBuyHigh        = 0.886;
input double FibSellLow        = 0.114;
input double FibSellHigh       = 0.50;
input bool   SoftPreferFib     = true;

input group "VOLUME / MOMENTUM"
input double VolExpandMult     = 1.20;
input bool   SoftPreferVolume  = true;
input int    MomentumBars      = 3;

input group "SESSION / NEWS (aware, never hard-block)"
input bool   SessionAware      = true;
input bool   NewsAware         = true;
input bool   BoostInKillZone   = true;
input bool   BoostInNewsVol    = true;

input group "SIZE & ACCOUNT"
input int    MaxOpenTrades     = 3;
input bool   UseFixedLot       = true;
input double LotSize           = 0.01;
input double RiskPercent       = 1.0;
input double MaxLotHardCap     = 5.0;
input double MinFreeMarginPct  = 12.0;
input double MaxSpreadPoints   = 0;      // 0=off
input int    SlippagePoints    = 40;
input int    TradeCooldownSec   = 4;

input group "STOPS & TP LADDER"
input int    ATR_Period        = 14;
input double SL_ATR            = 1.40;
input double TP1_ATR           = 1.00;
input double TP2_ATR           = 2.00;
input double TP3_ATR           = 3.50;
input double TP1_ClosePercent  = 40.0;
input double TP2_ClosePercent  = 40.0;
input bool   MoveBE_AtTP1      = true;
input double BE_OffsetPoints   = 5;
input bool   TrailAfterTP2     = true;
input double Trail_ATR         = 1.10;
input bool   HoldThroughNoise  = true;
input int    ReversalExitScore = 82;

input group "DASHBOARD"
input bool   EnableDashboard   = true;
input int    DashRefreshMs     = 700;

//====================================================================//
// TYPES
//====================================================================//
#define MAX_SYMS 32
#define MAX_POS  64

struct EngineSnap
{
   // structure
   bool hh, hl, lh, ll;
   bool bosBuy, bosSell;
   bool chochBuy, chochSell;
   bool bullTrend, bearTrend;
   // liquidity
   bool eqHigh, eqLow;
   bool sweepBuy, sweepSell;   // buy=lows swept
   bool stopHuntBuy, stopHuntSell;
   double poolLow, poolHigh;
   double sweepExtBuy, sweepExtSell;
   // ICT
   bool fvgBuy, fvgSell;
   bool obBuy, obSell;
   bool dispBuy, dispSell;
   bool inDiscount, inPremium;
   // fib
   double fib0, fib100, fib382, fib500, fib618, fib786;
   bool atFibBuy, atFibSell;
   // volume / momentum
   bool volExpand;
   bool momBuy, momSell;
   // HTF
   bool htfBull, htfBear, macroBull, macroBear;
   double atr;
   double swingHigh, swingLow;
};

struct StratSignal
{
   bool   buy;
   bool   sell;
   int    score;
   string tag;
   string reason;
};

struct Aware
{
   string session;
   bool   killZone;
   bool   newsVol;
};

struct SymCtx
{
   string name;
   datetime lastFire, lastFail;
   string lastTag, lastReason;
   int lastScore;
};

struct PosTrack
{
   ulong ticket;
   string sym;
   int stage;
   double tp1, tp2, tp3, entry;
   long type;
   string tag;
};

SymCtx g_syms[MAX_SYMS];
int g_symCount=0;
string g_active="";
PosTrack g_pos[MAX_POS];
int g_posCount=0;
long g_lastDash=0;
Aware g_aware;
string g_lastBestTag="-";
int g_lastBestScore=0;

//====================================================================//
// UTILS
//====================================================================//
ENUM_TIMEFRAMES ETF(){ return (EntryTF==PERIOD_CURRENT)?(ENUM_TIMEFRAMES)Period():EntryTF; }
double BidS(const string s){ return SymbolInfoDouble(s,SYMBOL_BID); }
double AskS(const string s){ return SymbolInfoDouble(s,SYMBOL_ASK); }
int DigS(const string s){ return (int)SymbolInfoInteger(s,SYMBOL_DIGITS); }
double PtS(const string s){ return SymbolInfoDouble(s,SYMBOL_POINT); }

double ATR_S(const string s, const int period=14)
{
   int p=MathMax(period,5); ENUM_TIMEFRAMES tf=ETF();
   if(Bars(s,tf)<p+5) return 0.0;
   double sum=0;
   for(int i=1;i<=p;i++)
   {
      double h=iHigh(s,tf,i), l=iLow(s,tf,i), pc=iClose(s,tf,i+1);
      sum += MathMax(h-l, MathMax(MathAbs(h-pc), MathAbs(l-pc)));
   }
   return sum/p;
}

double SMA_S(const string s, const ENUM_TIMEFRAMES tf, const int period, const int shift=1)
{
   if(Bars(s,tf)<period+shift+2) return 0.0;
   double a=0; for(int i=shift;i<shift+period;i++) a+=iClose(s,tf,i);
   return a/period;
}

bool SwingHighAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars=Bars(s,tf);
   if(bar-strength<0 || bar+strength>=bars) return false;
   double h=iHigh(s,tf,bar);
   for(int i=1;i<=strength;i++)
      if(iHigh(s,tf,bar-i)>=h || iHigh(s,tf,bar+i)>=h) return false;
   return true;
}
bool SwingLowAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars=Bars(s,tf);
   if(bar-strength<0 || bar+strength>=bars) return false;
   double l=iLow(s,tf,bar);
   for(int i=1;i<=strength;i++)
      if(iLow(s,tf,bar-i)<=l || iLow(s,tf,bar+i)<=l) return false;
   return true;
}

bool FindSwings(const string s, const ENUM_TIMEFRAMES tf, const int lb, const int strength,
                int &iH1, int &iH2, int &iL1, int &iL2)
{
   iH1=iH2=iL1=iL2=0;
   int sw=MathMax(strength,1), look=MathMax(lb,20);
   for(int i=sw+1;i<=look;i++)
   {
      if(iH1==0 && SwingHighAt(s,tf,i,sw)) iH1=i;
      else if(iH1>0 && iH2==0 && SwingHighAt(s,tf,i,sw)) iH2=i;
      if(iL1==0 && SwingLowAt(s,tf,i,sw)) iL1=i;
      else if(iL1>0 && iL2==0 && SwingLowAt(s,tf,i,sw)) iL2=i;
      if(iH1&&iH2&&iL1&&iL2) break;
   }
   return (iH1&&iH2&&iL1&&iL2);
}

//====================================================================//
// ACCOUNT
//====================================================================//
bool AccountReady(string &why)
{
   why="";
   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)==0){ why="trade not allowed"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){ why="terminal blocked"; return false; }
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   double fm=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(eq<=0){ why="bad equity"; return false; }
   if((fm/eq)*100.0 < MinFreeMarginPct){ why="low free margin"; return false; }
   return true;
}

//====================================================================//
// SESSION / NEWS AWARENESS
//====================================================================//
void UpdateAwareness(const string s)
{
   g_aware.session="OFF"; g_aware.killZone=false; g_aware.newsVol=false;
   if(SessionAware)
   {
      MqlDateTime t; TimeToStruct(TimeGMT(), t);
      int h=t.hour;
      bool london=(h>=7 && h<16), ny=(h>=12 && h<21), asia=(h>=0 && h<7);
      if(london&&ny){ g_aware.session="LONDON/NY"; g_aware.killZone=true; }
      else if(london){ g_aware.session="LONDON"; g_aware.killZone=true; }
      else if(ny){ g_aware.session="NEW YORK"; g_aware.killZone=true; }
      else if(asia){ g_aware.session="ASIA"; }
      else g_aware.session="OTHER";
   }
   if(NewsAware)
   {
      ENUM_TIMEFRAMES tf=ETF();
      double atr=ATR_S(s,ATR_Period);
      if(atr>0 && Bars(s,tf)>25)
      {
         double avg=0; for(int i=2;i<=21;i++) avg += (iHigh(s,tf,i)-iLow(s,tf,i));
         avg/=20.0;
         double r1=iHigh(s,tf,1)-iLow(s,tf,1);
         if(avg>0 && r1>=avg*1.45) g_aware.newsVol=true;
      }
   }
}

//====================================================================//
// ENGINE: STRUCTURE
//====================================================================//
void Eng_Structure(const string s, EngineSnap &e)
{
   ENUM_TIMEFRAMES tf=ETF();
   int iH1,iH2,iL1,iL2;
   if(FindSwings(s,tf,StructureLookback,SwingStrength,iH1,iH2,iL1,iL2))
   {
      double h1=iHigh(s,tf,iH1), h2=iHigh(s,tf,iH2);
      double l1=iLow(s,tf,iL1), l2=iLow(s,tf,iL2);
      e.hh=(h1>h2); e.hl=(l1>l2); e.lh=(h1<h2); e.ll=(l1<l2);
      e.bullTrend=(e.hh&&e.hl); e.bearTrend=(e.lh&&e.ll);
      e.swingHigh=h1; e.swingLow=l1;
   }
   else
   {
      e.swingHigh=iHigh(s,tf,iHighest(s,tf,MODE_HIGH,StructureLookback,1));
      e.swingLow =iLow(s,tf,iLowest(s,tf,MODE_LOW,StructureLookback,1));
   }
   double c1=iClose(s,tf,1);
   e.bosBuy  = (e.swingHigh>0 && c1>e.swingHigh);
   e.bosSell = (e.swingLow>0 && c1<e.swingLow);
   // CHoCH proxy: BOS against prior trend leg
   e.chochBuy  = e.bosBuy && (e.ll || e.bearTrend);
   e.chochSell = e.bosSell && (e.hh || e.bullTrend);
   // recent directional BOS window
   for(int i=1;i<=BOS_ConfirmBars;i++)
   {
      double c=iClose(s,tf,i);
      if(c>e.swingHigh) e.bosBuy=true;
      if(c<e.swingLow)  e.bosSell=true;
   }
}

//====================================================================//
// ENGINE: TREND (multi-TF)
//====================================================================//
void Eng_Trend(const string s, EngineSnap &e)
{
   int iH1,iH2,iL1,iL2;
   if(FindSwings(s,BiasTF,40,SwingStrength,iH1,iH2,iL1,iL2))
   {
      bool hh=iHigh(s,BiasTF,iH1)>iHigh(s,BiasTF,iH2);
      bool hl=iLow(s,BiasTF,iL1)>iLow(s,BiasTF,iL2);
      bool lh=iHigh(s,BiasTF,iH1)<iHigh(s,BiasTF,iH2);
      bool ll=iLow(s,BiasTF,iL1)<iLow(s,BiasTF,iL2);
      e.htfBull=(hh&&hl); e.htfBear=(lh&&ll);
   }
   double smaH=SMA_S(s,BiasTF,50);
   double cH=iClose(s,BiasTF,1);
   if(smaH>0){ if(cH>smaH) e.htfBull=true; if(cH<smaH) e.htfBear=true; }
   double smaD=SMA_S(s,MacroTF,20);
   double cD=iClose(s,MacroTF,1);
   if(smaD>0){ e.macroBull=(cD>smaD); e.macroBear=(cD<smaD); }
}

//====================================================================//
// ENGINE: LIQUIDITY
//====================================================================//
void Eng_Liquidity(const string s, EngineSnap &e)
{
   ENUM_TIMEFRAMES tf=ETF();
   if(e.atr<=0) return;
   double tol=e.atr*EqualTolATR;
   int lb=MathMax(StructureLookback/2,12);
   double lo=iLow(s,tf,iLowest(s,tf,MODE_LOW,lb,1));
   double hi=iHigh(s,tf,iHighest(s,tf,MODE_HIGH,lb,1));
   int nL=0,nH=0;
   for(int i=1;i<=lb;i++)
   {
      if(MathAbs(iLow(s,tf,i)-lo)<=tol) nL++;
      if(MathAbs(iHigh(s,tf,i)-hi)<=tol) nH++;
   }
   e.eqLow=(nL>=2); e.eqHigh=(nH>=2);
   e.poolLow = e.eqLow ? lo : e.swingLow;
   e.poolHigh= e.eqHigh ? hi : e.swingHigh;

   double minD=e.atr*SweepDepthATR;
   int swlb=MathMax(SweepLookback,5);
   for(int i=1;i<=swlb;i++)
   {
      double h=iHigh(s,tf,i), l=iLow(s,tf,i), c=iClose(s,tf,i);
      double rng=h-l; if(rng<=0) continue;
      if(!e.sweepBuy && e.poolLow>0 && l<e.poolLow-minD && c>e.poolLow)
      {
         if((MathMin(c,e.poolLow)-l)/rng >= SweepWickMin)
         { e.sweepBuy=true; e.sweepExtBuy=l; }
      }
      if(!e.sweepSell && e.poolHigh>0 && h>e.poolHigh+minD && c<e.poolHigh)
      {
         if((h-MathMax(c,e.poolHigh))/rng >= SweepWickMin)
         { e.sweepSell=true; e.sweepExtSell=h; }
      }
      // stop hunt candles
      double body=MathAbs(c-iOpen(s,tf,i));
      double upper=h-MathMax(c,iOpen(s,tf,i));
      double lower=MathMin(c,iOpen(s,tf,i))-l;
      if(lower/rng>=0.45 && c>iOpen(s,tf,i)) e.stopHuntBuy=true;
      if(upper/rng>=0.45 && c<iOpen(s,tf,i)) e.stopHuntSell=true;
   }
}

//====================================================================//
// ENGINE: ICT (FVG / OB / displacement / premium-discount)
//====================================================================//
void Eng_ICT(const string s, EngineSnap &e)
{
   ENUM_TIMEFRAMES tf=ETF();
   double o1=iOpen(s,tf,1), c1=iClose(s,tf,1), h1=iHigh(s,tf,1), l1=iLow(s,tf,1);
   double r1=h1-l1;
   if(r1>0)
   {
      double br=MathAbs(c1-o1)/r1;
      bool atrOK=(e.atr<=0)||(r1>=e.atr*DispATRMin);
      if(br>=DispBodyMin && atrOK){ e.dispBuy=(c1>o1); e.dispSell=(c1<o1); }
   }
   // FVG
   double gapB=iLow(s,tf,1)-iHigh(s,tf,3);
   double gapS=iLow(s,tf,3)-iHigh(s,tf,1);
   if(gapB>0 && (e.atr<=0 || gapB>=e.atr*FVG_MinATR)) e.fvgBuy=true;
   if(gapS>0 && (e.atr<=0 || gapS>=e.atr*FVG_MinATR)) e.fvgSell=true;
   // Order block: opposite candle before displacement
   double o2=iOpen(s,tf,2), c2=iClose(s,tf,2);
   if(e.dispBuy && c2<o2) e.obBuy=true;
   if(e.dispSell && c2>o2) e.obSell=true;
   // premium / discount from range
   if(e.swingHigh>e.swingLow)
   {
      double mid=(e.swingHigh+e.swingLow)*0.5;
      double px=BidS(s);
      e.inDiscount=(px<=mid); e.inPremium=(px>=mid);
   }
}

//====================================================================//
// ENGINE: FIBONACCI
//====================================================================//
void Eng_Fib(const string s, EngineSnap &e)
{
   e.fib100=e.swingHigh; e.fib0=e.swingLow;
   double rng=e.fib100-e.fib0;
   if(rng<=0) return;
   e.fib382=e.fib0+rng*0.382;
   e.fib500=e.fib0+rng*0.500;
   e.fib618=e.fib0+rng*0.618;
   e.fib786=e.fib0+rng*0.786;
   double pos=(BidS(s)-e.fib0)/rng;
   e.atFibBuy =(pos>=FibBuyLow && pos<=FibBuyHigh);
   e.atFibSell=(pos>=FibSellLow && pos<=FibSellHigh);
}

//====================================================================//
// ENGINE: VOLUME + MOMENTUM
//====================================================================//
void Eng_VolumeMomentum(const string s, EngineSnap &e)
{
   ENUM_TIMEFRAMES tf=ETF();
   double v1=(double)iTickVolume(s,tf,1), sum=0;
   for(int i=2;i<=21;i++) sum+=(double)iTickVolume(s,tf,i);
   double avg=sum/20.0;
   e.volExpand=(avg>0 && v1>=avg*VolExpandMult);
   int up=0, dn=0;
   for(int i=1;i<=MomentumBars;i++)
   {
      if(iClose(s,tf,i)>iOpen(s,tf,i)) up++;
      if(iClose(s,tf,i)<iOpen(s,tf,i)) dn++;
   }
   e.momBuy=(up>=MomentumBars-0); e.momSell=(dn>=MomentumBars-0);
   if(MomentumBars>=3){ e.momBuy=(up>=2); e.momSell=(dn>=2); }
}

//====================================================================//
// FULL MARKET SNAPSHOT
//====================================================================//
void ClearSnap(EngineSnap &e)
{
   e.hh=e.hl=e.lh=e.ll=false;
   e.bosBuy=e.bosSell=e.chochBuy=e.chochSell=false;
   e.bullTrend=e.bearTrend=false;
   e.eqHigh=e.eqLow=e.sweepBuy=e.sweepSell=false;
   e.stopHuntBuy=e.stopHuntSell=false;
   e.poolLow=e.poolHigh=e.sweepExtBuy=e.sweepExtSell=0;
   e.fvgBuy=e.fvgSell=e.obBuy=e.obSell=e.dispBuy=e.dispSell=false;
   e.inDiscount=e.inPremium=false;
   e.fib0=e.fib100=e.fib382=e.fib500=e.fib618=e.fib786=0;
   e.atFibBuy=e.atFibSell=false;
   e.volExpand=e.momBuy=e.momSell=false;
   e.htfBull=e.htfBear=e.macroBull=e.macroBear=false;
   e.atr=0; e.swingHigh=e.swingLow=0;
}

void BuildSnapshot(const string s, EngineSnap &e)
{
   ClearSnap(e);
   e.atr=ATR_S(s,ATR_Period);
   Eng_Structure(s,e);
   Eng_Trend(s,e);
   Eng_Liquidity(s,e);
   Eng_ICT(s,e);
   Eng_Fib(s,e);
   Eng_VolumeMomentum(s,e);
}

int ScoreDirection(const EngineSnap &e, const bool buy)
{
   int sc=0;
   if(buy)
   {
      if(e.htfBull) sc+=12; if(e.macroBull) sc+=8; if(e.bullTrend) sc+=10;
      if(e.bosBuy) sc+=10; if(e.chochBuy) sc+=8;
      if(e.sweepBuy) sc+=18; if(e.stopHuntBuy) sc+=6;
      if(e.dispBuy) sc+=12; if(e.fvgBuy) sc+=8; if(e.obBuy) sc+=8;
      if(e.atFibBuy||e.inDiscount) sc+=8;
      if(e.volExpand&&e.dispBuy) sc+=6; if(e.momBuy) sc+=4;
   }
   else
   {
      if(e.htfBear) sc+=12; if(e.macroBear) sc+=8; if(e.bearTrend) sc+=10;
      if(e.bosSell) sc+=10; if(e.chochSell) sc+=8;
      if(e.sweepSell) sc+=18; if(e.stopHuntSell) sc+=6;
      if(e.dispSell) sc+=12; if(e.fvgSell) sc+=8; if(e.obSell) sc+=8;
      if(e.atFibSell||e.inPremium) sc+=8;
      if(e.volExpand&&e.dispSell) sc+=6; if(e.momSell) sc+=4;
   }
   if(BoostInKillZone && g_aware.killZone) sc+=4;
   if(BoostInNewsVol && g_aware.newsVol && ((buy&&e.dispBuy)||(!buy&&e.dispSell))) sc+=5;
   if(SoftPreferFib)
   {
      if(buy && !e.atFibBuy && !e.inDiscount) sc-=3;
      if(!buy && !e.atFibSell && !e.inPremium) sc-=3;
   }
   if(SoftPreferVolume && !e.volExpand) sc-=2;
   if(sc<0) sc=0; if(sc>100) sc=100;
   return sc;
}

//====================================================================//
// STRATEGIES (from scratch)
//====================================================================//
StratSignal Strat_FlashSweep(const EngineSnap &e)
{
   StratSignal r; r.buy=r.sell=false; r.score=0; r.tag="FlashSweep"; r.reason="";
   int sb=ScoreDirection(e,true), ss=ScoreDirection(e,false);
   bool b = e.sweepBuy && e.dispBuy && (e.htfBull||e.bullTrend||e.macroBull);
   bool s = e.sweepSell && e.dispSell && (e.htfBear||e.bearTrend||e.macroBear);
   if(b && sb>=MinStrategyScore){ r.buy=true; r.score=sb; r.reason="FLASH sweep+disp+bias"; }
   if(s && ss>=MinStrategyScore){ r.sell=true; r.score=ss; r.reason="FLASH sweep+disp+bias"; }
   if(r.buy&&r.sell){ if(sb>=ss) r.sell=false; else r.buy=false; r.score=MathMax(sb,ss); }
   return r;
}

StratSignal Strat_ContSniper(const EngineSnap &e)
{
   StratSignal r; r.buy=r.sell=false; r.score=0; r.tag="ContSniper"; r.reason="";
   int sb=ScoreDirection(e,true), ss=ScoreDirection(e,false);
   bool b = (e.htfBull||e.bullTrend) && (e.bosBuy||e.obBuy||e.fvgBuy) && (e.dispBuy||e.momBuy);
   bool s = (e.htfBear||e.bearTrend) && (e.bosSell||e.obSell||e.fvgSell) && (e.dispSell||e.momSell);
   if(PreferOrderBlock){ if(b && !(e.obBuy||e.fvgBuy||e.bosBuy)) b=false;
                         if(s && !(e.obSell||e.fvgSell||e.bosSell)) s=false; }
   if(b && sb>=MinStrategyScore){ r.buy=true; r.score=sb; r.reason="CONT trend+structure+impulse"; }
   if(s && ss>=MinStrategyScore){ r.sell=true; r.score=ss; r.reason="CONT trend+structure+impulse"; }
   if(r.buy&&r.sell){ if(sb>=ss) r.sell=false; else r.buy=false; r.score=MathMax(sb,ss); }
   return r;
}

StratSignal Strat_RevSniper(const EngineSnap &e)
{
   StratSignal r; r.buy=r.sell=false; r.score=0; r.tag="RevSniper"; r.reason="";
   int sb=ScoreDirection(e,true), ss=ScoreDirection(e,false);
   // Reversal: opposing liquidity swept + choch/disp + zone
   bool b = e.sweepBuy && (e.chochBuy||e.dispBuy) && (e.obBuy||e.fvgBuy||e.stopHuntBuy) && e.inDiscount;
   bool s = e.sweepSell && (e.chochSell||e.dispSell) && (e.obSell||e.fvgSell||e.stopHuntSell) && e.inPremium;
   if(b && sb>=MinStrategyScore){ r.buy=true; r.score=sb+2; r.reason="REV sweep+choch/disp+zone"; }
   if(s && ss>=MinStrategyScore){ r.sell=true; r.score=ss+2; r.reason="REV sweep+choch/disp+zone"; }
   if(r.buy&&r.sell){ if(sb>=ss) r.sell=false; else r.buy=false; r.score=MathMax(sb,ss)+2; }
   if(r.score>100) r.score=100;
   return r;
}

StratSignal Strat_FibSniper(const EngineSnap &e)
{
   StratSignal r; r.buy=r.sell=false; r.score=0; r.tag="FibSniper"; r.reason="";
   int sb=ScoreDirection(e,true), ss=ScoreDirection(e,false);
   bool b = e.atFibBuy && (e.htfBull||e.bullTrend) && (e.dispBuy||e.momBuy||e.obBuy) && (e.inDiscount||e.sweepBuy);
   bool s = e.atFibSell && (e.htfBear||e.bearTrend) && (e.dispSell||e.momSell||e.obSell) && (e.inPremium||e.sweepSell);
   if(b && sb>=MinStrategyScore){ r.buy=true; r.score=sb; r.reason="FIB zone+bias+impulse"; }
   if(s && ss>=MinStrategyScore){ r.sell=true; r.score=ss; r.reason="FIB zone+bias+impulse"; }
   if(r.buy&&r.sell){ if(sb>=ss) r.sell=false; else r.buy=false; r.score=MathMax(sb,ss); }
   return r;
}

StratSignal Strat_BreakImpulse(const EngineSnap &e)
{
   StratSignal r; r.buy=r.sell=false; r.score=0; r.tag="BreakImpulse"; r.reason="";
   int sb=ScoreDirection(e,true), ss=ScoreDirection(e,false);
   bool b = e.bosBuy && e.dispBuy && (e.volExpand||e.momBuy) && (e.htfBull||e.macroBull||e.bullTrend);
   bool s = e.bosSell && e.dispSell && (e.volExpand||e.momSell) && (e.htfBear||e.macroBear||e.bearTrend);
   if(b && sb>=MinStrategyScore){ r.buy=true; r.score=sb; r.reason="BREAK BOS+disp+vol/mom"; }
   if(s && ss>=MinStrategyScore){ r.sell=true; r.score=ss; r.reason="BREAK BOS+disp+vol/mom"; }
   if(r.buy&&r.sell){ if(sb>=ss) r.sell=false; else r.buy=false; r.score=MathMax(sb,ss); }
   return r;
}

StratSignal PickBestStrategy(const EngineSnap &e)
{
   StratSignal best; best.buy=best.sell=false; best.score=-1; best.tag="NONE"; best.reason="no setup";
   StratSignal arr[5];
   int n=0;
   if(Enable_FlashSweep)   arr[n++]=Strat_FlashSweep(e);
   if(Enable_ContSniper)   arr[n++]=Strat_ContSniper(e);
   if(Enable_RevSniper)    arr[n++]=Strat_RevSniper(e);
   if(Enable_FibSniper)    arr[n++]=Strat_FibSniper(e);
   if(Enable_BreakImpulse) arr[n++]=Strat_BreakImpulse(e);

   for(int i=0;i<n;i++)
   {
      if(!(arr[i].buy||arr[i].sell)) continue;
      int sc=arr[i].score;
      // Instant aggressive boost already in score; pick highest
      if(sc>best.score) best=arr[i];
   }
   // Instant fire override: if any strategy has InstantFireScore, keep best
   if(best.score>=0 && best.score<MinStrategyScore && best.score<InstantFireScore)
   { best.buy=best.sell=false; best.tag="NONE"; best.reason="below score"; }
   return best;
}

//====================================================================//
// POSITIONS
//====================================================================//
int CountAllMagic()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue; n++;
   }
   return n;
}
int SymDir(const string s)
{
   bool b=false, sel=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(t==0||!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=s) continue;
      long ty=PositionGetInteger(POSITION_TYPE);
      if(ty==POSITION_TYPE_BUY) b=true; if(ty==POSITION_TYPE_SELL) sel=true;
   }
   if(b&&sel) return 2; if(b) return 1; if(sel) return -1; return 0;
}
int FindPos(const ulong ticket){ for(int i=0;i<g_posCount;i++) if(g_pos[i].ticket==ticket) return i; return -1; }
void TrackAdd(const ulong ticket,const string s,const double entry,const long type,
              const double tp1,const double tp2,const double tp3,const string tag)
{
   int idx=FindPos(ticket);
   if(idx<0){ if(g_posCount>=MAX_POS) return; idx=g_posCount++; }
   g_pos[idx].ticket=ticket; g_pos[idx].sym=s; g_pos[idx].stage=0;
   g_pos[idx].entry=entry; g_pos[idx].type=type;
   g_pos[idx].tp1=tp1; g_pos[idx].tp2=tp2; g_pos[idx].tp3=tp3; g_pos[idx].tag=tag;
}
void TrackPurge()
{
   for(int i=g_posCount-1;i>=0;i--)
      if(!PositionSelectByTicket(g_pos[i].ticket))
      { for(int j=i;j<g_posCount-1;j++) g_pos[j]=g_pos[j+1]; g_posCount--; }
}

//====================================================================//
// EXECUTION
//====================================================================//
double NormVol(const string s, double lots)
{
   double step=SymbolInfoDouble(s,SYMBOL_VOLUME_STEP);
   double vmin=SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(s,SYMBOL_VOLUME_MAX);
   if(step<=0) step=0.01;
   lots=MathFloor(lots/step+1e-12)*step;
   if(lots<vmin) lots=vmin; if(lots>vmax) lots=vmax; if(lots>MaxLotHardCap) lots=MaxLotHardCap;
   int vd=0; double x=step; while(vd<8 && MathAbs(x-MathRound(x))>1e-8){ x*=10; vd++; }
   return NormalizeDouble(lots,vd);
}
double CalcLots(const string s, const double slDist)
{
   if(UseFixedLot) return NormVol(s,LotSize);
   if(slDist<=0) return NormVol(s,LotSize);
   double tv=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_VALUE);
   double ts=SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE);
   if(tv<=0||ts<=0) return NormVol(s,LotSize);
   double risk=AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercent/100.0;
   double per=(slDist/ts)*tv; if(per<=0) return NormVol(s,LotSize);
   return NormVol(s, risk/per);
}
bool FixStops(const string s, const bool buy, const double price, double &sl, double &tp)
{
   int need=(int)MathMax(SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL), SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL));
   double minD=MathMax(need*PtS(s), PtS(s));
   if(buy){ if(sl>0 && price-sl<minD) sl=price-minD; if(tp>0 && tp-price<minD) tp=price+minD; }
   else { if(sl>0 && sl-price<minD) sl=price+minD; if(tp>0 && price-tp<minD) tp=price-minD; }
   sl=NormalizeDouble(sl,DigS(s)); tp=NormalizeDouble(tp,DigS(s));
   return buy ? (sl<price && tp>price) : (sl>price && tp<price);
}

bool OpenTrade(const string s, const bool buy, const EngineSnap &e, const StratSignal &sig)
{
   string aw; if(!AccountReady(aw)){ if(EnableVerbose) Print("ACCOUNT: ",aw); return false; }
   if(CountAllMagic()>=MaxOpenTrades) return false;
   if(MaxSpreadPoints>0 && SymbolInfoInteger(s,SYMBOL_SPREAD)>MaxSpreadPoints) return false;
   int dir=SymDir(s);
   if(buy && (dir<0 || dir==2)) return false;
   if(!buy && (dir>0)) return false;

   int si=-1; for(int i=0;i<g_symCount;i++) if(g_syms[i].name==s){ si=i; break; }
   if(si>=0){
      if(TimeCurrent()-g_syms[si].lastFire < TradeCooldownSec) return false;
      if(TimeCurrent()-g_syms[si].lastFail < TradeCooldownSec) return false;
   }
   if(e.atr<=0) return false;
   double price=buy?AskS(s):BidS(s);
   double sl=buy?price-e.atr*SL_ATR:price+e.atr*SL_ATR;
   if(buy && e.sweepExtBuy>0){ double inv=e.sweepExtBuy-e.atr*0.1; if(inv<price && inv<sl) sl=inv; }
   if(!buy && e.sweepExtSell>0){ double inv=e.sweepExtSell+e.atr*0.1; if(inv>price && inv>sl) sl=inv; }
   double slDist=MathAbs(price-sl);
   double tp1=buy?price+e.atr*TP1_ATR:price-e.atr*TP1_ATR;
   double tp2=buy?price+e.atr*TP2_ATR:price-e.atr*TP2_ATR;
   double tp3=buy?price+e.atr*TP3_ATR:price-e.atr*TP3_ATR;
   double tp=tp3;
   if(!FixStops(s,buy,price,sl,tp)) return false;
   tp1=NormalizeDouble(tp1,DigS(s)); tp2=NormalizeDouble(tp2,DigS(s)); tp3=tp;
   double lots=CalcLots(s,slDist); if(lots<=0) return false;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(s);
   bool ok=false;
   for(int a=0;a<4 && !ok;a++)
      ok=buy?trade.Buy(lots,s,0,sl,tp,TradeComment):trade.Sell(lots,s,0,sl,tp,TradeComment);

   if(ok)
   {
      ulong ticket=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL)==s && PositionGetInteger(POSITION_MAGIC)==MagicNumber)
         { ticket=t; break; }
      }
      TrackAdd(ticket,s,price,buy?POSITION_TYPE_BUY:POSITION_TYPE_SELL,tp1,tp2,tp3,sig.tag);
      if(si>=0){ g_syms[si].lastFire=TimeCurrent(); g_syms[si].lastScore=sig.score;
                 g_syms[si].lastTag=sig.tag; g_syms[si].lastReason=sig.reason; }
      g_lastBestTag=sig.tag; g_lastBestScore=sig.score;
      Print("SNIPER AI FIRE ",(buy?"BUY":"SELL")," [",sig.tag,"] ",s,
            " score=",sig.score," lots=",lots," | ",sig.reason,
            " | ",g_aware.session,(g_aware.newsVol?" | NEWS-VOL":""));
   }
   else
   {
      if(si>=0) g_syms[si].lastFail=TimeCurrent();
      Print("SNIPER AI fail ",s," ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
   }
   return ok;
}

//====================================================================//
// TRADE MANAGER
//====================================================================//
void ManageSymbol(const string s)
{
   TrackPurge();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0||!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)!=s) continue;

      int ti=FindPos(ticket);
      double open=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      double vol=PositionGetDouble(POSITION_VOLUME);
      long type=PositionGetInteger(POSITION_TYPE);
      double price=(type==POSITION_TYPE_BUY)?BidS(s):AskS(s);
      double atr=ATR_S(s,ATR_Period);

      double tp1,tp2,tp3; int stage=0;
      if(ti>=0){ tp1=g_pos[ti].tp1; tp2=g_pos[ti].tp2; tp3=g_pos[ti].tp3; stage=g_pos[ti].stage; }
      else {
         tp1=(type==POSITION_TYPE_BUY)?open+atr*TP1_ATR:open-atr*TP1_ATR;
         tp2=(type==POSITION_TYPE_BUY)?open+atr*TP2_ATR:open-atr*TP2_ATR;
         tp3=tp; TrackAdd(ticket,s,open,type,tp1,tp2,tp3,"Recover"); ti=FindPos(ticket);
      }

      if(stage<1)
      {
         bool hit=(type==POSITION_TYPE_BUY)?(price>=tp1):(price<=tp1);
         if(hit)
         {
            double cv=NormalizeDouble(vol*(TP1_ClosePercent/100.0),2);
            double vmin=SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
            if(cv>=vmin && cv<vol) trade.PositionClosePartial(ticket,cv);
            if(MoveBE_AtTP1)
            {
               double be=open+((type==POSITION_TYPE_BUY)?1:-1)*BE_OffsetPoints*PtS(s);
               trade.PositionModify(ticket,NormalizeDouble(be,DigS(s)),tp3);
            }
            if(ti>=0) g_pos[ti].stage=1;
            if(EnableVerbose) Print("SNIPER AI TP1 ",s," #",ticket);
            continue;
         }
      }
      if(stage<2)
      {
         bool hit=(type==POSITION_TYPE_BUY)?(price>=tp2):(price<=tp2);
         if(hit)
         {
            if(!PositionSelectByTicket(ticket)) continue;
            vol=PositionGetDouble(POSITION_VOLUME);
            double cv=NormalizeDouble(vol*(TP2_ClosePercent/100.0),2);
            double vmin=SymbolInfoDouble(s,SYMBOL_VOLUME_MIN);
            if(cv>=vmin && cv<vol) trade.PositionClosePartial(ticket,cv);
            if(ti>=0) g_pos[ti].stage=2;
            if(EnableVerbose) Print("SNIPER AI TP2 ",s," #",ticket);
            continue;
         }
      }
      if(TrailAfterTP2 && stage>=2 && atr>0)
      {
         double trail=atr*Trail_ATR;
         if(type==POSITION_TYPE_BUY)
         { double nsl=NormalizeDouble(price-trail,DigS(s)); if(nsl>sl&&nsl<price) trade.PositionModify(ticket,nsl,tp3); }
         else
         { double nsl=NormalizeDouble(price+trail,DigS(s)); if((sl==0||nsl<sl)&&nsl>price) trade.PositionModify(ticket,nsl,tp3); }
      }
      // strong reversal exit only after TP1
      if(stage>=1)
      {
         EngineSnap e; BuildSnapshot(s,e);
         int opp = ScoreDirection(e, type!=POSITION_TYPE_BUY);
         bool fireOpp=false;
         if(type==POSITION_TYPE_BUY && e.sweepSell && e.dispSell && opp>=ReversalExitScore) fireOpp=true;
         if(type==POSITION_TYPE_SELL && e.sweepBuy && e.dispBuy && opp>=ReversalExitScore) fireOpp=true;
         if(fireOpp)
         {
            trade.PositionClose(ticket);
            if(EnableVerbose) Print("SNIPER AI REVERSAL EXIT ",s," #",ticket);
         }
      }
   }
}

//====================================================================//
// ORCHESTRATOR
//====================================================================//
void EvaluateSymbol(const string s)
{
   if(!SymbolSelect(s,true)) return;
   if(Bars(s,ETF())<StructureLookback+30) return;
   UpdateAwareness(s);
   EngineSnap e; BuildSnapshot(s,e);
   StratSignal sig=PickBestStrategy(e);
   g_lastBestTag=sig.tag; g_lastBestScore=sig.score;

   if(sig.buy){ OpenTrade(s,true,e,sig); return; }
   if(sig.sell){ OpenTrade(s,false,e,sig); return; }

   if(EnableVerbose)
   {
      static datetime lastBar=0; datetime bt=iTime(s,ETF(),0);
      if(bt!=lastBar){ lastBar=bt;
         Print("SNIPER AI scan ",s," best=",sig.tag,"/",sig.score,
               " BUY=",ScoreDirection(e,true)," SELL=",ScoreDirection(e,false),
               " | ",g_aware.session,(g_aware.newsVol?" NEWS-VOL":"")); }
   }
}

void DrawDash()
{
   if(!EnableDashboard) return;
   long now=(long)GetTickCount(); if(now-g_lastDash<DashRefreshMs) return; g_lastDash=now;
   string s=g_active; if(s=="") s=_Symbol;
   EngineSnap e; BuildSnapshot(s,e);
   string aw; bool acc=AccountReady(aw);
   Comment(
      "========== SNIPER AI PRIME ==========\n",
      s," | ",EnumToString(ETF())," / ",EnumToString(BiasTF),"\n",
      "Session: ",g_aware.session,(g_aware.newsVol?" | EVENT VOL":""),"\n",
      "Best: ",g_lastBestTag," (",IntegerToString(g_lastBestScore),")\n",
      "Score BUY/SELL: ",IntegerToString(ScoreDirection(e,true)),"/",IntegerToString(ScoreDirection(e,false)),"\n",
      "Struct: ",(e.bullTrend?"BULL":(e.bearTrend?"BEAR":"RANGE")),
      " Sweep:",(e.sweepBuy?"B":"-"),(e.sweepSell?"S":"-"),
      " FVG:",(e.fvgBuy?"B":"-"),(e.fvgSell?"S":"-"),
      " OB:",(e.obBuy?"B":"-"),(e.obSell?"S":"-"),"\n",
      "Fib:",(e.atFibBuy?"BUYZONE":(e.atFibSell?"SELLZONE":"-")),
      " Disp:",(e.dispBuy?"B":"-"),(e.dispSell?"S":"-"),
      " Vol:",(e.volExpand?"EXP":"-"),"\n",
      "Open: ",IntegerToString(CountAllMagic()),"/",IntegerToString(MaxOpenTrades),
      " | Account: ",(acc?"READY":aw),"\n",
      "Strategies: Flash/Cont/Rev/Fib/Break\n",
      "Comment: SNIPER AI\n",
      "===================================="
   );
}

void AddSym(const string s)
{
   if(s==""||g_symCount>=MAX_SYMS) return;
   for(int i=0;i<g_symCount;i++) if(g_syms[i].name==s) return;
   if(!SymbolSelect(s,true)) return;
   g_syms[g_symCount].name=s; g_syms[g_symCount].lastFire=0; g_syms[g_symCount].lastFail=0;
   g_syms[g_symCount].lastTag="-"; g_syms[g_symCount].lastReason="-"; g_syms[g_symCount].lastScore=0;
   g_symCount++;
}
void BuildSymbols()
{
   g_symCount=0; AddSym(_Symbol);
   if(!EnableMultiSymbol) return;
   string parts[]; int n=StringSplit(ExtraSymbols,',',parts);
   for(int i=0;i<n;i++){ string x=parts[i]; StringTrimLeft(x); StringTrimRight(x); if(x!="") AddSym(x); }
}
void RunCycle(const string s){ g_active=s; ManageSymbol(s); EvaluateSymbol(s); }

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   BuildSymbols(); g_active=_Symbol;
   Print("SNIPER AI Loaded BUILD_ID=SA_PRIME_90 — FULL FROM-SCRATCH PRIME STACK");
   Print("Strategies: FlashSweep ContSniper RevSniper FibSniper BreakImpulse | MaxOpen=",MaxOpenTrades);
   Print("Engines: Structure Trend Liquidity ICT Fib Volume Momentum | Session/News aware (no hard-block)");
   Print("Trade comment: SNIPER AI");
   if(EnableMultiSymbol) EventSetTimer(MathMax(MultiSymbolTimerSec,1));
   DrawDash(); return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){ EventKillTimer(); Comment(""); }
void OnTick(){ RunCycle(_Symbol); DrawDash(); }
void OnTimer()
{
   if(!EnableMultiSymbol) return;
   for(int i=0;i<g_symCount;i++) if(g_syms[i].name!=_Symbol) RunCycle(g_syms[i].name);
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{ if(trans.type==TRADE_TRANSACTION_DEAL_ADD) TrackPurge(); }
//+------------------------------------------------------------------+
