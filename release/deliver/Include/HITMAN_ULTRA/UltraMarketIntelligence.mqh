#ifndef HITMAN_ULTRA_MARKET_INTELLIGENCE_MQH
#define HITMAN_ULTRA_MARKET_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — ULTRA MARKET INTELLIGENCE ENGINE (Phase 2)           |
//| Verify data before ANY analysis. Bad data = No trade.            |
//| Spread/news alone NEVER hard-reject (product lock).              |
//+------------------------------------------------------------------+

#define ULTRA_MKT_MIN_BARS     60
#define ULTRA_MKT_OHLC_SAMPLE  12

enum ENUM_ULTRA_MKT_STATE
{
   UMKT_NORMAL = 0,
   UMKT_STRONG_TREND,
   UMKT_DEVELOPING_TREND,
   UMKT_WEAK_TREND,
   UMKT_CONSOLIDATION,
   UMKT_EXPANSION,
   UMKT_COMPRESSION,
   UMKT_HIGH_VOLATILITY,
   UMKT_LOW_VOLATILITY
};

struct UltraMarketIntelState
{
   bool   booted;
   bool   approved;          // Mission Control: analysis allowed
   bool   tickOK;
   bool   candleOK;
   bool   ohlcOK;
   bool   histOK;
   bool   feedOK;
   bool   tickSpeedOK;
   bool   tickConsistOK;
   bool   candleCompleteOK;
   bool   gapOK;
   bool   spreadOK;          // informational — never sole reject
   bool   volatilityOK;
   bool   volumeOK;
   bool   liquidityOK;
   bool   sessionOK;         // informational
   bool   symbolPropsOK;
   bool   marketStatusOK;
   bool   tradingPermOK;
   bool   buffersOK;
   bool   indicatorsOK;
   bool   weekend;
   bool   holiday;
   bool   marketOpen;
   int    digits;
   double tickSize;
   double point;
   double contractSize;
   long   freezeLevel;
   long   stopLevel;
   double bid;
   double ask;
   double spreadPts;
   double atr;
   double atrRel;
   double tickSpeed;
   double lastBid;
   double lastAsk;
   long   lastEvalMs;
   long   lastQuoteAgeSec;
   int    gapCount;
   int    badOhlcCount;
   ENUM_ULTRA_MKT_STATE marketState;
   string status;            // APPROVED / DEGRADED / REJECTED
   string stateName;
   string detail;
   string symbol;
};

UltraMarketIntelState g_UltraMarketIntel;

//--------------------------------------------------------------------//
string UltraMarketIntel_StateName(const ENUM_ULTRA_MKT_STATE st)
{
   switch(st)
   {
      case UMKT_STRONG_TREND:      return "STRONG_TREND";
      case UMKT_DEVELOPING_TREND:  return "DEVELOPING_TREND";
      case UMKT_WEAK_TREND:        return "WEAK_TREND";
      case UMKT_CONSOLIDATION:     return "CONSOLIDATION";
      case UMKT_EXPANSION:         return "EXPANSION";
      case UMKT_COMPRESSION:       return "COMPRESSION";
      case UMKT_HIGH_VOLATILITY:   return "HIGH_VOLATILITY";
      case UMKT_LOW_VOLATILITY:    return "LOW_VOLATILITY";
      default:                     return "NORMAL";
   }
}

bool UltraMarketIntel_Approved()
{
   if(!UltraMarketIntelEnabled) return true;
   return g_UltraMarketIntel.approved;
}

