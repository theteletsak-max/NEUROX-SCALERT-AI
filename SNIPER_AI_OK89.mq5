//+------------------------------------------------------------------+
//| SNIPER_AI.mq5                                                     |
//| BUILD_ID: SA_FLASH_89                                             |
//| SNIPER AI — FROM-SCRATCH FLASH SNIPER CORE                        |
//| Trade comment: SNIPER AI                                          |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "7.00"
#property description "SNIPER AI FLASH CORE — own market reader + sniper execution"
#property description "Instant quality entries | TP1/TP2/TP3 | anytime | all brokers"

#include <Trade/Trade.mqh>
CTrade trade;

//====================================================================//
//  INPUTS
//====================================================================//
input group "GENERAL"
input long   MagicNumber   = 40001;
input string TradeComment  = "SNIPER AI";
input bool   EnableVerbose = true;

input group "SYMBOLS"
input bool   EnableMultiSymbol = false;
input string ExtraSymbols      = "";          // e.g. EURUSD,GBPUSD,XAUUSD
input int    MultiSymbolTimerSec = 1;

input group "TIMEFRAMES"
input ENUM_TIMEFRAMES EntryTF  = PERIOD_CURRENT;
input ENUM_TIMEFRAMES BiasTF   = PERIOD_H4;
input ENUM_TIMEFRAMES MacroTF  = PERIOD_D1;

input group "FLASH SNIPER STRATEGY"
input int    SwingStrength       = 2;
input int    StructureLookback   = 40;
input int    SweepLookback       = 20;
input double EqualTolATR         = 0.12;
input double SweepWickMin        = 0.28;
input double SweepDepthATR       = 0.06;
input double DispBodyMin         = 0.48;
input double DispATRMin          = 0.35;
input double FibBuyLow           = 0.50;       // discount fib band
input double FibBuyHigh          = 0.886;
input double FibSellLow          = 0.114;
input double FibSellHigh         = 0.50;       // premium fib band
input bool   PreferFibZone       = true;       // soft prefer, not endless block
input bool   RequireVolExpand    = false;      // soft prefer by default
input double VolExpandMult       = 1.20;
input int    MinSniperScore      = 62;         // 0-100 quality floor
input int    InstantScore        = 78;         // aggressive instant fire

input group "SIZE & ACCOUNT"
input int    MaxOpenTrades       = 3;
input bool   UseFixedLot         = true;
input double LotSize             = 0.01;
input double RiskPercent         = 1.0;
input double MaxLotHardCap       = 5.0;
input double MinFreeMarginPct    = 15.0;       // need free margin % of equity
input double MaxSpreadPoints     = 0;          // 0 = off (never hard-block by spread)
input int    SlippagePoints      = 40;
input int    TradeCooldownSec     = 5;          // short — aggressive

input group "STOPS & TP LADDER"
input int    ATR_Period          = 14;
input double SL_ATR              = 1.40;
input double TP1_ATR             = 1.00;
input double TP2_ATR             = 2.00;
input double TP3_ATR             = 3.50;
input double TP1_ClosePercent    = 40.0;       // close % at TP1
input double TP2_ClosePercent    = 40.0;       // of remainder at TP2
input bool   MoveBE_AtTP1        = true;
input double BE_OffsetPoints     = 5;
input bool   TrailAfterTP2       = true;
input double Trail_ATR           = 1.10;
input bool   HoldThroughNoise    = true;       // ignore weak opposite wicks
input int    ReversalExitScore   = 80;         // only strong opposite sniper closes early

input group "SESSION / NEWS AWARENESS (never hard-block)"
input bool   SessionAware        = true;
input bool   NewsAware           = true;
input int    NewsWindowMinutes   = 30;         // volatility-spike proxy window
input bool   BoostScoreInKillZone = true;
input bool   BoostScoreInNewsVol  = true;

input group "DASHBOARD"
input bool   EnableDashboard     = true;
input int    DashRefreshMs       = 800;

//====================================================================//
//  TYPES / STATE
//====================================================================//
#define MAX_SYMS 32
#define MAX_POS_TRACK 64

struct SymCtx
{
   string   name;
   datetime lastBar;
   datetime lastFire;
   datetime lastFail;
   string   lastReason;
   int      lastScore;
   int      lastDir;       // 1 buy, -1 sell, 0 none
};

struct PosTrack
{
   ulong  ticket;
   string sym;
   int    stage;           // 0=none,1=tp1 done,2=tp2 done
   double tp1;
   double tp2;
   double tp3;
   double entry;
   long   type;
};

