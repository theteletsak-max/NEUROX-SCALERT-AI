#ifndef HITMAN_ULTRA_MARKET_INTELLIGENCE_MQH
#define HITMAN_ULTRA_MARKET_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 2 · MARKET INTELLIGENCE ENGINE   |
//| Tick · Candle · Reader · Trend · Momentum · Vol · Liq · Spread   |
//| Session · Event · MTF · Quality · Cache · Sync                   |
//| NEVER opens/closes/manages trades — ONLY reads the market        |
//| Spread/vol/session/event alone NEVER hard-reject (product lock)  |
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
   bool   approved;          // data gate: analysis allowed (not a trade decision)
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
   double tickAccel;         // Chapter 2 — tick acceleration proxy
   int    tickDirection;     // -1 / 0 / +1
   double lastBid;
   double lastAsk;
   double lastTickSpeed;
   long   lastEvalMs;
   long   lastQuoteAgeSec;
   long   cacheMs;           // Chapter 2 — picture cache stamp
   int    gapCount;
   int    badOhlcCount;
   // Candle engine (Chapter 2 §2)
   int    candleStrength;    // 0..100
   int    candleMomentum;    // 0..100
   int    candleDirection;   // -1 / 0 / +1
   bool   candleRejection;
   bool   candleExpansion;
   bool   candleCompression;
   ENUM_ULTRA_MKT_STATE marketState;
   string status;            // APPROVED / DEGRADED / REJECTED
   string stateName;         // legacy classifier name
   string detail;
   string symbol;
   // MASTER SPEC CHAPTER 2 — canonical market picture (outputs only)
   string readerState;       // TRENDING|RANGING|TRANSITION|EXPANSION|COMPRESSION|HIGH_MOMENTUM|LOW_MOMENTUM
   string outTrend;          // BULLISH|BEARISH|NEUTRAL
   int    outTrendConf;      // 0..100
   string outMomentum;       // STRONG|MEDIUM|WEAK
   string outVolatility;     // EXPAND|COMPRESS|NORMAL (+ event note via context)
   string outLiquidity;      // RICH|NORMAL|THIN
   string outSpread;         // STABLE|ELEVATED|EXTREME
   string outSession;        // Asia|London|NewYork|Overlap|...
   string outEvent;          // NORMAL|PRE_NEWS|LIVE_NEWS|POST_NEWS (+ class)
   int    marketQuality;     // 0..100 — higher = better environment
   string mtfPicture;        // H4→H1→M15→M5 unified bias
   string marketContext;     // one-line picture for dashboard / sync consumers
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
// CHAPTER 2 — MARKET READER (exactly one state)                      //
//--------------------------------------------------------------------//
string UltraMarketIntel_ReaderFromParts(const bool expansion, const bool compression,
                                        const int momStrength, const int trendStrength,
                                        const bool trending, const bool ranging)
{
   // Priority: expansion/compression → momentum extremes → trend/range → transition
   if(expansion && !compression) return "EXPANSION";
   if(compression && !expansion) return "COMPRESSION";
   if(momStrength >= 75) return "HIGH_MOMENTUM";
   if(momStrength > 0 && momStrength <= 35) return "LOW_MOMENTUM";
   if(trending && trendStrength >= 55) return "TRENDING";
   if(ranging) return "RANGING";
   return "TRANSITION";
}

//--------------------------------------------------------------------//
// CHAPTER 2 — MTF CORE LADDER H4 → H1 → M15 → M5 (one picture)       //
//--------------------------------------------------------------------//
string UltraMarketIntel_MTFCorePicture(const string s)
{
   ENUM_TIMEFRAMES tfs[4];
   tfs[0] = PERIOD_H4; tfs[1] = PERIOD_H1; tfs[2] = PERIOD_M15; tfs[3] = PERIOD_M5;
   string labels[4];
   labels[0] = "H4"; labels[1] = "H1"; labels[2] = "M15"; labels[3] = "M5";
   int bull = 0, bear = 0;
   string bits = "";
   for(int i = 0; i < 4; i++)
   {
      double sma = UltraSMA(s, tfs[i], 20, 1);
      double c = iClose(s, tfs[i], 1);
      string d = "-";
      if(sma > 0.0 && c > 0.0)
      {
         if(c > sma){ d = "B"; bull++; }
         else if(c < sma){ d = "S"; bear++; }
      }
      if(i > 0) bits += ">";
      bits += labels[i];
      bits += d;
   }
   string bias = "NEUTRAL";
   if(bull >= 3 && bear == 0) bias = "BULLISH";
   else if(bear >= 3 && bull == 0) bias = "BEARISH";
   else if(bull > bear) bias = "BULL_LEAN";
   else if(bear > bull) bias = "BEAR_LEAN";
   return bits + "|" + bias;
}