//--------------------------------------------------------------------//
// SYMBOL PROPERTIES — digits · tick · point · contract · stops       //
//--------------------------------------------------------------------//
bool UltraMarketIntel_SymbolProps(const string s, string &why)
{
   why = "";
   long dig = 0;
   if(!SymbolInfoInteger(s, SYMBOL_DIGITS, dig) || dig < 0)
   { why = "digits unavailable"; return false; }
   g_UltraMarketIntel.digits = (int)dig;
   g_UltraMarketIntel.point = SymbolInfoDouble(s, SYMBOL_POINT);
   g_UltraMarketIntel.tickSize = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
   g_UltraMarketIntel.contractSize = SymbolInfoDouble(s, SYMBOL_TRADE_CONTRACT_SIZE);
   g_UltraMarketIntel.freezeLevel = UltraSymFreezeLevel(s);
   g_UltraMarketIntel.stopLevel = UltraSymStopsLevel(s);

   if(g_UltraMarketIntel.point <= 0.0)
   { why = "invalid point"; return false; }
   if(g_UltraMarketIntel.tickSize <= 0.0)
   { why = "invalid tick size"; return false; }
   if(g_UltraMarketIntel.contractSize <= 0.0)
   { why = "invalid contract size"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// MARKET STATUS — open/close · weekend · holiday proxy               //
//--------------------------------------------------------------------//
bool UltraMarketIntel_IsWeekend()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   // 0=Sun … 6=Sat
   return (dt.day_of_week == 0 || dt.day_of_week == 6);
}

bool UltraMarketIntel_SessionTradeOpen(const string s)
{
   // If session API fails, fall back to trade mode (broker-compatible)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime from = 0, to = 0;
   if(!SymbolInfoSessionTrade(s, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, from, to))
      return true; // unknown session table — do not invent a close
   if(from == 0 && to == 0)
      return false;
   // Session times are seconds from 00:00 server day in many brokers
   int nowSec = dt.hour * 3600 + dt.min * 60 + dt.sec;
   int fromSec = (int)from;
   int toSec = (int)to;
   if(toSec <= fromSec)
      return (nowSec >= fromSec || nowSec <= toSec);
   return (nowSec >= fromSec && nowSec <= toSec);
}

bool UltraMarketIntel_MarketStatus(const string s, string &why)
{
   why = "";
   g_UltraMarketIntel.weekend = UltraMarketIntel_IsWeekend();
   g_UltraMarketIntel.holiday = false;

   long tm = 0;
   if(!SymbolInfoInteger(s, SYMBOL_TRADE_MODE, tm))
   { why = "trade mode unavailable"; g_UltraMarketIntel.marketOpen = false; return false; }

   bool modeOpen = (tm != SYMBOL_TRADE_MODE_DISABLED);
   bool sessOpen = UltraMarketIntel_SessionTradeOpen(s);
   // Weekend is informational — FX often opens Sunday evening (24/5)
   g_UltraMarketIntel.marketOpen = (modeOpen && sessOpen);

   // Holiday proxy: weekday + trade disabled
   if(!g_UltraMarketIntel.weekend && !modeOpen)
      g_UltraMarketIntel.holiday = true;

   if(!modeOpen)
   { why = "trading disabled on symbol"; return false; }
   // Only hard-reject weekend when broker actually closed (mode already checked)
   // and explicit weekend reject is on AND session table says closed
   if(g_UltraMarketIntel.weekend && UltraMarketIntelRejectWeekend && !sessOpen)
   { why = "weekend market closed"; return false; }
   if(g_UltraMarketIntel.holiday && UltraMarketIntelRejectHoliday)
   { why = "holiday / market closed"; return false; }
   return true;
}

bool UltraMarketIntel_TradingPerm(string &why)
{
   why = "";
   // Ultra Backtest Compat — same strategy in Tester/Demo/Live
   if(!UltraBT_ConnectedOK()){ why = "terminal disconnected"; return false; }
   if(!UltraBT_TradeAllowed()){ why = "trading not permitted"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// TICK / FEED / CONSISTENCY                                          //
//--------------------------------------------------------------------//
bool UltraMarketIntel_VerifyTick(const string s, string &why)
{
   why = "";
   g_UltraMarketIntel.bid = SymbolInfoDouble(s, SYMBOL_BID);
   g_UltraMarketIntel.ask = SymbolInfoDouble(s, SYMBOL_ASK);
   long spr = 0;
   SymbolInfoInteger(s, SYMBOL_SPREAD, spr);
   g_UltraMarketIntel.spreadPts = (double)spr;

   if(g_UltraMarketIntel.bid <= 0.0 || g_UltraMarketIntel.ask <= 0.0)
   { why = "invalid tick prices"; return false; }
   if(g_UltraMarketIntel.ask < g_UltraMarketIntel.bid)
   { why = "ask < bid"; return false; }

   // Quote age (soft): last tick time if available
   datetime lt = (datetime)SymbolInfoInteger(s, SYMBOL_TIME);
   if(lt > 0)
      g_UltraMarketIntel.lastQuoteAgeSec = (long)(TimeCurrent() - lt);
   else
      g_UltraMarketIntel.lastQuoteAgeSec = 0;

   g_UltraMarketIntel.tickSpeed = g_UltraEventStats.tickSpeed;
   g_UltraMarketIntel.tickSpeedOK = true;
   if(UltraMarketIntelMinTickSpeed > 0.0 && g_UltraMarketIntel.tickSpeed > 0.0 &&
      g_UltraMarketIntel.tickSpeed < UltraMarketIntelMinTickSpeed)
      g_UltraMarketIntel.tickSpeedOK = false; // soft — never sole reject

   // Consistency vs prior quote
   g_UltraMarketIntel.tickConsistOK = true;
   if(g_UltraMarketIntel.lastBid > 0.0 && g_UltraMarketIntel.atr > 0.0)
   {
      double jump = MathAbs(g_UltraMarketIntel.bid - g_UltraMarketIntel.lastBid);
      if(jump > g_UltraMarketIntel.atr * UltraMarketIntelMaxJumpATR)
         g_UltraMarketIntel.tickConsistOK = false; // soft gap/spike flag
   }
   g_UltraMarketIntel.lastBid = g_UltraMarketIntel.bid;
   g_UltraMarketIntel.lastAsk = g_UltraMarketIntel.ask;

   // Spread: informational only — NEVER hard reject (product lock)
   g_UltraMarketIntel.spreadOK = (g_UltraMarketIntel.spreadPts >= 0.0);
   if(UltraMarketIntelSpreadWarnPts > 0.0 &&
      g_UltraMarketIntel.spreadPts > UltraMarketIntelSpreadWarnPts)
      g_UltraMarketIntel.spreadOK = false; // DEGRADED only

   return true;
}

//--------------------------------------------------------------------//
// CANDLE / OHLC / HISTORY / GAPS                                     //
//--------------------------------------------------------------------//
bool UltraMarketIntel_OHLCValid(const string s, const ENUM_TIMEFRAMES tf, const int shift)
{
   double o = iOpen(s, tf, shift);
   double h = iHigh(s, tf, shift);
   double l = iLow(s, tf, shift);
   double c = iClose(s, tf, shift);
   if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0) return false;
   if(h < l) return false;
   if(h < o || h < c) return false;
   if(l > o || l > c) return false;
   return true;
}

bool UltraMarketIntel_VerifyCandles(const string s, string &why)
{
   why = "";
   ENUM_TIMEFRAMES tf = UltraETF();
   int bars = Bars(s, tf);
   g_UltraMarketIntel.histOK = (bars >= ULTRA_MKT_MIN_BARS);
   if(!g_UltraMarketIntel.histOK)
   { why = "insufficient history"; return false; }

   // Closed candle required for analysis integrity
   g_UltraMarketIntel.candleCompleteOK = (iTime(s, tf, 1) > 0 && UltraMarketIntel_OHLCValid(s, tf, 1));
   if(!g_UltraMarketIntel.candleCompleteOK)
   { why = "incomplete / missing closed candle"; return false; }

   // Forming candle (shift 0) must still be structurally valid
   g_UltraMarketIntel.candleOK = UltraMarketIntel_OHLCValid(s, tf, 0);
   if(!g_UltraMarketIntel.candleOK)
   { why = "corrupt forming candle"; return false; }

   int bad = 0;
   int gaps = 0;
   g_UltraMarketIntel.atr = UltraATR(s, IDP_ATR_Period);
   for(int i = 1; i <= ULTRA_MKT_OHLC_SAMPLE; i++)
   {
      if(!UltraMarketIntel_OHLCValid(s, tf, i)) bad++;
      if(i < ULTRA_MKT_OHLC_SAMPLE && g_UltraMarketIntel.atr > 0.0)
      {
         double gap = MathAbs(iOpen(s, tf, i) - iClose(s, tf, i + 1));
         if(gap > g_UltraMarketIntel.atr * UltraMarketIntelGapATR)
            gaps++;
      }
   }
   g_UltraMarketIntel.badOhlcCount = bad;
   g_UltraMarketIntel.gapCount = gaps;
   g_UltraMarketIntel.ohlcOK = (bad == 0);
   if(!g_UltraMarketIntel.ohlcOK)
   { why = "corrupted OHLC sample"; return false; }

   g_UltraMarketIntel.gapOK = (gaps <= UltraMarketIntelMaxGaps);
   // Gaps degrade; only hard-reject if extreme and configured
   if(!g_UltraMarketIntel.gapOK && UltraMarketIntelRejectBadGaps)
   { why = "excessive price gaps"; return false; }
   return true;
}

//--------------------------------------------------------------------//
// BUFFERS / INDICATORS (lightweight)                                 //
//--------------------------------------------------------------------//
bool UltraMarketIntel_VerifyBuffers(const string s, string &why)
{
   why = "";
   ENUM_TIMEFRAMES tf = UltraETF();
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int n = CopyRates(s, tf, 0, 8, rates);
   g_UltraMarketIntel.buffersOK = (n >= 5);
   if(!g_UltraMarketIntel.buffersOK)
   { why = "corrupted / empty rate buffers"; return false; }
   return true;
}

bool UltraMarketIntel_VerifyIndicators()
{
   // Soft: if foundation reports handles broken after boot → not OK
   if(g_UltraFoundation.booted && !g_UltraFoundation.handlesOK)
   {
      g_UltraMarketIntel.indicatorsOK = false;
      return false;
   }
   g_UltraMarketIntel.indicatorsOK = true;
   return true;
}

//--------------------------------------------------------------------//
// VOLATILITY / VOLUME / LIQUIDITY BEHAVIOUR                          //
//--------------------------------------------------------------------//
void UltraMarketIntel_Behaviour(const string s)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double atr = g_UltraMarketIntel.atr;
   if(atr <= 0.0) atr = UltraATR(s, IDP_ATR_Period);
   g_UltraMarketIntel.atr = atr;

   double avg = 0.0;
   for(int i = 2; i <= 21; i++)
      avg += (iHigh(s, tf, i) - iLow(s, tf, i));
   avg /= 20.0;
   double r1 = iHigh(s, tf, 1) - iLow(s, tf, 1);
   g_UltraMarketIntel.atrRel = (avg > 0.0) ? (r1 / avg) : 1.0;

   g_UltraMarketIntel.volatilityOK = (atr > 0.0);
   long vol = iTickVolume(s, tf, 1);
   if(vol <= 0) vol = iVolume(s, tf, 1);
   g_UltraMarketIntel.volumeOK = (vol >= 0); // zero volume = soft (some symbols)

   // Liquidity proxy: spread vs ATR in points
   double point = g_UltraMarketIntel.point;
   if(point <= 0.0) point = SymbolInfoDouble(s, SYMBOL_POINT);
   double atrPts = (point > 0.0 && atr > 0.0) ? (atr / point) : 0.0;
   g_UltraMarketIntel.liquidityOK = true;
   if(atrPts > 0.0 && g_UltraMarketIntel.spreadPts > atrPts * UltraMarketIntelLiqSpreadATR)
      g_UltraMarketIntel.liquidityOK = false; // soft degrade

   g_UltraMarketIntel.sessionOK = true; // session never hard-blocks
}

//--------------------------------------------------------------------//
// MARKET STATE CLASSIFIER                                            //
//--------------------------------------------------------------------//
void UltraMarketIntel_Classify(const string s)
{
   ENUM_TIMEFRAMES tf = UltraETF();
   double rel = g_UltraMarketIntel.atrRel;
   // Lightweight SMA proxy — no ephemeral indicator handles
   double ema = 0.0;
   double sum = 0.0;
   int n = 0;
   for(int i = 1; i <= 50; i++)
   {
      double c = iClose(s, tf, i);
      if(c > 0.0){ sum += c; n++; }
   }
   if(n > 0) ema = sum / (double)n;
   double c1 = iClose(s, tf, 1);
   double slope = 0.0;
   if(n >= 20)
   {
      double early = 0.0, late = 0.0;
      for(int i = 1; i <= 10; i++) late += iClose(s, tf, i);
      for(int i = 11; i <= 20; i++) early += iClose(s, tf, i);
      early /= 10.0; late /= 10.0;
      if(early > 0.0) slope = (late - early) / early;
   }

   ENUM_ULTRA_MKT_STATE st = UMKT_NORMAL;

   if(rel >= UltraMarketIntelHighVolRel)
      st = UMKT_HIGH_VOLATILITY;
   else if(rel <= UltraMarketIntelLowVolRel)
      st = UMKT_LOW_VOLATILITY;
   else if(rel >= UltraMarketIntelExpandRel)
      st = UMKT_EXPANSION;
   else if(rel <= UltraMarketIntelCompressRel)
      st = UMKT_COMPRESSION;

   // Trend overlay when not in extreme vol regime
   if(st == UMKT_NORMAL || st == UMKT_EXPANSION || st == UMKT_COMPRESSION)
   {
      double absSlope = MathAbs(slope);
      bool directional = (ema > 0.0 && c1 > 0.0 &&
                          MathAbs(c1 - ema) / ema >= 0.0005);
      if(absSlope >= 0.0018 && directional)
         st = UMKT_STRONG_TREND;
      else if(absSlope >= 0.0009 && directional)
         st = UMKT_DEVELOPING_TREND;
      else if(absSlope >= 0.00035)
         st = UMKT_WEAK_TREND;
      else if(rel <= UltraMarketIntelCompressRel || absSlope < 0.00025)
         st = UMKT_CONSOLIDATION;
   }

   g_UltraMarketIntel.marketState = st;
   g_UltraMarketIntel.stateName = UltraMarketIntel_StateName(st);
}

//--------------------------------------------------------------------//
bool UltraMarketIntel_Reject(const string why)
{
   g_UltraMarketIntel.approved = false;
   g_UltraMarketIntel.status = "REJECTED";
   g_UltraMarketIntel.detail = why;
   g_UltraCore.dataOK = false;
   g_UltraCore.marketOK = false;
   g_UltraCore.validated = false;
   if(UltraMarketIntelLog)
      UltraLog("MARKET_INTEL REJECTED detail=" + why);
   if(UltraMarketIntelAutoRecover)
      UltraRecover("MARKET_INTEL " + why);
   return false;
}

//--------------------------------------------------------------------//
// FULL VALIDATION PIPELINE                                           //
//--------------------------------------------------------------------//
bool UltraMarketIntel_Validate(const string s)
{
   if(!UltraMarketIntelEnabled)
   {
      g_UltraMarketIntel.approved = true;
      g_UltraMarketIntel.status = "APPROVED";
      g_UltraMarketIntel.detail = "disabled-pass";
      g_UltraCore.dataOK = true;
      g_UltraCore.marketOK = true;
      return true;
   }

   long now = (long)GetTickCount();
   int interval = UltraMarketIntelIntervalMs;
   if(interval < 25) interval = 25;

   // Throttle full pipeline; keep prior decision between scans
   if(g_UltraMarketIntel.lastEvalMs > 0 &&
      (now - g_UltraMarketIntel.lastEvalMs) < interval &&
      g_UltraMarketIntel.symbol == s)
   {
      return g_UltraMarketIntel.approved;
   }
   g_UltraMarketIntel.lastEvalMs = now;
   g_UltraMarketIntel.symbol = s;

   string why = "";
   g_UltraMarketIntel.detail = "OK";

   // 1) Trading permissions
   g_UltraMarketIntel.tradingPermOK = UltraMarketIntel_TradingPerm(why);
   if(!g_UltraMarketIntel.tradingPermOK)
      return UltraMarketIntel_Reject(why);

   // 2) Symbol properties
   g_UltraMarketIntel.symbolPropsOK = UltraMarketIntel_SymbolProps(s, why);
   if(!g_UltraMarketIntel.symbolPropsOK)
      return UltraMarketIntel_Reject(why);

   // 3) Market status / weekend / holiday
   g_UltraMarketIntel.marketStatusOK = UltraMarketIntel_MarketStatus(s, why);
   if(!g_UltraMarketIntel.marketStatusOK)
      return UltraMarketIntel_Reject(why);

   // 4) Tick integrity + live feed
   g_UltraMarketIntel.tickOK = UltraMarketIntel_VerifyTick(s, why);
   g_UltraMarketIntel.feedOK = g_UltraMarketIntel.tickOK &&
                               (TerminalInfoInteger(TERMINAL_CONNECTED) != 0);
   if(!g_UltraMarketIntel.tickOK || !g_UltraMarketIntel.feedOK)
      return UltraMarketIntel_Reject((StringLen(why) > 0) ? why : "live feed invalid");

   // Stale quote hard-reject only when extreme (live-only — skipped in Strategy Tester)
   if(!UltraBT_SkipLiveOnly() &&
      UltraMarketIntelMaxQuoteAgeSec > 0 &&
      g_UltraMarketIntel.lastQuoteAgeSec > UltraMarketIntelMaxQuoteAgeSec)
      return UltraMarketIntel_Reject("stale live quote");

   // 5) Candle / OHLC / history / gaps
   if(!UltraMarketIntel_VerifyCandles(s, why))
      return UltraMarketIntel_Reject(why);

   // 6) Buffers
   if(!UltraMarketIntel_VerifyBuffers(s, why))
      return UltraMarketIntel_Reject(why);

   // 7) Indicators (soft broken → reject only if strict)
   bool indOK = UltraMarketIntel_VerifyIndicators();
   if(!indOK && UltraMarketIntelStrictIndicators)
      return UltraMarketIntel_Reject("broken indicator handles");

   // 8) Behavioural context (never sole hard-reject)
   UltraMarketIntel_Behaviour(s);
   UltraData_Refresh(s);

   // 9) Classify market state
   UltraMarketIntel_Classify(s);

   // Compose APPROVED / DEGRADED
   bool soft = (!g_UltraMarketIntel.spreadOK || !g_UltraMarketIntel.tickSpeedOK ||
                !g_UltraMarketIntel.tickConsistOK || !g_UltraMarketIntel.gapOK ||
                !g_UltraMarketIntel.liquidityOK || !g_UltraMarketIntel.indicatorsOK ||
                g_UltraMarketIntel.weekend);

   g_UltraMarketIntel.approved = true;
   g_UltraCore.dataOK = true;
   g_UltraCore.marketOK = true;
   g_UltraCore.validated = true;

   if(soft)
   {
      g_UltraMarketIntel.status = "DEGRADED";
      if(!g_UltraMarketIntel.spreadOK) g_UltraMarketIntel.detail = "wide spread (info)";
      else if(!g_UltraMarketIntel.liquidityOK) g_UltraMarketIntel.detail = "thin liquidity proxy";
      else if(!g_UltraMarketIntel.tickConsistOK) g_UltraMarketIntel.detail = "tick jump";
      else if(!g_UltraMarketIntel.gapOK) g_UltraMarketIntel.detail = "gap noise";
      else if(!g_UltraMarketIntel.tickSpeedOK) g_UltraMarketIntel.detail = "slow ticks";
      else if(!g_UltraMarketIntel.indicatorsOK) g_UltraMarketIntel.detail = "indicator soft";
      else g_UltraMarketIntel.detail = "weekend/session soft";
   }
   else
   {
      g_UltraMarketIntel.status = "APPROVED";
      g_UltraMarketIntel.detail = "verified";
   }

   if(UltraMarketIntelLog && g_UltraMarketIntel.status != "APPROVED")
   {
      UltraLog("MARKET_INTEL " + g_UltraMarketIntel.status +
               " state=" + g_UltraMarketIntel.stateName +
               " detail=" + g_UltraMarketIntel.detail +
               " spr=" + DoubleToString(g_UltraMarketIntel.spreadPts, 0) +
               " atrRel=" + DoubleToString(g_UltraMarketIntel.atrRel, 2));
   }
   return true;
}

//--------------------------------------------------------------------//
// BOOT / TICK / DASHBOARD                                            //
//--------------------------------------------------------------------//
void UltraMarketIntel_Boot()
{
   g_UltraMarketIntel.booted = false;
   g_UltraMarketIntel.approved = false;
   g_UltraMarketIntel.tickOK = g_UltraMarketIntel.candleOK = false;
   g_UltraMarketIntel.ohlcOK = g_UltraMarketIntel.histOK = false;
   g_UltraMarketIntel.feedOK = g_UltraMarketIntel.tickSpeedOK = false;
   g_UltraMarketIntel.tickConsistOK = g_UltraMarketIntel.candleCompleteOK = false;
   g_UltraMarketIntel.gapOK = g_UltraMarketIntel.spreadOK = false;
   g_UltraMarketIntel.volatilityOK = g_UltraMarketIntel.volumeOK = false;
   g_UltraMarketIntel.liquidityOK = g_UltraMarketIntel.sessionOK = false;
   g_UltraMarketIntel.symbolPropsOK = g_UltraMarketIntel.marketStatusOK = false;
   g_UltraMarketIntel.tradingPermOK = g_UltraMarketIntel.buffersOK = false;
   g_UltraMarketIntel.indicatorsOK = false;
   g_UltraMarketIntel.weekend = g_UltraMarketIntel.holiday = false;
   g_UltraMarketIntel.marketOpen = false;
   g_UltraMarketIntel.digits = 0;
   g_UltraMarketIntel.tickSize = g_UltraMarketIntel.point = 0.0;
   g_UltraMarketIntel.contractSize = 0.0;
   g_UltraMarketIntel.freezeLevel = g_UltraMarketIntel.stopLevel = 0;
   g_UltraMarketIntel.bid = g_UltraMarketIntel.ask = 0.0;
   g_UltraMarketIntel.spreadPts = g_UltraMarketIntel.atr = 0.0;
   g_UltraMarketIntel.atrRel = g_UltraMarketIntel.tickSpeed = 0.0;
   g_UltraMarketIntel.lastBid = g_UltraMarketIntel.lastAsk = 0.0;
   g_UltraMarketIntel.lastEvalMs = 0;
   g_UltraMarketIntel.lastQuoteAgeSec = 0;
   g_UltraMarketIntel.gapCount = g_UltraMarketIntel.badOhlcCount = 0;
   g_UltraMarketIntel.marketState = UMKT_NORMAL;
   g_UltraMarketIntel.status = "INIT";
   g_UltraMarketIntel.stateName = "NORMAL";
   g_UltraMarketIntel.detail = "booting";
   g_UltraMarketIntel.symbol = "";
   g_UltraCore.marketOK = false;

   if(!UltraMarketIntelEnabled)
   {
      g_UltraMarketIntel.booted = true;
      g_UltraMarketIntel.approved = true;
      g_UltraMarketIntel.status = "APPROVED";
      g_UltraMarketIntel.detail = "disabled-pass";
      g_UltraCore.marketOK = true;
      return;
   }

   string sym = BrokerSymbol;
   if(StringLen(sym) == 0) sym = _Symbol;
   UltraMarketIntel_Validate(sym);
   g_UltraMarketIntel.booted = true;

   if(UltraMarketIntelLog)
   {
      UltraLog("MARKET_INTEL boot status=" + g_UltraMarketIntel.status +
               " state=" + g_UltraMarketIntel.stateName +
               " detail=" + g_UltraMarketIntel.detail +
               " dig=" + IntegerToString(g_UltraMarketIntel.digits) +
               " stop=" + IntegerToString((int)g_UltraMarketIntel.stopLevel) +
               " freeze=" + IntegerToString((int)g_UltraMarketIntel.freezeLevel));
   }
}

void UltraMarketIntel_OnTick(const string s)
{
   if(!UltraMarketIntelEnabled) return;
   UltraMarketIntel_Validate(s);
}

string UltraMarketIntel_Dashboard()
{
   string t = "MARKET: ";
   t += g_UltraMarketIntel.status;
   t += " ";
   t += g_UltraMarketIntel.stateName;
   t += " | ";
   t += g_UltraMarketIntel.detail;
   t += " spr=";
   t += DoubleToString(g_UltraMarketIntel.spreadPts, 0);
   t += " atrR=";
   t += DoubleToString(g_UltraMarketIntel.atrRel, 2);
   if(g_UltraMarketIntel.weekend) t += " WEEKEND";
   if(g_UltraMarketIntel.holiday) t += " HOLIDAY";
   if(!g_UltraMarketIntel.marketOpen) t += " CLOSED";
   return t;
}

#endif // HITMAN_ULTRA_MARKET_INTELLIGENCE_MQH