struct MarketRead
{
   bool   bullStruct;
   bool   bearStruct;
   bool   htfBull;
   bool   htfBear;
   bool   macroBull;
   bool   macroBear;
   bool   sweepBuy;        // sell-side liquidity taken (lows) → buy setup
   bool   sweepSell;       // buy-side liquidity taken (highs) → sell setup
   bool   dispBuy;
   bool   dispSell;
   bool   volExpand;
   bool   inDiscount;
   bool   inPremium;
   bool   atFibBuy;
   bool   atFibSell;
   double atr;
   double fib0;
   double fib100;
   double fib618;
   double swingHigh;
   double swingLow;
   double poolBuy;
   double poolSell;
   double sweepExtBuy;
   double sweepExtSell;
   int    scoreBuy;
   int    scoreSell;
   string whyBuy;
   string whySell;
};

struct AwareState
{
   string session;
   bool   killZone;
   bool   newsVol;
   string note;
};

SymCtx     g_syms[MAX_SYMS];
int        g_symCount = 0;
string     g_active = "";
PosTrack   g_pos[MAX_POS_TRACK];
int        g_posCount = 0;
long       g_lastDash = 0;
AwareState g_aware;

//====================================================================//
//  UTILS
//====================================================================//
ENUM_TIMEFRAMES ETF()
{
   return (EntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : EntryTF;
}

double BidS(const string s){ return SymbolInfoDouble(s, SYMBOL_BID); }
double AskS(const string s){ return SymbolInfoDouble(s, SYMBOL_ASK); }
int DigS(const string s){ return (int)SymbolInfoInteger(s, SYMBOL_DIGITS); }
double PtS(const string s){ return SymbolInfoDouble(s, SYMBOL_POINT); }

double ATR_S(const string s, const int period = 14)
{
   int p = MathMax(period, 5);
   ENUM_TIMEFRAMES tf = ETF();
   if(Bars(s, tf) < p + 5) return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= p; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), pc = iClose(s, tf, i + 1);
      double tr = MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
      sum += tr;
   }
   return sum / p;
}

double SMA_S(const string s, const ENUM_TIMEFRAMES tf, const int period, const int shift = 1)
{
   if(Bars(s, tf) < period + shift + 2) return 0.0;
   double a = 0.0;
   for(int i = shift; i < shift + period; i++) a += iClose(s, tf, i);
   return a / period;
}

bool SwingHighAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double h = iHigh(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iHigh(s, tf, bar - i) >= h || iHigh(s, tf, bar + i) >= h) return false;
   return true;
}

bool SwingLowAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double l = iLow(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iLow(s, tf, bar - i) <= l || iLow(s, tf, bar + i) <= l) return false;
   return true;
}

bool FindSwings(const string s, const ENUM_TIMEFRAMES tf, const int lb, const int strength,
                double &sh1, double &sh2, double &sl1, double &sl2)
{
   sh1 = sh2 = sl1 = sl2 = 0.0;
   int i1h = 0, i2h = 0, i1l = 0, i2l = 0;
   int swn = MathMax(strength, 1);
   int look = MathMax(lb, 20);
   for(int i = swn + 1; i <= look; i++)
   {
      if(i1h == 0 && SwingHighAt(s, tf, i, swn)) i1h = i;
      else if(i1h > 0 && i2h == 0 && SwingHighAt(s, tf, i, swn)) i2h = i;
      if(i1l == 0 && SwingLowAt(s, tf, i, swn)) i1l = i;
      else if(i1l > 0 && i2l == 0 && SwingLowAt(s, tf, i, swn)) i2l = i;
      if(i1h && i2h && i1l && i2l) break;
   }
   if(!(i1h && i2h && i1l && i2l)) return false;
   sh1 = iHigh(s, tf, i1h); sh2 = iHigh(s, tf, i2h);
   sl1 = iLow(s, tf, i1l);  sl2 = iLow(s, tf, i2l);
   return true;
}

double TickVolAvg(const string s, const int bars)
{
   ENUM_TIMEFRAMES tf = ETF();
   int n = MathMax(bars, 5);
   if(Bars(s, tf) < n + 2) return 0.0;
   double sum = 0.0;
   for(int i = 2; i <= n + 1; i++) sum += (double)iTickVolume(s, tf, i);
   return sum / n;
}

//====================================================================//
//  ACCOUNT GATE
//====================================================================//
bool AccountReady(string &why)
{
   why = "";
   if(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) == 0)
   { why = "account trade not allowed"; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   { why = "terminal trade not allowed"; return false; }
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(eq <= 0.0){ why = "equity invalid"; return false; }
   double pct = (fm / eq) * 100.0;
   if(pct < MinFreeMarginPct)
   { why = StringFormat("free margin %.1f%% < %.1f%%", pct, MinFreeMarginPct); return false; }
   return true;
}