//--------------------------------------------------------------------//
// CHAPTER 2 — MARKET QUALITY SCORE 0..100                            //
//--------------------------------------------------------------------//
int UltraMarketIntel_ComposeQuality(const UltraMarketIntelState &m)
{
   int q = 50;
   // Trend
   if(m.outTrend == "BULLISH" || m.outTrend == "BEARISH")
      q += MathMin(15, m.outTrendConf / 7);
   else
      q -= 5;
   // Momentum
   if(m.outMomentum == "STRONG") q += 12;
   else if(m.outMomentum == "MEDIUM") q += 6;
   else q -= 4;
   // Liquidity
   if(m.outLiquidity == "RICH") q += 10;
   else if(m.outLiquidity == "THIN") q -= 10;
   // Volatility — adapt, never block; mild prefer normal/expand over chaos
   if(m.outVolatility == "NORMAL") q += 6;
   else if(m.outVolatility == "EXPAND") q += 2;
   else if(m.outVolatility == "COMPRESS") q += 1;
   // Spread — informational; elevated/extreme soft-penalize only
   if(m.outSpread == "STABLE") q += 8;
   else if(m.outSpread == "ELEVATED") q -= 4;
   else if(m.outSpread == "EXTREME") q -= 10;
   // Session context
   if(m.outSession == "Overlap" || m.outSession == "London" || m.outSession == "NewYork")
      q += 6;
   else if(m.outSession == "Tokyo" || m.outSession == "Asia" || m.outSession == "Sydney")
      q += 2;
   // Event — continue analysis; soft environment note
   if(StringFind(m.outEvent, "LIVE") >= 0) q -= 6;
   else if(StringFind(m.outEvent, "PRE") >= 0 || StringFind(m.outEvent, "POST") >= 0) q -= 2;
   if(q < 0) q = 0;
   if(q > 100) q = 100;
   return q;
}

