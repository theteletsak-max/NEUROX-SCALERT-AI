//+------------------------------------------------------------------+
//| SNIPER_AI_OK14.mq5                                                |
//| BUILD_ID: SA_TRADE_READY_14                                       |
//| SNIPER AI - production execution build (no dashboard)             |
//| Strategy: H4 bias -> H1 setup -> M5 entry | Comment: SNIPER AI    |
//| Broker-safe execution. ASCII only. Put in Experts, F7.            |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.40"
#property description "SNIPER AI institutional sniper EA"
#property description "H4 H1 M5 precision execution 24/7"

#define SA_COMMENT        "SNIPER AI"
#define SA_LOG            "SNIPER AI | "
#define SA_H4_BARS        160
#define SA_H1_BARS        160
#define SA_M5_BARS        48
#define SA_ATR_PERIOD     14
#define SA_ATR_AVG_N      40
#define SA_DISP_MULT      1.7
#define SA_ZONE_PAD       0.35

// Portable numeric retcodes (avoid named retcode identifiers)
#define SA_RC_DONE           10009
#define SA_RC_PLACED         10008
#define SA_RC_DONE_PARTIAL   10010
#define SA_RC_REQUOTE        10004
#define SA_RC_REJECT         10006
#define SA_RC_CANCEL         10007
#define SA_RC_TOO_MANY       10018
#define SA_RC_TIMEOUT        10012
#define SA_RC_PRICE_OFF      10021
#define SA_RC_PRICE_CHANGED  10020
#define SA_RC_CONTEXT        10031

//==================================================================
// CONFIG
//==================================================================
input double InpLot                = 0.01;
input int    InpMaxTrades          = 3;
input long   InpMagic              = 20260726;
input int    InpSlippagePoints     = 150;
input int    InpMaxRetries         = 5;
input int    InpRetryBaseMs        = 120;
input int    InpSwingStrength      = 2;
input int    InpMinScore           = 14;
input int    InpMinConfluence      = 4;
input bool   InpAllowContinuation  = true;
input bool   InpAllowReversal      = true;
input bool   InpRequireZoneTouch   = true;
input bool   InpOnePerM5           = true;
input bool   InpTradeChartOnly     = true;
input bool   InpScanAllForex       = false;
input int    InpMaxSymbolsPerTick  = 12;
input double InpAtrMultSL          = 1.5;
input double InpRR                 = 2.0;
input double InpBreakEvenR         = 1.0;
input bool   InpUseTrailing        = false;
input double InpTrailStartR        = 1.5;
input double InpTrailStepR         = 0.5;
input double InpMaxDailyDDPercent  = 0.0;
input int    InpMaxConsecutiveLoss = 0;
input double InpHighVolMult        = 1.8;
input double InpExtremeVolMult     = 2.5;
input double InpSLBoostHigh        = 1.15;
input double InpSLBoostExtreme     = 1.35;
input bool   InpLogEvents          = true;
input bool   InpOpenThenStops      = true;
input bool   InpLogEachM5          = true;

//==================================================================
// TYPES
//==================================================================
struct SaSymCache
  {
   string symbol;
   double point;
   double volMin;
   double volMax;
   double volStep;
   int    digits;
   int    stopsLevel;
   int    freezeLevel;
   long   fillingMode;
   long   tradeMode;
   bool   ready;
  };

struct SaSetup
  {
   string symbol;
   int    side;
   int    path;
   int    bias;
   int    mkt;
   int    score;
   int    conf;
   double atr;
   double entry;
   double sl;
   double tp;
   double lots;
   string reason;
   bool   valid;
  };

//==================================================================
// GLOBAL STATE
//==================================================================
int      g_atrHandle = INVALID_HANDLE;
string   g_atrSymbol = "";
datetime g_lastM5Chart = 0;
datetime g_dayStamp = 0;
double   g_dayStartEquity = 0.0;
int      g_consecLoss = 0;
int      g_tick = 0;
int      g_scanCursor = 0;
string   g_lastAction = "boot";
string   g_execStatus = "idle";
datetime g_entryStamp[];
string   g_entrySymbol[];

//==================================================================
// UTIL / LOGGING
//==================================================================
void SaLog(const string msg)
  {
   if(InpLogEvents)
      Print(SA_LOG, msg);
  }

int SaClampInt(const int v, const int lo, const int hi)
  {
   if(v < lo)
      return lo;
   if(v > hi)
      return hi;
   return v;
  }

double SaMaxD(const double a, const double b)
  {
   return (a > b ? a : b);
  }

bool SaIsForexSymbol(const string symbol)
  {
   string path = SymbolInfoString(symbol, SYMBOL_PATH);
   string pathL = path;
   StringToLower(pathL);
   if(StringFind(pathL, "forex") >= 0)
      return true;
   string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   if(StringLen(base) == 3 && StringLen(profit) == 3 && base != profit)
      return true;
   return false;
  }

//==================================================================
// SYMBOL / MARKET DATA
//==================================================================
bool SaLoadSymbol(const string symbol, SaSymCache &c)
  {
   c.symbol = symbol;
   c.ready = false;
   if(!SymbolSelect(symbol, true))
      return false;
   c.point       = SymbolInfoDouble(symbol, SYMBOL_POINT);
   c.volMin      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   c.volMax      = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   c.volStep     = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   c.digits      = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   c.stopsLevel  = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   c.freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   c.fillingMode = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   c.tradeMode   = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(c.point <= 0.0 || c.volStep <= 0.0 || c.volMin <= 0.0)
      return false;
   c.ready = true;
   return true;
  }