//====================================================================//
//  SESSION + NEWS AWARENESS (never blocks)
//====================================================================//
void UpdateAwareness()
{
   g_aware.session = "OFF";
   g_aware.killZone = false;
   g_aware.newsVol = false;
   g_aware.note = "";

   if(SessionAware)
   {
      MqlDateTime t; TimeToStruct(TimeGMT(), t);
      int h = t.hour;
      bool london = (h >= 7 && h < 16);
      bool ny     = (h >= 12 && h < 21);
      bool asia   = (h >= 0 && h < 7);
      if(london && ny) { g_aware.session = "LONDON/NY OVERLAP"; g_aware.killZone = true; }
      else if(london)  { g_aware.session = "LONDON"; g_aware.killZone = true; }
      else if(ny)      { g_aware.session = "NEW YORK"; g_aware.killZone = true; }
      else if(asia)    { g_aware.session = "ASIA"; g_aware.killZone = false; }
      else             { g_aware.session = "OTHER"; }
   }

   if(NewsAware)
   {
      // Volatility-spike proxy = news/event energy (no calendar hard-block)
      string s = g_active;
      if(s == "") s = _Symbol;
      double atr = ATR_S(s, ATR_Period);
      double avg = 0.0;
      ENUM_TIMEFRAMES tf = ETF();
      int n = 20;
      if(Bars(s, tf) > n + 5 && atr > 0.0)
      {
         for(int i = 2; i <= n + 1; i++)
            avg += (iHigh(s, tf, i) - iLow(s, tf, i));
         avg /= n;
         double r1 = iHigh(s, tf, 1) - iLow(s, tf, 1);
         if(avg > 0.0 && r1 >= avg * 1.45)
         {
            g_aware.newsVol = true;
            g_aware.note = "EVENT/VOL SPIKE — trade allowed";
         }
      }
   }
}