//--------------------------------------------------------------------//
// CHAPTER 2 — PUBLISH LITE (from Validate — no trade path)           //
//--------------------------------------------------------------------//
void UltraMarketIntel_PublishLite(const string s)
{
   // Trend proxy from classifier
   g_UltraMarketIntel.outTrend = "NEUTRAL";
   g_UltraMarketIntel.outTrendConf = 40;
   if(g_UltraMarketIntel.marketState == UMKT_STRONG_TREND ||
      g_UltraMarketIntel.marketState == UMKT_DEVELOPING_TREND)
   {
      double c1 = iClose(s, UltraETF(), 1);
      double sma = UltraSMA(s, UltraETF(), 50, 1);
      if(sma > 0.0 && c1 > sma){ g_UltraMarketIntel.outTrend = "BULLISH"; g_UltraMarketIntel.outTrendConf = 70; }
      else if(sma > 0.0 && c1 < sma){ g_UltraMarketIntel.outTrend = "BEARISH"; g_UltraMarketIntel.outTrendConf = 70; }
      else g_UltraMarketIntel.outTrendConf = 55;
   }
   else if(g_UltraMarketIntel.marketState == UMKT_WEAK_TREND)
      g_UltraMarketIntel.outTrendConf = 45;

   // Momentum from candle engine
   int ms = g_UltraMarketIntel.candleMomentum;
   if(ms >= 70) g_UltraMarketIntel.outMomentum = "STRONG";
   else if(ms >= 40) g_UltraMarketIntel.outMomentum = "MEDIUM";
   else g_UltraMarketIntel.outMomentum = "WEAK";

   // Volatility
   if(g_UltraMarketIntel.candleExpansion ||
      g_UltraMarketIntel.atrRel >= UltraMarketIntelExpandRel)
      g_UltraMarketIntel.outVolatility = "EXPAND";
   else if(g_UltraMarketIntel.candleCompression ||
           g_UltraMarketIntel.atrRel <= UltraMarketIntelCompressRel)
      g_UltraMarketIntel.outVolatility = "COMPRESS";
   else
      g_UltraMarketIntel.outVolatility = "NORMAL";

   // Liquidity
   if(!g_UltraMarketIntel.liquidityOK) g_UltraMarketIntel.outLiquidity = "THIN";
   else if(g_UltraMarketIntel.volumeOK && g_UltraMarketIntel.spreadOK)
      g_UltraMarketIntel.outLiquidity = "RICH";
   else
      g_UltraMarketIntel.outLiquidity = "NORMAL";

   // Spread (never rejects)
   double warn = UltraMarketIntelSpreadWarnPts;
   if(warn <= 0.0) warn = UltraEventSpreadWarnPts;
   if(g_UltraMarketIntel.spreadPts >= warn * 2.0)
      g_UltraMarketIntel.outSpread = "EXTREME";
   else if(g_UltraMarketIntel.spreadPts >= warn)
      g_UltraMarketIntel.outSpread = "ELEVATED";
   else
      g_UltraMarketIntel.outSpread = "STABLE";

   g_UltraMarketIntel.outSession = "OFF";
   g_UltraMarketIntel.outEvent = "NORMAL";

   bool trending = (g_UltraMarketIntel.marketState == UMKT_STRONG_TREND ||
                    g_UltraMarketIntel.marketState == UMKT_DEVELOPING_TREND ||
                    g_UltraMarketIntel.marketState == UMKT_WEAK_TREND);
   bool ranging = (g_UltraMarketIntel.marketState == UMKT_CONSOLIDATION ||
                   g_UltraMarketIntel.marketState == UMKT_NORMAL);
   g_UltraMarketIntel.readerState = UltraMarketIntel_ReaderFromParts(
      (g_UltraMarketIntel.outVolatility == "EXPAND"),
      (g_UltraMarketIntel.outVolatility == "COMPRESS"),
      ms, g_UltraMarketIntel.outTrendConf, trending, ranging);

   g_UltraMarketIntel.mtfPicture = UltraMarketIntel_MTFCorePicture(s);
   g_UltraMarketIntel.marketQuality = UltraMarketIntel_ComposeQuality(g_UltraMarketIntel);
   g_UltraMarketIntel.marketContext = "MKT ";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.readerState;
   g_UltraMarketIntel.marketContext += " | ";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outTrend;
   g_UltraMarketIntel.marketContext += " ";
   g_UltraMarketIntel.marketContext += IntegerToString(g_UltraMarketIntel.outTrendConf);
   g_UltraMarketIntel.marketContext += " | mom=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outMomentum;
   g_UltraMarketIntel.marketContext += " | vol=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outVolatility;
   g_UltraMarketIntel.marketContext += " | liq=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outLiquidity;
   g_UltraMarketIntel.marketContext += " | spr=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outSpread;
   g_UltraMarketIntel.marketContext += " | Q=";
   g_UltraMarketIntel.marketContext += IntegerToString(g_UltraMarketIntel.marketQuality);
   g_UltraMarketIntel.cacheMs = (long)GetTickCount();
}