double SaPip(const SaSymCache &c)
  {
   if(c.digits == 3 || c.digits == 5)
      return c.point * 10.0;
   return c.point;
  }

double SaNormPrice(const SaSymCache &c, const double price)
  {
   return NormalizeDouble(price, c.digits);
  }

double SaNormLots(const SaSymCache &c, double lots)
  {
   if(c.volStep <= 0.0)
      return 0.0;
   lots = MathFloor(lots / c.volStep + 1e-12) * c.volStep;
   if(lots < c.volMin)
      lots = c.volMin;
   if(lots > c.volMax)
      lots = c.volMax;
   int prec = 2;
   if(c.volStep < 0.01)
      prec = 3;
   if(c.volStep < 0.001)
      prec = 4;
   return NormalizeDouble(lots, prec);
  }

bool SaCopyRatesTF(const string symbol, const ENUM_TIMEFRAMES tf, const int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   return (CopyRates(symbol, tf, 0, count, rates) >= count);
  }

bool SaEnsureAtr(const string symbol)
  {
   if(g_atrHandle != INVALID_HANDLE && g_atrSymbol == symbol)
      return true;
   if(g_atrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
     }
   g_atrHandle = iATR(symbol, PERIOD_H1, SA_ATR_PERIOD);
   g_atrSymbol = symbol;
   return (g_atrHandle != INVALID_HANDLE);
  }

bool SaAtrSeries(const string symbol, double &atrNow, double &atrAvg)
  {
   atrNow = 0.0;
   atrAvg = 0.0;
   if(!SaEnsureAtr(symbol))
      return false;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, 1, SA_ATR_AVG_N, buf) < SA_ATR_AVG_N)
      return false;
   atrNow = buf[0];
   double sum = 0.0;
   for(int i = 0; i < SA_ATR_AVG_N; i++)
      sum += buf[i];
   atrAvg = sum / (double)SA_ATR_AVG_N;
   return (atrNow > 0.0 && atrAvg > 0.0);
  }

//==================================================================
// SWING / STRUCTURE
//==================================================================
bool SaIsSwingHigh(const MqlRates &r[], const int i, const int strength, const int n)
  {
   if(i - strength < 0 || i + strength >= n)
      return false;
   for(int k = 1; k <= strength; k++)
     {
      if(r[i].high < r[i - k].high || r[i].high <= r[i + k].high)
         return false;
     }
   return true;
  }

bool SaIsSwingLow(const MqlRates &r[], const int i, const int strength, const int n)
  {
   if(i - strength < 0 || i + strength >= n)
      return false;
   for(int k = 1; k <= strength; k++)
     {
      if(r[i].low > r[i - k].low || r[i].low >= r[i + k].low)
         return false;
     }
   return true;
  }

int SaBiasH4(const MqlRates &r[], const int n, const int strength)
  {
   double h1 = 0, h2 = 0, l1 = 0, l2 = 0;
   int hc = 0, lc = 0;
   for(int i = strength + 1; i < n - strength; i++)
     {
      if(hc < 2 && SaIsSwingHigh(r, i, strength, n))
        {
         if(hc == 0)
            h1 = r[i].high;
         else
            h2 = r[i].high;
         hc++;
        }
      if(lc < 2 && SaIsSwingLow(r, i, strength, n))
        {
         if(lc == 0)
            l1 = r[i].low;
         else
            l2 = r[i].low;
         lc++;
        }
      if(hc >= 2 && lc >= 2)
         break;
     }
   if(hc < 2 || lc < 2)
      return 0;
   bool hh = (h1 > h2);
   bool hl = (l1 > l2);
   bool lh = (h1 < h2);
   bool ll = (l1 < l2);
   if(hh && hl)
      return 1;
   if(lh && ll)
      return -1;
   if(hh && !ll)
      return 1;
   if(ll && !hh)
      return -1;
   return 0;
  }

void SaRecentSwings(const MqlRates &r[], const int n, const int strength, double &swingHigh, double &swingLow)
  {
   swingHigh = 0.0;
   swingLow = 0.0;
   for(int i = strength + 1; i < n - strength; i++)
     {
      if(swingHigh == 0.0 && SaIsSwingHigh(r, i, strength, n))
         swingHigh = r[i].high;
      if(swingLow == 0.0 && SaIsSwingLow(r, i, strength, n))
         swingLow = r[i].low;
      if(swingHigh > 0.0 && swingLow > 0.0)
         break;
     }
  }

//==================================================================
// ENTRY CONFIRM (M5)
//==================================================================
bool SaM5Buy(const MqlRates &m5[], const int n)
  {
   if(n < 4)
      return false;
   double body = m5[1].close - m5[1].open;
   double range = m5[1].high - m5[1].low;
   if(range <= 0.0 || body <= 0.0)
      return false;
   bool bull = (m5[1].close > m5[1].open);
   bool up = (m5[1].close > m5[2].close && m5[2].close >= m5[3].close);
   bool strong = (body >= range * 0.55);
   bool brk = (m5[1].close > m5[2].high);
   return (bull && strong && up && brk);
  }

bool SaM5Sell(const MqlRates &m5[], const int n)
  {
   if(n < 4)
      return false;
   double body = m5[1].open - m5[1].close;
   double range = m5[1].high - m5[1].low;
   if(range <= 0.0 || body <= 0.0)
      return false;
   bool bear = (m5[1].close < m5[1].open);
   bool dn = (m5[1].close < m5[2].close && m5[2].close <= m5[3].close);
   bool strong = (body >= range * 0.55);
   bool brk = (m5[1].close < m5[2].low);
   return (bear && strong && dn && brk);
  }