//====================================================================//
//  MARKET READER — own features from scratch
//====================================================================//
void ReadMarket(const string s, MarketRead &m)
{
   m.bullStruct=false; m.bearStruct=false;
   m.htfBull=false; m.htfBear=false; m.macroBull=false; m.macroBear=false;
   m.sweepBuy=false; m.sweepSell=false; m.dispBuy=false; m.dispSell=false;
   m.volExpand=false; m.inDiscount=false; m.inPremium=false;
   m.atFibBuy=false; m.atFibSell=false;
   m.atr=0; m.fib0=0; m.fib100=0; m.fib618=0;
   m.swingHigh=0; m.swingLow=0; m.poolBuy=0; m.poolSell=0;
   m.sweepExtBuy=0; m.sweepExtSell=0;
   m.scoreBuy=0; m.scoreSell=0;
   m.whyBuy=""; m.whySell="";
   ENUM_TIMEFRAMES tf = ETF();
   m.atr = ATR_S(s, ATR_Period);

   double sh1, sh2, sl1, sl2;
   if(FindSwings(s, tf, StructureLookback, SwingStrength, sh1, sh2, sl1, sl2))
   {
      m.bullStruct = (sh1 > sh2 && sl1 > sl2);
      m.bearStruct = (sh1 < sh2 && sl1 < sl2);
      m.swingHigh = sh1;
      m.swingLow  = sl1;
   }
   else
   {
      m.swingHigh = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, StructureLookback, 1));
      m.swingLow  = iLow(s, tf, iLowest(s, tf, MODE_LOW, StructureLookback, 1));
   }

   // Fibonacci range from swing high/low
   m.fib100 = m.swingHigh;
   m.fib0   = m.swingLow;
   double rng = m.fib100 - m.fib0;
   if(rng > 0.0)
   {
      m.fib618 = m.fib0 + rng * 0.618;
      double price = BidS(s);
      double pos = (price - m.fib0) / rng; // 0=low, 1=high
      m.inDiscount = (pos <= 0.50);
      m.inPremium  = (pos >= 0.50);
      m.atFibBuy   = (pos >= FibBuyLow && pos <= FibBuyHigh);
      m.atFibSell  = (pos >= FibSellLow && pos <= FibSellHigh);
   }

   // HTF / Macro bias (structure + SMA) — price only
   double bsh1,bsh2,bsl1,bsl2;
   if(FindSwings(s, BiasTF, 40, SwingStrength, bsh1, bsh2, bsl1, bsl2))
   {
      m.htfBull = (bsh1 > bsh2 && bsl1 > bsl2);
      m.htfBear = (bsh1 < bsh2 && bsl1 < bsl2);
   }
   double smaH = SMA_S(s, BiasTF, 50);
   double cH = iClose(s, BiasTF, 1);
   if(smaH > 0.0)
   {
      // MA confirms or seeds HTF bias when swings missing
      if(cH > smaH) m.htfBull = true;
      if(cH < smaH) m.htfBear = true;
   }
   double smaD = SMA_S(s, MacroTF, 20);
   double cD = iClose(s, MacroTF, 1);
   if(smaD > 0.0)
   {
      m.macroBull = (cD > smaD);
      m.macroBear = (cD < smaD);
   }

   // Equal liquidity pools
   if(m.atr > 0.0)
   {
      double tol = m.atr * EqualTolATR;
      int lb = MathMax(StructureLookback / 2, 12);
      double lo = iLow(s, tf, iLowest(s, tf, MODE_LOW, lb, 1));
      double hi = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, lb, 1));
      int nL = 0, nH = 0;
      for(int i = 1; i <= lb; i++)
      {
         if(MathAbs(iLow(s, tf, i) - lo) <= tol) nL++;
         if(MathAbs(iHigh(s, tf, i) - hi) <= tol) nH++;
      }
      if(nL >= 2) m.poolBuy = lo;
      else m.poolBuy = m.swingLow;
      if(nH >= 2) m.poolSell = hi;
      else m.poolSell = m.swingHigh;
   }

   // Liquidity sweeps + reclaim (FLASH)
   int swlb = MathMax(SweepLookback, 5);
   double minDepth = (m.atr > 0.0) ? m.atr * SweepDepthATR : 0.0;
   for(int i = 1; i <= swlb; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), c = iClose(s, tf, i);
      double range = h - l;
      if(range <= 0.0) continue;
      // buy setup: sweep lows of pool/swing then reclaim
      if(!m.sweepBuy && m.poolBuy > 0.0)
      {
         if(l < m.poolBuy - minDepth && c > m.poolBuy)
         {
            double wick = MathMin(c, m.poolBuy) - l;
            if(wick / range >= SweepWickMin)
            {
               m.sweepBuy = true;
               m.sweepExtBuy = l;
            }
         }
      }
      if(!m.sweepSell && m.poolSell > 0.0)
      {
         if(h > m.poolSell + minDepth && c < m.poolSell)
         {
            double wick = h - MathMax(c, m.poolSell);
            if(wick / range >= SweepWickMin)
            {
               m.sweepSell = true;
               m.sweepExtSell = h;
            }
         }
      }
   }

   // Displacement impulse (bar1)
   double o1 = iOpen(s, tf, 1), c1 = iClose(s, tf, 1);
   double h1 = iHigh(s, tf, 1), l1 = iLow(s, tf, 1);
   double r1 = h1 - l1;
   if(r1 > 0.0)
   {
      double body = MathAbs(c1 - o1) / r1;
      bool atrOK = (m.atr <= 0.0) || (r1 >= m.atr * DispATRMin);
      if(body >= DispBodyMin && atrOK)
      {
         m.dispBuy  = (c1 > o1);
         m.dispSell = (c1 < o1);
      }
   }

   // Volume expansion
   double v1 = (double)iTickVolume(s, tf, 1);
   double vavg = TickVolAvg(s, 20);
   m.volExpand = (vavg > 0.0 && v1 >= vavg * VolExpandMult);

   //----- SCORE (own confluence) -----
   int sb = 0, ss = 0;
   // Bias
   if(m.htfBull) sb += 14; if(m.htfBear) ss += 14;
   if(m.macroBull) sb += 8; if(m.macroBear) ss += 8;
   if(m.bullStruct) sb += 10; if(m.bearStruct) ss += 10;
   // Sweep flash
   if(m.sweepBuy) sb += 22; if(m.sweepSell) ss += 22;
   // Displacement
   if(m.dispBuy) sb += 16; if(m.dispSell) ss += 16;
   // Fib / premium-discount
   if(m.atFibBuy || m.inDiscount) sb += 10;
   if(m.atFibSell || m.inPremium) ss += 10;
   // Volume
   if(m.volExpand && m.dispBuy) sb += 8;
   if(m.volExpand && m.dispSell) ss += 8;
   // Awareness boosts (never subtract to block)
   if(BoostScoreInKillZone && g_aware.killZone) { sb += 4; ss += 4; }
   if(BoostScoreInNewsVol && g_aware.newsVol)
   {
      if(m.dispBuy && m.sweepBuy) sb += 6;
      if(m.dispSell && m.sweepSell) ss += 6;
   }
   // Soft fib prefer: small haircut only if PreferFibZone and far from zone
   if(PreferFibZone)
   {
      if(!m.atFibBuy && !m.inDiscount && sb > 0) sb -= 4;
      if(!m.atFibSell && !m.inPremium && ss > 0) ss -= 4;
   }
   if(RequireVolExpand)
   {
      if(!m.volExpand && m.dispBuy) sb -= 3;
      if(!m.volExpand && m.dispSell) ss -= 3;
   }
   if(sb < 0) sb = 0; if(ss < 0) ss = 0;
   if(sb > 100) sb = 100; if(ss > 100) ss = 100;
   m.scoreBuy = sb;
   m.scoreSell = ss;

   m.whyBuy = StringFormat("BUY score=%d sweep=%d disp=%d fib=%d vol=%d htf=%d",
                           sb, m.sweepBuy, m.dispBuy, (m.atFibBuy||m.inDiscount), m.volExpand, m.htfBull);
   m.whySell = StringFormat("SELL score=%d sweep=%d disp=%d fib=%d vol=%d htf=%d",
                            ss, m.sweepSell, m.dispSell, (m.atFibSell||m.inPremium), m.volExpand, m.htfBear);
}