//--------------------------------------------------------------------//
// CHAPTER 2 — SYNC FROM SNAP (one unified picture · no duplicate)    //
//--------------------------------------------------------------------//
void UltraMarketIntel_SyncFromSnap(const UltraSnap &u)
{
   // Trend
   if(u.trend.bull && !u.trend.bear)
   {
      g_UltraMarketIntel.outTrend = "BULLISH";
      g_UltraMarketIntel.outTrendConf = MathMax(u.trend.strength, u.trend.persistence);
   }
   else if(u.trend.bear && !u.trend.bull)
   {
      g_UltraMarketIntel.outTrend = "BEARISH";
      g_UltraMarketIntel.outTrendConf = MathMax(u.trend.strength, u.trend.persistence);
   }
   else
   {
      g_UltraMarketIntel.outTrend = "NEUTRAL";
      g_UltraMarketIntel.outTrendConf = MathMin(50, u.trend.strength);
   }
   if(g_UltraMarketIntel.outTrendConf > 100) g_UltraMarketIntel.outTrendConf = 100;
   if(g_UltraMarketIntel.outTrendConf < 0) g_UltraMarketIntel.outTrendConf = 0;

   // Momentum
   if(u.mom.strength >= 70 || u.mom.impulse) g_UltraMarketIntel.outMomentum = "STRONG";
   else if(u.mom.strength >= 40) g_UltraMarketIntel.outMomentum = "MEDIUM";
   else g_UltraMarketIntel.outMomentum = "WEAK";

   // Volatility — never blocks
   if(u.vol.expansion) g_UltraMarketIntel.outVolatility = "EXPAND";
   else if(u.vol.compression) g_UltraMarketIntel.outVolatility = "COMPRESS";
   else g_UltraMarketIntel.outVolatility = "NORMAL";

   // Liquidity
   if(u.liq.genuineBuy || u.liq.genuineSell || u.liq.quality >= 65.0)
      g_UltraMarketIntel.outLiquidity = "RICH";
   else if(u.liq.fakeBuy || u.liq.fakeSell || u.liq.quality < 35.0)
      g_UltraMarketIntel.outLiquidity = "THIN";
   else
      g_UltraMarketIntel.outLiquidity = "NORMAL";

   // Spread from snap / live
   double spr = u.ctx.spreadPts;
   if(spr <= 0.0) spr = g_UltraMarketIntel.spreadPts;
   double warn = UltraMarketIntelSpreadWarnPts;
   if(warn <= 0.0) warn = UltraEventSpreadWarnPts;
   if(spr >= warn * 2.0) g_UltraMarketIntel.outSpread = "EXTREME";
   else if(spr >= warn) g_UltraMarketIntel.outSpread = "ELEVATED";
   else g_UltraMarketIntel.outSpread = "STABLE";

   // Session — context only
   if(StringLen(u.ctx.sessionRegion) > 0) g_UltraMarketIntel.outSession = u.ctx.sessionRegion;
   else if(StringLen(u.ctx.session) > 0) g_UltraMarketIntel.outSession = u.ctx.session;
   else g_UltraMarketIntel.outSession = "OFF";

   // Event — continue analysing; never disable trading here
   if(StringLen(u.ctx.eventState) > 0)
   {
      g_UltraMarketIntel.outEvent = u.ctx.eventState;
      if(StringLen(u.ctx.eventClass) > 0 && u.ctx.eventClass != "NONE")
      {
         g_UltraMarketIntel.outEvent += "/";
         g_UltraMarketIntel.outEvent += u.ctx.eventClass;
      }
   }
   else if(u.ctx.duringNews) g_UltraMarketIntel.outEvent = "LIVE_NEWS";
   else if(u.ctx.beforeNews) g_UltraMarketIntel.outEvent = "PRE_NEWS";
   else if(u.ctx.afterNews)  g_UltraMarketIntel.outEvent = "POST_NEWS";
   else g_UltraMarketIntel.outEvent = "NORMAL";

   bool trending = (u.trend.bull || u.trend.bear) && u.trend.strength >= 55;
   bool ranging = (u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION);
   g_UltraMarketIntel.readerState = UltraMarketIntel_ReaderFromParts(
      u.vol.expansion, u.vol.compression, u.mom.strength, u.trend.strength,
      trending, ranging);

   // Prefer snap MTF votes; refresh core ladder when symbol known
   string sym = g_UltraMarketIntel.symbol;
   if(StringLen(sym) == 0) sym = _Symbol;
   g_UltraMarketIntel.mtfPicture = UltraMarketIntel_MTFCorePicture(sym);
   g_UltraMarketIntel.mtfPicture += " votesB/S=";
   g_UltraMarketIntel.mtfPicture += IntegerToString(u.trend.mtfVotesBuy);
   g_UltraMarketIntel.mtfPicture += "/";
   g_UltraMarketIntel.mtfPicture += IntegerToString(u.trend.mtfVotesSell);

   g_UltraMarketIntel.marketQuality = UltraMarketIntel_ComposeQuality(g_UltraMarketIntel);
   g_UltraMarketIntel.marketContext = "MKT ";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.readerState;
   g_UltraMarketIntel.marketContext += " | ";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outTrend;
   g_UltraMarketIntel.marketContext += " ";
   g_UltraMarketIntel.marketContext += IntegerToString(g_UltraMarketIntel.outTrendConf);
   g_UltraMarketIntel.marketContext += " | mom=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outMomentum;
   g_UltraMarketIntel.marketContext += " | vol=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outVolatility;
   g_UltraMarketIntel.marketContext += " | liq=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outLiquidity;
   g_UltraMarketIntel.marketContext += " | spr=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outSpread;
   g_UltraMarketIntel.marketContext += " | sess=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outSession;
   g_UltraMarketIntel.marketContext += " | evt=";
   g_UltraMarketIntel.marketContext += g_UltraMarketIntel.outEvent;
   g_UltraMarketIntel.marketContext += " | Q=";
   g_UltraMarketIntel.marketContext += IntegerToString(g_UltraMarketIntel.marketQuality);
   g_UltraMarketIntel.cacheMs = (long)GetTickCount();

   // Keep legacy stateName aligned to reader when useful
   if(g_UltraMarketIntel.readerState == "TRENDING")
      g_UltraMarketIntel.stateName = (g_UltraMarketIntel.outTrendConf >= 70) ? "STRONG_TREND" : "DEVELOPING_TREND";
   else if(g_UltraMarketIntel.readerState == "RANGING")
      g_UltraMarketIntel.stateName = "CONSOLIDATION";
   else if(g_UltraMarketIntel.readerState == "EXPANSION")
      g_UltraMarketIntel.stateName = "EXPANSION";
   else if(g_UltraMarketIntel.readerState == "COMPRESSION")
      g_UltraMarketIntel.stateName = "COMPRESSION";
   else if(g_UltraMarketIntel.readerState == "HIGH_MOMENTUM")
      g_UltraMarketIntel.stateName = "HIGH_VOLATILITY";
   else if(g_UltraMarketIntel.readerState == "LOW_MOMENTUM")
      g_UltraMarketIntel.stateName = "LOW_VOLATILITY";
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

   // Tick direction + acceleration (Chapter 2 §1)
   g_UltraMarketIntel.tickDirection = 0;
   if(g_UltraMarketIntel.lastBid > 0.0)
   {
      if(g_UltraMarketIntel.bid > g_UltraMarketIntel.lastBid) g_UltraMarketIntel.tickDirection = 1;
      else if(g_UltraMarketIntel.bid < g_UltraMarketIntel.lastBid) g_UltraMarketIntel.tickDirection = -1;
   }
   if(g_UltraMarketIntel.lastTickSpeed > 0.0 && g_UltraMarketIntel.tickSpeed > 0.0)
      g_UltraMarketIntel.tickAccel = g_UltraMarketIntel.tickSpeed - g_UltraMarketIntel.lastTickSpeed;
   else
      g_UltraMarketIntel.tickAccel = 0.0;
   g_UltraMarketIntel.lastTickSpeed = g_UltraMarketIntel.tickSpeed;

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

   // Candle engine — strength · momentum · direction · rejection · expand/compress
   double o1 = iOpen(s, tf, 1), h1 = iHigh(s, tf, 1), l1 = iLow(s, tf, 1), c1 = iClose(s, tf, 1);
   double range = h1 - l1;
   double body = MathAbs(c1 - o1);
   g_UltraMarketIntel.candleDirection = (c1 > o1) ? 1 : ((c1 < o1) ? -1 : 0);
   g_UltraMarketIntel.candleStrength = (range > 0.0)
      ? (int)MathRound(100.0 * body / range) : 0;
   if(g_UltraMarketIntel.candleStrength > 100) g_UltraMarketIntel.candleStrength = 100;
   g_UltraMarketIntel.candleMomentum = (int)MathRound(
      0.55 * g_UltraMarketIntel.candleStrength +
      0.45 * MathMin(100.0, g_UltraMarketIntel.atrRel * 50.0));
   if(g_UltraMarketIntel.candleMomentum > 100) g_UltraMarketIntel.candleMomentum = 100;
   double upperWick = h1 - MathMax(o1, c1);
   double lowerWick = MathMin(o1, c1) - l1;
   g_UltraMarketIntel.candleRejection =
      (range > 0.0 && (upperWick >= range * 0.55 || lowerWick >= range * 0.55));
   g_UltraMarketIntel.candleExpansion =
      (avg > 0.0 && r1 >= avg * UltraMarketIntelExpandRel);
   g_UltraMarketIntel.candleCompression =
      (avg > 0.0 && r1 <= avg * UltraMarketIntelCompressRel);

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

   // 9) Classify market state + Chapter 2 lite picture/cache
   UltraMarketIntel_Classify(s);
   UltraMarketIntel_PublishLite(s);

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
               " reader=" + g_UltraMarketIntel.readerState +
               " Q=" + IntegerToString(g_UltraMarketIntel.marketQuality) +
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
   g_UltraMarketIntel.tickAccel = 0.0;
   g_UltraMarketIntel.tickDirection = 0;
   g_UltraMarketIntel.lastBid = g_UltraMarketIntel.lastAsk = 0.0;
   g_UltraMarketIntel.lastTickSpeed = 0.0;
   g_UltraMarketIntel.lastEvalMs = 0;
   g_UltraMarketIntel.lastQuoteAgeSec = 0;
   g_UltraMarketIntel.cacheMs = 0;
   g_UltraMarketIntel.gapCount = g_UltraMarketIntel.badOhlcCount = 0;
   g_UltraMarketIntel.candleStrength = g_UltraMarketIntel.candleMomentum = 0;
   g_UltraMarketIntel.candleDirection = 0;
   g_UltraMarketIntel.candleRejection = false;
   g_UltraMarketIntel.candleExpansion = g_UltraMarketIntel.candleCompression = false;
   g_UltraMarketIntel.marketState = UMKT_NORMAL;
   g_UltraMarketIntel.status = "INIT";
   g_UltraMarketIntel.stateName = "NORMAL";
   g_UltraMarketIntel.detail = "booting";
   g_UltraMarketIntel.symbol = "";
   g_UltraMarketIntel.readerState = "TRANSITION";
   g_UltraMarketIntel.outTrend = "NEUTRAL";
   g_UltraMarketIntel.outTrendConf = 0;
   g_UltraMarketIntel.outMomentum = "WEAK";
   g_UltraMarketIntel.outVolatility = "NORMAL";
   g_UltraMarketIntel.outLiquidity = "NORMAL";
   g_UltraMarketIntel.outSpread = "STABLE";
   g_UltraMarketIntel.outSession = "OFF";
   g_UltraMarketIntel.outEvent = "NORMAL";
   g_UltraMarketIntel.marketQuality = 0;
   g_UltraMarketIntel.mtfPicture = "";
   g_UltraMarketIntel.marketContext = "MKT INIT";
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
   if(StringLen(g_UltraMarketIntel.marketContext) > 0)
      t += g_UltraMarketIntel.marketContext;
   else
   {
      t += g_UltraMarketIntel.readerState;
      t += " Q=";
      t += IntegerToString(g_UltraMarketIntel.marketQuality);
   }
   t += " | ";
   t += g_UltraMarketIntel.detail;
   if(StringLen(g_UltraMarketIntel.mtfPicture) > 0)
   {
      t += " | ";
      t += g_UltraMarketIntel.mtfPicture;
   }
   if(g_UltraMarketIntel.weekend) t += " WEEKEND";
   if(g_UltraMarketIntel.holiday) t += " HOLIDAY";
   if(!g_UltraMarketIntel.marketOpen) t += " CLOSED";
   return t;
}

#endif // HITMAN_ULTRA_MARKET_INTELLIGENCE_MQH