//==================================================================
// RISK / MONEY
//==================================================================
void SaRollDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   datetime day = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(day != g_dayStamp)
     {
      g_dayStamp = day;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
     }
  }

int SaCountMagic()
  {
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      c++;
     }
   return c;
  }

int SaCountMagicSymbol(const string symbol)
  {
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      c++;
     }
   return c;
  }

bool SaTradingAllowed(string &why)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      why = "terminal trade off";
      return false;
     }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      why = "ea trade off";
      return false;
     }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      why = "no connection";
      return false;
     }
   why = "ok";
   return true;
  }

bool SaRiskGate(string &why)
  {
   SaRollDay();
   if(SaCountMagic() >= InpMaxTrades)
     {
      why = "max trades";
      return false;
     }
   if(InpMaxDailyDDPercent > 0.0 && g_dayStartEquity > 0.0)
     {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dd = (g_dayStartEquity - eq) / g_dayStartEquity * 100.0;
      if(dd >= InpMaxDailyDDPercent)
        {
         why = "daily DD";
         return false;
        }
     }
   if(InpMaxConsecutiveLoss > 0 && g_consecLoss >= InpMaxConsecutiveLoss)
     {
      why = "consec loss";
      return false;
     }
   return SaTradingAllowed(why);
  }

bool SaBuildStops(const SaSymCache &c, const int side, const int mkt, const double atr,
                  double &entry, double &sl, double &tp, string &why)
  {
   double boost = 1.0;
   if(mkt == 2)
      boost = InpSLBoostHigh;
   if(mkt == 3)
      boost = InpSLBoostExtreme;

   double bid = SymbolInfoDouble(c.symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(c.symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
     {
      why = "no quotes";
      return false;
     }

   double spread = ask - bid;
   double minDist = SaMaxD((double)c.stopsLevel, (double)c.freezeLevel) * c.point;
   minDist = SaMaxD(minDist, spread + c.point);
   double stopDist = atr * InpAtrMultSL * boost;
   double floorDist = SaMaxD(minDist, SaPip(c) * 3.0);
   if(stopDist < floorDist)
      stopDist = floorDist;

   if(side == 1)
     {
      entry = ask;
      sl = SaNormPrice(c, entry - stopDist);
      tp = SaNormPrice(c, entry + stopDist * InpRR);
      if(sl >= entry || tp <= entry)
        {
         why = "bad buy stops";
         return false;
        }
      if(entry - sl < minDist)
         sl = SaNormPrice(c, entry - SaMaxD(minDist, c.point));
      if(tp - entry < minDist)
         tp = SaNormPrice(c, entry + SaMaxD(minDist, c.point));
     }
   else if(side == -1)
     {
      entry = bid;
      sl = SaNormPrice(c, entry + stopDist);
      tp = SaNormPrice(c, entry - stopDist * InpRR);
      if(sl <= entry || tp >= entry)
        {
         why = "bad sell stops";
         return false;
        }
      if(sl - entry < minDist)
         sl = SaNormPrice(c, entry + SaMaxD(minDist, c.point));
      if(entry - tp < minDist)
         tp = SaNormPrice(c, entry - SaMaxD(minDist, c.point));
     }
   else
     {
      why = "no side";
      return false;
     }

   why = "ok";
   return true;
  }

bool SaMarginOK(const string symbol, const int side, const double lots, const double price, string &why)
  {
   double margin = 0.0;
   ENUM_ORDER_TYPE ot = (side == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcMargin(ot, symbol, lots, price, margin))
     {
      why = "margin calc fail";
      return false;
     }
   if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      why = "insufficient margin";
      return false;
     }
   why = "ok";
   return true;
  }

//==================================================================
// EXECUTION ENGINE (broker-safe OrderSend)
//==================================================================
int SaFillCandidates(const SaSymCache &c, ENUM_ORDER_TYPE_FILLING &fills[])
  {
   ArrayResize(fills, 0);
   int n = 0;
   // Prefer modes advertised by the symbol, then safe fallbacks
   if((c.fillingMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
     {
      ArrayResize(fills, n + 1);
      fills[n++] = ORDER_FILLING_IOC;
     }
   if((c.fillingMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
     {
      ArrayResize(fills, n + 1);
      fills[n++] = ORDER_FILLING_FOK;
     }
   // RETURN is widely accepted on forex retail
   ArrayResize(fills, n + 1);
   fills[n++] = ORDER_FILLING_RETURN;
   // Ensure at least IOC/FOK tried even if bitmask empty/wrong
   bool hasIoc = false, hasFok = false;
   for(int i = 0; i < n; i++)
     {
      if(fills[i] == ORDER_FILLING_IOC) hasIoc = true;
      if(fills[i] == ORDER_FILLING_FOK) hasFok = true;
     }
   if(!hasIoc)
     {
      ArrayResize(fills, n + 1);
      fills[n++] = ORDER_FILLING_IOC;
     }
   if(!hasFok)
     {
      ArrayResize(fills, n + 1);
      fills[n++] = ORDER_FILLING_FOK;
     }
   return n;
  }

bool SaRetcodeRetryable(const uint rc)
  {
   if(rc == SA_RC_REQUOTE) return true;
   if(rc == SA_RC_REJECT) return true;
   if(rc == SA_RC_CANCEL) return true;
   if(rc == SA_RC_TOO_MANY) return true;
   if(rc == SA_RC_TIMEOUT) return true;
   if(rc == SA_RC_PRICE_OFF) return true;
   if(rc == SA_RC_PRICE_CHANGED) return true;
   if(rc == SA_RC_CONTEXT) return true;
   if(rc == 10030) return true; // invalid fill -> try other filling
   if(rc == 10016) return true; // invalid stops -> open then stops
   if(rc == 10015) return true; // invalid price
   if(rc == 0) return true;
   return false;
  }

bool SaRetcodeFilled(const uint rc)
  {
   return (rc == SA_RC_DONE || rc == SA_RC_PLACED || rc == SA_RC_DONE_PARTIAL);
  }

bool SaModifySLTP(const ulong ticket, const string symbol, const double sl, const double tp)
  {
   for(int attempt = 1; attempt <= InpMaxRetries; attempt++)
     {
      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action   = TRADE_ACTION_SLTP;
      req.position = ticket;
      req.symbol   = symbol;
      req.sl       = sl;
      req.tp       = tp;
      req.magic    = (ulong)InpMagic;
      ResetLastError();
      bool ok = OrderSend(req, res);
      if(ok || SaRetcodeFilled(res.retcode))
         return true;
      SaLog("SLTP modify fail ticket=" + (string)ticket + " rc=" + IntegerToString((int)res.retcode) + " err=" + IntegerToString(GetLastError()));
      if(attempt < InpMaxRetries)
         Sleep(InpRetryBaseMs * attempt);
     }
   return false;
  }

bool SaFindOurPosition(const string symbol, ulong &ticket)
  {
   ticket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      ticket = t;
      return true;
     }
   return false;
  }

bool SaAttachStops(const string symbol, double sl, double tp, string &why)
  {
   ulong ticket = 0;
   for(int attempt = 1; attempt <= InpMaxRetries; attempt++)
     {
      if(!SaFindOurPosition(symbol, ticket))
        {
         Sleep(InpRetryBaseMs * attempt);
         continue;
        }
      SaSymCache c;
      if(!SaLoadSymbol(symbol, c))
        {
         why = "stops: symbol cache fail";
         return false;
        }
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double spread = ask - bid;
      double minDist = SaMaxD((double)c.stopsLevel, (double)c.freezeLevel) * c.point;
      minDist = SaMaxD(minDist, spread + c.point);
      long type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      if(type == POSITION_TYPE_BUY)
        {
         if(ask - sl < minDist) sl = SaNormPrice(c, ask - SaMaxD(minDist, c.point));
         if(tp - ask < minDist) tp = SaNormPrice(c, ask + SaMaxD(minDist, c.point));
         if(sl >= open) sl = SaNormPrice(c, open - SaMaxD(minDist, c.point));
        }
      else
        {
         if(sl - bid < minDist) sl = SaNormPrice(c, bid + SaMaxD(minDist, c.point));
         if(bid - tp < minDist) tp = SaNormPrice(c, bid - SaMaxD(minDist, c.point));
         if(sl <= open) sl = SaNormPrice(c, open + SaMaxD(minDist, c.point));
        }
      if(SaModifySLTP(ticket, symbol, sl, tp))
        {
         why = "filled+stops";
         return true;
        }
      Sleep(InpRetryBaseMs * attempt);
     }
   why = "filled but stops not set";
   // Position is open - count as trade executed
   return true;
  }

bool SaOrderSendOnce(const SaSymCache &c, const int side, const double lots,
                     const double price, const double sl, const double tp,
                     const ENUM_ORDER_TYPE_FILLING fill, MqlTradeResult &res)
  {
   MqlTradeRequest req;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action       = TRADE_ACTION_DEAL;
   req.symbol       = c.symbol;
   req.volume       = lots;
   req.type         = (side == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   req.price        = price;
   req.sl           = sl;
   req.tp           = tp;
   req.deviation    = InpSlippagePoints;
   req.magic        = (ulong)InpMagic;
   req.comment      = SA_COMMENT;
   req.type_filling = fill;
   req.type_time    = ORDER_TIME_GTC;
   ResetLastError();
   return OrderSend(req, res);
  }

bool SaSendMarket(const SaSymCache &c, const int side, const double lots,
                  double sl, double tp, string &why)
  {
   if(side != 1 && side != -1)
     { why = "invalid side"; g_execStatus = why; return false; }
   if(lots <= 0.0)
     { why = "invalid lots"; g_execStatus = why; return false; }
   if(sl <= 0.0 || tp <= 0.0)
     { why = "invalid stops"; g_execStatus = why; return false; }
   if(c.tradeMode == SYMBOL_TRADE_MODE_DISABLED)
     { why = "symbol trade disabled"; g_execStatus = why; return false; }
   if(side == 1 && c.tradeMode == SYMBOL_TRADE_MODE_SHORTONLY)
     { why = "long disabled"; g_execStatus = why; return false; }
   if(side == -1 && c.tradeMode == SYMBOL_TRADE_MODE_LONGONLY)
     { why = "short disabled"; g_execStatus = why; return false; }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     { why = "account trade off"; g_execStatus = why; return false; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     { why = "algo trading off"; g_execStatus = why; return false; }

   ENUM_ORDER_TYPE_FILLING fills[];
   int nf = SaFillCandidates(c, fills);
   uint lastRc = 0;

   for(int attempt = 1; attempt <= InpMaxRetries; attempt++)
     {
      double bid = SymbolInfoDouble(c.symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(c.symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0)
        {
         why = "no quotes";
         g_execStatus = why;
         Sleep(InpRetryBaseMs * attempt);
         continue;
        }

      double spread = ask - bid;
      double minDist = SaMaxD((double)c.stopsLevel, (double)c.freezeLevel) * c.point;
      minDist = SaMaxD(minDist, spread + c.point);
      double price = (side == 1 ? ask : bid);

      // Keep stops legal vs live quotes
      if(side == 1)
        {
         if(ask - sl < minDist) sl = SaNormPrice(c, ask - SaMaxD(minDist, c.point));
         if(tp - ask < minDist) tp = SaNormPrice(c, ask + SaMaxD(minDist, c.point));
         if(sl >= ask || tp <= ask)
           { why = "stops invalid vs ask"; g_execStatus = why; return false; }
        }
      else
        {
         if(sl - bid < minDist) sl = SaNormPrice(c, bid + SaMaxD(minDist, c.point));
         if(bid - tp < minDist) tp = SaNormPrice(c, bid - SaMaxD(minDist, c.point));
         if(sl <= bid || tp >= bid)
           { why = "stops invalid vs bid"; g_execStatus = why; return false; }
        }

      for(int fi = 0; fi < nf; fi++)
        {
         MqlTradeResult res;
         // 1) Try market with SL/TP attached
         bool ok = SaOrderSendOnce(c, side, lots, price, sl, tp, fills[fi], res);
         lastRc = res.retcode;
         if(ok || SaRetcodeFilled(lastRc))
           {
            why = "filled";
            g_execStatus = "FILLED";
            g_lastAction = (side == 1 ? "BUY filled " : "SELL filled ") + c.symbol;
            SaLog(g_lastAction + " lots=" + DoubleToString(lots, 2) + " comment=" + SA_COMMENT + " fill=" + IntegerToString((int)fills[fi]));
            return true;
           }

         // 2) Broker rejects attached stops / fill -> open flat, then attach stops
         bool tryTwoStep = InpOpenThenStops;
         if(lastRc == 10016 || lastRc == 10030 || lastRc == 10015 || lastRc == SA_RC_REJECT)
            tryTwoStep = true;
         if(tryTwoStep)
           {
            ZeroMemory(res);
            ok = SaOrderSendOnce(c, side, lots, price, 0.0, 0.0, fills[fi], res);
            lastRc = res.retcode;
            if(ok || SaRetcodeFilled(lastRc))
              {
               g_execStatus = "FILLED_OPEN";
               g_lastAction = (side == 1 ? "BUY open " : "SELL open ") + c.symbol;
               SaLog(g_lastAction + " lots=" + DoubleToString(lots, 2) + " comment=" + SA_COMMENT + " (attach stops next)");
               string sw;
               SaAttachStops(c.symbol, sl, tp, sw);
               why = "filled";
               g_execStatus = "FILLED";
               SaLog("execution complete " + c.symbol + " " + sw);
               return true;
              }
           }

         SaLog(StringFormat("order reject %s fill=%d rc=%u err=%d attempt=%d",
                            c.symbol, (int)fills[fi], lastRc, GetLastError(), attempt));
        }

      why = StringFormat("retcode=%u err=%d", lastRc, GetLastError());
      g_execStatus = why;
      if(attempt < InpMaxRetries && SaRetcodeRetryable(lastRc))
        {
         Sleep(InpRetryBaseMs * attempt);
         continue;
        }
      break;
     }
   return false;
  }

//==================================================================
// TRADE MANAGER
//==================================================================
double SaRecoverRisk(const long type, const double open, const double sl, const double tp)
  {
   double risk = (type == POSITION_TYPE_BUY ? (open - sl) : (sl - open));
   if(risk > 0.0)
      return risk;
   if(InpRR > 0.0)
     {
      double reward = (type == POSITION_TYPE_BUY ? (tp - open) : (open - tp));
      if(reward > 0.0)
         return reward / InpRR;
     }
   return 0.0;
  }

void SaManagePositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(point <= 0.0)
         continue;

      double risk = SaRecoverRisk(type, open, sl, tp);
      if(risk <= 0.0)
         continue;

      bool beHit = false;
      if(type == POSITION_TYPE_BUY && bid >= open + risk * InpBreakEvenR)
         beHit = true;
      if(type == POSITION_TYPE_SELL && ask <= open - risk * InpBreakEvenR)
         beHit = true;

      if(beHit)
        {
         bool already = false;
         if(type == POSITION_TYPE_BUY && sl >= open - point)
            already = true;
         if(type == POSITION_TYPE_SELL && sl > 0.0 && sl <= open + point)
            already = true;
         if(!already)
           {
            double newSL = NormalizeDouble(open, digits);
            if(SaModifySLTP(ticket, symbol, newSL, tp))
               sl = newSL;
           }
        }

      if(!InpUseTrailing)
         continue;

      bool armed = false;
      if(type == POSITION_TYPE_BUY && bid >= open + risk * InpTrailStartR)
         armed = true;
      if(type == POSITION_TYPE_SELL && ask <= open - risk * InpTrailStartR)
         armed = true;
      if(!armed)
         continue;

      double step = risk * InpTrailStepR;
      if(type == POSITION_TYPE_BUY)
        {
         double nsl = NormalizeDouble(bid - step, digits);
         if(nsl > sl + point)
            SaModifySLTP(ticket, symbol, nsl, tp);
        }
      else
        {
         double nsl = NormalizeDouble(ask + step, digits);
         if(sl == 0.0 || nsl < sl - point)
            SaModifySLTP(ticket, symbol, nsl, tp);
        }
     }
  }

//==================================================================
// ONE-PER-M5 GUARD
//==================================================================
bool SaAlreadyEntered(const string symbol, const datetime m5bar)
  {
   int n = ArraySize(g_entrySymbol);
   for(int i = 0; i < n; i++)
     {
      if(g_entrySymbol[i] == symbol && g_entryStamp[i] == m5bar)
         return true;
     }
   return false;
  }

void SaMarkEntered(const string symbol, const datetime m5bar)
  {
   int n = ArraySize(g_entrySymbol);
   ArrayResize(g_entrySymbol, n + 1);
   ArrayResize(g_entryStamp, n + 1);
   g_entrySymbol[n] = symbol;
   g_entryStamp[n] = m5bar;
   if(n + 1 > 64)
     {
      for(int i = 0; i < 64; i++)
        {
         g_entrySymbol[i] = g_entrySymbol[i + (n + 1 - 64)];
         g_entryStamp[i] = g_entryStamp[i + (n + 1 - 64)];
        }
      ArrayResize(g_entrySymbol, 64);
      ArrayResize(g_entryStamp, 64);
     }
  }

//==================================================================
// DECISION ENGINE (strategy preserved)
//==================================================================
bool SaAnalyzeSymbol(const string symbol, const bool allowEntry, SaSetup &out)
  {
   out.symbol = symbol;
   out.side = 0;
   out.path = 0;
   out.bias = 0;
   out.mkt = 1;
   out.score = 0;
   out.conf = 0;
   out.atr = 0.0;
   out.entry = 0.0;
   out.sl = 0.0;
   out.tp = 0.0;
   out.lots = 0.0;
   out.reason = "scanning";
   out.valid = false;

   SaSymCache c;
   if(!SaLoadSymbol(symbol, c))
     {
      out.reason = "symbol cache fail";
      return false;
     }
   if(c.tradeMode == SYMBOL_TRADE_MODE_DISABLED)
     {
      out.reason = "trade disabled";
      return false;
     }

   MqlRates h4[], h1[], m5[];
   if(!SaCopyRatesTF(symbol, PERIOD_H4, SA_H4_BARS, h4))
     {
      out.reason = "no H4";
      return false;
     }
   if(!SaCopyRatesTF(symbol, PERIOD_H1, SA_H1_BARS, h1))
     {
      out.reason = "no H1";
      return false;
     }
   if(!SaCopyRatesTF(symbol, PERIOD_M5, SA_M5_BARS, m5))
     {
      out.reason = "no M5";
      return false;
     }

   double atrNow = 0.0, atrAvg = 0.0;
   if(!SaAtrSeries(symbol, atrNow, atrAvg))
     {
      out.reason = "no ATR";
      return false;
     }
   out.atr = atrNow;

   out.mkt = 1;
   if(atrNow >= atrAvg * InpExtremeVolMult)
      out.mkt = 3;
   else if(atrNow >= atrAvg * InpHighVolMult)
      out.mkt = 2;
   else if(atrNow <= atrAvg * 0.55)
      out.mkt = 0;

   int strength = SaClampInt(InpSwingStrength, 1, 5);
   out.bias = SaBiasH4(h4, ArraySize(h4), strength);

   double swingHigh = 0.0, swingLow = 0.0;
   SaRecentSwings(h1, ArraySize(h1), strength, swingHigh, swingLow);

   bool bosBull = false, bosBear = false, chochBull = false, chochBear = false;
   double c1 = h1[1].close;
   if(swingHigh > 0.0 && c1 > swingHigh)
     {
      if(out.bias == 1 || out.bias == 0)
         bosBull = true;
      if(out.bias == -1)
         chochBull = true;
     }
   if(swingLow > 0.0 && c1 < swingLow)
     {
      if(out.bias == -1 || out.bias == 0)
         bosBear = true;
      if(out.bias == 1)
         chochBear = true;
     }

   double pip = SaPip(c);
   double tol = SaMaxD(pip * 2.0, out.atr * 0.05);
   double rh = h1[3].high, rl = h1[3].low;
   int n1 = ArraySize(h1);
   int limSweep = (n1 < 16 ? n1 : 16);
   for(int i = 3; i < limSweep; i++)
     {
      if(h1[i].high > rh)
         rh = h1[i].high;
      if(h1[i].low < rl)
         rl = h1[i].low;
     }
   bool buySweep = (h1[1].high > rh + tol * 0.25 && h1[1].close < rh);
   bool sellSweep = (h1[1].low < rl - tol * 0.25 && h1[1].close > rl);
   int eqhc = 0, eqlc = 0;
   int limEq = (n1 < 30 ? n1 : 30);
   for(int i = 3; i < limEq; i++)
     {
      if(MathAbs(h1[i].high - h1[2].high) <= tol)
         eqhc++;
      if(MathAbs(h1[i].low - h1[2].low) <= tol)
         eqlc++;
     }
   bool eqH = (eqhc >= 1);
   bool eqL = (eqlc >= 1);

   double b1 = MathAbs(h1[1].close - h1[1].open);
   double b2 = MathAbs(h1[2].close - h1[2].open);
   double b3 = MathAbs(h1[3].close - h1[3].open);
   double b4 = MathAbs(h1[4].close - h1[4].open);
   double avg = (b2 + b3 + b4) / 3.0;
   if(avg <= 0.0)
      avg = b1;

   bool bullDisp = (h1[1].close > h1[1].open && b1 >= avg * SA_DISP_MULT);
   bool bearDisp = (h1[1].close < h1[1].open && b1 >= avg * SA_DISP_MULT);
   bool bullFVG = (h1[3].high < h1[1].low);
   bool bearFVG = (h1[3].low > h1[1].high);
   bool bullOB = (bullDisp && h1[2].close < h1[2].open);
   bool bearOB = (bearDisp && h1[2].close > h1[2].open);

   double zLo = 0.0, zHi = 0.0;
   if(bullFVG)
     {
      zLo = h1[3].high;
      zHi = h1[1].low;
     }
   if(bearFVG)
     {
      zLo = h1[1].high;
      zHi = h1[3].low;
     }
   if(bullOB && !(zHi > zLo))
     {
      zLo = h1[2].low;
      zHi = h1[2].high;
     }
   if(bearOB && !(zHi > zLo))
     {
      zLo = h1[2].low;
      zHi = h1[2].high;
     }

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   bool bullTouch = false, bearTouch = false;
   if(zHi > zLo)
     {
      double pad = (zHi - zLo) * SA_ZONE_PAD;
      if(bid <= zHi + pad && bid >= zLo - pad)
        {
         if(bullFVG || bullOB || bullDisp)
            bullTouch = true;
         if(bearFVG || bearOB || bearDisp)
            bearTouch = true;
        }
     }

   int score = 0;
   if(buySweep || sellSweep)
      score += 3;
   if(eqH)
      score += 1;
   if(eqL)
      score += 1;
   if(bullDisp || bearDisp)
      score += 2;
   if(bullFVG || bearFVG)
      score += 3;
   if(bullOB || bearOB)
      score += 2;
   if(bosBull || bosBear)
      score += 3;
   if(chochBull || chochBear)
      score += 3;
   if(out.bias != 0)
      score += 2;

   int need = InpMinScore;
   if(out.mkt == 2)
      need = InpMinScore + 1;
   if(out.mkt == 3)
      need = InpMinScore + 3;

   bool m5buy = SaM5Buy(m5, ArraySize(m5));
   bool m5sell = SaM5Sell(m5, ArraySize(m5));

   // Path A - Continuation
   if(InpAllowContinuation && out.bias == 1)
     {
      int conf = 0;
      if(out.bias == 1)
         conf++;
      if(bosBull)
         conf++;
      if(bullDisp)
         conf++;
      if(bullFVG || bullOB)
         conf++;
      if(bullTouch || !InpRequireZoneTouch)
         conf++;
      if(sellSweep || eqL)
         conf++;
      if(m5buy)
         conf++;
      bool institutional = (bosBull && (bullFVG || bullOB) && bullDisp);
      bool locationOk = (!InpRequireZoneTouch || bullTouch || bullFVG || bullOB);
      if(institutional && locationOk && m5buy && conf >= InpMinConfluence)
        {
         out.side = 1;
         out.path = 1;
         out.conf = conf;
         out.score = score + 8 + conf;
         out.reason = "CONT precision";
        }
     }

   if(out.side == 0 && InpAllowContinuation && out.bias == -1)
     {
      int conf = 0;
      if(out.bias == -1)
         conf++;
      if(bosBear)
         conf++;
      if(bearDisp)
         conf++;
      if(bearFVG || bearOB)
         conf++;
      if(bearTouch || !InpRequireZoneTouch)
         conf++;
      if(buySweep || eqH)
         conf++;
      if(m5sell)
         conf++;
      bool institutional = (bosBear && (bearFVG || bearOB) && bearDisp);
      bool locationOk = (!InpRequireZoneTouch || bearTouch || bearFVG || bearOB);
      if(institutional && locationOk && m5sell && conf >= InpMinConfluence)
        {
         out.side = -1;
         out.path = 1;
         out.conf = conf;
         out.score = score + 8 + conf;
         out.reason = "CONT precision";
        }
     }

   // Path B - Reversal
   if(out.side == 0 && InpAllowReversal && sellSweep && chochBull && (bullDisp || bullFVG || bullOB) && m5buy)
     {
      int conf = 4;
      if(bullTouch || bullFVG)
         conf++;
      if(bullDisp)
         conf++;
      if(conf >= InpMinConfluence)
        {
         out.side = 1;
         out.path = 2;
         out.conf = conf;
         out.score = score + 10 + conf;
         out.reason = "REV precision";
        }
      else
         out.reason = "rev conf low";
     }

   if(out.side == 0 && InpAllowReversal && buySweep && chochBear && (bearDisp || bearFVG || bearOB) && m5sell)
     {
      int conf = 4;
      if(bearTouch || bearFVG)
         conf++;
      if(bearDisp)
         conf++;
      if(conf >= InpMinConfluence)
        {
         out.side = -1;
         out.path = 2;
         out.conf = conf;
         out.score = score + 10 + conf;
         out.reason = "REV precision";
        }
      else
         out.reason = "rev conf low";
     }

   if(out.side == 0)
     {
      out.score = score;
      out.reason = "awaiting setup";
      return false;
     }
   if(out.score < need)
     {
      out.reason = "score low";
      out.side = 0;
      return false;
     }
   if(!allowEntry)
     {
      out.reason = "signal only";
      return false;
     }

   datetime m5bar = m5[0].time;
   if(InpOnePerM5 && SaAlreadyEntered(symbol, m5bar))
     {
      out.reason = "one per M5";
      out.side = 0;
      return false;
     }
   if(SaCountMagicSymbol(symbol) >= InpMaxTrades)
     {
      out.reason = "symbol max";
      out.side = 0;
      return false;
     }

   string why;
   if(!SaRiskGate(why))
     {
      out.reason = why;
      out.side = 0;
      return false;
     }
   if(!SaBuildStops(c, out.side, out.mkt, out.atr, out.entry, out.sl, out.tp, why))
     {
      out.reason = why;
      out.side = 0;
      return false;
     }

   out.lots = SaNormLots(c, InpLot);
   if(out.lots <= 0.0)
     {
      out.reason = "lot invalid";
      out.side = 0;
      return false;
     }
   if(!SaMarginOK(symbol, out.side, out.lots, out.entry, why))
     {
      out.reason = why;
      out.side = 0;
      return false;
     }

   if(!SaSendMarket(c, out.side, out.lots, out.sl, out.tp, why))
     {
      out.reason = why;
      return false;
     }

   SaMarkEntered(symbol, m5bar);
   out.valid = true;
   out.reason = "executed";
   return true;
  }

//==================================================================
// SYSTEM CORE
//==================================================================
void SaCollectForex(string &symbols[])
  {
   ArrayResize(symbols, 1);
   symbols[0] = _Symbol;
   if(InpTradeChartOnly || !InpScanAllForex)
      return;

   int n = 1;
   int total = SymbolsTotal(true);
   for(int i = 0; i < total; i++)
     {
      string s = SymbolName(i, true);
      if(s == _Symbol)
         continue;
      if(!SaIsForexSymbol(s))
         continue;
      ArrayResize(symbols, n + 1);
      symbols[n] = s;
      n++;
     }
  }

void SaEvaluatePass(const bool newM5)
  {
   string why;
   if(!SaTradingAllowed(why))
     {
      g_lastAction = why;
      return;
     }

   string symbols[];
   SaCollectForex(symbols);
   int n = ArraySize(symbols);
   if(n <= 0)
      return;

   bool allow = newM5;
   SaSetup chartSetup;
   if(SaAnalyzeSymbol(_Symbol, allow, chartSetup))
     {
      SaLog("TRADE EXECUTED " + _Symbol + " side=" + IntegerToString(chartSetup.side) +
            " path=" + IntegerToString(chartSetup.path) + " score=" + IntegerToString(chartSetup.score));
      return;
     }
   if(InpLogEachM5)
      SaLog(_Symbol + " M5 scan: " + chartSetup.reason +
            " score=" + IntegerToString(chartSetup.score) +
            " bias=" + IntegerToString(chartSetup.bias) +
            " exec=" + g_execStatus);

   if(InpTradeChartOnly || !InpScanAllForex)
      return;

   if(g_scanCursor < 1 || g_scanCursor >= n)
      g_scanCursor = 1;
   int checked = 0;
   int idx = g_scanCursor;
   while(checked < InpMaxSymbolsPerTick && checked < n - 1)
     {
      if(idx >= n)
         idx = 1;
      if(SaCountMagic() >= InpMaxTrades)
         break;
      SaSetup s;
      if(SaAnalyzeSymbol(symbols[idx], allow, s))
        {
         g_scanCursor = idx + 1;
         return;
        }
      idx++;
      checked++;
     }
   g_scanCursor = idx;
  }

void SaOnDealOut(const ulong deal)
  {
   if(!HistoryDealSelect(deal))
      return;
   if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic)
      return;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;
   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                   + HistoryDealGetDouble(deal, DEAL_SWAP)
                   + HistoryDealGetDouble(deal, DEAL_COMMISSION);
   if(profit < 0.0)
      g_consecLoss++;
   else
      g_consecLoss = 0;
  }

//==================================================================
// EVENT HANDLERS
//==================================================================
int OnInit()
  {
   if(InpLot <= 0.0 || InpMaxTrades < 1 || InpAtrMultSL <= 0.0 || InpRR <= 0.0)
     {
      Print(SA_LOG, "invalid inputs");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(SA_COMMENT != "SNIPER AI")
     {
      Print(SA_LOG, "comment lock failed");
      return INIT_FAILED;
     }

   SymbolSelect(_Symbol, true);
   if(!SaEnsureAtr(_Symbol))
     {
      Print(SA_LOG, "ATR init failed");
      return INIT_FAILED;
     }

   ArrayResize(g_entrySymbol, 0);
   ArrayResize(g_entryStamp, 0);
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_lastAction = "online 24/7";
   g_execStatus = "armed";
   Comment("");
   SaLog(StringFormat("ONLINE %s build=SA_TRADE_READY_14 lot=%.2f max=%d comment=%s",
                      _Symbol, InpLot, InpMaxTrades, SA_COMMENT));
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
      SaLog("WARN: terminal not connected");
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      SaLog("WARN: AutoTrading is OFF in terminal toolbar - enable it");
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      SaLog("WARN: Algo Trading disabled for this EA - allow live trading in dialog");
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      SaLog("WARN: account trading not allowed");
   SaSymCache c0;
   if(SaLoadSymbol(_Symbol, c0))
      SaLog(StringFormat("symbol mode=%d filling=%d stops=%d freeze=%d",
                         (int)c0.tradeMode, (int)c0.fillingMode, c0.stopsLevel, c0.freezeLevel));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_atrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
     }
   Comment("");
   SaLog(StringFormat("stopped reason=%d", reason));
  }

void OnTick()
  {
   g_tick++;
   SaManagePositions();

   datetime t[];
   ArraySetAsSeries(t, true);
   if(CopyTime(_Symbol, PERIOD_M5, 0, 1, t) != 1)
     {
      g_lastAction = "data wait";
      return;
     }

   bool newM5 = false;
   if(t[0] != g_lastM5Chart)
     {
      g_lastM5Chart = t[0];
      newM5 = true;
     }

   if(newM5)
      SaEvaluatePass(true);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   HistorySelect(0, TimeCurrent());
   SaOnDealOut(trans.deal);
  }
//+------------------------------------------------------------------+