//====================================================================//
//  POSITION HELPERS
//====================================================================//
int CountAllMagic()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      n++;
   }
   return n;
}

int CountSym(const string s)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      n++;
   }
   return n;
}

int SymDir(const string s) // 1 buy open, -1 sell open, 0 none, 2 both(shouldn't)
{
   bool b = false, sel = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      long ty = PositionGetInteger(POSITION_TYPE);
      if(ty == POSITION_TYPE_BUY) b = true;
      if(ty == POSITION_TYPE_SELL) sel = true;
   }
   if(b && sel) return 2;
   if(b) return 1;
   if(sel) return -1;
   return 0;
}

int FindPosTrack(const ulong ticket)
{
   for(int i = 0; i < g_posCount; i++)
      if(g_pos[i].ticket == ticket) return i;
   return -1;
}

void TrackAdd(const ulong ticket, const string s, const double entry, const long type,
              const double tp1, const double tp2, const double tp3)
{
   int idx = FindPosTrack(ticket);
   if(idx < 0)
   {
      if(g_posCount >= MAX_POS_TRACK) return;
      idx = g_posCount++;
   }
   g_pos[idx].ticket = ticket;
   g_pos[idx].sym = s;
   g_pos[idx].stage = 0;
   g_pos[idx].entry = entry;
   g_pos[idx].type = type;
   g_pos[idx].tp1 = tp1;
   g_pos[idx].tp2 = tp2;
   g_pos[idx].tp3 = tp3;
}

void TrackPurgeClosed()
{
   for(int i = g_posCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_pos[i].ticket))
      {
         for(int j = i; j < g_posCount - 1; j++) g_pos[j] = g_pos[j + 1];
         g_posCount--;
      }
   }
}

//====================================================================//
//  EXECUTION — instant, broker-safe
//====================================================================//
double NormVol(const string s, double lots)
{
   double step = SymbolInfoDouble(s, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(s, SYMBOL_VOLUME_MAX);
   if(step <= 0.0) step = 0.01;
   lots = MathFloor(lots / step + 1e-12) * step;
   if(lots < vmin) lots = vmin;
   if(lots > vmax) lots = vmax;
   if(lots > MaxLotHardCap) lots = MaxLotHardCap;
   int vd = 0; double x = step;
   while(vd < 8 && MathAbs(x - MathRound(x)) > 1e-8) { x *= 10.0; vd++; }
   return NormalizeDouble(lots, vd);
}

double CalcLots(const string s, const double slDist)
{
   if(UseFixedLot) return NormVol(s, LotSize);
   if(slDist <= 0.0) return NormVol(s, LotSize);
   double tickVal = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0) return NormVol(s, LotSize);
   double risk = AccountInfoDouble(ACCOUNT_EQUITY) * RiskPercent / 100.0;
   double per = (slDist / tickSize) * tickVal;
   if(per <= 0.0) return NormVol(s, LotSize);
   return NormVol(s, risk / per);
}

bool FixStops(const string s, const bool buy, const double price, double &sl, double &tp)
{
   int stops = (int)SymbolInfoInteger(s, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze = (int)SymbolInfoInteger(s, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist = MathMax(stops, freeze) * PtS(s);
   if(minDist <= 0.0) minDist = PtS(s);
   if(buy)
   {
      if(sl > 0 && price - sl < minDist) sl = price - minDist;
      if(tp > 0 && tp - price < minDist) tp = price + minDist;
   }
   else
   {
      if(sl > 0 && sl - price < minDist) sl = price + minDist;
      if(tp > 0 && price - tp < minDist) tp = price - minDist;
   }
   sl = NormalizeDouble(sl, DigS(s));
   tp = NormalizeDouble(tp, DigS(s));
   if(buy) return (sl < price && tp > price);
   return (sl > price && tp < price);
}

bool SpreadOK(const string s)
{
   if(MaxSpreadPoints <= 0) return true; // never hard-block when off
   long spr = SymbolInfoInteger(s, SYMBOL_SPREAD);
   return (spr <= MaxSpreadPoints);
}

bool OpenSniper(const string s, const bool buy, const MarketRead &m, const int score, const string why)
{
   string aw;
   if(!AccountReady(aw))
   {
      if(EnableVerbose) Print("ACCOUNT GATE: ", aw);
      return false;
   }
   if(CountAllMagic() >= MaxOpenTrades) return false;
   if(!SpreadOK(s)) return false; // only if user set a cap

   int dir = SymDir(s);
   if(buy && (dir == -1 || dir == 2)) return false;  // no opposite same time
   if(!buy && (dir == 1 || dir == 2)) return false;

   // per-symbol cooldown
   int si = -1;
   for(int i = 0; i < g_symCount; i++) if(g_syms[i].name == s) { si = i; break; }
   if(si >= 0)
   {
      if(TimeCurrent() - g_syms[si].lastFire < TradeCooldownSec) return false;
      if(TimeCurrent() - g_syms[si].lastFail < TradeCooldownSec) return false;
   }

   double atr = m.atr;
   if(atr <= 0.0) return false;
   double price = buy ? AskS(s) : BidS(s);
   double slDist = atr * SL_ATR;
   double sl = buy ? price - slDist : price + slDist;
   // sweep invalidation safer SL
   if(buy && m.sweepExtBuy > 0.0)
   {
      double inv = m.sweepExtBuy - atr * 0.10;
      if(inv < price && inv < sl) sl = inv;
   }
   if(!buy && m.sweepExtSell > 0.0)
   {
      double inv = m.sweepExtSell + atr * 0.10;
      if(inv > price && inv > sl) sl = inv;
   }
   slDist = MathAbs(price - sl);

   double tp1 = buy ? price + atr * TP1_ATR : price - atr * TP1_ATR;
   double tp2 = buy ? price + atr * TP2_ATR : price - atr * TP2_ATR;
   double tp3 = buy ? price + atr * TP3_ATR : price - atr * TP3_ATR;
   // broker TP = TP3 so ladder manages partials
   double tp = tp3;
   if(!FixStops(s, buy, price, sl, tp)) return false;
   tp1 = NormalizeDouble(tp1, DigS(s));
   tp2 = NormalizeDouble(tp2, DigS(s));
   tp3 = tp;

   double lots = CalcLots(s, slDist);
   if(lots <= 0.0) return false;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(s);

   bool ok = false;
   for(int a = 0; a < 4 && !ok; a++)
      ok = buy ? trade.Buy(lots, s, 0, sl, tp, TradeComment)
               : trade.Sell(lots, s, 0, sl, tp, TradeComment);

   if(ok)
   {
      ulong ticket = trade.ResultOrder();
      // Prefer position ticket
      if(PositionSelect(s))
      {
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong t = PositionGetTicket(i);
            if(!PositionSelectByTicket(t)) continue;
            if(PositionGetString(POSITION_SYMBOL) == s &&
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            { ticket = t; break; }
         }
      }
      TrackAdd(ticket, s, price, buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, tp1, tp2, tp3);
      if(si >= 0)
      {
         g_syms[si].lastFire = TimeCurrent();
         g_syms[si].lastScore = score;
         g_syms[si].lastDir = buy ? 1 : -1;
         g_syms[si].lastReason = why;
      }
      Print("SNIPER AI FIRE ", (buy ? "BUY" : "SELL"), " ", s,
            " score=", score, " lots=", lots,
            " TP1/2/3=", DoubleToString(tp1, DigS(s)), "/",
            DoubleToString(tp2, DigS(s)), "/", DoubleToString(tp3, DigS(s)),
            " | ", why, " | ", g_aware.session,
            (g_aware.newsVol ? " | NEWS-VOL" : ""));
   }
   else
   {
      if(si >= 0) g_syms[si].lastFail = TimeCurrent();
      Print("SNIPER AI order fail ", s, " ", trade.ResultRetcode(), " ",
            trade.ResultRetcodeDescription());
   }
   return ok;
}

//====================================================================//
//  TRADE MANAGER — TP ladder, BE, trail, hold, smart reversal
//====================================================================//
void ManageSymbol(const string s)
{
   TrackPurgeClosed();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;

      int ti = FindPosTrack(ticket);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double vol = PositionGetDouble(POSITION_VOLUME);
      long type = PositionGetInteger(POSITION_TYPE);
      double price = (type == POSITION_TYPE_BUY) ? BidS(s) : AskS(s);
      double atr = ATR_S(s, ATR_Period);

      double tp1, tp2, tp3;
      if(ti >= 0)
      {
         tp1 = g_pos[ti].tp1; tp2 = g_pos[ti].tp2; tp3 = g_pos[ti].tp3;
      }
      else
      {
         // recover ladder from ATR if tracking lost
         tp1 = (type == POSITION_TYPE_BUY) ? open + atr * TP1_ATR : open - atr * TP1_ATR;
         tp2 = (type == POSITION_TYPE_BUY) ? open + atr * TP2_ATR : open - atr * TP2_ATR;
         tp3 = tp;
         TrackAdd(ticket, s, open, type, tp1, tp2, tp3);
         ti = FindPosTrack(ticket);
      }

      int stage = (ti >= 0) ? g_pos[ti].stage : 0;

      // TP1 hit → partial + BE
      if(stage < 1)
      {
         bool hit = (type == POSITION_TYPE_BUY) ? (price >= tp1) : (price <= tp1);
         if(hit)
         {
            double closeVol = NormalizeDouble(vol * (TP1_ClosePercent / 100.0), 2);
            double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
            if(closeVol >= vmin && closeVol < vol)
               trade.PositionClosePartial(ticket, closeVol);
            if(MoveBE_AtTP1)
            {
               double be = open;
               double off = BE_OffsetPoints * PtS(s);
               if(type == POSITION_TYPE_BUY) be = open + off;
               else be = open - off;
               be = NormalizeDouble(be, DigS(s));
               trade.PositionModify(ticket, be, tp3);
            }
            if(ti >= 0) g_pos[ti].stage = 1;
            if(EnableVerbose) Print("SNIPER AI TP1 lock ", s, " #", ticket);
            continue;
         }
      }

      // TP2 hit → partial + optional trail arm
      if(stage < 2)
      {
         bool hit = (type == POSITION_TYPE_BUY) ? (price >= tp2) : (price <= tp2);
         if(hit)
         {
            if(!PositionSelectByTicket(ticket)) continue;
            vol = PositionGetDouble(POSITION_VOLUME);
            double closeVol = NormalizeDouble(vol * (TP2_ClosePercent / 100.0), 2);
            double vmin = SymbolInfoDouble(s, SYMBOL_VOLUME_MIN);
            if(closeVol >= vmin && closeVol < vol)
               trade.PositionClosePartial(ticket, closeVol);
            if(ti >= 0) g_pos[ti].stage = 2;
            if(EnableVerbose) Print("SNIPER AI TP2 extend ", s, " #", ticket);
            continue;
         }
      }

      // Trail after TP2
      if(TrailAfterTP2 && stage >= 2 && atr > 0.0)
      {
         double trail = atr * Trail_ATR;
         if(type == POSITION_TYPE_BUY)
         {
            double nsl = NormalizeDouble(price - trail, DigS(s));
            if(nsl > sl && nsl < price) trade.PositionModify(ticket, nsl, tp3);
         }
         else
         {
            double nsl = NormalizeDouble(price + trail, DigS(s));
            if((sl == 0.0 || nsl < sl) && nsl > price) trade.PositionModify(ticket, nsl, tp3);
         }
      }

      // Smart reversal exit — only strong opposite sniper, never irregular noise
      if(!HoldThroughNoise || stage >= 1)
      {
         MarketRead rm;
         ReadMarket(s, rm);
         bool strongOpp = false;
         if(type == POSITION_TYPE_BUY && rm.scoreSell >= ReversalExitScore && rm.sweepSell && rm.dispSell)
            strongOpp = true;
         if(type == POSITION_TYPE_SELL && rm.scoreBuy >= ReversalExitScore && rm.sweepBuy && rm.dispBuy)
            strongOpp = true;
         if(strongOpp && stage >= 1) // only after TP1 secured
         {
            trade.PositionClose(ticket);
            if(EnableVerbose) Print("SNIPER AI REVERSAL EXIT ", s, " #", ticket);
         }
      }
   }
}

//====================================================================//
//  SIGNAL → FIRE
//====================================================================//
void EvaluateSymbol(const string s)
{
   if(!SymbolSelect(s, true)) return;
   if(Bars(s, ETF()) < StructureLookback + 30) return;

   UpdateAwareness();
   MarketRead m;
   ReadMarket(s, m);

   int si = -1;
   for(int i = 0; i < g_symCount; i++) if(g_syms[i].name == s) { si = i; break; }
   if(si >= 0)
   {
      g_syms[si].lastScore = MathMax(m.scoreBuy, m.scoreSell);
      g_syms[si].lastReason = (m.scoreBuy >= m.scoreSell) ? m.whyBuy : m.whySell;
   }

   // Core FLASH quality: sweep + displacement required (this IS the sniper)
   bool buyCore  = m.sweepBuy && m.dispBuy && (m.htfBull || m.bullStruct || m.macroBull);
   bool sellCore = m.sweepSell && m.dispSell && (m.htfBear || m.bearStruct || m.macroBear);

   bool buyFire = buyCore && m.scoreBuy >= MinSniperScore;
   bool sellFire = sellCore && m.scoreSell >= MinSniperScore;

   // Instant aggressive path
   if(m.scoreBuy >= InstantScore && buyCore) buyFire = true;
   if(m.scoreSell >= InstantScore && sellCore) sellFire = true;

   // Never both
   if(buyFire && sellFire)
   {
      if(m.scoreBuy > m.scoreSell) sellFire = false;
      else if(m.scoreSell > m.scoreBuy) buyFire = false;
      else { buyFire = false; sellFire = false; }
   }

   if(buyFire)
   {
      OpenSniper(s, true, m, m.scoreBuy, m.whyBuy);
      return;
   }
   if(sellFire)
   {
      OpenSniper(s, false, m, m.scoreSell, m.whySell);
      return;
   }

   if(EnableVerbose)
   {
      static datetime lastLogBar = 0;
      datetime bt = iTime(s, ETF(), 0);
      if(bt != lastLogBar)
      {
         lastLogBar = bt;
         Print("SNIPER AI scan ", s, " | ", m.whyBuy, " | ", m.whySell,
               " | ", g_aware.session, (g_aware.newsVol ? " NEWS-VOL" : ""));
      }
   }
}

//====================================================================//
//  DASHBOARD
//====================================================================//
void DrawDash()
{
   if(!EnableDashboard) return;
   long now = (long)GetTickCount();
   if(now - g_lastDash < DashRefreshMs) return;
   g_lastDash = now;

   string s = g_active;
   if(s == "") s = _Symbol;
   MarketRead m; ReadMarket(s, m);
   string aw;
   bool acc = AccountReady(aw);

   Comment(
      "========== SNIPER AI ==========\n",
      s, " | ", EnumToString(ETF()), " / Bias ", EnumToString(BiasTF), "\n",
      "Session: ", g_aware.session, (g_aware.newsVol ? " | EVENT VOL" : ""), "\n",
      "BUY ", IntegerToString(m.scoreBuy), "  SELL ", IntegerToString(m.scoreSell), "\n",
      "Sweep B/S: ", (m.sweepBuy?"Y":"N"), "/", (m.sweepSell?"Y":"N"),
      " Disp: ", (m.dispBuy?"B":"-"), (m.dispSell?"S":"-"),
      " Fib: ", (m.atFibBuy?"BUYZONE":(m.atFibSell?"SELLZONE":"-")), "\n",
      "HTF: ", (m.htfBull?"BULL":(m.htfBear?"BEAR":"FLAT")),
      " Macro: ", (m.macroBull?"BULL":(m.macroBear?"BEAR":"FLAT")), "\n",
      "Open: ", IntegerToString(CountAllMagic()), "/", IntegerToString(MaxOpenTrades),
      " | Account: ", (acc ? "READY" : aw), "\n",
      "Comment: SNIPER AI\n",
      "==============================="
   );
}

//====================================================================//
//  SYMBOL BOOTSTRAP
//====================================================================//
void AddSym(const string s)
{
   if(s == "" || g_symCount >= MAX_SYMS) return;
   for(int i = 0; i < g_symCount; i++) if(g_syms[i].name == s) return;
   if(!SymbolSelect(s, true)) return;
   g_syms[g_symCount].name = s;
   g_syms[g_symCount].lastBar = 0;
   g_syms[g_symCount].lastFire = 0;
   g_syms[g_symCount].lastFail = 0;
   g_syms[g_symCount].lastReason = "-";
   g_syms[g_symCount].lastScore = 0;
   g_syms[g_symCount].lastDir = 0;
   g_symCount++;
}

void BuildSymbolList()
{
   g_symCount = 0;
   AddSym(_Symbol);
   if(!EnableMultiSymbol) return;
   string parts[];
   int n = StringSplit(ExtraSymbols, ',', parts);
   for(int i = 0; i < n; i++)
   {
      string x = parts[i];
      StringTrimLeft(x); StringTrimRight(x);
      if(x != "") AddSym(x);
   }
}

//====================================================================//
//  EVENTS
//====================================================================//
void RunCycle(const string s)
{
   g_active = s;
   ManageSymbol(s);
   EvaluateSymbol(s);
}

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   BuildSymbolList();
   g_active = _Symbol;

   Print("SNIPER AI Loaded BUILD_ID=SA_FLASH_89 — FROM-SCRATCH FLASH CORE");
   Print("MaxOpen=", MaxOpenTrades, " | Entry=", EnumToString(ETF()),
         " Bias=", EnumToString(BiasTF), " | MultiSym=", EnableMultiSymbol,
         " count=", g_symCount);
   Print("Trade comment MUST be: SNIPER AI");
   Print("Session/News = awareness only (never hard-block). Instant sniper fire.");

   if(EnableMultiSymbol)
      EventSetTimer(MathMax(MultiSymbolTimerSec, 1));

   DrawDash();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Comment("");
}

void OnTick()
{
   RunCycle(_Symbol);
   DrawDash();
}

void OnTimer()
{
   if(!EnableMultiSymbol) return;
   for(int i = 0; i < g_symCount; i++)
   {
      if(g_syms[i].name == _Symbol) continue;
      RunCycle(g_syms[i].name);
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   TrackPurgeClosed();
}
//+------------------------------------------------------------------+
