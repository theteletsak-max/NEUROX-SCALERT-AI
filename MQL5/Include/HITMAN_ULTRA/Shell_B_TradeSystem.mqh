#ifndef HITMAN_ULTRA_SHELL_B_MQH
#define HITMAN_ULTRA_SHELL_B_MQH
//+------------------------------------------------------------------+
//| Shell B — Trade system / management / events (post-Ultra)        |
//+------------------------------------------------------------------+

int OnInit()
{
   if(StringCompare(TradeComment, "HITMAN AI") != 0)
   {
      Print("HITMAN AI INIT FAILED: TradeComment input must be exactly HITMAN AI");
      return(INIT_PARAMETERS_INCORRECT);
   }

   trade.SetExpertMagicNumber(MagicNumber);

   BrokerSymbol = DetectBrokerSymbol(_Symbol);
   PrimarySymbol = BrokerSymbol;

   // Must run before indicator initialization - InitializeSymbols() builds
   // MultiSymbolList (via BuildMultiSymbolList at its end), and every
   // indicator handle array below is sized/indexed against that list.
   InitializeSymbols();

   ResizePerSymbolTrackingArrays();

   if(!InitializeIndicators())
   {
      Print("Indicator initialization failed.");
      return(INIT_FAILED);
   }

   if(!InitializeMarketFilters())
   {
      Print("Market Filter initialization failed.");
      return(INIT_FAILED);
   }

   InitializeRiskEngine();

   ApplyChartTheme();

   RestoreTradeStates();

   RestoreTradeStatistics();

   RestoreSignalStatistics();

   RestoreStrategyPerformance();

   // TRADEUNBLOCK53: wipe stuck PeakEquity GV so a re-enabled DD shield
   // starts from current equity (was permanently blocking at ~50%+ DD).
   if(ResetPeakEquityOnInit)
      ResetPeakEquityToCurrent();

   CreateChartBackground();

   if(EnableMultiSymbolTrading)
   {
      EventSetTimer(MultiSymbolTimerSeconds);
      Print("Multi-symbol timer started (", MultiSymbolTimerSeconds, "s interval).");
   }

   Print("HITMAN EA / HITMAN AI Loaded BUILD_ID=HA_ULTRA_93 MaxOpen=", MaxOpenTrades);
   UltraCoreInit();
   UltraSystemController_Boot();
   {
      ENUM_TIMEFRAMES etf = (EntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : EntryTF;
      Print("OK93 ENTRY TF=", EnumToString(etf),
            " (EntryTF input=", EnumToString(EntryTF),
            ") — change the chart timeframe to change trading TF, or set EntryTF input");
   }
   Print("HITMAN MASTER BLUEPRINT: modules 00-40 | Shell A/B | HITMAN AI live path");
   if(EnableAPEXStrategy || EnableContFallback || EnableLCSStrategy)
      Print("OK93 WARNING: old APEX/ContFallback/LCS input ON — evaluators STUBBED; ULTRA only fires");
   Print("INSTANT OPEN + QUALITY PREFER MODE=", InstantQualityMode);
   Print("QUALITY SELECT: IDP_Hard=", IDP_HardGate, " MinPulse=", IDP_MinAbsPulse,
         " ContScore=", ContStruct_MinScore, " ADX=", ContStruct_RequireTrendADX,
         " SkipRange=", ContStruct_SkipRanging);
   Print("INSTANT EXEC: TradeCD=", TradeCooldownMinutes, " AttemptCD=", AttemptCooldownSeconds,
         " ContCD=", ContFallbackCooldownMinutes,
         " TickDetect=", EnableTickLevelSignalDetection,
         " NeverBlock=", NeverBlockValidSniperEntry,
         " UltraAggro=", UltraAggressiveFire);
   Print("CRITICAL: SOURCE must be HITMAN_AI / HITMAN_EA");
   Print("INSTANT QUALITY81: ANYTIME + STRONG/QUALITY + IDP CORE | AntiScalp=", EnableAntiScalpMode,
         " HardBlock=", APEX_SessionHardBlock, " (must be false)",
         " NewsAware=", EnableNewsAwareness,
         " IDP=", EnableIDPConfluence,
         " SpreadAlwaysAllow | MaxOpen=", MaxOpenTrades,
         " Lot=", LotSize);
   Print("APEX ", EnumToString(APEX_BiasTF), "/", EnumToString(APEX_EntryTF),
         " | ContFallback cooldown=", ContFallbackCooldownMinutes, "m hold=", ContFallbackMinimumHoldBars,
         " | DD shield=", EnableDrawdownProtection);
   Print("STRONG QUALITY Cont: ADX=", ContStruct_RequireTrendADX,
         " SkipRange=", ContStruct_SkipRanging,
         " MinScore=", ContStruct_MinScore,
         " TwoBarBOS=", ContStruct_RequireTwoBarBOS,
         " ZoneOrDisp=", ContStruct_ZoneOrDisplacement,
         " CF_Cooldown=", ContFallbackCooldownMinutes);
   Print("ANYTIME: SessionHardBlock=", APEX_SessionHardBlock,
         " | SessionDetect=", EnableSessionDetect,
         " | Spread/News never hard-block | ContFallback=", EnableContFallback);
   Print("IDP BUILT-IN CORE: Enable=", EnableIDPConfluence,
         " HardGate=", IDP_HardGate,
         " RequireStrong=", IDP_RequireStrong,
         " MinAbs=", IDP_MinAbsPulse,
         " StrongAbs=", IDP_StrongAbsPulse,
         " Shift=", IDP_PulseShift,
         " ATR=", IDP_ATR_Period,
         " EMA=", IDP_EMA_Period);
   Print("IDP: pulse computed INSIDE EA (no iCustom) - chart SNIPER_IDP optional visual only");
   UpdateNewsAwareness();
   {
      string sn="", sd=""; bool a=false,b=false,c=false,d=false; int h=-1;
      DetectMarketSession(sn, sd, a, b, c, d, h);
      Print("SESSION DETECT ON LOAD: ", sd);
   }
   AnalyzeLiveMarket(true);
   Print("MARKET: ", LiveMarketSummary());
   if(PrintPathStatsOnInit)
      PrintStrategyPerformanceReport();

   return(INIT_SUCCEEDED);
}

// Sizes every per-symbol tracking array to match MultiSymbolList, with
// safe defaults (no cooldown active, no handles yet).
void ResizePerSymbolTrackingArrays()
{
   int n = ArraySize(MultiSymbolList);

   ArrayResize(LastTradeTimeArr, n);
   ArrayResize(LastAttemptTimeArr, n);
   ArrayResize(LastTradeWasLossArr, n);
   ArrayResize(LastLossCloseTimeArr, n);
   ArrayResize(EMAHandles, n);
   ArrayResize(ADXHandles, n);
   ArrayResize(ATRHandlesArr, n);
   ArrayResize(FilterATRHandles, n);
   ArrayResize(HTFEMAHandlesArr, n);
   ArrayResize(RSIHandlesArr, n);
   ArrayResize(BBHandlesArr, n);
   ArrayResize(FastEMAHandlesArr, n);
   ArrayResize(SlowEMAHandlesArr, n);

   ArrayResize(LastEntryEvalBarTimeArr, n);
   ArrayResize(ConsecutiveLossesPerSymbolArr, n);
   ArrayResize(ConsecutiveWinsPerSymbolArr, n);
   ArrayResize(CHoCH_LastBarTimeArr, n);
   ArrayResize(CHoCH_LastBullTrendArr, n);
   ArrayResize(CHoCH_StateInitializedArr, n);
   ArrayResize(DiagLastBarTimeArr, n);
   ArrayResize(LastBOSTrueBarTimeArr, n);
   ArrayResize(LastCHoCHTrueBarTimeArr, n);
   ArrayResize(LastCHoCHWasBullArr, n);
   ArrayResize(LastSweepTrueBarTimeArr, n);
   ArrayResize(CHoCH_CacheCycleArr, n);
   ArrayResize(CHoCH_CacheResultArr, n);
   ArrayResize(RSI_CacheCycleArr, n);
   ArrayResize(RSI_CacheValueArr, n);
   ArrayResize(BB_CacheCycleArr, n);
   ArrayResize(BB_CacheUpperArr, n);
   ArrayResize(BB_CacheLowerArr, n);
   ArrayResize(BB_CacheMidArr, n);

   ArrayResize(OB_Bull_BarTimeArr, n);
   ArrayResize(OB_Bull_TopArr, n);
   ArrayResize(OB_Bull_BottomArr, n);
   ArrayResize(OB_Bull_ActiveArr, n);
   ArrayResize(OB_Bull_MitigatedArr, n);
   ArrayResize(OB_Bear_BarTimeArr, n);
   ArrayResize(OB_Bear_TopArr, n);
   ArrayResize(OB_Bear_BottomArr, n);
   ArrayResize(OB_Bear_ActiveArr, n);
   ArrayResize(OB_Bear_MitigatedArr, n);
   ArrayResize(OB_LastProcessedBarTimeArr, n);

   ArrayResize(FVG_Bull_BarTimeArr, n);
   ArrayResize(FVG_Bull_TopArr, n);
   ArrayResize(FVG_Bull_BottomArr, n);
   ArrayResize(FVG_Bull_ActiveArr, n);
   ArrayResize(FVG_Bull_FilledPctArr, n);
   ArrayResize(FVG_Bear_BarTimeArr, n);
   ArrayResize(FVG_Bear_TopArr, n);
   ArrayResize(FVG_Bear_BottomArr, n);
   ArrayResize(FVG_Bear_ActiveArr, n);
   ArrayResize(FVG_Bear_FilledPctArr, n);
   ArrayResize(FVG_LastProcessedBarTimeArr, n);

   ArrayResize(SwingHighCacheCycleArr, n);
   ArrayResize(SwingHighCacheArr, n);
   ArrayResize(SwingLowCacheCycleArr, n);
   ArrayResize(SwingLowCacheArr, n);
   ArrayResize(BOS_CacheCycleArr, n);
   ArrayResize(BOS_CacheResultArr, n);
   ArrayResize(LastApprovedBuyBarTimeArr, n);
   ArrayResize(LastApprovedSellBarTimeArr, n);
   ArrayResize(RegimeLastStateArr, n);

   for(int i = 0; i < n; i++)
   {
      LastTradeTimeArr[i]     = 0;
      LastAttemptTimeArr[i]   = 0;
      LastTradeWasLossArr[i]  = false;
      LastLossCloseTimeArr[i] = 0;
      EMAHandles[i]           = INVALID_HANDLE;
      ADXHandles[i]           = INVALID_HANDLE;
      ATRHandlesArr[i]        = INVALID_HANDLE;
      FilterATRHandles[i]     = INVALID_HANDLE;
      HTFEMAHandlesArr[i]     = INVALID_HANDLE;
      RSIHandlesArr[i]        = INVALID_HANDLE;
      BBHandlesArr[i]         = INVALID_HANDLE;
      FastEMAHandlesArr[i]    = INVALID_HANDLE;
      SlowEMAHandlesArr[i]    = INVALID_HANDLE;

      LastEntryEvalBarTimeArr[i]    = 0;
      ConsecutiveLossesPerSymbolArr[i] = 0;
      ConsecutiveWinsPerSymbolArr[i]   = 0;
      CHoCH_LastBarTimeArr[i]       = 0;
      CHoCH_LastBullTrendArr[i]     = false;
      CHoCH_StateInitializedArr[i]  = false;
      DiagLastBarTimeArr[i]         = 0;
      LastBOSTrueBarTimeArr[i]      = 0;
      LastCHoCHTrueBarTimeArr[i]    = 0;
      LastCHoCHWasBullArr[i]        = false;
      LastSweepTrueBarTimeArr[i]    = 0;
      CHoCH_CacheCycleArr[i]        = -1;
      CHoCH_CacheResultArr[i]       = false;
      RSI_CacheCycleArr[i]          = -1;
      RSI_CacheValueArr[i]          = EMPTY_VALUE;
      BB_CacheCycleArr[i]           = -1;

      OB_Bull_ActiveArr[i]     = false;
      OB_Bull_MitigatedArr[i]  = false;
      OB_Bull_BarTimeArr[i]    = 0;
      OB_Bear_ActiveArr[i]     = false;
      OB_Bear_MitigatedArr[i]  = false;
      OB_Bear_BarTimeArr[i]    = 0;
      OB_LastProcessedBarTimeArr[i] = 0;

      FVG_Bull_ActiveArr[i]    = false;
      FVG_Bull_FilledPctArr[i] = 0.0;
      FVG_Bull_BarTimeArr[i]   = 0;
      FVG_Bear_ActiveArr[i]    = false;
      FVG_Bear_FilledPctArr[i] = 0.0;
      FVG_Bear_BarTimeArr[i]   = 0;
      FVG_LastProcessedBarTimeArr[i] = 0;

      SwingHighCacheCycleArr[i] = -1;
      SwingHighCacheArr[i]      = EMPTY_VALUE;
      SwingLowCacheCycleArr[i]  = -1;
      SwingLowCacheArr[i]       = EMPTY_VALUE;
      BOS_CacheCycleArr[i]    = -1;
      BOS_CacheResultArr[i]   = false;
      LastApprovedBuyBarTimeArr[i]  = 0;
      LastApprovedSellBarTimeArr[i] = 0;
      RegimeLastStateArr[i]   = -1;
   }
}

input group "WATERMARK"

// FIX: the first version of this watermark used a hand-built 32-bit BMP
// with a real per-pixel alpha channel. In theory MT5 supports that for
// bitmap loader did not render that hand-built alpha data at all (the
// object showed up completely invisible on your chart, not just faint).
// Rather than keep chasing an unverified alpha format, the fade is now
// baked directly into a plain, standard 24-bit BMP (blended against solid
// white, since ApplyChartTheme() below fixes the chart background to
// white anyway) - this is the well-supported, guaranteed-to-render path.
// The visual result is identical to a true translucent watermark as long
// as the chart background stays white; if you ever change
// ChartThemeBackground away from white, this image would need
// re-blending against the new color to keep looking faded rather than
// showing a slightly mismatched box.
//
// Place chart_background.bmp in <Data Folder>\MQL5\Images\ before
// compiling this .mq5 (File > Open Data Folder in MT5 to find it).
//
// Sizing fits the image's native 2:3 aspect ratio (520x780) into a box
// scaled off chart height, so it's never stretched/squashed out of shape -
// only scaled and (optionally) nudged from dead-center.

input double WatermarkScalePercent = 55.0; // size of the watermark as a % of chart height, aspect-ratio preserved
input int    WatermarkOffsetX      = 0;    // pixels to shift from dead-center horizontally (+right / -left)
input int    WatermarkOffsetY      = 0;    // pixels to shift from dead-center vertically (+down / -up)

#define WATERMARK_IMG_W 520
#define WATERMARK_IMG_H 780

//+------------------------------------------------------------------+
//| Create Centered Watermark (real alpha-channel 32-bit BMP)         |
//+------------------------------------------------------------------+
void CreateChartBackground()
{
   // Watermark disabled - no BMP resource required for compile/run.
   return;
}

//======================== CHART EVENT ==============================//

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Keep the background image filling the chart if the window is resized.
   if(id == CHARTEVENT_CHART_CHANGE)
      CreateChartBackground();
}

//======================== DEINIT ===================================//

void OnDeinit(const int reason)
{
   for(int i = 0; i < ArraySize(MultiSymbolList); i++)
   {
      if(i < ArraySize(EMAHandles) && EMAHandles[i] != INVALID_HANDLE)
         IndicatorRelease(EMAHandles[i]);

      if(i < ArraySize(ADXHandles) && ADXHandles[i] != INVALID_HANDLE)
         IndicatorRelease(ADXHandles[i]);

      if(i < ArraySize(ATRHandlesArr) && ATRHandlesArr[i] != INVALID_HANDLE)
         IndicatorRelease(ATRHandlesArr[i]);

      if(i < ArraySize(FilterATRHandles) && FilterATRHandles[i] != INVALID_HANDLE)
         IndicatorRelease(FilterATRHandles[i]);

      if(i < ArraySize(HTFEMAHandlesArr) && HTFEMAHandlesArr[i] != INVALID_HANDLE)
         IndicatorRelease(HTFEMAHandlesArr[i]);

      if(i < ArraySize(RSIHandlesArr) && RSIHandlesArr[i] != INVALID_HANDLE)
         IndicatorRelease(RSIHandlesArr[i]);

      if(i < ArraySize(BBHandlesArr) && BBHandlesArr[i] != INVALID_HANDLE)
         IndicatorRelease(BBHandlesArr[i]);

      if(i < ArraySize(FastEMAHandlesArr) && FastEMAHandlesArr[i] != INVALID_HANDLE)
         IndicatorRelease(FastEMAHandlesArr[i]);

      if(i < ArraySize(SlowEMAHandlesArr) && SlowEMAHandlesArr[i] != INVALID_HANDLE)
         IndicatorRelease(SlowEMAHandlesArr[i]);
   }

   if(EnableMultiSymbolTrading)
      EventKillTimer();

    ObjectDelete(0, BG_OBJECT_NAME);
}

//======================== TRADE TRANSACTION =========================//
// Fires whenever a deal/order/position changes. Used here specifically to
// catch the moment a position belonging to this EA (matching symbol +
// magic number) actually CLOSES, so we can tell whether it was a win or
// loss - which drives both the post-loss cooldown and the trade
// statistics tracked in Part 18.

//================ SIGNAL SNAPSHOT TRACKING (loss/signal diagnosis) ===//
// FIX/UPGRADE: RecordTradeStatistic() below tracks WHETHER a trade won or
// lost, but nothing tracked WHY - which specific signals (BOS, FVG, order
// block, MTF confluence, volatility expansion...) were actually present
// when that trade opened. Without that, there's no way to tell whether a
// losing streak means "the strategy doesn't work" or "one specific signal
// keeps producing bad entries while the others are fine." This captures a
// snapshot of every signal's state at the moment of entry, then on close
// reports it alongside the win/loss result and tallies each signal's own
// win rate over time - so it becomes possible to actually see which
// signals are earning their place in the score and which aren't.
//
// In-memory only (not persisted across restart) - this is a diagnostic
// aid, not something safety-critical like TP1 tracking, so losing the
// snapshot table on a restart is an acceptable tradeoff against not
// bloating the GlobalVariable store further.

// Declared here (rather than down in Part 15's Market Regime Detection
// section, where the related input/function live) because MQL5 needs a
// type fully declared before it's used as a struct field - SignalSnapshot
// below needs MarketRegime to already exist.
enum MarketRegime
{
   REGIME_TRENDING,
   REGIME_RANGING
};

// OK70: clean live-market snapshot used by diagnostics + wait reasons
struct LiveMarketAnalysis
{
   bool     valid;
   bool     bull;
   bool     bear;
   bool     trendStrong;
   MarketRegime regime;
   bool     bosBuy;
   bool     bosSell;
   bool     zoneBuy;
   bool     zoneSell;
   bool     nearBuy;
   bool     nearSell;
   bool     dispBuy;
   bool     dispSell;
   bool     contBuyOK;
   bool     contSellOK;
   string   contBuyDetail;
   string   contSellDetail;
   string   session;
   string   sessionName;   // LONDON / NEWYORK / LONDON+NY / ASIA / OFF
   bool     inLondon;
   bool     inNewYork;
   bool     inAsia;
   bool     inOverlap;
   int      sessionHour;
   string   news;
   string   apexBuy;
   string   apexSell;
   string   bias;
   string   summary;
   datetime barTime;
};
LiveMarketAnalysis g_LiveMkt;
ulong              g_LiveMktCycle = 0;
string             g_LastSessionNameLogged = "";

struct SignalSnapshot
{
   ulong  ticket;
   bool   isBuy;
   int    score;
   int    requiredScore;
   bool   trendOK;
   bool   htfOK;
   bool   confluenceOK;
   bool   mtfConfluenceOK;
   bool   bosPresent;
   bool   chochPresent;
   bool   sweepPresent;
   bool   fvgPresent;
   bool   obPresent;
   bool   volExpanding;
   MarketRegime regime;
};

SignalSnapshot SignalSnapshots[];

// PRISM structure snapshot — MUST be declared before CapturePendingSignalSnapshot().
struct PRISMStructureSnapshot
{
   int  rec;
   bool bos;
   bool choch;
   bool sweep;
   bool ob;
   bool fvg;
   bool trend;
   bool trendStrong;
   bool htfConfirms;
};

PRISMStructureSnapshot PRISM_GetStructureSnapshot(bool buy, int recency = -1);
string PRISMGetTradeGrade(bool buy, const string strategyTag);
int CalculatePRISMScore(bool buy);
int EffectiveMinimumMPIScore();
void MarkContFallbackFillIfNeeded(); // OK64 anti-scalp fill stamp (defined near ContFallback)
void UpdateNewsAwareness(); // OK65 news know/log (no block)
void AnalyzeLiveMarket(const bool force = false); // OK70 clean market read
string LiveMarketSummary();
void PrintLiveMarketAnalysis();
bool ContStruct_HasQualityBOS(const bool buy);
bool ContStruct_GetFreshZone(const bool buy, double &zTop, double &zBot, string &kind);
bool ContStruct_PriceNearZone(const bool buy, const double zTop, const double zBot);
bool ContStruct_HasDisplacement(const bool buy);
bool ContFallbackBestStructureOK(const bool buy, string &detail); // body later (helpers still call it)

int FindSignalSnapshot(ulong ticket)
{
   for(int i = 0; i < ArraySize(SignalSnapshots); i++)
      if(SignalSnapshots[i].ticket == ticket)
         return i;
   return -1;
}

void RemoveSignalSnapshot(int index)
{
   int last = ArraySize(SignalSnapshots) - 1;

   for(int j = index; j < last; j++)
      SignalSnapshots[j] = SignalSnapshots[j + 1];

   ArrayResize(SignalSnapshots, last);
}

// Per-signal win/loss tallies - persisted (same mechanism as the aggregate
// trade stats) so "which signals actually work" survives a restart too.
double SigStat_BOS_Win=0, SigStat_BOS_Loss=0;
double SigStat_CHoCH_Win=0, SigStat_CHoCH_Loss=0;
double SigStat_Sweep_Win=0, SigStat_Sweep_Loss=0;
double SigStat_FVG_Win=0, SigStat_FVG_Loss=0;
double SigStat_OB_Win=0, SigStat_OB_Loss=0;
double SigStat_MTF_Win=0, SigStat_MTF_Loss=0;
double SigStat_VolExp_Win=0, SigStat_VolExp_Loss=0;

string SigStatsGVPrefix()
{
   return "HitmanAI_" + IntegerToString(MagicNumber) + "_SigStats_";
}

void SaveSignalStatistics()
{
   string p = SigStatsGVPrefix();
   GlobalVariableSet(p+"bos_w", SigStat_BOS_Win);   GlobalVariableSet(p+"bos_l", SigStat_BOS_Loss);
   GlobalVariableSet(p+"choch_w", SigStat_CHoCH_Win); GlobalVariableSet(p+"choch_l", SigStat_CHoCH_Loss);
   GlobalVariableSet(p+"sweep_w", SigStat_Sweep_Win); GlobalVariableSet(p+"sweep_l", SigStat_Sweep_Loss);
   GlobalVariableSet(p+"fvg_w", SigStat_FVG_Win);   GlobalVariableSet(p+"fvg_l", SigStat_FVG_Loss);
   GlobalVariableSet(p+"ob_w", SigStat_OB_Win);     GlobalVariableSet(p+"ob_l", SigStat_OB_Loss);
   GlobalVariableSet(p+"mtf_w", SigStat_MTF_Win);   GlobalVariableSet(p+"mtf_l", SigStat_MTF_Loss);
   GlobalVariableSet(p+"vol_w", SigStat_VolExp_Win);GlobalVariableSet(p+"vol_l", SigStat_VolExp_Loss);
}

void RestoreSignalStatistics()
{
   string p = SigStatsGVPrefix();
   if(!GlobalVariableCheck(p+"bos_w")) return;

   SigStat_BOS_Win=GlobalVariableGet(p+"bos_w");     SigStat_BOS_Loss=GlobalVariableGet(p+"bos_l");
   SigStat_CHoCH_Win=GlobalVariableGet(p+"choch_w"); SigStat_CHoCH_Loss=GlobalVariableGet(p+"choch_l");
   SigStat_Sweep_Win=GlobalVariableGet(p+"sweep_w"); SigStat_Sweep_Loss=GlobalVariableGet(p+"sweep_l");
   SigStat_FVG_Win=GlobalVariableGet(p+"fvg_w");     SigStat_FVG_Loss=GlobalVariableGet(p+"fvg_l");
   SigStat_OB_Win=GlobalVariableGet(p+"ob_w");       SigStat_OB_Loss=GlobalVariableGet(p+"ob_l");
   SigStat_MTF_Win=GlobalVariableGet(p+"mtf_w");     SigStat_MTF_Loss=GlobalVariableGet(p+"mtf_l");
   SigStat_VolExp_Win=GlobalVariableGet(p+"vol_w");  SigStat_VolExp_Loss=GlobalVariableGet(p+"vol_l");
}

// FIX: a signal with 1 win and 0 losses used to report as a supposedly
// meaningful "100% win rate" - statistically worthless at that sample
// size but easy to over-trust reading it off the Journal. Returns -2
// (distinct from -1's "no data yet") once there IS data but not enough of
// it to mean anything; PrintSignalPerformanceReport() below reports that
// distinctly instead of stating a number.
input int MinSignalSampleSize = 20;

double SignalWinRate(double wins, double losses)
{
   double total = wins + losses;
   if(total <= 0) return -1; // no data yet
   if(total < MinSignalSampleSize) return -2; // some data, not enough to trust yet
   return (wins/total)*100.0;
}

string FormatSignalWinRate(double r, double wins, double losses)
{
   if(r == -1) return "no data";
   if(r == -2) return "insufficient sample (" + IntegerToString((int)(wins+losses)) + "/" + IntegerToString(MinSignalSampleSize) + " needed)";
   return DoubleToString(r,1) + "% win";
}

//================ ADAPTIVE AI WEIGHTING (NEW) =========================//
// FIX/UPGRADE: SigStat_BOS_Win/Loss, SigStat_CHoCH_Win/Loss, etc. (above)
// were being tracked and printed in the signal review report, but nothing
// ever fed that information BACK into CalculateTradeScore() - a
// confirmation type that has empirically been a coin flip (or worse) on
// this instrument scored exactly the same flat weight as one that's been
// reliably right. This closes that loop: once a signal type has a large
// enough sample (MinSignalSampleSize), its score contribution is scaled by
// a multiplier derived from its actual live win rate - better than 50%
// scores above face value (up to a capped bonus), worse than 50% scores
// below face value (down to a capped discount). Before the sample is large
// enough, the multiplier is a neutral 1.0 - no distortion from noise-level
// sample sizes. This is opt-outable; with it off, scoring behaves exactly
// as before (flat weights).

input group "ADAPTIVE AI WEIGHTING"

input bool   EnableAdaptiveWeighting     = true;
input double AdaptiveWeightMinMultiplier = 0.6; // floor - even a poorly-performing confirmation still contributes something, never zeroed out entirely
input double AdaptiveWeightMaxMultiplier = 1.4; // ceiling - caps how much a strong performer can be over-weighted, so one lucky streak can't dominate the score

double SignalWeightMultiplier(double wins, double losses)
{
   if(!EnableAdaptiveWeighting)
      return 1.0;

   double winRate = SignalWinRate(wins, losses); // -1 no data, -2 insufficient sample, else 0-100

   if(winRate < 0.0)
      return 1.0; // not enough data yet - stay neutral rather than guess

   // Map win rate linearly: 50% win rate -> 1.0x (neutral), scaling toward
   // the min/max multipliers as win rate moves toward 0% or 100%.
   double normalized = (winRate - 50.0) / 50.0; // -1.0 .. +1.0
   double multiplier;

   if(normalized >= 0.0)
      multiplier = 1.0 + normalized * (AdaptiveWeightMaxMultiplier - 1.0);
   else
      multiplier = 1.0 + normalized * (1.0 - AdaptiveWeightMinMultiplier);

   return MathMax(AdaptiveWeightMinMultiplier, MathMin(AdaptiveWeightMaxMultiplier, multiplier));
}

// Called from OnTradeTransaction when a position closes. Looks up the
// snapshot captured at entry, prints a full breakdown against the actual
// result, and tallies each present signal's win/loss count.
void ReportSignalOutcome(ulong ticket, bool wasWin, double profit)
{
   int idx = FindSignalSnapshot(ticket);

   if(idx < 0)
   {
      Print("No signal snapshot for closed ticket ", ticket, " (opened before this feature, or restart occurred).");
      return;
   }

   SignalSnapshot s = SignalSnapshots[idx];

   Print("=== SIGNAL REVIEW | ticket ", ticket, " | ", wasWin ? "WIN" : "LOSS",
         " (", DoubleToString(profit,2), ") ===");
   Print("Score: ", s.score, "/", s.requiredScore, " | Regime: ", EnumToString(s.regime));
   Print("Trend:", s.trendOK, " HTF:", s.htfOK, " Confluence:", s.confluenceOK, " MTF:", s.mtfConfluenceOK);
   Print("BOS:", s.bosPresent, " CHoCH:", s.chochPresent, " Sweep:", s.sweepPresent,
         " FVG:", s.fvgPresent, " OB:", s.obPresent, " VolExpansion:", s.volExpanding);

   if(s.bosPresent)      { if(wasWin) SigStat_BOS_Win++;   else SigStat_BOS_Loss++; }
   if(s.chochPresent)    { if(wasWin) SigStat_CHoCH_Win++; else SigStat_CHoCH_Loss++; }
   if(s.sweepPresent)    { if(wasWin) SigStat_Sweep_Win++; else SigStat_Sweep_Loss++; }
   if(s.fvgPresent)      { if(wasWin) SigStat_FVG_Win++;   else SigStat_FVG_Loss++; }
   if(s.obPresent)       { if(wasWin) SigStat_OB_Win++;    else SigStat_OB_Loss++; }
   if(s.mtfConfluenceOK) { if(wasWin) SigStat_MTF_Win++;   else SigStat_MTF_Loss++; }
   if(s.volExpanding)    { if(wasWin) SigStat_VolExp_Win++;else SigStat_VolExp_Loss++; }

   SaveSignalStatistics();

   RemoveSignalSnapshot(idx);
}

//+------------------------------------------------------------------+
//|      PART 15i - PER-STRATEGY PERFORMANCE TRACKING (NEW)          |
//+------------------------------------------------------------------+
// ADDED to directly answer "strategy vs validation": you now have nine
// selectable strategies and zero real trade history behind any of them.
// This is the missing measurement layer - every closed trade is
// attributed to the SPECIFIC strategy (tag) that produced it, tracked
// and persisted separately, with the same MinSignalSampleSize gating
// already used for the BOS/CHoCH/etc signal stats above (so a strategy
// with 2 trades reports "insufficient sample," not a fake 100%/0% rate).
// This is what actually lets you tell, once you have real volume, which
// of these nine is worth keeping - rather than adding more strategies
// being mistaken for adding more evidence.

#define STRATEGY_TAG_COUNT 15
string g_StrategyTagNames[STRATEGY_TAG_COUNT] = {
   "APEX", "ContFallback", "LCS",
   "SMC", "MeanReversion", "VolBreakout", "TrendFollow",
   "TrendPullback", "LiquiditySweep", "FVG+OB", "VolBreakout(Spec)", "SpecCompliant",
   "InstantTrend", "ContSniper", "RevSniper"
};
double g_StrategyTagWins[STRATEGY_TAG_COUNT];
double g_StrategyTagLosses[STRATEGY_TAG_COUNT];

int FindStrategyTagIndex(string tag)
{
   for(int i = 0; i < STRATEGY_TAG_COUNT; i++)
      if(g_StrategyTagNames[i] == tag)
         return i;

   return -1;
}

string StrategyStatsGVPrefix()
{
   return "SniperAI_" + IntegerToString(MagicNumber) + "_StratStats_";
}

void SaveStrategyPerformance()
{
   string p = StrategyStatsGVPrefix();

   for(int i = 0; i < STRATEGY_TAG_COUNT; i++)
   {
      GlobalVariableSet(p + g_StrategyTagNames[i] + "_w", g_StrategyTagWins[i]);
      GlobalVariableSet(p + g_StrategyTagNames[i] + "_l", g_StrategyTagLosses[i]);
   }
}

void RestoreStrategyPerformance()
{
   string p = StrategyStatsGVPrefix();

   for(int i = 0; i < STRATEGY_TAG_COUNT; i++)
   {
      g_StrategyTagWins[i]   = GlobalVariableCheck(p + g_StrategyTagNames[i] + "_w") ? GlobalVariableGet(p + g_StrategyTagNames[i] + "_w") : 0.0;
      g_StrategyTagLosses[i] = GlobalVariableCheck(p + g_StrategyTagNames[i] + "_l") ? GlobalVariableGet(p + g_StrategyTagNames[i] + "_l") : 0.0;
   }
}

// Called from OnTradeTransaction right after a position closes - looks up
// which strategy produced this specific ticket (via TradeStates[], Part 6)
// and tallies the result. If the ticket's TradeState was already pruned
// or never had a tag (e.g. a position opened before this feature, or one
// restored after a restart, since strategyTag isn't currently persisted
// to disk the way TP1/TP2 prices are), it's silently skipped - a known,
// documented gap rather than attributing a result to the wrong strategy.
void RecordStrategyPerformance(ulong positionTicket, bool wasWin)
{
   int stateIdx = FindTradeState(positionTicket);

   if(stateIdx < 0)
      return;

   string tag = TradeStates[stateIdx].strategyTag;

   if(tag == "")
      return;

   int tagIdx = FindStrategyTagIndex(tag);

   if(tagIdx < 0)
      return; // unrecognized tag - shouldn't happen unless g_StrategyTagNames is out of sync with strategyTag values used elsewhere

   if(wasWin)
      g_StrategyTagWins[tagIdx]++;
   else
      g_StrategyTagLosses[tagIdx]++;

   SaveStrategyPerformance();
}

void PrintStrategyPerformanceReport()
{
   Print("==== PER-STRATEGY PERFORMANCE (FULL UPGRADE) ====");

   // Focus on live PRISM tags first
   string liveTags[3] = {"APEX", "ContFallback", "LCS"};
   for(int t = 0; t < 3; t++)
   {
      int i = FindStrategyTagIndex(liveTags[t]);
      if(i < 0) continue;
      double r = SignalWinRate(g_StrategyTagWins[i], g_StrategyTagLosses[i]);
      Print(liveTags[t], ": ", FormatSignalWinRate(r, g_StrategyTagWins[i], g_StrategyTagLosses[i]),
            " (", (int)g_StrategyTagWins[i], "W/", (int)g_StrategyTagLosses[i], "L)",
            " rankBase=", PathBasePriority(liveTags[t]));
   }

   Print("=================================================");
}

// Prints a full per-signal win-rate breakdown on demand (e.g. call from
// DebugSignals(), or manually via script) so it's easy to see at a glance
// which signals are actually correlating with wins over time.
void PrintSignalPerformanceReport()
{
   Print("==== SIGNAL PERFORMANCE (all-time) ====");

   double r;

   r = SignalWinRate(SigStat_BOS_Win, SigStat_BOS_Loss);
   Print("BOS: ", FormatSignalWinRate(r, SigStat_BOS_Win, SigStat_BOS_Loss), " (", (int)SigStat_BOS_Win, "W/", (int)SigStat_BOS_Loss, "L)");

   r = SignalWinRate(SigStat_CHoCH_Win, SigStat_CHoCH_Loss);
   Print("CHoCH: ", FormatSignalWinRate(r, SigStat_CHoCH_Win, SigStat_CHoCH_Loss), " (", (int)SigStat_CHoCH_Win, "W/", (int)SigStat_CHoCH_Loss, "L)");

   r = SignalWinRate(SigStat_Sweep_Win, SigStat_Sweep_Loss);
   Print("Liquidity Sweep: ", FormatSignalWinRate(r, SigStat_Sweep_Win, SigStat_Sweep_Loss), " (", (int)SigStat_Sweep_Win, "W/", (int)SigStat_Sweep_Loss, "L)");

   r = SignalWinRate(SigStat_FVG_Win, SigStat_FVG_Loss);
   Print("FVG: ", FormatSignalWinRate(r, SigStat_FVG_Win, SigStat_FVG_Loss), " (", (int)SigStat_FVG_Win, "W/", (int)SigStat_FVG_Loss, "L)");

   r = SignalWinRate(SigStat_OB_Win, SigStat_OB_Loss);
   Print("Order Block: ", FormatSignalWinRate(r, SigStat_OB_Win, SigStat_OB_Loss), " (", (int)SigStat_OB_Win, "W/", (int)SigStat_OB_Loss, "L)");

   r = SignalWinRate(SigStat_MTF_Win, SigStat_MTF_Loss);
   Print("MTF Confluence: ", FormatSignalWinRate(r, SigStat_MTF_Win, SigStat_MTF_Loss), " (", (int)SigStat_MTF_Win, "W/", (int)SigStat_MTF_Loss, "L)");

   r = SignalWinRate(SigStat_VolExp_Win, SigStat_VolExp_Loss);
   Print("Vol Expansion: ", FormatSignalWinRate(r, SigStat_VolExp_Win, SigStat_VolExp_Loss), " (", (int)SigStat_VolExp_Win, "W/", (int)SigStat_VolExp_Loss, "L)");

   Print("========================================");

   PrintStrategyPerformanceReport();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   long dealMagic  = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   string dealSym  = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   long dealEntry  = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

   if(dealMagic != MagicNumber)
      return;

   // FIX: this used to compare dealSym against the global BrokerSymbol -
   // which in multi-symbol mode is whatever symbol the last trading-cycle
   // iteration happened to leave it as, not necessarily the symbol this
   // deal actually belongs to. Look up the deal's own symbol directly
   // instead, so loss tracking updates the correct symbol's slot
   // regardless of what BrokerSymbol currently points to.
   int dealSymIdx = GetSymbolIndex(dealSym);

   if(dealSymIdx < 0)
      return; // deal belongs to a symbol this EA instance isn't tracking

   // DEAL_ENTRY_OUT (or OUT_BY) means this deal closed some or all of a
   // position - that's the only case relevant to win/loss tracking. Entry
   // deals (DEAL_ENTRY_IN) are trade opens, not closes.
   if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY)
      return;

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                  + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                  + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(profit < 0)
   {
      LastTradeWasLossArr[dealSymIdx]  = true;
      LastLossCloseTimeArr[dealSymIdx] = TimeCurrent();
      Print("Trade closed at a loss on ", dealSym, " (", DoubleToString(profit,2), ") - post-loss cooldown engaged.");
   }
   else
   {
      LastTradeWasLossArr[dealSymIdx] = false;
   }

   // FIX: GetEffectiveMinimumScore() (Part 15) used to read the single
   // GLOBAL Stat_ConsecutiveLosses counter - meaning a losing streak on
   // BTCUSD raised the score bar for EURUSD signals too, and vice versa,
   // even though the two have nothing to do with each other. Tracked
   // per-symbol here (index-matched to MultiSymbolList like everything
   // else per-symbol in this file) so each symbol's adaptive scoring
   // penalty only reacts to that symbol's own recent results.
   if(dealSymIdx < ArraySize(ConsecutiveLossesPerSymbolArr))
   {
      if(profit < 0)
      {
         ConsecutiveLossesPerSymbolArr[dealSymIdx]++;
         ConsecutiveWinsPerSymbolArr[dealSymIdx] = 0;
      }
      else
      {
         ConsecutiveWinsPerSymbolArr[dealSymIdx]++;
         ConsecutiveLossesPerSymbolArr[dealSymIdx] = 0;
      }
   }

   RecordTradeStatistic(profit);
   ReportSignalOutcome(trans.position, profit >= 0, profit);
   RecordStrategyPerformance(trans.position, profit >= 0);
}

// FIX: EventSetTimer() was being called in OnInit whenever
// EnableMultiSymbolTrading was on, but no OnTimer() existed anywhere to
// catch those events - and OnTick() never looped over MultiSymbolList
// either. The result: turning on multi-symbol trading built all the
// per-symbol indicator handles and tracking arrays, but never actually
// evaluated or traded any symbol beyond the chart's own. This is what
// actually makes it work: RunTradingCycle() runs the full
// manage-then-evaluate sequence for one symbol; OnTick() drives the
// primary/chart symbol in real time (as it always did); OnTimer() drives
// every OTHER symbol in MultiSymbolList on a schedule, since MT5 only
// delivers OnTick() for the symbol the chart is actually showing - there's
// no way to get real-time ticks for a symbol nothing is charting.

void RunTradingCycle(string symbol)
{
   // HARDEN: never manage/execute on an empty symbol handle
   if(symbol == NULL || StringLen(symbol) == 0)
      return;

   BrokerSymbol = symbol;

   ManageOpenTrades();

   if(TradingAllowed)
      InstantExecution();
}

void OnTimer()
{
   if(!EnableMultiSymbolTrading)
      return;

   for(int i = 0; i < ArraySize(MultiSymbolList); i++)
   {
      if(MultiSymbolList[i] == PrimarySymbol)
         continue; // already handled every tick by OnTick() below

      RunTradingCycle(MultiSymbolList[i]);
   }

   BrokerSymbol = PrimarySymbol; // restore before the dashboard next reads it
}

void OnTick()
{
   RunTradingCycle(PrimarySymbol);

   UpdateDashboard();
}
//+------------------------------------------------------------------+
//|                 Sniper AI - Part 2                       |
//|                    Indicator Engine                              |
//+------------------------------------------------------------------+

//======================== INDICATOR INPUTS =========================//

input group "INDICATORS"

input int EMA_Period = 200;
input int ADX_Period = 14;
input int ATR_Period = 14;

input double ADX_Minimum = 18.0; // aggressive sniper: strong enough trend, not ultra-strict 25

input group "SIGNAL STABILITY"

// FIX: GetEMA()/GetADX()/GetATR() used to read buffer index 0, which is
// the CURRENTLY FORMING bar - its EMA/ADX value keeps changing tick to
// tick until that bar actually closes. That meant TrendBullish/Bearish
// (and everything built on top of them: StrongBuySetup, StrongSellSetup,
// the dashboard, trend-exit) could flip its answer mid-bar and "repaint" -
// the same live signal could read differently a few seconds apart with no
// new closed data, purely because the forming candle moved. With this on,
// every trend/strength read used for decisions comes from the last fully
// CLOSED bar (index 1) instead - the same principle already applied to
// GetRecentHigh()/GetRecentLow()'s confirmed-swing logic. Off reverts to
// the original (faster-reacting but repaint-prone) behavior.
input bool UseClosedBarConfirmation = false; // CHANGED per request for instant execution: false = evaluate off the live/forming bar (index 0) instead of waiting for it to close (index 1), combined with EnableTickLevelSignalDetection (already on by default) so every tick gets a fresh read. Tradeoff: a signal can appear and then disappear again before that bar actually closes, since it's reading unfinished price action - this is normal for "instant" reaction, not a bug.

int SignalBarIndex()
{
   return UseClosedBarConfirmation ? 1 : 0;
}

//======================== INDICATOR CACHE (perf) ====================//
// FIX: GetEMA(), GetADX(), and GetATR() each independently called
// UpdateIndicators(), which does 3 CopyBuffer() calls - so a single
// decision path (e.g. TrendBullish() -> GetEMA() -> GetEMASlope() ->
// TrendStrong() -> GetADX()) could trigger the same CopyBuffer() work
// several times over for the same symbol on the same tick. This caches
// the result per (symbol, trading cycle) - g_CycleCounter increments once
// per RunTradingCycle() call (Part 1), so every read within that same
// cycle for that symbol reuses the already-copied buffers instead of
// re-fetching identical data from the terminal.
ulong g_CycleCounter = 0;
long  IndicatorCacheCycleArr[];

//======================== INITIALIZE ===============================//

bool InitializeIndicators()
{
   // UPGRADE: creates one full set of indicator handles PER SYMBOL in
   // MultiSymbolList, not just for BrokerSymbol. In single-symbol mode
   // (EnableMultiSymbolTrading = false) MultiSymbolList only contains the
   // chart's own symbol, so this loop runs once and behaves exactly like
   // the original single-handle version did.

   ArrayResize(IndicatorCacheCycleArr, ArraySize(MultiSymbolList));

   for(int i = 0; i < ArraySize(MultiSymbolList); i++)
   {
      IndicatorCacheCycleArr[i] = -1;

      string sym = MultiSymbolList[i];

      EMAHandles[i] = iMA(sym, TrendTF, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

      if(EMAHandles[i] == INVALID_HANDLE)
      {
         Print("Failed to create EMA Handle for ", sym);
         return false;
      }

      ADXHandles[i] = iADX(sym, TrendTF, ADX_Period);

      if(ADXHandles[i] == INVALID_HANDLE)
      {
         Print("Failed to create ADX Handle for ", sym);
         return false;
      }

      ATRHandlesArr[i] = iATR(sym, EntryTF, ATR_Period);

      if(ATRHandlesArr[i] == INVALID_HANDLE)
      {
         Print("Failed to create ATR Handle for ", sym);
         return false;
      }

      HTFEMAHandlesArr[i] = iMA(sym, HigherTimeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

      if(HTFEMAHandlesArr[i] == INVALID_HANDLE)
      {
         Print("Failed to create HTF EMA Handle for ", sym);
         return false;
      }

      // RSI removed from PRISM stack (user request) — no iRSI handle.
      // Dead mean-reversion helpers can still read BB; GetRSI() returns empty.
      RSIHandlesArr[i] = INVALID_HANDLE;
      // OK91: DELETED old indicators — BB / FastEMA / SlowEMA no longer created.
      // Signal path uses PRIME price-action engines (structure/liq/ICT/Fib/vol).
      BBHandlesArr[i] = INVALID_HANDLE;
      FastEMAHandlesArr[i] = INVALID_HANDLE;
      SlowEMAHandlesArr[i] = INVALID_HANDLE;
   }

   ArraySetAsSeries(EMABuffer, true);
   ArraySetAsSeries(ADXBuffer, true);
   ArraySetAsSeries(ATRBuffer, true);
   ArraySetAsSeries(HTF_EMABuffer, true);

   Print("Indicators initialized successfully for ", ArraySize(MultiSymbolList), " symbol(s).");

   return true;
}

//======================== UPDATE ==================================//

bool UpdateIndicators()
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0)
   {
      Print("Indicator lookup failed - symbol not in MultiSymbolList: ", BrokerSymbol);
      return false;
   }

   // Cache hit - already refreshed this trading cycle for this symbol.
   if(idx < ArraySize(IndicatorCacheCycleArr) && IndicatorCacheCycleArr[idx] == (long)g_CycleCounter)
      return true;

   // FIX: previously a handle going INVALID_HANDLE at runtime (e.g. a
   // symbol briefly dropped and re-added, or a terminal hiccup) meant this
   // symbol was silently dead until the EA was manually removed and
   // re-attached - Print() and return false, forever. This attempts a
   // one-time recreation of any invalid handle for this symbol before
   // giving up, so a transient handle loss can self-heal instead of
   // requiring manual intervention.
   if(EMAHandles[idx] == INVALID_HANDLE)
      EMAHandles[idx] = iMA(BrokerSymbol, TrendTF, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);

   if(ADXHandles[idx] == INVALID_HANDLE)
      ADXHandles[idx] = iADX(BrokerSymbol, TrendTF, ADX_Period);

   if(ATRHandlesArr[idx] == INVALID_HANDLE)
      ATRHandlesArr[idx] = iATR(BrokerSymbol, EntryTF, ATR_Period);

   if(EMAHandles[idx] == INVALID_HANDLE ||
      ADXHandles[idx] == INVALID_HANDLE ||
      ATRHandlesArr[idx] == INVALID_HANDLE)
   {
      Print("Indicator handle invalid for ", BrokerSymbol, " and could not be recreated.");
      return false;
   }

   // Wait until enough bars are loaded
   if(Bars(BrokerSymbol, TrendTF) < EMA_Period + 10)
      return false;

   if(Bars(BrokerSymbol, EntryTF) < ATR_Period + 10)
      return false;

   // FIX: Bars() only reports how many candles exist in the terminal's
   // history for that timeframe - it says nothing about whether the
   // indicator itself has actually finished calculating over them yet
   // (e.g. right after a handle is (re)created, or during a fast history
   // backfill). BarsCalculated() is the real readiness signal; without
   // this, CopyBuffer() succeeding could still be reading from an
   // indicator that hasn't caught up to all the requested bars.
   if(BarsCalculated(EMAHandles[idx]) < 4 || BarsCalculated(ADXHandles[idx]) < 4 ||
      BarsCalculated(ATRHandlesArr[idx]) < 4)
      return false;

   ResetLastError();

   // 4 bars fetched (not 3): index 0 = forming bar, index 1 = last closed
   // bar (what SignalBarIndex() points decisions at by default), index 3
   // used by the slope calc below as "2 closed bars back" from index 1.
   if(CopyBuffer(EMAHandles[idx],0,0,4,EMABuffer) < 4)
   {
      Print("EMA CopyBuffer Error: ",GetLastError());
      return false;
   }

   if(CopyBuffer(ADXHandles[idx],0,0,4,ADXBuffer) < 4)
   {
      Print("ADX CopyBuffer Error: ",GetLastError());
      return false;
   }

   if(CopyBuffer(ATRHandlesArr[idx],0,0,4,ATRBuffer) < 4)
   {
      Print("ATR CopyBuffer Error: ",GetLastError());
      return false;
   }

   IndicatorCacheCycleArr[idx] = (long)g_CycleCounter;

   return true;
}

//======================== HELPERS =================================//

double GetEMA()
{
   if(!UpdateIndicators())
      return EMPTY_VALUE;

   return EMABuffer[SignalBarIndex()];
}


double GetADX()
{
   if(!UpdateIndicators())
      return EMPTY_VALUE;

   return ADXBuffer[SignalBarIndex()];
}


double GetATR()
{
   if(!UpdateIndicators())
      return 0.0;

   double v = ATRBuffer[SignalBarIndex()];
   // HARDEN: EMPTY_VALUE is >0 and would inflate stops/trails — treat as unavailable
   if(!MathIsValidNumber(v) || v == EMPTY_VALUE || v <= 0.0)
      return 0.0;
   return v;
}


// FIX/UPGRADE - SMARTER TREND DETECTION: price above the EMA doesn't
// necessarily mean an uptrend - price can sit above a flat or even
// slightly declining EMA during chop, which used to count as "bullish"
// just as confidently as a genuine trending move. This adds a slope
// check: the EMA itself has to actually be rising (comparing its current
// value against a few bars back, reusing the buffer already copied by
// UpdateIndicators) for the trend to count as bullish, and falling for
// bearish. Off by default is not an option here since it's a correctness
// improvement, but it's still togglable in case the extra requirement
// ever needs to be disabled for testing.

input bool EnableSmarterTrendDetection = false; // CHANGED per request: this added a second, stricter AND-condition on top of price-vs-EMA (EMA slope also had to agree), which was quietly stacking with the score/confluence gates below to block valid setups. false = trend is just price vs EMA again.

double GetEMASlope()
{
   if(!UpdateIndicators())
      return 0.0;

   // Compares SignalBarIndex() (last closed bar by default) against 2
   // bars further back - a short, responsive, non-repainting slope
   // reading without needing a separate indicator or buffer.
   int b = SignalBarIndex();
   return EMABuffer[b] - EMABuffer[b + 2];
}

bool TrendBullish()
{
   double ema = GetEMA();

   if(ema == EMPTY_VALUE)
      return false;

   bool priceAboveEMA = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID) > ema;

   if(!EnableSmarterTrendDetection)
      return priceAboveEMA;

   return priceAboveEMA && (GetEMASlope() > 0.0);
}


bool TrendBearish()
{
   double ema = GetEMA();

   if(ema == EMPTY_VALUE)
      return false;

   bool priceBelowEMA = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID) < ema;

   if(!EnableSmarterTrendDetection)
      return priceBelowEMA;

   return priceBelowEMA && (GetEMASlope() < 0.0);
}


bool TrendStrong()
{
   if(!UseADX)
      return true;

   return GetADX() >= ADX_Minimum;
}


//======================== HTF TREND ================================//

double GetHTF_EMA()
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0 || HTFEMAHandlesArr[idx] == INVALID_HANDLE)
      return EMPTY_VALUE;

   // FIX: was CopyBuffer(...,0,1,HTF_EMABuffer) reading only index 0 - the
   // currently forming HIGHER TIMEFRAME bar. On, say, H4 confirmation for
   // an M15 entry timeframe, that forming H4 bar's EMA can still be
   // changing for hours, so HTF confirmation could silently flip well
   // after a trade was already opened based on it. Now fetches 2 bars and
   // uses SignalBarIndex() the same way GetEMA() does, so HTF confirmation
   // is anchored to the last CLOSED H4 bar by default.
   int need = SignalBarIndex() + 1;

   if(CopyBuffer(HTFEMAHandlesArr[idx], 0, 0, need, HTF_EMABuffer) < need)
      return EMPTY_VALUE;

   return HTF_EMABuffer[SignalBarIndex()];
}

// FIX: HTFTrendBullish()/HTFTrendBearish() used to both return TRUE when
// HTF data wasn't ready - meaning a missing/not-yet-loaded HTF read could
// approve EITHER direction with no real confirmation behind it at all
// (the opposite of what "confirmation" is supposed to guarantee). Default
// behavior now fails CLOSED (blocks the trade) when HTF data isn't ready;
// HTFFailSafeAllowsTrade lets you restore the old fail-open behavior if
// you'd rather not wait on HTF data during startup/history loading.
input bool HTFFailSafeAllowsTrade = false;

bool HTFTrendBullish()
{
   double htfEma = GetHTF_EMA();

   if(htfEma == EMPTY_VALUE)
      return HTFFailSafeAllowsTrade;

   return SymbolInfoDouble(BrokerSymbol, SYMBOL_BID) > htfEma;
}

bool HTFTrendBearish()
{
   double htfEma = GetHTF_EMA();

   if(htfEma == EMPTY_VALUE)
      return HTFFailSafeAllowsTrade;

   return SymbolInfoDouble(BrokerSymbol, SYMBOL_BID) < htfEma;
}

bool HTFConfirms(bool buy)
{
   if(!EnableHTFConfirmation)
      return true;

   return buy ? HTFTrendBullish() : HTFTrendBearish();
}
//+------------------------------------------------------------------+
//|                 Sniper AI - Part 3                       |
//|                     Market Scanner                               |
//+------------------------------------------------------------------+

//====================== BROKER SYMBOL ==============================//

string DetectBrokerSymbol(string symbol)
{
   if(SymbolSelect(symbol,true))
      return(symbol);

   return(_Symbol);
}

//====================== TREND =====================================//

bool IsBullTrend()
{
   if(!UseEMA)
      return(true);

   return(TrendBullish());
}

bool IsBearTrend()
{
   if(!UseEMA)
      return(true);

   return(TrendBearish());
}

//+------------------------------------------------------------------+
//|                 Sniper AI - Part 4                       |
//|              Decision Tree & Score Engine                        |
//+------------------------------------------------------------------+

// NOTE: An earlier, simpler scoring system (ScoreTrend/ScoreADX/ScoreATR/
// ScoreSpread/ScoreMarket -> CalculateScore -> BuySignal/SellSignal) used
// to live here. It was never called by anything in the execution path -
// StrongBuySetup()/StrongSellSetup() (Part 15) is the scoring system that
// actually gates trades - so the dead duplicate has been removed.
//+------------------------------------------------------------------+
//|                 Sniper AI - Part 5                       |
//|                     Professional Risk Engine                     |
//+------------------------------------------------------------------+

input group "RISK ENGINE"

// ALLTRADE56: period-loss shields OFF by default (same philosophy as drawdown OFF).
// Turn any Enable* back on if you want hard stops after a bad day/week/month.
input bool   EnableDailyLossProtection = false; // OFF: was hard-blocking all symbols after 5% day
input double MaxDailyLossPercent = 5.0;
input double MaxDrawdownPercent  = 20.0;

//=============================================================//
// Peak-Equity Drawdown (FIX - real high-water-mark tracking)
//=============================================================//
// FIX: the old GetCurrentDrawdown() compared current BALANCE against
// current EQUITY - that's a snapshot of open floating P/L, not drawdown.
// A profitable account can absolutely have a genuine 15% peak-to-trough
// drawdown along the way while this old calculation reads 0%, because
// balance itself only moves when a trade closes - it was structurally
// incapable of seeing the thing "max drawdown protection" is supposed to
// protect against. This tracks the account's actual highest-ever equity
// (persisted via GlobalVariable so a restart doesn't forget it and quietly
// re-arm protection at whatever the current balance happens to be) and
// measures drawdown from THAT peak, which is what "max drawdown" means
// everywhere outside this file too.

string PeakEquityGVName()
{
   return "HitmanAI_" + IntegerToString(MagicNumber) + "_PeakEquity";
}

double GetPeakEquity()
{
   string key = PeakEquityGVName();
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MathIsValidNumber(currentEquity) || currentEquity <= 0.0)
      return 0.0;

   if(!GlobalVariableCheck(key))
   {
      GlobalVariableSet(key, currentEquity);
      return currentEquity;
   }

   double peak = GlobalVariableGet(key);
   if(!MathIsValidNumber(peak) || peak <= 0.0)
   {
      peak = currentEquity;
      GlobalVariableSet(key, peak);
      return peak;
   }

   if(currentEquity > peak)
   {
      peak = currentEquity;
      GlobalVariableSet(key, peak);
   }

   return peak;
}

double GetCurrentDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double peak   = GetPeakEquity();

   if(peak <= 0.0)
      return 0.0;

   double dd = ((peak - equity) / peak) * 100.0;

   return (dd > 0.0) ? dd : 0.0;
}

//=============================================================//
// Drawdown Protection
//=============================================================//

// TRADEUNBLOCK (OK53): drawdown protection is OFF by default.
// Live Journals showed PeakEquity GV stuck (~50%+ DD vs MaxDrawdownPercent=20)
// which hard-blocked ALL new entries via RiskManagementOK → DrawdownProtection.
// With shield off, this EA will not halt new entries or emergency-flat on peak DD.
// MaxDailyLossPercent / weekly / monthly (separate inputs) still apply unless disabled.
// Set EnableDrawdownProtection=true if you want the peak-equity safety net again.
// ResetPeakEquityOnInit=true clears the stuck GV on attach so re-enabling starts clean.

input bool EnableDrawdownProtection = false;  // OFF: was blocking all entries when PeakEquity stuck

input bool EnableEmergencyCloseOnDrawdown = true;

// Clear HitmanAI_<Magic>_PeakEquity on every OnInit and seed from current equity.
// Needed when shield is re-enabled after a deep drawdown so trading is not permanently dead.
input bool ResetPeakEquityOnInit = true;  // TRADEUNBLOCK: wipe stuck peak equity GV on attach

bool DrawdownEmergencyCloseTriggered = false;

// After emergency close, no new trade for MaxDrawdownCooldownMinutes
// regardless of how quickly equity recovers. Position management unaffected.
// (Only relevant if EnableDrawdownProtection is turned back on.)
input int MaxDrawdownCooldownMinutes = 5;

datetime DrawdownEmergencyCloseTime = 0;
datetime g_LastDrawdownBlockPrint = 0;

void ResetPeakEquityToCurrent()
{
   string key = PeakEquityGVName();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MathIsValidNumber(equity) || equity <= 0.0)
      return;

   double oldPeak = 0.0;
   if(GlobalVariableCheck(key))
      oldPeak = GlobalVariableGet(key);

   GlobalVariableSet(key, equity);
   Print("TRADEUNBLOCK: PeakEquity reset ", DoubleToString(oldPeak, 2),
         " → ", DoubleToString(equity, 2), " (GV ", key, ")");
}

bool DrawdownProtection()
{
   if(!EnableDrawdownProtection)
      return true;

   double dd = GetCurrentDrawdown();

   if(dd >= MaxDrawdownPercent)
   {
      // Rate-limit: one print per 60s (was flooding Experts every FinalTradeCheck)
      if(TimeCurrent() - g_LastDrawdownBlockPrint >= 60)
      {
         g_LastDrawdownBlockPrint = TimeCurrent();
         Print("Trading blocked: Max drawdown from peak equity reached (", DoubleToString(dd,2),
               "%). Fix: Inputs → EnableDrawdownProtection=false OR ResetPeakEquityOnInit=true + re-attach.");
      }

      if(EnableEmergencyCloseOnDrawdown && !DrawdownEmergencyCloseTriggered)
      {
         Print("Max drawdown breached for the first time - closing all open positions for this EA.");
         CloseAllEAPositions();
         DrawdownEmergencyCloseTriggered = true;
         DrawdownEmergencyCloseTime = TimeCurrent();
      }

      return false;
   }

   // Mandatory cooldown after the emergency close, independent of how
   // quickly equity recovers above the re-arm threshold below.
   if(DrawdownEmergencyCloseTriggered && DrawdownEmergencyCloseTime > 0)
   {
      if(TimeCurrent() - DrawdownEmergencyCloseTime < MaxDrawdownCooldownMinutes * 60)
      {
         if(EnableVerboseLogging)
            Print("Trading blocked: post-drawdown cooldown active (", MaxDrawdownCooldownMinutes, " min).");
         return false;
      }
   }

   // Re-arm once drawdown has recovered comfortably below the limit AND
   // the mandatory cooldown above has elapsed, so a later, genuinely new
   // breach can trigger the emergency close again instead of it being a
   // one-time-ever event for the life of the chart.
   if(DrawdownEmergencyCloseTriggered && dd < MaxDrawdownPercent * 0.5)
      DrawdownEmergencyCloseTriggered = false;

   return true;
}

//=============================================================//
// Daily Loss Protection (real - tracks the day's opening balance)
//=============================================================//

void UpdateDailyReferenceBalance()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   now.hour = 0;
   now.min  = 0;
   now.sec  = 0;

   datetime today = StructToTime(now);

   if(today != DailyTrackedDay)
   {
      DailyTrackedDay   = today;
      DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      DailyLossCloseTriggered = false; // new day - re-arm the emergency close for the new session
   }
}

// FIX - THIS IS THE ACTUAL PROBLEM BEHIND THE 18%+ DAILY LOSS SEEN IN
// TESTING: DailyLossProtection() below only ever blocked NEW trades once
// the limit was hit. It never touched positions that were ALREADY open -
// so once the 5% threshold was crossed, new entries stopped, but existing
// open positions kept losing on their own with nothing stopping them,
// dragging the account down to 18%+ before those positions individually
// hit their own stops. A "daily loss limit" that only stops new trades
// isn't actually a loss limit - it's just a new-trade filter. This adds a
// real emergency close: the first time the limit is breached each day,
// every open position belonging to this EA gets closed immediately.

input bool EnableEmergencyCloseOnDailyLoss = true;

bool DailyLossCloseTriggered = false;

void CloseAllEAPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      if(trade.PositionClose(ticket))
         Print("Emergency close: closed ticket ", ticket);
      else
         Print("Emergency close FAILED on ticket ", ticket, ": ", trade.ResultRetcodeDescription());
   }
}

bool DailyLossProtection()
{
   if(!EnableDailyLossProtection || MaxDailyLossPercent <= 0.0)
      return true;

   UpdateDailyReferenceBalance();

   if(DailyStartBalance <= 0.0)
      return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   double dailyLossPercent = ((DailyStartBalance - equity) / DailyStartBalance) * 100.0;

   if(dailyLossPercent >= MaxDailyLossPercent)
   {
      Print("Trading blocked: Daily loss limit reached (", DoubleToString(dailyLossPercent,2), "%)");

      if(EnableEmergencyCloseOnDailyLoss && !DailyLossCloseTriggered)
      {
         Print("Daily loss limit breached for the first time today - closing all open positions for this EA.");
         CloseAllEAPositions();
         DailyLossCloseTriggered = true;
      }

      return false;
   }

   return true;
}

//=============================================================//
// Weekly / Monthly Loss Protection
// (same pattern as Daily Loss Protection above - reference balance
// stamped at the start of the period, emergency close via the shared
// CloseAllEAPositions() the first time the limit is breached each
// period, re-armed automatically when a new period starts. No separate
// engine - this reuses the exact same mechanism as the daily check.)
//=============================================================//

input bool   EnableWeeklyLossProtection        = false; // ALLTRADE56: OFF
input double MaxWeeklyLossPercent              = 10.0;
input bool   EnableEmergencyCloseOnWeeklyLoss  = true;

input bool   EnableMonthlyLossProtection       = false; // ALLTRADE56: OFF
input double MaxMonthlyLossPercent             = 15.0;
input bool   EnableEmergencyCloseOnMonthlyLoss = true;

bool WeeklyLossCloseTriggered  = false;
bool MonthlyLossCloseTriggered = false;

// Monday 00:00 (broker time) of the current week.
void UpdateWeeklyReferenceBalance()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   now.hour = 0;
   now.min  = 0;
   now.sec  = 0;

   datetime today = StructToTime(now);

   // day_of_week: 0=Sunday...6=Saturday. Treat Monday as the start of the
   // week regardless of which day the EA happens to (re)start on.
   int daysSinceMonday = (now.day_of_week == 0) ? 6 : (now.day_of_week - 1);

   datetime weekStart = today - (datetime)(daysSinceMonday * 86400);

   if(weekStart != WeeklyTrackedWeekStart)
   {
      WeeklyTrackedWeekStart  = weekStart;
      WeeklyStartBalance      = AccountInfoDouble(ACCOUNT_BALANCE);
      WeeklyLossCloseTriggered = false; // new week - re-arm
   }
}

void UpdateMonthlyReferenceBalance()
{
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   now.day  = 1;
   now.hour = 0;
   now.min  = 0;
   now.sec  = 0;

   datetime monthStart = StructToTime(now);

   if(monthStart != MonthlyTrackedMonthStart)
   {
      MonthlyTrackedMonthStart  = monthStart;
      MonthlyStartBalance       = AccountInfoDouble(ACCOUNT_BALANCE);
      MonthlyLossCloseTriggered = false; // new month - re-arm
   }
}

bool WeeklyLossProtection()
{
   if(!EnableWeeklyLossProtection || MaxWeeklyLossPercent <= 0.0)
      return true;

   UpdateWeeklyReferenceBalance();

   if(WeeklyStartBalance <= 0.0)
      return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   double weeklyLossPercent = ((WeeklyStartBalance - equity) / WeeklyStartBalance) * 100.0;

   if(weeklyLossPercent >= MaxWeeklyLossPercent)
   {
      Print("Trading blocked: Weekly loss limit reached (", DoubleToString(weeklyLossPercent,2), "%)");

      if(EnableEmergencyCloseOnWeeklyLoss && !WeeklyLossCloseTriggered)
      {
         Print("Weekly loss limit breached for the first time this week - closing all open positions for this EA.");
         CloseAllEAPositions();
         WeeklyLossCloseTriggered = true;
      }

      return false;
   }

   return true;
}

bool MonthlyLossProtection()
{
   if(!EnableMonthlyLossProtection || MaxMonthlyLossPercent <= 0.0)
      return true;

   UpdateMonthlyReferenceBalance();

   if(MonthlyStartBalance <= 0.0)
      return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   double monthlyLossPercent = ((MonthlyStartBalance - equity) / MonthlyStartBalance) * 100.0;

   if(monthlyLossPercent >= MaxMonthlyLossPercent)
   {
      Print("Trading blocked: Monthly loss limit reached (", DoubleToString(monthlyLossPercent,2), "%)");

      if(EnableEmergencyCloseOnMonthlyLoss && !MonthlyLossCloseTriggered)
      {
         Print("Monthly loss limit breached for the first time this month - closing all open positions for this EA.");
         CloseAllEAPositions();
         MonthlyLossCloseTriggered = true;
      }

      return false;
   }

   return true;
}

//=============================================================//
// Maximum Trades
// (uses CountOpenTrades() from Part 9 - one counting function,
//  not two slightly-different duplicates)
//=============================================================//

bool MaxTradesProtection()
{
   // OPENCAPS47: adjustable — EnforceOpenTradeCaps=false or MaxOpenTrades=0 → unlimited
   if(!EnforceOpenTradeCaps || MaxOpenTrades <= 0)
      return true;

   int openNow = CountOpenTrades();
   if(openNow >= MaxOpenTrades)
   {
      if(EnableVerboseLogging)
         Print("Trading blocked: per-symbol open cap (", openNow, "/", MaxOpenTrades,
               ") on ", BrokerSymbol);
      return false;
   }
   return true;
}

//=============================================================//
// Portfolio-wide exposure caps (NEW)
//=============================================================//
// FIX: MaxOpenTrades only ever capped trades on the CURRENT symbol - in
// multi-symbol mode, that means 3 trades on EURUSD, 3 on GBPUSD, 3 on
// XAUUSD, etc. simultaneously, with no account-wide ceiling at all, and no
// awareness that EURUSD+GBPUSD+USDJPY all carry correlated USD exposure.
// This adds two portfolio-level checks on top of (not instead of) the
// existing per-symbol cap: a hard cap on total EA positions across every
// symbol, and a cap on how many open positions can share the same
// currency (either side of the pair) - catching the "three different
// pairs, one hidden USD bet" case that a pure trade-count limit misses.

// PORTFOLIO RISK helpers — caps live in "OPEN TRADES CAPS" Inputs (top).
// MaxOpenTrades / MaxTotalOpenTradesAllSymbols / MaxOpenTradesPerCurrency
// are adjustable there (0 = unlimited). EnforceOpenTradeCaps is the master.

int CountTotalOpenTradesAllSymbols()
{
   int total = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetDouble(POSITION_VOLUME) <= IgnoreTradesAboveLots)
      {
         total++;
      }
   }

   return total;
}

// Counts how many currently-open EA positions share a currency with the
// CANDIDATE symbol (BrokerSymbol) - both the base and quote 3-letter code
// are checked against every open position's own symbol, so EURUSD and
// USDJPY both count toward "USD exposure" even though neither is USDUSD.
// Extracted from IsNonScalpSymbol() so the same keyword check can be run
// against ANY symbol (e.g. a position's own symbol), not just the current
// BrokerSymbol. IsNonScalpSymbol() below is now a thin wrapper over this.
bool SymbolMatchesNonScalpKeywords(string symbol)
{
   string keywords[];
   int count = StringSplit(NonScalpSymbolKeywords, ',', keywords);

   string symUpper = symbol;
   StringToUpper(symUpper);

   for(int i = 0; i < count; i++)
   {
      string keyword = keywords[i];
      StringTrimLeft(keyword);
      StringTrimRight(keyword);
      StringToUpper(keyword);

      if(keyword == "")
         continue;

      if(StringFind(symUpper, keyword) >= 0)
         return true;
   }

   return false;
}

int CountOpenTradesSharingCurrency(string candidateSymbol)
{
   // FIX: BTCUSD's quote currency is "USD" - textually identical to every
   // USD-quoted forex pair (EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD) and
   // XAUUSD. If crypto positions (matched by NonScalpSymbolKeywords, e.g.
   // BTC/ETH) already occupy their own per-symbol trade slots, this cap
   // was counting THOSE as "USD exposure" too - meaning a few open BTCUSD
   // trades could fill up MaxOpenTradesPerCurrency and silently block
   // every forex pair from ever opening, since they all share that same
   // USD bucket with something that isn't actually the same kind of macro
   // USD exposure a forex pair represents. Crypto symbols are now
   // excluded from this grouping entirely - on both sides: a crypto
   // candidate never counts forex positions toward its own currency cap,
   // and a crypto position never counts toward a forex candidate's cap.
   if(SymbolMatchesNonScalpKeywords(candidateSymbol))
      return 0; // crypto symbols are governed by MaxOpenTrades/MaxTotalOpenTradesAllSymbols only, not currency grouping

   string baseCcy  = StringSubstr(candidateSymbol, 0, 3);
   string quoteCcy = StringSubstr(candidateSymbol, 3, 3);

   int total = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      if(PositionGetDouble(POSITION_VOLUME) > IgnoreTradesAboveLots)
         continue;

      string posSymbol = PositionGetString(POSITION_SYMBOL);

      if(SymbolMatchesNonScalpKeywords(posSymbol))
         continue; // a crypto position never counts toward a forex candidate's currency exposure

      string posBase  = StringSubstr(posSymbol, 0, 3);
      string posQuote = StringSubstr(posSymbol, 3, 3);

      if(posBase == baseCcy || posBase == quoteCcy || posQuote == baseCcy || posQuote == quoteCcy)
         total++;
   }

   return total;
}

bool PortfolioExposureOK()
{
   // OPENCAPS47: master off → skip account/currency open-trade caps
   if(!EnforceOpenTradeCaps)
      return true;

   if(MaxTotalOpenTradesAllSymbols > 0 && CountTotalOpenTradesAllSymbols() >= MaxTotalOpenTradesAllSymbols)
   {
      if(EnableVerboseLogging)
         Print("Trading blocked: account-wide open trade cap reached (",
               CountTotalOpenTradesAllSymbols(), "/", MaxTotalOpenTradesAllSymbols, ")");
      return false;
   }

   if(MaxOpenTradesPerCurrency > 0 && CountOpenTradesSharingCurrency(BrokerSymbol) >= MaxOpenTradesPerCurrency)
   {
      if(EnableVerboseLogging)
         Print("Trading blocked: currency exposure cap reached for ", BrokerSymbol,
               " (cap=", MaxOpenTradesPerCurrency, ")");
      return false;
   }

   return true;
}

//=============================================================//
// Calculate Lot Size
//=============================================================//

input group "LOT SIZING (advanced)"

// LotSize / UseFixedLot / RiskPercent / MaxLotSizeHardCap are in
// TRADE SIZE & LIMITS at the top. CalculateLotSize() now always honors them.
// SymbolRiskOverrides scales RiskPercent per symbol when UseFixedLot=false.

input string SymbolRiskOverrides = "";

double GetSymbolRiskMultiplier(string symbol)
{
   if(StringLen(SymbolRiskOverrides) == 0)
      return 1.0;

   string pairs[];
   int pairCount = StringSplit(SymbolRiskOverrides, ',', pairs);

   for(int i = 0; i < pairCount; i++)
   {
      string kv[];
      int kvCount = StringSplit(pairs[i], ':', kv);

      if(kvCount != 2)
         continue;

      string sym = kv[0];
      StringTrimLeft(sym);
      StringTrimRight(sym);

      // Match by substring so "XAUUSD" matches broker-suffixed
      // "XAUUSD.m" too, same tolerance already used elsewhere in this
      // file for symbol matching (see NonScalpSymbolKeywords).
      if(StringFind(symbol, sym) >= 0)
      {
         double mult = StringToDouble(kv[1]);
         return (mult > 0.0) ? mult : 1.0;
      }
   }

   return 1.0;
}

double CalculateRiskBasedLot(double slDistance)
{
   double lot = LotSize;

   if(!UseFixedLot)
   {
      if(slDistance <= 0.0)
         return LotSize; // can't derive risk-based size without a stop distance - fail safe

      double tickValue = SymbolInfoDouble(BrokerSymbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(BrokerSymbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue <= 0.0 || tickSize <= 0.0)
         return LotSize; // can't price the risk on this symbol - fail safe

      double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
      double effectiveRiskPercent = RiskPercent * GetSymbolRiskMultiplier(BrokerSymbol);
      double riskMoney   = equity * (effectiveRiskPercent / 100.0);
      double lossPerLot  = (slDistance / tickSize) * tickValue;

      if(lossPerLot <= 0.0)
         return LotSize;

      lot = riskMoney / lossPerLot;
   }

   double minLot  = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_STEP);

   if(lotStep > 0.0)
      lot = MathFloor(lot / lotStep) * lotStep;

   if(lot < minLot) lot = minLot;
   if(maxLot > 0.0 && lot > maxLot) lot = maxLot;
   if(lot > MaxLotSizeHardCap) lot = MaxLotSizeHardCap;

   return NormalizeLotVolume(lot);
}

double NormalizeLotVolume(double lot)
{
   double lotStep = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_STEP);
   int digits = 2;
   if(lotStep > 0.0 && lotStep < 1.0)
   {
      digits = 0;
      double step = lotStep;
      while(digits < 8 && MathAbs(step - MathRound(step)) > 1e-12)
      {
         step *= 10.0;
         digits++;
      }
   }
   return NormalizeDouble(lot, digits);
}

double CalculateLotSize(double slDistance = 0.0)
{
   // Adjustable sizing: UseFixedLot=true -> LotSize input.
   // UseFixedLot=false -> RiskPercent of equity vs SL distance.
   if(!UseFixedLot)
      return CalculateRiskBasedLot(slDistance);

   double minLot  = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_STEP);

   double lot = LotSize;

   if(lotStep > 0.0)
      lot = MathFloor(lot / lotStep) * lotStep;

   if(lot < minLot)
      lot = minLot;
   if(maxLot > 0.0 && lot > maxLot)
      lot = maxLot;
   if(lot > MaxLotSizeHardCap)
      lot = MaxLotSizeHardCap;

   return NormalizeLotVolume(lot);
}

//=============================================================//
// Margin Availability Check
//=============================================================//
// FIX: neither ExecuteBuy() nor ExecuteSell() checked whether the account
// actually had enough free margin before sending the order - they relied
// entirely on the broker rejecting it after the fact. This uses
// OrderCalcMargin() to work out the margin the trade would actually
// require and compares it against ACCOUNT_MARGIN_FREE (with a small
// safety buffer) before ever calling trade.Buy()/trade.Sell(), so a
// margin shortfall is caught and logged cleanly instead of surfacing as a
// generic broker-side rejection.

input double MarginSafetyBufferPercent = 10.0; // require this much extra free margin headroom beyond the calculated requirement

bool HasSufficientMargin(ENUM_ORDER_TYPE orderType, double lot, double price)
{
   double requiredMargin = 0.0;

   if(!OrderCalcMargin(orderType, BrokerSymbol, lot, price, requiredMargin))
   {
      Print("OrderCalcMargin failed - proceeding without a pre-trade margin check (error ", GetLastError(), ")");
      return true; // fail open - don't block trading just because the margin calc call itself failed
   }

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double requiredWithBuffer = requiredMargin * (1.0 + MarginSafetyBufferPercent / 100.0);

   if(freeMargin < requiredWithBuffer)
   {
      Print("Trade blocked: insufficient free margin. Required (with buffer): ",
            DoubleToString(requiredWithBuffer,2), ", Free: ", DoubleToString(freeMargin,2));
      return false;
   }

   return true;
}

//=============================================================//
// Margin Level Protection
//=============================================================//
// FIX: HasSufficientMargin() (Part 5) checks whether THIS trade's own
// margin requirement fits in free margin, but nothing checked the
// account's overall MARGIN LEVEL - a thin cushion across already-open
// positions where one more trade could tip the account toward a margin
// call even if this specific trade's own requirement technically fits.

input double MinMarginLevelPercent = 0.0; // ALLTRADE56: 0=off — was 200% blocking accounts with open risk

bool MarginLevelProtection()
{
   if(MinMarginLevelPercent <= 0.0)
      return true;

   double usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);

   if(usedMargin <= 0.0)
      return true; // no open exposure yet - nothing to protect against

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = (equity / usedMargin) * 100.0;

   if(marginLevel < MinMarginLevelPercent)
   {
      Print("Trading blocked: margin level too low (", DoubleToString(marginLevel,1), "%)");
      return false;
   }

   return true;
}

//=============================================================//
// Master Risk Check
//=============================================================//

bool RiskManagementOK()
{
   if(!DrawdownProtection())
      return false;

   if(!DailyLossProtection())
      return false;

   if(!WeeklyLossProtection())
      return false;

   if(!MonthlyLossProtection())
      return false;

   if(!MaxTradesProtection())
      return false;

   if(!MarginLevelProtection())
      return false;

   if(!PortfolioExposureOK())
      return false;

   return true;
}
//+------------------------------------------------------------------+
//|              PART 6 - EXECUTION ENGINE                            |
//+------------------------------------------------------------------+

input group "LOGGING"

// FIX: the EA printed a running commentary on almost every tick/bar
// ("Instant Execution Running", "FINAL CHECK PASSED", every blocked
// reason, etc.) which floods the Experts/Journal tab and adds needless
// overhead on long unattended runs. Off by default now - trade opens/
// closes, errors, and emergency actions always print regardless of this
// setting (those are the ones you actually need in the log); routine
// per-tick/per-bar status chatter only prints when this is turned on.
input bool EnableVerboseLogging = false;

//================ INPUT SETTINGS ===================================//

input double StopLossPoints   = 500;
input double TakeProfitPoints = 1000;
input int    SlippagePoints   = 20;
input int TradeCooldownMinutes = 0;   // OK79 aggressive instant (NeverBlock bypasses anyway)
input int AttemptCooldownSeconds = 1;  // OK79 aggressive instant retry

// #12 Broker filling / slippage profiles (per instrument class)
input group "SLIPPAGE PROFILES (#12)"
input bool   EnableSlippageProfiles     = true;   // use FX/Gold/Crypto deviation presets
input int    ForexSlippagePoints        = 20;     // majors / crosses
input int    GoldSlippagePoints         = 80;     // XAU / XAG style
input int    CryptoSlippagePoints       = 150;    // BTC/ETH when NonScalp match
input double NonScalpSlippageMultiplier = 5.0;    // fallback if profiles OFF (legacy)

int GetEffectiveSlippagePoints()
{
   if(EnableSlippageProfiles)
   {
      if(IsNonScalpSymbol())
         return MathMax(1, CryptoSlippagePoints);
      string sym = BrokerSymbol;
      StringToUpper(sym);
      if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0 ||
         StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
         return MathMax(1, GoldSlippagePoints);
      return MathMax(1, ForexSlippagePoints);
   }

   // Legacy path
   if(IsNonScalpSymbol())
      return (int)MathRound(SlippagePoints * NonScalpSlippageMultiplier);

   return MathMax(1, SlippagePoints);
}

input group "NON-SCALP SYMBOL OVERRIDE"

// FIX: EntryTF, the cooldown, and the ATR stop multiplier apply the same
// way to every symbol - but BTCUSD moves so many real dollars even on a
// short timeframe that trading it on the same cadence as forex naturally
// produces scalp-style behavior (quick in, quick out on small wiggles).
// Symbols matching NonScalpSymbolKeywords get a wider stop distance and a
// longer minimum wait between trades, so they hold for real moves instead
// of reacting to short-term noise. Other symbols (XAUUSD, forex pairs)
// are completely unaffected - only the matched symbol gets this treatment.

input string NonScalpSymbolKeywords   = "BTC,ETH";
input double NonScalpSLMultiplierBoost = 2.0;   // multiplies SL_ATR_Multiplier for matched symbols - wider stop, wider TP1/TP2 (they scale off SL distance)
input int    NonScalpCooldownMinutes   = 0;    // 0 with Ultra aggro — BTC/ETH use MaxOpenTrades, not idle wait
input int    NonScalpMinimumHoldBars   = 80;    // bars (on EntryTF) before trend-exit/trailing can act on matched symbols (vs MinimumHoldBars for everything else) - 80 x M15 = ~20 hours

// FIX - THIS IS WHY BTCUSD KEPT CLOSING TRADES: once holdPeriodOK became
// true, EnableTrendExit checked ADX on every tick and closed the position
// the instant ADX dipped below TrendExitADXLevel (20) - even briefly. BTC's
// ADX crosses that kind of threshold often without the underlying trend
// actually being over, so positions were getting closed out on ADX noise
// rather than a genuine trend reversal - the exact opposite of "don't
// scalp BTC." Disabled by default for matched symbols; SL/TP1/TP2/trailing
// still fully protect the trade, this only removes the ADX-based early exit.
input bool NonScalpDisableTrendExit = true;

// FIX: this used to duplicate the exact same keyword-matching logic that
// now lives in SymbolMatchesNonScalpKeywords() (defined earlier, next to
// CountOpenTradesSharingCurrency which also needs to run this check
// against arbitrary symbols, not just BrokerSymbol). Kept as a thin
// wrapper so every existing call site (GetTradeDistances, CooldownFinished,
// ManageOpenTrades, NewsTradingAllowed, etc.) is untouched.
bool IsNonScalpSymbol()
{
   return SymbolMatchesNonScalpKeywords(BrokerSymbol);
}

input group "DYNAMIC STOPS & SNIPER TARGETS"

// FIX: StopLossPoints/TakeProfitPoints above are a flat "points" distance,
// tuned for forex-style pricing. That's what was leaving BTCUSD trades
// with no SL/TP at all - 500 points on a symbol where SYMBOL_POINT is tiny
// relative to a $60,000+ price is a fraction of a dollar, which brokers
// reject as an invalid/too-close stop. ATR scales to whatever the
// instrument is actually doing right now, in real price terms, so the
// same settings work sanely on XAUUSD, BTCUSD, or EURUSD alike.

input bool   UseDynamicStops        = true;   // ATR-based SL/TP instead of fixed points
input double SL_ATR_Multiplier      = 2.0;    // stop-loss distance = ATR x this
input double TP1_RR_Ratio           = 1.5;    // CHANGED from 1.0 - at 1.0, a TP1-only win (50% of position at 1R) only nets +0.5R while a full loss costs -1R, meaning even a 50% win rate loses money. At 1.5, a TP1-only win nets +0.75R - still less than a full loss, but the gap is smaller. See TP1_ClosePercent below for the other lever on this same tradeoff.
input double TP2_RR_Ratio           = 2.5;    // TP2 distance = SL distance x this (final target, set as broker TP)
input double TP1_ClosePercent       = 50.0;   // % of the position closed when TP1 is hit
input bool   MoveSLToBreakEvenAtTP1 = true;   // fallback: move remaining SL to entry if SecureProfitOnTPHit=false

input group "AGGRESSIVE PROFIT LADDER"
// SURE ladder (aggressive):
// TP1 hit → SL locks INTO profit → remainder MUST run to TP2
// TP2 hit → SL locks further → remainder MUST run to TP3 / trail
// Broker TP opens at TP3 (far) so the broker cannot close the trade at TP2
// before the EA locks profit and advances the ladder.

input bool   AggressiveProfitLadder   = true;  // master ladder switch (forced on when ForceSureProfitLadder)
input bool   ForceSureProfitLadder    = true;  // overrides UseFixedTradeManagement — ladder ALWAYS active
input bool   SecureProfitOnTPHit      = true;  // move SL INTO profit (not just breakeven) when a TP hits
input double LockProfitAtTP1_Fraction = 0.80;  // lock 80% of TP1 move as secured profit (aggressive)
input double LockProfitAtTP2_Fraction = 0.85;  // lock ~85% of TP2 move (near/above TP1) when TP2 hits
input double LockProfitBufferATR      = 0.05;  // small ATR buffer so locked SL is not glued to exact wick
input bool   ExtendTPAfterLock        = true;  // after TP1 → broker TP=TP3; after TP2 → TP3 or trail(0)
input bool   DetectTPByBarTouch       = true;  // count TP hit if bar high/low touched level (sure detect)
input double AggressiveTrailATRMult   = 1.5;   // tight ATR trail after TP1 locks profit
input bool   BrokerTPStartsAtTP3      = true;  // open with far TP3 so EA owns TP1/TP2 ladder steps

input group "MARKET DEFENSE ENGINE"
// Defends open trades against the market flipping, chopping, or trapping.
// Runs every tick in ManageOpenTrades — can lock BE, tighten SL, or close.

input bool   EnableMarketDefense            = true;  // master defense switch
input bool   DefenseCloseOnHardReversal     = true;  // opposite correct RevSniper stack → close
input bool   DefenseLockBEOnAdverseSweep    = true;  // wrong-side sweep vs our trade → lock BE
input bool   DefenseTightenOnChop           = true;  // IMCE manipulation/chop while in profit → BE
input bool   DefenseCloseOnTrapAgainst      = true;  // fake-breakout trap in our direction → close if pre-TP1
input bool   DefenseRetraceLockFromPeak     = true;  // retrace from MFE → lock portion of peak profit
input double DefenseRetraceATR              = 0.70;  // ATR retrace from peak that triggers lock
input double DefenseRetraceLockFraction     = 0.50;  // lock this fraction of peak favorable move
input bool   DefenseRequireInProfitToClose  = false; // if true, hard-reversal close only when already green
input bool   DefenseLogActions              = true;  // print DEFEND actions to Experts

// #7 mid-path BE before TP1 (lighter than full close)
input bool   DefensePreTP1AdverseBE         = true;  // lock BE pre-TP1 on adverse move (wick pressure)
input double DefensePreTP1AdverseATR        = 0.55;  // adverse ATR from entry that arms pre-TP1 BE
input bool   DefensePreTP1RequireProfitTiny = false; // if true, only BE when back near flat/green

// #8 MAE hard cut before TP1
input bool   DefenseMAE_StopEnabled         = true;  // close if floating loss exceeds MAE ATR
input double DefenseMAE_ATR                 = 1.25;  // max adverse excursion in ATR before TP1 (0=off)

//================ TRADE STATE TRACKING (for TP1/TP2/TP3) ============//
// MT5 positions only carry one SL and one TP natively - there's no built-in
// concept of "close half here, let the rest run to a further target." This
// struct/array is what makes that possible: at the moment a trade is opened,
// its TP1/TP2/TP3 levels and original volume are recorded here so
// ManageOpenTrades() can recognize "price just reached this position's
// TP1/TP2" and act once each, while the broker-side TP field tracks
// whichever target is currently active for the remaining volume.

struct TradeState
{
   ulong  ticket;
   double tp1Price;
   double tp2Price;
   double tp3Price;
   bool   isBuy;
   bool   tp1Taken;
   bool   tp2Taken; // UPGRADE: TP2 scale-out / TP3 runner activation flag
   string strategyTag; // NEW - which strategy (SMC/MeanReversion/TrendPullback/etc) actually produced this trade, for per-strategy performance tracking (Part 15i)
   double peakFavorable; // DEFEND: best favorable price excursion from entry (absolute price)
   double peakAdverse;   // AUDITOK52: max adverse distance from entry (sticky arm for pre-TP1 BE)
};

// NEW - set right before ExecuteBuy()/ExecuteSell() is called in
// InstantExecution(), read by RegisterTradeState() below so each trade's
// originating strategy is recorded without threading an extra parameter
// through the whole execution call chain.
string g_PendingStrategyTag = "";


TradeState TradeStates[];

// FIX: the in-memory array alone loses all TP1/TP2 tracking if the EA is
// removed/re-attached, the terminal restarts, or the platform crashes -
// any position already open at that point would just run to its
// broker-side TP with no further scale-out ever happening. MT5's
// GlobalVariable store is written to disk and survives all of that, so
// every state change is mirrored there and RestoreTradeStates() (called
// from OnInit) rebuilds the in-memory table from it on startup.

string TradeStateGVPrefix()
{
   return "HitmanAI_" + IntegerToString(MagicNumber) + "_TP1_";
}

void PersistTradeState(int index)
{
   // HARDEN: never index TradeStates out of range
   if(index < 0 || index >= ArraySize(TradeStates))
      return;
   if(TradeStates[index].ticket == 0)
      return;

   string prefix = TradeStateGVPrefix() + IntegerToString(TradeStates[index].ticket);

   GlobalVariableSet(prefix + "_tp1",    TradeStates[index].tp1Price);
   GlobalVariableSet(prefix + "_tp2",    TradeStates[index].tp2Price);
   GlobalVariableSet(prefix + "_tp3",    TradeStates[index].tp3Price);
   GlobalVariableSet(prefix + "_buy",    TradeStates[index].isBuy    ? 1.0 : 0.0);
   GlobalVariableSet(prefix + "_taken",  TradeStates[index].tp1Taken ? 1.0 : 0.0);
   GlobalVariableSet(prefix + "_taken2", TradeStates[index].tp2Taken ? 1.0 : 0.0);
   GlobalVariableSet(prefix + "_mfe",    TradeStates[index].peakFavorable);
   GlobalVariableSet(prefix + "_mae",    TradeStates[index].peakAdverse);
}

void DeleteTradeStateGlobals(ulong ticket)
{
   if(ticket == 0)
      return;

   string prefix = TradeStateGVPrefix() + IntegerToString(ticket);

   GlobalVariableDel(prefix + "_tp1");
   GlobalVariableDel(prefix + "_tp2");
   GlobalVariableDel(prefix + "_tp3");
   GlobalVariableDel(prefix + "_buy");
   GlobalVariableDel(prefix + "_taken");
   GlobalVariableDel(prefix + "_taken2");
   GlobalVariableDel(prefix + "_mfe");
   GlobalVariableDel(prefix + "_mae");
}

void RegisterTradeState(ulong ticket, double tp1Price, double tp2Price, double tp3Price, bool isBuy)
{
   // HARDEN: never register unresolved ticket 0 (pollutes GV namespace _TP1_0_*)
   if(ticket == 0)
   {
      Print("HARDEN: RegisterTradeState skipped — ticket is 0");
      return;
   }

   int n = ArraySize(TradeStates);
   ArrayResize(TradeStates, n + 1);

   TradeStates[n].ticket      = ticket;
   TradeStates[n].tp1Price    = tp1Price;
   TradeStates[n].tp2Price    = tp2Price;
   TradeStates[n].tp3Price    = tp3Price;
   TradeStates[n].isBuy       = isBuy;
   TradeStates[n].tp1Taken    = false;
   TradeStates[n].tp2Taken    = false;
   TradeStates[n].strategyTag = g_PendingStrategyTag;
   TradeStates[n].peakFavorable = 0.0;
   TradeStates[n].peakAdverse = 0.0;

   PersistTradeState(n);
}

// Rebuilds TradeStates[] from GlobalVariables for every currently-open
// position belonging to this EA (matching magic number). Call once from
// OnInit so a restart doesn't silently drop TP1/TP2 tracking for trades
// that were already open.
void RestoreTradeStates()
{
   ArrayResize(TradeStates, 0);

   string prefix = TradeStateGVPrefix();

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      // MT5 position tickets are globally unique across all symbols in the
      // account, so no symbol filter is needed here - the magic number
      // check below is sufficient on its own (see FIX note from the
      // multi-symbol persistence bug fixed earlier in this file).

      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      string tp1Key    = prefix + IntegerToString(ticket) + "_tp1";
      string tp2Key    = prefix + IntegerToString(ticket) + "_tp2";
      string tp3Key    = prefix + IntegerToString(ticket) + "_tp3";
      string buyKey    = prefix + IntegerToString(ticket) + "_buy";
      string takenKey  = prefix + IntegerToString(ticket) + "_taken";
      string taken2Key = prefix + IntegerToString(ticket) + "_taken2";

      if(!GlobalVariableCheck(tp1Key))
         continue; // no persisted TP1 data for this position - opened before this feature, or state was lost

      int n = ArraySize(TradeStates);
      ArrayResize(TradeStates, n + 1);

      TradeStates[n].ticket   = ticket;
      TradeStates[n].tp1Price = GlobalVariableGet(tp1Key);
      TradeStates[n].tp2Price = GlobalVariableCheck(tp2Key) ? GlobalVariableGet(tp2Key) : 0.0;
      TradeStates[n].tp3Price = GlobalVariableCheck(tp3Key) ? GlobalVariableGet(tp3Key) : 0.0;
      TradeStates[n].isBuy    = (GlobalVariableGet(buyKey) > 0.5);
      TradeStates[n].tp1Taken = (GlobalVariableGet(takenKey) > 0.5);
      TradeStates[n].tp2Taken = GlobalVariableCheck(taken2Key) ? (GlobalVariableGet(taken2Key) > 0.5) : false;
      string mfeKey = prefix + IntegerToString(ticket) + "_mfe";
      string maeKey = prefix + IntegerToString(ticket) + "_mae";
      TradeStates[n].peakFavorable = GlobalVariableCheck(mfeKey) ? GlobalVariableGet(mfeKey) : 0.0;
      TradeStates[n].peakAdverse   = GlobalVariableCheck(maeKey) ? GlobalVariableGet(maeKey) : 0.0;
      TradeStates[n].strategyTag = "";

      // HARDEN: discard corrupt GV prices so ladder/defense cannot use NaN
      if(!MathIsValidNumber(TradeStates[n].tp1Price) || TradeStates[n].tp1Price <= 0.0)
      {
         ArrayResize(TradeStates, n); // drop this slot
         continue;
      }
      if(!MathIsValidNumber(TradeStates[n].tp2Price) || TradeStates[n].tp2Price < 0.0)
         TradeStates[n].tp2Price = 0.0;
      if(!MathIsValidNumber(TradeStates[n].tp3Price) || TradeStates[n].tp3Price < 0.0)
         TradeStates[n].tp3Price = 0.0;
      if(!MathIsValidNumber(TradeStates[n].peakFavorable) || TradeStates[n].peakFavorable < 0.0)
         TradeStates[n].peakFavorable = 0.0;
      if(!MathIsValidNumber(TradeStates[n].peakAdverse) || TradeStates[n].peakAdverse < 0.0)
         TradeStates[n].peakAdverse = 0.0;
   }

   Print("Restored ", ArraySize(TradeStates), " TP1 trade state(s) from persistent storage.");
}

int FindTradeState(ulong ticket)
{
   for(int i = 0; i < ArraySize(TradeStates); i++)
      if(TradeStates[i].ticket == ticket)
         return i;

   return -1;
}

// Drops entries for tickets that are no longer open (closed/hit their
// full TP), so this array doesn't grow forever over a long-running EA.
// Also clears their persisted GlobalVariables so closed trades don't
// leave stale entries behind on disk.
void PruneTradeStates()
{
   for(int i = ArraySize(TradeStates) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(TradeStates[i].ticket))
      {
         DeleteTradeStateGlobals(TradeStates[i].ticket);

         for(int j = i; j < ArraySize(TradeStates) - 1; j++)
            TradeStates[j] = TradeStates[j + 1];

         ArrayResize(TradeStates, ArraySize(TradeStates) - 1);
      }
   }
}

input group "TP3 / RUNNER MODE"

// UPGRADE: previously the whole remaining position (after TP1) closed in
// one shot at TP2 - there was no concept of a "runner" that keeps going
// for an outsized move. This adds a second scale-out at TP2 (mirroring the
// TP1 mechanism, same minimum-lot fallback behavior) and, for whatever's
// left after that, either lets it trail with no fixed cap (if EnableTrailing
// is on) or gives it one more real target, TP3, so it's never left
// completely unmanaged.

input double TP2_ClosePercent = 50.0;   // % of the REMAINING (post-TP1) position closed at TP2
input double TP3_RR_Ratio     = 4.0;    // TP3 distance = SL distance x this - used as the runner's target when trailing is off
input bool   EnableTP3Runner  = true;   // if false, TP2 behaves like a normal final target (old behavior) instead of releasing a runner

// Works out the SL/TP1/TP2/TP3 price distances for a new trade. Falls back
// to the original fixed-points behavior if UseDynamicStops is off, so
// nothing changes for anyone who preferred the old behavior.
void GetTradeDistances(double &slDistance, double &tp1Distance, double &tp2Distance, double &tp3Distance)
{
   double point = SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT);

   if(UseDynamicStops)
   {
      double atr = GetFilterATR();

      if(atr <= 0.0)
      {
         // ATR not ready yet - fail safe to the fixed-points distance
         // rather than opening with no usable distance at all.
         slDistance = StopLossPoints * point;
      }
      else
      {
         slDistance = atr * SL_ATR_Multiplier;
      }
   }
   else
   {
      slDistance = StopLossPoints * point;
   }

   // Widen the stop for symbols matched by NonScalpSymbolKeywords (BTC/ETH
   // by default) - TP1/TP2/TP3 scale off slDistance below, so this widens
   // the whole trade proportionally, not just the stop-loss.
   if(IsNonScalpSymbol())
      slDistance = slDistance * NonScalpSLMultiplierBoost;

   // OK64: ContFallback / APEX get wider SL so they cannot behave like scalps
   if(EnableAntiScalpMode && ContFallbackSL_ATR_Boost > 1.0 &&
      (g_PendingStrategyTag == "ContFallback" || g_PendingStrategyTag == "APEX" || g_PendingStrategyTag == "LCS" || PRIME_IsLiveTag(g_PendingStrategyTag)))
      slDistance = slDistance * ContFallbackSL_ATR_Boost;

   tp1Distance = slDistance * TP1_RR_Ratio;
   tp2Distance = slDistance * TP2_RR_Ratio;
   tp3Distance = slDistance * TP3_RR_Ratio;
}

bool ProfitLadderActive()
{
   return (ForceSureProfitLadder || (AggressiveProfitLadder && !UseFixedTradeManagement));
}

// Broker TP must start at far TP3 so the broker cannot full-close at TP2
// before the EA locks SL and advances TP1 → TP2 → TP3.
double InitialBrokerTP(const bool isBuy, const double entry,
                       const double tp2Distance, const double tp3Distance,
                       const double tp2Price, const double tp3Price)
{
   if(ForceSureProfitLadder || (AggressiveProfitLadder && BrokerTPStartsAtTP3))
   {
      if(tp3Price > 0.0)
         return tp3Price;
      return isBuy ? (entry + tp3Distance) : (entry - tp3Distance);
   }
   if(tp2Price > 0.0)
      return tp2Price;
   return isBuy ? (entry + tp2Distance) : (entry - tp2Distance);
}

// HARDEN: iHigh/iLow return 0 on failure — never treat as a real touch.
bool SafeBarTouchedHigh(const int bar, const double level)
{
   double hi = iHigh(BrokerSymbol, EntryTF, bar);
   if(!MathIsValidNumber(hi) || hi <= 0.0 || hi == EMPTY_VALUE)
      return false;
   return (hi >= level);
}

bool SafeBarTouchedLow(const int bar, const double level)
{
   double lo = iLow(BrokerSymbol, EntryTF, bar);
   if(!MathIsValidNumber(lo) || lo <= 0.0 || lo == EMPTY_VALUE)
      return false;
   return (lo <= level);
}

// BUGFIX40: never credit pre-entry bar wicks as TP hits (was firing TP1/TP2
// instantly on new trades when prior bar already swept the level).
// barsHeld==0 (same bar as entry): live price only.
// barsHeld>=1: may use forming bar 0 wick.
// barsHeld>=2: may also use completed bar 1 wick.
bool LevelTouchedForTP(const bool isBuy, const double level, const double price, const int barsHeld)
{
   if(!MathIsValidNumber(level) || !MathIsValidNumber(price) || level <= 0.0 || price <= 0.0)
      return false;

   if(isBuy)
   {
      if(price >= level)
         return true;
      if(!DetectTPByBarTouch)
         return false;
      if(barsHeld >= 1 && SafeBarTouchedHigh(0, level))
         return true;
      if(barsHeld >= 2 && SafeBarTouchedHigh(1, level))
         return true;
      return false;
   }

   if(price <= level)
      return true;
   if(!DetectTPByBarTouch)
      return false;
   if(barsHeld >= 1 && SafeBarTouchedLow(0, level))
      return true;
   if(barsHeld >= 2 && SafeBarTouchedLow(1, level))
      return true;
   return false;
}

//================ NORMALIZE PRICE ===================================//

double NormalizeTradePrice(double price)
{
   int digits = (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS);

   double tickSize = SymbolInfoDouble(BrokerSymbol, SYMBOL_TRADE_TICK_SIZE);

   // Rounding to the right number of decimal places is not enough for
   // symbols like BTCUSD, where the broker's real price increment
   // (tick size) is coarser than the decimal digits suggest - e.g. digits=2
   // lets 63295.71 look "valid" even though the broker only accepts
   // multiples of 1.00 or 0.50. Snap to the tick grid first, then to digits.
   if(tickSize > 0.0)
      price = MathRound(price / tickSize) * tickSize;

   return NormalizeDouble(price, digits);
}


//================ CHECK STOPS ======================================//

bool CheckTradeStops(double entry,double &sl,double &tp)
{
   double point =
      SymbolInfoDouble(BrokerSymbol,SYMBOL_POINT);

   if(point <= 0)
      return false;

   long stopLevel =
      SymbolInfoInteger(BrokerSymbol,SYMBOL_TRADE_STOPS_LEVEL);

   long freezeLevel =
      SymbolInfoInteger(BrokerSymbol,SYMBOL_TRADE_FREEZE_LEVEL);

   double minimumDistance =
      MathMax((double)stopLevel,(double)freezeLevel) * point;

   // FIX: the flat "100 points" floor used to apply unconditionally,
   // before the ATR-scaled floor even had a chance to matter - a forex-
   // scale assumption baked in regardless of what the broker or the
   // instrument's real volatility actually called for. Now it's only used
   // as a last-resort fallback when ATR data isn't available at all;
   // when it is, the ATR-scaled floor below is what actually governs the
   // minimum distance, since that adapts to what the instrument is really
   // doing in price terms rather than an arbitrary point count.
   double atrFloor = GetFilterATR() * 0.05;

   if(atrFloor > 0.0)
   {
      if(atrFloor > minimumDistance)
         minimumDistance = atrFloor;
   }
   else if(minimumDistance < 100 * point)
   {
      minimumDistance = 100 * point;
   }

   if(sl < entry)
   {
      if((entry - sl) < minimumDistance)
         sl = entry - minimumDistance;
   }
   else
   {
      if((sl - entry) < minimumDistance)
         sl = entry + minimumDistance;
   }

   if(tp > entry)
   {
      if((tp - entry) < minimumDistance)
         tp = entry + minimumDistance;
   }
   else
   {
      if((entry - tp) < minimumDistance)
         tp = entry - minimumDistance;
   }

   sl = NormalizeTradePrice(sl);
   tp = NormalizeTradePrice(tp);

   return true;
}

//================ POSITION TICKET RESOLUTION =========================//
// FIX: RegisterTradeState()/RecordSignalSnapshot() used to be called with
// trade.ResultOrder() - the ORDER ticket. On many account/broker setups
// the POSITION ticket (what PositionSelectByTicket/PruneTradeStates/
// FindTradeState actually look up by) is not guaranteed to equal the order
// ticket. The officially correct way to resolve "which position did this
// order create" is the order's own ORDER_POSITION_ID field in history.
// Falls back to the order ticket itself only if that lookup fails, which
// is still better than nothing.

ulong ResolvePositionTicket(ulong orderTicket)
{
   // AUDITFIX49: ensure history is loaded before HistoryOrderSelect
   if(orderTicket == 0)
      return 0;

   datetime from = TimeCurrent() - 86400;
   datetime to   = TimeCurrent() + 60;
   if(!HistorySelect(from, to))
      HistorySelect(0, TimeCurrent() + 60);

   if(HistoryOrderSelect(orderTicket))
   {
      ulong posId = (ulong)HistoryOrderGetInteger(orderTicket, ORDER_POSITION_ID);

      if(posId != 0)
         return posId;
   }

   return orderTicket;
}

//================ PENDING SIGNAL SNAPSHOT (fix #6) ===================//
// FIX: RecordSignalSnapshot() used to be called AFTER the trade already
// executed, and recalculated CalculateTradeScore()/every signal flag fresh
// at that point - by which time price/indicators may have already ticked
// forward from the moment StrongBuySetup()/StrongSellSetup() actually
// approved the trade. That meant the score saved for post-trade signal
// review could quietly differ from the score that actually triggered the
// entry. StrongBuySetup()/StrongSellSetup() now capture the exact snapshot
// at the moment of the decision (Part 15) into this pending slot;
// RecordSignalSnapshot() (called after a successful fill) just stamps the
// real ticket onto that already-captured data instead of recomputing it.

SignalSnapshot PendingSignalSnapshot;
bool PendingSignalSnapshotValid = false;

void CapturePendingSignalSnapshot(bool buy, string strategyTag = "")
{
   PRISMStructureSnapshot s = PRISM_GetStructureSnapshot(buy);

   PendingSignalSnapshot.ticket          = 0;
   PendingSignalSnapshot.isBuy           = buy;
   PendingSignalSnapshot.score           = CalculatePRISMScore(buy);
   PendingSignalSnapshot.requiredScore   = EffectiveMinimumMPIScore();
   PendingSignalSnapshot.trendOK         = s.trend;
   PendingSignalSnapshot.htfOK           = s.htfConfirms;
   PendingSignalSnapshot.confluenceOK    = HasStructureConfluence(buy);
   PendingSignalSnapshot.mtfConfluenceOK = HasHTFStructureConfluence(buy);
   PendingSignalSnapshot.bosPresent      = s.bos;
   PendingSignalSnapshot.chochPresent    = s.choch;
   PendingSignalSnapshot.sweepPresent    = s.sweep;
   PendingSignalSnapshot.fvgPresent      = s.fvg;
   PendingSignalSnapshot.obPresent       = s.ob;
   PendingSignalSnapshot.volExpanding    = IsVolatilityExpanding();
   PendingSignalSnapshot.regime          = GetMarketRegime();

   PendingSignalSnapshotValid = true;

   if(EnableBeastMode && strategyTag != "" && (EnableVerboseLogging || EnableSetupLogging))
      Print("BEAST snapshot: ", strategyTag, " grade=", PRISMGetTradeGrade(buy, strategyTag),
            " MPI=", PendingSignalSnapshot.score);
}

void RecordSignalSnapshot(ulong ticket, bool buy)
{
   // HARDEN: never snapshot unresolved tickets
   if(ticket == 0)
      return;

   int n = ArraySize(SignalSnapshots);
   ArrayResize(SignalSnapshots, n + 1);

   if(PendingSignalSnapshotValid && PendingSignalSnapshot.isBuy == buy)
   {
      SignalSnapshots[n] = PendingSignalSnapshot;
      SignalSnapshots[n].ticket = ticket;
   }
   else
   {
      // No pending snapshot available (shouldn't normally happen) - fall
      // back to recomputing fresh, same as the original behavior.
      SignalSnapshots[n].ticket          = ticket;
      SignalSnapshots[n].isBuy           = buy;
      SignalSnapshots[n].score           = CalculateTradeScore(buy);
      SignalSnapshots[n].requiredScore   = GetEffectiveMinimumScore();
      SignalSnapshots[n].trendOK         = buy ? IsBullTrend() : IsBearTrend();
      SignalSnapshots[n].htfOK           = HTFConfirms(buy);
      SignalSnapshots[n].confluenceOK    = HasStructureConfluence(buy);
      SignalSnapshots[n].mtfConfluenceOK = HasHTFStructureConfluence(buy);
      SignalSnapshots[n].bosPresent      = DetectBOS();
      SignalSnapshots[n].chochPresent    = DetectCHoCH();
      SignalSnapshots[n].sweepPresent    = DetectLiquiditySweep();
      SignalSnapshots[n].fvgPresent      = buy ? DetectBullishFVG() : DetectBearishFVG();
      SignalSnapshots[n].obPresent       = buy ? DetectBullishOrderBlock() : DetectBearishOrderBlock();
      SignalSnapshots[n].volExpanding    = IsVolatilityExpanding();
      SignalSnapshots[n].regime          = GetMarketRegime();
   }

   PendingSignalSnapshotValid = false;
}

//================ EXECUTE BUY ======================================//

//================ DYNAMIC FILLING MODE (broker compatibility) =====//
// FIX: CTrade does not automatically detect which order-filling mode a
// given symbol/broker actually supports - left unset, it defaults to
// ORDER_FILLING_FOK, which plenty of brokers (especially ECN/exchange-
// execution ones) reject outright ("Unsupported filling mode"), silently
// failing every single order. This reads the symbol's real supported
// modes (SYMBOL_FILLING_MODE) and picks the best match each time a trade
// is about to be placed, instead of assuming one fixed mode works
// everywhere.

void ConfigureFillingMode(string symbol)
{
   long fillingModes = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);

   if((fillingModes & SYMBOL_FILLING_FOK) != 0)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((fillingModes & SYMBOL_FILLING_IOC) != 0)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN); // safest fallback - supported almost everywhere
}

// BROKER RESPONSE CLASSIFICATION (this pass): the retry loop below already
// handled requotes/price-changes well, but treated every OTHER retcode as
// one undifferentiated "other error" bucket that just fell through to the
// no-stops fallback. Some retcodes are worth a fresh retry (transient
// connection/timeout hiccups); some mean the order is fundamentally
// unplaceable right now and retrying (or attempting the no-stops fallback)
// is pointless and just wastes time while conditions keep moving. This
// gives each case a clear, distinct log message so failures are easy to
// diagnose from the Journal instead of all looking like the same generic
// "BUY FAILED".
bool IsTransientOrderRetcode(uint retcode)
{
   return (retcode == TRADE_RETCODE_REQUOTE ||
           retcode == TRADE_RETCODE_PRICE_OFF ||
           retcode == TRADE_RETCODE_PRICE_CHANGED ||
           retcode == TRADE_RETCODE_TIMEOUT ||
           retcode == TRADE_RETCODE_CONNECTION);
}

bool IsFatalOrderRetcode(uint retcode)
{
   return (retcode == TRADE_RETCODE_NO_MONEY ||
           retcode == TRADE_RETCODE_MARKET_CLOSED ||
           retcode == TRADE_RETCODE_TRADE_DISABLED ||
           retcode == TRADE_RETCODE_INVALID_VOLUME ||
           retcode == TRADE_RETCODE_CLIENT_DISABLES_AT ||
           retcode == TRADE_RETCODE_SERVER_DISABLES_AT);
}

string DescribeOrderRetcode(uint retcode, string desc)
{
   if(retcode == TRADE_RETCODE_NO_MONEY)        return "insufficient free margin - not retrying.";
   if(retcode == TRADE_RETCODE_MARKET_CLOSED)   return "market closed for this symbol - not retrying.";
   if(retcode == TRADE_RETCODE_TRADE_DISABLED)  return "trading disabled for this symbol/account - not retrying.";
   if(retcode == TRADE_RETCODE_INVALID_VOLUME)  return "broker rejected the lot size as invalid - not retrying.";
   if(retcode == TRADE_RETCODE_CLIENT_DISABLES_AT) return "AutoTrading disabled on the client terminal - not retrying.";
   if(retcode == TRADE_RETCODE_SERVER_DISABLES_AT) return "AutoTrading disabled by the broker server - not retrying.";
   return desc;
}

bool ExecuteBuy()
{
   int symIdx = GetSymbolIndex(BrokerSymbol);

   if(symIdx < 0)
   {
      Print("ExecuteBuy: symbol not in tracking list: ", BrokerSymbol);
      return false;
   }

   ConfigureFillingMode(BrokerSymbol);

   // Stops repeated failed attempts from firing on every single tick
   // (was previously only gated by TradeCooldownMinutes, which only starts
   // counting after a *successful* trade - so a persistently-failing
   // attempt, e.g. invalid stops, would retry every tick with no limit).
   if(TimeCurrent() - LastAttemptTimeArr[symIdx] < AttemptCooldownSeconds)
   {
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("BUY aborted: attempt cooldown (", AttemptCooldownSeconds, "s) on ", BrokerSymbol);
      return false;
   }

   if(!RiskManagementOK())
      return false;

   if(!TradeProtectionOK())
      return false;

   // Sanity: direction still agrees — skip abort in UltraAggressiveFire
   // (path+engines already approved; price can wick without flipping EMA).
   // Live gate is EvaluateStrategySignals (APEX → ContFallback only).
   if(!IsBullTrend() && !(UltraAggressiveFire || NeverBlockValidSniperEntry))
   {
      if(EnableVerboseLogging)
         Print("BUY aborted: trend no longer bullish at execution time.");
      return false;
   }

   double ask = SymbolInfoDouble(BrokerSymbol,SYMBOL_ASK);
   double point = SymbolInfoDouble(BrokerSymbol,SYMBOL_POINT);

   if(ask <= 0 || point <= 0)
   {
      Print("Invalid market price.");
      return false;
   }

   double sl = 0.0;
   double tp = 0.0;
   double tp1Price = 0.0;
   double tp2Price = 0.0;
   double tp3Price = 0.0;

   double slDistance, tp1Distance, tp2Distance, tp3Distance;
   GetTradeDistances(slDistance, tp1Distance, tp2Distance, tp3Distance);

   sl = ask - slDistance;
   // APEX/LCS structural SL beyond sweep extreme (wider/safer wins)
   if(APEX_UseSweepSL && g_PendingStrategyTag == "APEX" && g_APEX_InvalidationPrice > 0.0)
   {
      double apexSL = g_APEX_InvalidationPrice;
      if(apexSL < ask)
      {
         if(apexSL < sl)
            sl = apexSL;
         Print("APEX BUY SL → sweep invalidation ", DoubleToString(sl, (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)),
               " on ", BrokerSymbol);
      }
   }
   else if(LCS_UseSweepSL && g_PendingStrategyTag == "LCS" && g_LCS_InvalidationPrice > 0.0)
   {
      double lcsSL = g_LCS_InvalidationPrice;
      if(lcsSL < ask)
      {
         if(lcsSL < sl)
            sl = lcsSL;
         Print("LCS BUY SL → sweep invalidation ", DoubleToString(sl, (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)),
               " on ", BrokerSymbol);
      }
   }
   tp1Price = ask + tp1Distance; // soft TP1 — EA locks SL here then runs to TP2
   tp2Price = ask + tp2Distance;
   tp3Price = ask + tp3Distance;
   // Far broker TP (TP3) so ladder is not cut short by a full close at TP2
   tp = InitialBrokerTP(true, ask, tp2Distance, tp3Distance, tp2Price, tp3Price);

   if(!CheckTradeStops(ask,sl,tp))
   {
      Print("Failed to validate BUY stops.");
      return false;
   }

   // FIX: if CheckTradeStops() above widened sl to meet the broker's
   // minimum stop distance (or the ATR floor), tp1Price/tp2Price/tp3Price
   // above were already computed from the ORIGINAL, pre-widening
   // slDistance - silently breaking the intended R:R ratio in exactly the
   // case where a broker's stop rules forced a wider stop than the ATR
   // math called for. Recomputed here proportionally from the actual
   // final sl distance, so TP1/TP2/TP3 always reflect the real risk being
   // taken, not the originally-planned one.
   double actualSLDistance = ask - sl;

   if(MathAbs(actualSLDistance - slDistance) > SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT))
   {
      tp1Price = ask + actualSLDistance * TP1_RR_Ratio;
      tp2Price = ask + actualSLDistance * TP2_RR_Ratio;
      tp3Price = ask + actualSLDistance * TP3_RR_Ratio;
      tp = InitialBrokerTP(true, ask, actualSLDistance * TP2_RR_Ratio,
                          actualSLDistance * TP3_RR_Ratio, tp2Price, tp3Price);
      CheckTradeStops(ask, sl, tp); // re-validate the adjusted tp against broker minimums too
   }

   double lot = CalculateLotSize(actualSLDistance);

   if(lot <= 0)
   {
      Print("Invalid lot size.");
      return false;
   }

   // FIX #9: check free margin BEFORE sending, instead of relying on the
   // broker to reject an under-margined order after the fact.
   if(!HasSufficientMargin(ORDER_TYPE_BUY, lot, ask))
      return false;

   LastAttemptTimeArr[symIdx] = TimeCurrent();

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(GetEffectiveSlippagePoints());

   // FIX #8: no retry existed for transient execution errors like requotes
   // or the price moving between our snapshot above and the send. This
   // retries a few times, re-pulling the live price and recomputing
   // sl/tp/tp1/tp2/tp3 off it each time, instead of giving up on the very
   // first requote.
   const int MAX_SEND_RETRIES = 3;
   bool result = false;

   for(int attempt = 1; attempt <= MAX_SEND_RETRIES; attempt++)
   {
      // Quick re-validation immediately before sending (fix #5 from the
      // signal-detection review): a signal confirmed a moment ago can
      // stop being valid by the time we actually place the order,
      // especially across retries after a requote. Re-check the cheap,
      // fast-changing gates (spread widened, terminal disabled trading)
      // right here rather than trusting the state from earlier in the
      // function.
      ResetLastError();

      result = trade.Buy(lot, BrokerSymbol, 0.0, sl, tp, TradeComment);

      if(result)
         break;

      uint retcode = trade.ResultRetcode();

      if(IsTransientOrderRetcode(retcode))
      {
         if(EnableVerboseLogging)
            Print("BUY transient error (", retcode, ") attempt ", attempt, "/", MAX_SEND_RETRIES, " - refreshing price and retrying.");

         Sleep(200);

         ask = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);

         if(ask <= 0)
            break;

         sl = ask - slDistance;
         tp1Price = ask + tp1Distance;
         tp2Price = ask + tp2Distance;
         tp3Price = ask + tp3Distance;
         tp = InitialBrokerTP(true, ask, tp2Distance, tp3Distance, tp2Price, tp3Price);

         CheckTradeStops(ask, sl, tp);
         continue;
      }

      if(IsFatalOrderRetcode(retcode))
      {
         Print("BUY FAILED (fatal) | Retcode: ", retcode, " | ", DescribeOrderRetcode(retcode, trade.ResultRetcodeDescription()));
         return false; // no point trying the no-stops fallback either - the order itself is unplaceable right now
      }

      break; // any other error - fall through to the no-stops fallback / failure logging below
   }

   if(result)
   {
      Print("BUY executed successfully.");
      ulong posTicket = ResolvePositionTicket(trade.ResultOrder());
      LastTradeTimeArr[symIdx] = TimeCurrent();
      MarkContFallbackFillIfNeeded();
      RegisterTradeState(posTicket, tp1Price, tp2Price, tp3Price, true);
      RecordSignalSnapshot(posTicket, true);
      return true;
   }

   // Fallback: some brokers/symbols (commonly crypto CFDs) reject SL/TP
   // attached to a market order outright, even when the prices themselves
   // are valid. Retry with no stops, then attach them via PositionModify
   // once the position exists.
   if(trade.ResultRetcode() == TRADE_RETCODE_INVALID_STOPS)
   {
      if(EnableVerboseLogging)
         Print("BUY retry: opening without stops, will attach SL/TP after fill.");

      ResetLastError();

      bool openedNoStops = trade.Buy(lot, BrokerSymbol, 0.0, 0.0, 0.0, TradeComment);

      if(openedNoStops)
      {
         ulong newTicket = ResolvePositionTicket(trade.ResultOrder());
         bool stopsAttached = false;

         if(newTicket == 0)
         {
            Print("HARDEN: BUY no-stops fill but ticket unresolved — abort attach");
            return false;
         }

         if(PositionSelectByTicket(newTicket))
         {
            if(trade.PositionModify(newTicket, sl, tp))
            {
               stopsAttached = true;
            }
            else
            {
               // FIX: previously this just logged a failure and left the
               // position open with NO SL/TP at all - an unprotected
               // position is a worse outcome than no position. Retry once
               // more with the broker's minimum-distance stops
               // recalculated off the current price, and if that still
               // fails, close the position immediately rather than leave
               // risk unmanaged.
               Print("BUY opened without stops, first attach attempt failed: ",
                     trade.ResultRetcodeDescription(), " - retrying with recalculated stops.");

               double curPrice = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
               double retrySL = curPrice - slDistance;
               // SAFE42: far TP3 so sure ladder is not cut at TP2
               double retryTP1 = curPrice + slDistance * TP1_RR_Ratio;
               double retryTP2 = curPrice + slDistance * TP2_RR_Ratio;
               double retryTP3 = curPrice + slDistance * TP3_RR_Ratio;
               double retryTP = InitialBrokerTP(true, curPrice, slDistance * TP2_RR_Ratio,
                                               slDistance * TP3_RR_Ratio, retryTP2, retryTP3);
               CheckTradeStops(curPrice, retrySL, retryTP);

               if(trade.PositionModify(newTicket, retrySL, retryTP))
               {
                  stopsAttached = true;
                  sl = retrySL; tp = retryTP;
                  tp1Price = retryTP1; tp2Price = retryTP2; tp3Price = retryTP3;
               }
            }
         }

         if(!stopsAttached)
         {
            Print("BUY: could not attach SL/TP after fallback - closing the unprotected position for safety (ticket ", newTicket, ").");
            trade.PositionClose(newTicket);
            return false;
         }

         Print("BUY executed successfully (no-stops fallback).");
         LastTradeTimeArr[symIdx] = TimeCurrent();
         MarkContFallbackFillIfNeeded();
         RegisterTradeState(newTicket, tp1Price, tp2Price, tp3Price, true);
         RecordSignalSnapshot(newTicket, true);
         return true;
      }
   }

   Print(
      "BUY FAILED | Retcode: ",
      trade.ResultRetcode(),
      " | ",
      trade.ResultRetcodeDescription()
   );

   return false;
}
//================ EXECUTE SELL =====================================//

bool ExecuteSell()
{
   int symIdx = GetSymbolIndex(BrokerSymbol);

   if(symIdx < 0)
   {
      Print("ExecuteSell: symbol not in tracking list: ", BrokerSymbol);
      return false;
   }

   ConfigureFillingMode(BrokerSymbol);

   if(TimeCurrent() - LastAttemptTimeArr[symIdx] < AttemptCooldownSeconds)
   {
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("SELL aborted: attempt cooldown (", AttemptCooldownSeconds, "s) on ", BrokerSymbol);
      return false;
   }

   if(!RiskManagementOK())
      return false;

   if(!TradeProtectionOK())
      return false;

   // See the matching comment in ExecuteBuy() - cheap re-check that the
   // basic trend direction hasn't already reversed between decision and
   // execution.
   if(!IsBearTrend() && !(UltraAggressiveFire || NeverBlockValidSniperEntry))
   {
      if(EnableVerboseLogging)
         Print("SELL aborted: trend no longer bearish at execution time.");
      return false;
   }

   double bid = SymbolInfoDouble(BrokerSymbol,SYMBOL_BID);
   double point = SymbolInfoDouble(BrokerSymbol,SYMBOL_POINT);

   if(bid <= 0 || point <= 0)
   {
      Print("Invalid market price.");
      return false;
   }

   double sl = 0.0;
   double tp = 0.0;
   double tp1Price = 0.0;
   double tp2Price = 0.0;
   double tp3Price = 0.0;

   double slDistance, tp1Distance, tp2Distance, tp3Distance;
   GetTradeDistances(slDistance, tp1Distance, tp2Distance, tp3Distance);

   sl = bid + slDistance;
   if(APEX_UseSweepSL && g_PendingStrategyTag == "APEX" && g_APEX_InvalidationPrice > 0.0)
   {
      double apexSL = g_APEX_InvalidationPrice;
      if(apexSL > bid)
      {
         if(apexSL > sl)
            sl = apexSL;
         Print("APEX SELL SL → sweep invalidation ", DoubleToString(sl, (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)),
               " on ", BrokerSymbol);
      }
   }
   else if(LCS_UseSweepSL && g_PendingStrategyTag == "LCS" && g_LCS_InvalidationPrice > 0.0)
   {
      double lcsSL = g_LCS_InvalidationPrice;
      if(lcsSL > bid)
      {
         if(lcsSL > sl)
            sl = lcsSL;
         Print("LCS SELL SL → sweep invalidation ", DoubleToString(sl, (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)),
               " on ", BrokerSymbol);
      }
   }
   tp1Price = bid - tp1Distance;
   tp2Price = bid - tp2Distance;
   tp3Price = bid - tp3Distance;
   tp = InitialBrokerTP(false, bid, tp2Distance, tp3Distance, tp2Price, tp3Price);

   if(!CheckTradeStops(bid,sl,tp))
   {
      Print("Failed to validate SELL stops.");
      return false;
   }

   // See the matching fix and comment in ExecuteBuy() above.
   double actualSLDistance = sl - bid;

   if(MathAbs(actualSLDistance - slDistance) > SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT))
   {
      tp1Price = bid - actualSLDistance * TP1_RR_Ratio;
      tp2Price = bid - actualSLDistance * TP2_RR_Ratio;
      tp3Price = bid - actualSLDistance * TP3_RR_Ratio;
      tp = InitialBrokerTP(false, bid, actualSLDistance * TP2_RR_Ratio,
                          actualSLDistance * TP3_RR_Ratio, tp2Price, tp3Price);
      CheckTradeStops(bid, sl, tp);
   }

   double lot = CalculateLotSize(actualSLDistance);

   if(lot <= 0)
   {
      Print("Invalid lot size.");
      return false;
   }

   if(!HasSufficientMargin(ORDER_TYPE_SELL, lot, bid))
      return false;

   LastAttemptTimeArr[symIdx] = TimeCurrent();

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(GetEffectiveSlippagePoints());

   const int MAX_SEND_RETRIES = 3;
   bool result = false;

   for(int attempt = 1; attempt <= MAX_SEND_RETRIES; attempt++)
   {
      ResetLastError();

      result = trade.Sell(lot, BrokerSymbol, 0.0, sl, tp, TradeComment);

      if(result)
         break;

      uint retcode = trade.ResultRetcode();

      if(IsTransientOrderRetcode(retcode))
      {
         if(EnableVerboseLogging)
            Print("SELL transient error (", retcode, ") attempt ", attempt, "/", MAX_SEND_RETRIES, " - refreshing price and retrying.");

         Sleep(200);

         bid = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);

         if(bid <= 0)
            break;

         sl = bid + slDistance;
         tp1Price = bid - tp1Distance;
         tp2Price = bid - tp2Distance;
         tp3Price = bid - tp3Distance;
         tp = InitialBrokerTP(false, bid, tp2Distance, tp3Distance, tp2Price, tp3Price);

         CheckTradeStops(bid, sl, tp);
         continue;
      }

      if(IsFatalOrderRetcode(retcode))
      {
         Print("SELL FAILED (fatal) | Retcode: ", retcode, " | ", DescribeOrderRetcode(retcode, trade.ResultRetcodeDescription()));
         return false;
      }

      break;
   }

   if(result)
   {
      Print("SELL executed successfully.");
      ulong posTicket = ResolvePositionTicket(trade.ResultOrder());
      LastTradeTimeArr[symIdx] = TimeCurrent();
      MarkContFallbackFillIfNeeded();
      RegisterTradeState(posTicket, tp1Price, tp2Price, tp3Price, false);
      RecordSignalSnapshot(posTicket, false);
      return true;
   }

   // Same no-stops fallback as ExecuteBuy() - see comments there.
   if(trade.ResultRetcode() == TRADE_RETCODE_INVALID_STOPS)
   {
      if(EnableVerboseLogging)
         Print("SELL retry: opening without stops, will attach SL/TP after fill.");

      ResetLastError();

      bool openedNoStops = trade.Sell(lot, BrokerSymbol, 0.0, 0.0, 0.0, TradeComment);

      if(openedNoStops)
      {
         ulong newTicket = ResolvePositionTicket(trade.ResultOrder());
         bool stopsAttached = false;

         if(newTicket == 0)
         {
            Print("HARDEN: SELL no-stops fill but ticket unresolved — abort attach");
            return false;
         }

         if(PositionSelectByTicket(newTicket))
         {
            if(trade.PositionModify(newTicket, sl, tp))
            {
               stopsAttached = true;
            }
            else
            {
               Print("SELL opened without stops, first attach attempt failed: ",
                     trade.ResultRetcodeDescription(), " - retrying with recalculated stops.");

               double curPrice = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
               double retrySL = curPrice + slDistance;
               // SAFE42: far TP3 so sure ladder is not cut at TP2
               double retryTP1 = curPrice - slDistance * TP1_RR_Ratio;
               double retryTP2 = curPrice - slDistance * TP2_RR_Ratio;
               double retryTP3 = curPrice - slDistance * TP3_RR_Ratio;
               double retryTP = InitialBrokerTP(false, curPrice, slDistance * TP2_RR_Ratio,
                                               slDistance * TP3_RR_Ratio, retryTP2, retryTP3);
               CheckTradeStops(curPrice, retrySL, retryTP);

               if(trade.PositionModify(newTicket, retrySL, retryTP))
               {
                  stopsAttached = true;
                  sl = retrySL; tp = retryTP;
                  tp1Price = retryTP1; tp2Price = retryTP2; tp3Price = retryTP3;
               }
            }
         }

         if(!stopsAttached)
         {
            Print("SELL: could not attach SL/TP after fallback - closing the unprotected position for safety (ticket ", newTicket, ").");
            trade.PositionClose(newTicket);
            return false;
         }

         Print("SELL executed successfully (no-stops fallback).");
         LastTradeTimeArr[symIdx] = TimeCurrent();
         MarkContFallbackFillIfNeeded();
         RegisterTradeState(newTicket, tp1Price, tp2Price, tp3Price, false);
         RecordSignalSnapshot(newTicket, false);
         return true;
      }
   }

   Print(
      "SELL FAILED | Retcode: ",
      trade.ResultRetcode(),
      " | ",
      trade.ResultRetcodeDescription()
   );

   return false;
}
input int PostLossCooldownMinutes = 0; // aggressive sniper: do not block re-entry after a loss

bool CooldownFinished()
{
   int symIdx = GetSymbolIndex(BrokerSymbol);

   if(symIdx < 0)
   {
      // ALLTRADE56: do not hard-block unknown index — allow entry path
      Print("CooldownFinished: symbol not in tracking list yet: ", BrokerSymbol,
            " — allowing (fail-open)");
      return true;
   }

   if(LastTradeTimeArr[symIdx] == 0)
      return true;

   // ALLTRADE56 / NeverBlock: MaxOpenTrades is the real limit — no idle cooldown blocks
   if(NeverBlockValidSniperEntry || UltraAggressiveFire)
      return true;

   if(TradeCooldownMinutes <= 0 && (NonScalpCooldownMinutes <= 0 || !IsNonScalpSymbol()))
      return true;

   int cooldownMinutes = IsNonScalpSymbol() ? NonScalpCooldownMinutes : TradeCooldownMinutes;

   if(cooldownMinutes <= 0)
      return true;

   if(TimeCurrent() - LastTradeTimeArr[symIdx] < cooldownMinutes * 60)
      return false;

   if(PostLossCooldownMinutes > 0 &&
      LastTradeWasLossArr[symIdx] &&
      (TimeCurrent() - LastLossCloseTimeArr[symIdx] < PostLossCooldownMinutes * 60))
   {
      if(EnableVerboseLogging)
         Print("Post-loss cooldown active - waiting before next entry.");
      return false;
   }

   return true;
}
// NOTE: Parts 7 and 8 used to hold a second, unused signal path
// (RunAISignalEngine, calling the now-removed BuySignal/SellSignal) and
// an EA "control module" (StartHitmanAI/RunHitmanAI/StopHitmanAI)
// that just printed log messages and was never called from OnInit/OnTick/
// OnDeinit. Removed as dead code - InstantExecution() (called from OnTick)
// is the actual, and only, execution path.
//+------------------------------------------------------------------+
//|              PART 9 - TRADE PROTECTION SYSTEM                    |
//+------------------------------------------------------------------+

//================ PROTECTION SETTINGS ==============================//

input group "SPREAD"
// OK66: high spread NEVER blocks — CheckSpread is a no-op allow.

//================ CHECK SPREAD =====================================//

bool CheckSpread()
{
   return true; // never block on spread (news spikes included)
}


//================ COUNT OPEN TRADES ================================//

// FIX/UPGRADE: an EA that hardcodes 0.01 lots should never itself open
// anything larger - but a leftover position from before that fix (like the
// old 0.29-lot BTCUSD trade from earlier) can still be sitting open. This
// keeps those out of the trade count / dashboard so they don't clutter the
// view or eat into MaxOpenTrades, WITHOUT skipping them in
// ManageOpenTrades() - that still applies SL/TP/breakeven/trailing to every
// matching position regardless of size, since ignoring risk management on
// a real open position just because of its size would be the more
// dangerous choice.

input double IgnoreTradesAboveLots = 100.0; // only ignore absurd sizes; was 0.015 and bypassed MaxOpenTrades when LotSize raised

int CountOpenTrades()
{
   int total = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      // FIX: this used to read PositionGetString(POSITION_SYMBOL) /
      // PositionGetInteger(POSITION_MAGIC) / PositionGetDouble(POSITION_VOLUME)
      // directly, with no PositionGetTicket(i) beforehand to actually
      // select position #i into context first. Without that selection
      // step, each of those Get calls falls back to whatever position was
      // last selected elsewhere in the program (or nothing), so the loop
      // could silently recheck the same position over and over instead of
      // iterating through every open position - producing a wrong count.
      // PositionGetTicket(i) both returns the ticket AND selects that
      // position for the subsequent property reads, same pattern already
      // used correctly elsewhere in this file (RestoreTradeStates, etc).
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == BrokerSymbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetDouble(POSITION_VOLUME) <= IgnoreTradesAboveLots)
      {
         total++;
      }
   }

   return total;
}


//================ TRADE PROTECTION CHECK ===========================//

// FIX: this used to re-check CountOpenTrades() >= MaxOpenTrades here, on
// top of the identical check MaxTradesProtection() (Part 5) already does
// inside RiskManagementOK() - both functions are called back-to-back on
// every trade attempt (see FinalTradeCheck), so the same PositionsTotal()
// loop was running twice for the same answer. Removed here; the check
// still happens exactly once, via RiskManagementOK() -> MaxTradesProtection().

bool TradeProtectionOK()
{
   // CheckSpread / NewsTradingAllowed are permanent allow (OK66) — only terminal gate remains
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("Trading disabled by terminal");
      return false;
   }
   return true;
}
//+------------------------------------------------------------------+
//|              PART 10 - TRADE MANAGEMENT SYSTEM                   |
//+------------------------------------------------------------------+

//================ MANAGEMENT SETTINGS ==============================//

input bool EnableBreakEven = true;
input bool EnableTrailing  = true;   // OK38: ON — trail runner after TP ladder locks profit

// false = aggressive TP1/TP2/TP3 scale-out + SL profit lock + ATR trailing (OK38 default).
// true  = fixed SL/TP/breakeven only (old PRISM fixed mode).
input bool UseFixedTradeManagement = false;

input double BreakEvenPoints = 500;
input double TrailingPoints  = 300;

// FIX: BreakEvenPoints was a flat points distance, same forex-scale
// assumption already fixed for stops/TP - suitable for EURUSD, not
// necessarily for XAUUSD or BTCUSD. EnableATRBreakEven mirrors the
// existing EnableATRTrailing pattern: when on, the breakeven trigger
// distance scales off ATR instead of a fixed point count.
input bool   EnableATRBreakEven      = true;
input double ATR_BreakEvenMultiplier = 1.0;

double GetBreakEvenDistance(double point)
{
   if(EnableATRBreakEven)
   {
      double atr = GetFilterATR();

      if(atr > 0.0)
         return atr * ATR_BreakEvenMultiplier;
   }

   return BreakEvenPoints * point;
}

//----- Aggressive profit-lock SL after a TP level is hit ----------------//
// Locks the stop INTO profit so a reversal can't give back the whole move.
// fraction=0 → breakeven; fraction=1 → lock at the hit TP level (minus buffer).
double ComputeProfitLockSL(const bool isBuy,
                           const double openPrice,
                           const double tpLevelHit,
                           const double fraction,
                           const double currentSL)
{
   double frac = MathMax(0.0, MathMin(fraction, 1.5));
   double move = isBuy ? (tpLevelHit - openPrice) : (openPrice - tpLevelHit);
   if(move <= 0.0)
      return currentSL;

   double atr = GetFilterATR();
   double buffer = (atr > 0.0) ? (atr * LockProfitBufferATR) : 0.0;

   double locked = isBuy
      ? (openPrice + move * frac - buffer)
      : (openPrice - move * frac + buffer);

   // Never lock on the wrong side of entry when SecureProfit is on with frac>0
   if(isBuy && locked < openPrice)
      locked = openPrice;
   if(!isBuy && locked > openPrice)
      locked = openPrice;

   locked = NormalizeTradePrice(locked);

   // Never loosen an existing stop
   if(isBuy)
   {
      if(currentSL > 0.0 && locked <= currentSL)
         return currentSL;
      return locked;
   }

   if(currentSL > 0.0 && locked >= currentSL)
      return currentSL;
   return locked;
}

bool ApplyProfitLockSL(const ulong ticket,
                       const bool isBuy,
                       const double openPrice,
                       const double tpLevelHit,
                       const double fraction,
                       const double nextTP,
                       const bool applyTP)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   double newSL = curSL;

   if(SecureProfitOnTPHit)
      newSL = ComputeProfitLockSL(isBuy, openPrice, tpLevelHit, fraction, curSL);
   else if(MoveSLToBreakEvenAtTP1)
      newSL = isBuy
         ? ((curSL < openPrice) ? openPrice : curSL)
         : ((curSL > openPrice || curSL == 0.0) ? openPrice : curSL);

   // BUGFIX40: applyTP=true allows nextTP=0 to CLEAR broker TP for trailing.
   // Old code only set TP when nextTP>0, so trail runners kept TP3 and got cut.
   double newTP = curTP;
   if(applyTP)
      newTP = nextTP;
   else if(ExtendTPAfterLock && nextTP > 0.0)
      newTP = nextTP;

   if(MathAbs(newSL - curSL) < SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT) &&
      MathAbs(newTP - curTP) < SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT))
      return true;

   bool ok = trade.PositionModify(ticket, newSL, newTP);
   if(ok)
      Print("PROFIT LOCK: ticket ", ticket,
            " SL→", DoubleToString(newSL, (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)),
            " TP→", DoubleToString(newTP, (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)),
            " (secured after TP hit)");
   else
      Print("PROFIT LOCK failed on ticket ", ticket, ": ", trade.ResultRetcodeDescription());
   return ok;
}

input group "LONG-TERM HOLDING - ADAPTIVE / SAFETY"

// FIX/UPGRADE - the original long-term-holding logic only ever counted
// bars: EnableLongTermHolding + MinimumHoldBars decided when trend-exit/
// trailing were even ALLOWED to touch a position, but there was: (a) no
// cap on how long a trade could be held if nothing else ever triggered,
// (b) no adaptation to whether the market is actually trending or
// ranging right now, and (c) no way to recognize "this trade has gone
// nowhere for a very long time" and do something about it. The three
// settings below address each of those, independently of each other.

input bool   EnableMaxHoldBars      = true;
input int    MaxHoldBars            = 800;   // hard cap (EntryTF bars) - closes the position outright if still open this long, regardless of any other condition
input bool   EnableAdaptiveHoldTime = true;   // shortens the minimum hold requirement while the market is in a RANGING regime (Part 15) - a trade sitting through chop doesn't need the same patience as one riding a genuine trend
input double RangingHoldTimeFactor  = 0.5;    // effectiveMinHoldBars is multiplied by this while GetMarketRegime() == REGIME_RANGING

input bool   EnableStagnationExit      = true;
input int    StagnationLookbackBars    = 150; // only checked once a trade has been open at least this many EntryTF bars
input double StagnationProgressATRMultiple = 0.5; // if the position's favorable excursion hasn't reached this many ATRs by then, it's judged stagnant and closed

// Forward — implemented with Market Defense Engine (after IMCE/trap helpers)
bool MarketDefendOpenPosition(const ulong ticket, const long type, const double openPrice,
                              const double price, double &currentSL, double &currentTP,
                              const int stateIndex);

//================ MANAGE OPEN TRADES ===============================//

void ManageOpenTrades()
{
   PruneTradeStates();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {

      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;


      if(!PositionSelectByTicket(ticket))
         continue;


      string symbol =
      PositionGetString(
         POSITION_SYMBOL
      );


      if(symbol != BrokerSymbol)
         continue;


      // FIX: this loop was only ever filtering by symbol - never by magic
      // number. CountOpenTrades() and the TP1/TP2 state tracking both
      // correctly check MagicNumber, but this actual management loop (the
      // one that moves stops, takes partial profit, and CLOSES positions)
      // never did. That means it was managing and potentially closing ANY
      // position on this symbol - a manual trade you opened yourself, a
      // different EA's position, or a leftover position from earlier
      // testing with a different magic number - not just this EA's own
      // trades. This is very likely the cause of "closes other trades."

      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;


      long type =
      PositionGetInteger(
         POSITION_TYPE
      );


      double openPrice =
      PositionGetDouble(
         POSITION_PRICE_OPEN
      );


      double currentSL =
      PositionGetDouble(
         POSITION_SL
      );


      double currentTP =
      PositionGetDouble(
         POSITION_TP
      );


      double point =
      SymbolInfoDouble(
         BrokerSymbol,
         SYMBOL_POINT
      );


      double price;


      if(type == POSITION_TYPE_BUY)
      {
         price =
         SymbolInfoDouble(
            BrokerSymbol,
            SYMBOL_BID
         );
      }
      else
      {
         price =
         SymbolInfoDouble(
            BrokerSymbol,
            SYMBOL_ASK
         );
      }

      // HARDEN: skip corrupt price/point/bar data — do not manage blindly
      if(point <= 0.0 || !MathIsValidNumber(point))
         continue;
      if(price <= 0.0 || !MathIsValidNumber(price))
         continue;


      // How many bars has this position been open? Used to gate trailing/
      // trend-exit management so a fresh trade isn't immediately stopped
      // out or closed by noise (EnableLongTermHolding/MinimumHoldBars).
      //
      // Uses EntryTF (the EA's actual trading timeframe), not PERIOD_CURRENT.
      // PERIOD_CURRENT is whatever timeframe the chart the EA is attached to
      // happens to be showing - if the EA sits on an H4 chart but trades off
      // M15 (the default EntryTF), MinimumHoldBars=20 would mean 80 hours
      // instead of the intended ~5 hours, holding trades far longer than
      // configured before any protective management can act.
      //
      // Symbols matching NonScalpSymbolKeywords use NonScalpMinimumHoldBars
      // instead - same idea as the cooldown/SL widening: BTCUSD gets held
      // long enough to actually be a swing-style trade rather than being
      // eligible for trend-exit/trailing management after the same short
      // window used for forex pairs.
      int effectiveMinHoldBars = IsNonScalpSymbol() ? NonScalpMinimumHoldBars : MinimumHoldBars;

      // OK64: ContFallback / APEX / LCS are swing tags — force longer hold
      int stHold = FindTradeState(ticket);
      string holdTag = (stHold >= 0) ? TradeStates[stHold].strategyTag : "";
      bool swingTag = (holdTag == "ContFallback" || holdTag == "APEX" || holdTag == "LCS");
      if(EnableAntiScalpMode && swingTag)
         effectiveMinHoldBars = (int)MathMax(effectiveMinHoldBars, ContFallbackMinimumHoldBars);

      // UPGRADE: adapt the minimum hold requirement to the current market
      // regime - a ranging market doesn't reward the same patience a
      // genuine trend does, so require less time before management can
      // step in while ranging.
      bool allowAdaptiveHold = EnableAdaptiveHoldTime && EnableRegimeDetection && GetMarketRegime() == REGIME_RANGING;
      if(allowAdaptiveHold && ContFallbackDisableAdaptiveHold && swingTag)
         allowAdaptiveHold = false;
      if(allowAdaptiveHold)
         effectiveMinHoldBars = (int)MathMax(1.0, effectiveMinHoldBars * RangingHoldTimeFactor);

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int barsHeld = iBarShift(BrokerSymbol, EntryTF, openTime);
      if(barsHeld < 0)
         barsHeld = 0;
      bool holdPeriodOK = (!EnableLongTermHolding) || (barsHeld >= effectiveMinHoldBars);


      //================ MAX HOLD TIME (hard cap) =================//
      // UPGRADE: previously nothing forced a trade closed if it just sat
      // there indefinitely with none of trend-exit/trailing/TP ever
      // triggering. This is a simple backstop - regardless of every other
      // condition, a position this old gets closed.

      if(EnableMaxHoldBars && barsHeld >= MaxHoldBars)
      {
         Print("Max hold time reached (", barsHeld, " bars) - closing ticket ", ticket);
         trade.PositionClose(ticket);
         continue;
      }

      //================ MARKET DEFENSE =================//
      // Protect open trades against flips, chop, traps, and peak retrace.
      int defendState = FindTradeState(ticket);
      if(EnableMarketDefense)
      {
         if(MarketDefendOpenPosition(ticket, type, openPrice, price, currentSL, currentTP, defendState))
            continue; // position closed by defense
         // refresh after possible SL modify
         if(!PositionSelectByTicket(ticket))
            continue;
         currentSL = PositionGetDouble(POSITION_SL);
         currentTP = PositionGetDouble(POSITION_TP);
      }


      //================ BREAK EVEN =================//
      // (Break-even stays active in BOTH fixed and dynamic management
      // modes - "Fixed Break-Even" is explicitly kept per your P.R.I.S.M.
      // spec even with trailing/partial-close disabled.)

      if(EnableBreakEven)
      {
         double breakEvenDistance = GetBreakEvenDistance(point);

         if(type == POSITION_TYPE_BUY)
         {

            if(price - openPrice >= breakEvenDistance)
            {

               if(currentSL < openPrice)
               {
                  if(trade.PositionModify(ticket, openPrice, currentTP))
                     currentSL = openPrice;
               }

            }

         }



         if(type == POSITION_TYPE_SELL)
         {

            if(openPrice - price >= breakEvenDistance)
            {

               if(currentSL > openPrice || currentSL == 0)
               {
                  if(trade.PositionModify(ticket, openPrice, currentTP))
                     currentSL = openPrice;
               }

            }

         }

      }



      //================ TP1 SCALE-OUT + PROFIT LOCK → TP2 ================//
      // BUGFIX40: no false pre-entry TP touch; failed partial does not advance;
      // EnableTP3Runner honored for post-TP1 broker TP; skip trail same tick.

      bool ladderActedThisTick = false;

      if(ProfitLadderActive())
      {
      int stateIndex = FindTradeState(ticket);

      if(stateIndex >= 0 && !TradeStates[stateIndex].tp1Taken)
      {
         bool tp1Hit = LevelTouchedForTP((type == POSITION_TYPE_BUY),
                                         TradeStates[stateIndex].tp1Price, price, barsHeld);

         if(tp1Hit)
         {
            double currentVolume = PositionGetDouble(POSITION_VOLUME);

            double volumeStep = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_STEP);
            double minVolume  = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_MIN);

            double closeVolume = currentVolume * (TP1_ClosePercent / 100.0);

            if(volumeStep > 0)
               closeVolume = MathFloor(closeVolume / volumeStep) * volumeStep;

            double remainder = currentVolume - closeVolume;
            bool advanceLadder = false;
            bool didPartial = false;

            if(closeVolume >= minVolume && remainder >= minVolume)
            {
               if(trade.PositionClosePartial(ticket, closeVolume))
               {
                  Print("TP1 hit: closed ", DoubleToString(closeVolume,2),
                        " lots of ticket ", ticket, " — locking profit, remainder → TP2");
                  advanceLadder = true;
                  didPartial = true;
               }
               else
               {
                  Print("TP1 partial close failed on ticket ", ticket, ": ",
                        trade.ResultRetcodeDescription(), " — will retry next tick");
               }
            }
            else if(remainder < minVolume && currentVolume >= minVolume && closeVolume >= minVolume)
            {
               if(trade.PositionClose(ticket))
               {
                  Print("TP1 hit but position too small to split - closed in full: ", ticket);
                  TradeStates[stateIndex].tp1Taken = true;
                  DeleteTradeStateGlobals(ticket);
                  continue;
               }
            }
            else
            {
               // Min lot: cannot partial — still lock SL and advance (intentional)
               Print("TP1 hit at min lot — locking SL into profit, advancing to TP2: ", ticket);
               advanceLadder = true;
            }

            if(advanceLadder)
            {
               // SAFE42: lock must succeed; if partial already done, still set flag
               // so we never partial twice — lock retries via needsLock path below.
               double nextTP = TradeStates[stateIndex].tp2Price;
               if(EnableTP3Runner && TradeStates[stateIndex].tp3Price > 0.0)
                  nextTP = TradeStates[stateIndex].tp3Price;

               bool locked = ApplyProfitLockSL(ticket,
                                 (type == POSITION_TYPE_BUY),
                                 openPrice,
                                 TradeStates[stateIndex].tp1Price,
                                 LockProfitAtTP1_Fraction,
                                 nextTP,
                                 true);
               if(locked || didPartial)
               {
                  TradeStates[stateIndex].tp1Taken = true;
                  PersistTradeState(stateIndex);
                  ladderActedThisTick = true;
                  if(locked)
                     Print("SURE LADDER: TP1 secured → now hunting TP2 on ticket ", ticket);
                  else
                     Print("SAFE: TP1 partial done, lock pending retry on ticket ", ticket);
               }
               else
               {
                  Print("SAFE: TP1 lock FAILED on ticket ", ticket,
                        " — will retry next tick (flag not set)");
               }
            }
         }
      }

      // SAFE42: if TP1 was marked earlier but SL never locked, retry lock every tick
      if(stateIndex >= 0 && TradeStates[stateIndex].tp1Taken && SecureProfitOnTPHit)
      {
         if(PositionSelectByTicket(ticket))
         {
            double liveSL = PositionGetDouble(POSITION_SL);
            double wantSL = ComputeProfitLockSL((type == POSITION_TYPE_BUY), openPrice,
                                                TradeStates[stateIndex].tp1Price,
                                                LockProfitAtTP1_Fraction, liveSL);
            bool needsLock = (type == POSITION_TYPE_BUY)
               ? (liveSL < wantSL - SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT))
               : (liveSL == 0.0 || liveSL > wantSL + SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT));
            if(needsLock && !TradeStates[stateIndex].tp2Taken)
            {
               double nextTP = TradeStates[stateIndex].tp2Price;
               if(EnableTP3Runner && TradeStates[stateIndex].tp3Price > 0.0)
                  nextTP = TradeStates[stateIndex].tp3Price;
               if(ApplyProfitLockSL(ticket, (type == POSITION_TYPE_BUY), openPrice,
                                    TradeStates[stateIndex].tp1Price,
                                    LockProfitAtTP1_Fraction, nextTP, true))
               {
                  ladderActedThisTick = true;
                  Print("SAFE: retried TP1 profit lock OK on ticket ", ticket);
               }
            }
         }
      }



      //================ TP2 SCALE-OUT + PROFIT LOCK → TP3 / TRAIL =========//
      if(stateIndex >= 0 && TradeStates[stateIndex].tp1Taken && !TradeStates[stateIndex].tp2Taken
         && TradeStates[stateIndex].tp2Price > 0.0)
      {
         // When EnableTP3Runner=false, TP2 is the final target: lock + leave TP at TP2
         bool tp2Hit = LevelTouchedForTP((type == POSITION_TYPE_BUY),
                                         TradeStates[stateIndex].tp2Price, price, barsHeld);

         if(tp2Hit)
         {
            double currentVolume2 = PositionGetDouble(POSITION_VOLUME);

            double volumeStep2 = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_STEP);
            double minVolume2  = SymbolInfoDouble(BrokerSymbol, SYMBOL_VOLUME_MIN);

            double closeVolume2 = currentVolume2 * (TP2_ClosePercent / 100.0);

            if(volumeStep2 > 0)
               closeVolume2 = MathFloor(closeVolume2 / volumeStep2) * volumeStep2;

            double remainder2 = currentVolume2 - closeVolume2;
            bool advanceTP2 = false;
            bool didPartial2 = false;

            if(closeVolume2 >= minVolume2 && remainder2 >= minVolume2)
            {
               if(trade.PositionClosePartial(ticket, closeVolume2))
               {
                  Print("TP2 hit: closed ", DoubleToString(closeVolume2,2),
                        " lots of ticket ", ticket, " — locking more profit, runner → TP3/trail");
                  advanceTP2 = true;
                  didPartial2 = true;
               }
               else
               {
                  Print("TP2 partial close failed on ticket ", ticket, ": ",
                        trade.ResultRetcodeDescription(), " — will retry next tick");
               }
            }
            else if(remainder2 < minVolume2 && currentVolume2 >= minVolume2 && closeVolume2 >= minVolume2)
            {
               // BUGFIX40: mirror TP1 — can't leave dust remainder
               if(trade.PositionClose(ticket))
               {
                  Print("TP2 hit but position too small to split - closed in full: ", ticket);
                  TradeStates[stateIndex].tp2Taken = true;
                  DeleteTradeStateGlobals(ticket);
                  continue;
               }
            }
            else
            {
               Print("TP2 hit at min lot — lock SL further, activate runner: ", ticket);
               advanceTP2 = true;
            }

            if(advanceTP2)
            {
               bool lockOK = false;
               if(PositionSelectByTicket(ticket))
               {
                  if(!EnableTP3Runner)
                  {
                     lockOK = ApplyProfitLockSL(ticket,
                                       (type == POSITION_TYPE_BUY),
                                       openPrice,
                                       TradeStates[stateIndex].tp2Price,
                                       LockProfitAtTP2_Fraction,
                                       TradeStates[stateIndex].tp2Price,
                                       true);
                     if(lockOK)
                        Print("SURE LADDER: TP2 secured as final target on ticket ", ticket);
                  }
                  else if(EnableTrailing)
                  {
                     lockOK = ApplyProfitLockSL(ticket,
                                       (type == POSITION_TYPE_BUY),
                                       openPrice,
                                       TradeStates[stateIndex].tp2Price,
                                       LockProfitAtTP2_Fraction,
                                       0.0,
                                       true);
                     if(PositionSelectByTicket(ticket))
                     {
                        double curSL2 = PositionGetDouble(POSITION_SL);
                        double tp1Lock = TradeStates[stateIndex].tp1Price;
                        bool needRaise = (type == POSITION_TYPE_BUY)
                           ? (curSL2 < tp1Lock)
                           : (curSL2 == 0.0 || curSL2 > tp1Lock);
                        if(needRaise)
                        {
                           if(trade.PositionModify(ticket, tp1Lock, 0.0))
                              lockOK = true;
                        }
                        else
                        {
                           double curTP2 = PositionGetDouble(POSITION_TP);
                           if(curTP2 > 0.0)
                              trade.PositionModify(ticket, curSL2, 0.0);
                           lockOK = true; // SL already at/above TP1
                        }
                     }
                     if(lockOK)
                        Print("SURE LADDER: TP2 secured → trailing runner on ticket ", ticket);
                  }
                  else
                  {
                     double nextTP = TradeStates[stateIndex].tp3Price;
                     lockOK = ApplyProfitLockSL(ticket,
                                       (type == POSITION_TYPE_BUY),
                                       openPrice,
                                       TradeStates[stateIndex].tp2Price,
                                       LockProfitAtTP2_Fraction,
                                       nextTP,
                                       true);
                     if(PositionSelectByTicket(ticket))
                     {
                        double curSL2 = PositionGetDouble(POSITION_SL);
                        double tp1Lock = TradeStates[stateIndex].tp1Price;
                        double curTP2 = PositionGetDouble(POSITION_TP);
                        bool needRaise = (type == POSITION_TYPE_BUY)
                           ? (curSL2 < tp1Lock)
                           : (curSL2 == 0.0 || curSL2 > tp1Lock);
                        if(needRaise)
                           trade.PositionModify(ticket, tp1Lock, curTP2);
                     }
                     if(lockOK)
                        Print("SURE LADDER: TP2 secured → hunting TP3 on ticket ", ticket);
                  }
               }

               // SAFE42: mark taken if lock OK OR partial already done (avoid double partial)
               if(lockOK || didPartial2)
               {
                  TradeStates[stateIndex].tp2Taken = true;
                  PersistTradeState(stateIndex);
                  ladderActedThisTick = true;
                  if(!lockOK)
                     Print("SAFE: TP2 partial done, lock pending — ticket ", ticket);
               }
               else
               {
                  Print("SAFE: TP2 lock FAILED on ticket ", ticket,
                        " — will retry next tick (flag not set)");
               }
            }
         }
      }

      // AUDITFIX49: TP2 lock retry (mirror TP1 SAFE42) when partial done but SL not locked
      if(stateIndex >= 0 && TradeStates[stateIndex].tp2Taken && SecureProfitOnTPHit)
      {
         if(PositionSelectByTicket(ticket))
         {
            double liveSL2 = PositionGetDouble(POSITION_SL);
            double wantSL2 = ComputeProfitLockSL((type == POSITION_TYPE_BUY), openPrice,
                                                 TradeStates[stateIndex].tp2Price,
                                                 LockProfitAtTP2_Fraction, liveSL2);
            bool needsLock2 = (type == POSITION_TYPE_BUY)
               ? (liveSL2 < wantSL2 - SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT))
               : (liveSL2 == 0.0 || liveSL2 > wantSL2 + SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT));
            if(needsLock2)
            {
               double nextTP2 = 0.0;
               bool applyTP = true;
               if(!EnableTP3Runner)
                  nextTP2 = TradeStates[stateIndex].tp2Price;
               else if(EnableTrailing)
                  nextTP2 = 0.0;
               else
                  nextTP2 = TradeStates[stateIndex].tp3Price;

               if(ApplyProfitLockSL(ticket, (type == POSITION_TYPE_BUY), openPrice,
                                    TradeStates[stateIndex].tp2Price,
                                    LockProfitAtTP2_Fraction, nextTP2, applyTP))
               {
                  ladderActedThisTick = true;
                  Print("SAFE: retried TP2 profit lock OK on ticket ", ticket);
               }
            }
         }
      }
      } // end sure profit ladder (TP1 → lock → TP2 → lock → TP3/trail)



      //================ STAGNATION EXIT (UPGRADE) =================//
      // BUGFIX40: skip once TP1 profit is locked — current P/L distance is NOT
      // MFE and was killing pullback runners after a successful TP1 bank.

      int stagState = FindTradeState(ticket);
      bool profitAlreadyLocked = (stagState >= 0 && TradeStates[stagState].tp1Taken);

      if(EnableStagnationExit && barsHeld >= StagnationLookbackBars && !profitAlreadyLocked)
      {
         double atrNow = GetFilterATR();

         if(atrNow > 0.0)
         {
            double favorableMove = (type == POSITION_TYPE_BUY) ? (price - openPrice) : (openPrice - price);

            if(favorableMove < atrNow * StagnationProgressATRMultiple)
            {
               Print("Stagnation exit: ticket ", ticket, " has made no real progress after ",
                     barsHeld, " bars - closing.");
               trade.PositionClose(ticket);
               continue;
            }
         }
      }



      //================ TREND EXIT (ADX) =================//
      // Closes the position if the trend has lost strength, once the
      // minimum hold period has passed. Skipped for non-scalp symbols
      // (BTC/ETH by default) unless NonScalpDisableTrendExit is turned off.

      bool trendExitAllowed = EnableTrendExit && !(IsNonScalpSymbol() && NonScalpDisableTrendExit);

      if(trendExitAllowed && holdPeriodOK)
      {
         if(GetADX() < TrendExitADXLevel)
         {
            Print("Trend exit: ADX below ", TrendExitADXLevel, ", closing ticket ", ticket);
            trade.PositionClose(ticket);
            continue;
         }
      }



      //================ TRAILING STOP =================//
      // BUGFIX40: skip same tick as ladder lock (stale currentSL was loosening
      // the just-secured profit SL). Re-read live SL before comparing.

      // Trail always after TP1 profit-lock (aggressive); otherwise wait for hold period
      int trailStateGate = FindTradeState(ticket);
      bool trailAfterLock = (ProfitLadderActive() && trailStateGate >= 0 &&
                             TradeStates[trailStateGate].tp1Taken);
      if(!ladderActedThisTick &&
         (!UseFixedTradeManagement || ForceSureProfitLadder) &&
         EnableTrailing && (holdPeriodOK || trailAfterLock))
      {
         // Refresh SL/TP after possible ladder modifies earlier in this loop
         if(!PositionSelectByTicket(ticket))
            continue;
         currentSL = PositionGetDouble(POSITION_SL);
         currentTP = PositionGetDouble(POSITION_TP);

         double newSL;

         double trailingDistance = TrailingPoints * point;

         if(EnableATRTrailing)
         {
            double atr = GetFilterATR();

            if(atr > 0.0)
            {
               bool afterTP1 = trailAfterLock;
               double trailMult = (ProfitLadderActive() && afterTP1)
                  ? AggressiveTrailATRMult
                  : ATR_TrailingMultiplier;
               trailingDistance = atr * trailMult;
            }
         }



         if(type == POSITION_TYPE_BUY)
         {

            newSL =
            price - trailingDistance;


            long stopLevel =
SymbolInfoInteger(
   BrokerSymbol,
   SYMBOL_TRADE_STOPS_LEVEL
);


double minimumDistance =
stopLevel * point;


if((price - newSL) >= minimumDistance)
{
   newSL = NormalizeTradePrice(newSL);


   if(newSL > currentSL)
   {
      if(trade.PositionModify(ticket, newSL, currentTP))
         currentSL = newSL;
   }
}

         }



         if(type == POSITION_TYPE_SELL)
         {

            newSL =
            price + trailingDistance;


            long stopLevel =
SymbolInfoInteger(
   BrokerSymbol,
   SYMBOL_TRADE_STOPS_LEVEL
);


double minimumDistance =
stopLevel * point;


if((newSL - price) >= minimumDistance)
{
   newSL = NormalizeTradePrice(newSL);


   if(newSL < currentSL || currentSL == 0)
   {
      if(trade.PositionModify(ticket, newSL, currentTP))
         currentSL = newSL;
   }
}
         }

      }

   }

}
//+------------------------------------------------------------------+
//|              PART 11 - ADVANCED MARKET FILTERS                   |
//+------------------------------------------------------------------+

//================ FILTER SETTINGS ==================================//

input bool EnableVolatilityFilter = false;

input int ATR_Filter_Period = 14;

input double MinimumATRPoints = 20;


//================ INITIALIZE FILTER =================================//

bool InitializeMarketFilters()
{
   // Per-symbol, same pattern as InitializeIndicators() - loops over
   // MultiSymbolList instead of creating a single handle for BrokerSymbol.

   for(int i = 0; i < ArraySize(MultiSymbolList); i++)
   {
      FilterATRHandles[i] = iATR(MultiSymbolList[i], EntryTF, ATR_Filter_Period);

      if(FilterATRHandles[i] == INVALID_HANDLE)
      {
         Print("Market Filter ATR failed for ", MultiSymbolList[i]);
         return false;
      }
   }

   return true;

}


//================ GET ATR ===========================================//

double GetFilterATR()
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0 || FilterATRHandles[idx] == INVALID_HANDLE)
      return 0;

   double atr[];

   ArraySetAsSeries(
      atr,
      true
   );


   if(CopyBuffer(
      FilterATRHandles[idx],
      0,
      0,
      1,
      atr
   ) <= 0)
   {
      return 0;
   }

   // HARDEN: refuse EMPTY_VALUE / NaN as a usable ATR
   if(!MathIsValidNumber(atr[0]) || atr[0] == EMPTY_VALUE || atr[0] <= 0.0)
      return 0;

   return atr[0];

}


//================ MARKET CONDITION CHECK ============================//

bool MarketConditionOK()
{

   // Volatility filter disabled
   if(!EnableVolatilityFilter)
   {
      return true;
   }


   double atr =
   GetFilterATR();


   double point =
   SymbolInfoDouble(
      BrokerSymbol,
      SYMBOL_POINT
   );


   if(point <= 0)
      return true;


   double atrPoints =
   atr / point;


   if(atrPoints < MinimumATRPoints)
   {
      if(EnableVerboseLogging)
         Print("Market blocked: Low volatility");
      return false;
   }


   return true;

}

//================ VOLATILITY EXPANSION FILTER ========================//
// FIX/UPGRADE: EnableVolatilityFilter above only checks "is ATR above a
// fixed number" - a static threshold that means something different on
// every symbol and never adapts to changing conditions. This is a
// genuinely different signal: is volatility EXPANDING right now, relative
// to its own recent history? Compares current ATR to the average ATR over
// the last VolatilityExpansionLookback bars - a ratio meaningfully above 1
// means volatility is actively picking up (the kind of environment SMC
// setups tend to work better in), not just "high" by some arbitrary
// fixed number.

input group "VOLATILITY EXPANSION FILTER"

input bool   EnableVolatilityExpansionFilter = false;
input int    VolatilityExpansionLookback     = 20;
input double VolatilityExpansionMultiplier   = 1.2;

bool IsVolatilityExpanding()
{
   if(!EnableVolatilityExpansionFilter)
      return false; // filter off - contributes nothing to score, doesn't block anything

   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0 || FilterATRHandles[idx] == INVALID_HANDLE)
      return false;

   double atrHistory[];
   ArraySetAsSeries(atrHistory, true);

   int needed = VolatilityExpansionLookback + 1;

   if(CopyBuffer(FilterATRHandles[idx], 0, 0, needed, atrHistory) < needed)
      return false; // not enough history yet - fail safe, don't award the score bonus

   double currentATR = atrHistory[0];

   double sum = 0.0;

   for(int i = 1; i <= VolatilityExpansionLookback; i++)
      sum += atrHistory[i];

   double avgATR = sum / VolatilityExpansionLookback;

   if(avgATR <= 0.0)
      return false;

   return (currentATR >= avgATR * VolatilityExpansionMultiplier);
}

// NEW (this pass): the complement of the expansion check above. A
// volatility CONTRACTION (current ATR meaningfully below its own recent
// average) typically precedes a breakout - useful as context even though
// it points the opposite direction from "trade now": it's a reason to
// expect a move is coming, not evidence a move is already underway. Not
// wired into the trade score as a bonus (that would fight the expansion
// filter's logic); exposed for diagnostics/dashboard and for the
// volatility-breakout strategy setups, which specifically want to know
// "are we coiled" before a range/channel break.
input double VolatilityContractionMultiplier = 0.7;

bool IsVolatilityContracting()
{
   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0 || FilterATRHandles[idx] == INVALID_HANDLE)
      return false;

   double atrHistory[];
   ArraySetAsSeries(atrHistory, true);

   int needed = VolatilityExpansionLookback + 1;
   if(CopyBuffer(FilterATRHandles[idx], 0, 0, needed, atrHistory) < needed)
      return false;

   double currentATR = atrHistory[0];
   double sum = 0.0;
   for(int i = 1; i <= VolatilityExpansionLookback; i++)
      sum += atrHistory[i];

   double avgATR = sum / VolatilityExpansionLookback;
   if(avgATR <= 0.0)
      return false;

   return (currentATR <= avgATR * VolatilityContractionMultiplier);
}
//+------------------------------------------------------------------+
//|              PART 12 - SMART MONEY CONCEPTS ENGINE               |
//+------------------------------------------------------------------+

//================ SMC SETTINGS =====================================//

input int StructureLookback = 20;
input int SwingBars = 3; // REDUCED from 5 per request - a swing point needed 4 clean bars on each side to confirm at 5, which is genuinely rare. At 3, swing points (and therefore BOS/liquidity-sweep reference levels) register more often. Tradeoff: each individual swing point is less significant/confirmed than before - more opportunities, slightly lower bar for what counts as "structure."

// FIX #1 - TIMEFRAME MISMATCH: every function in this section used to read
// PERIOD_CURRENT, which is whatever timeframe the chart the EA happens to
// be attached to is showing - not EntryTF, the timeframe the EA actually
// trades off (M15 by default). Attach this EA to an H4 chart and every BOS/
// FVG/order-block/liquidity-sweep read was silently analyzing H4 structure
// while the EA executed as if it were M15 structure. This is the exact
// same class of bug already fixed for barsHeld() in ManageOpenTrades() -
// now applied consistently here too. All iHigh/iLow/iClose/iOpen calls
// below use EntryTF explicitly.


//================ GET HIGH ==========================================//

double GetRecentHigh(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   // FIX #2 - INCOMPLETE CANDLE: the old loop let i-j reach 0, which is the
   // currently-forming (unclosed) bar. Validating a "confirmed" swing high
   // against a candle whose high can still move intrabar means the signal
   // could repaint - true one tick, false the next, on the same bar. j now
   // stops one bar short so index 0 is never touched; only fully closed
   // bars (index 1+) count as confirmation.
   //
   // tf defaults to PERIOD_CURRENT as a sentinel (MQL5 default params must
   // be compile-time constants, so it can't default directly to the
   // EntryTF input) - mapped to EntryTF below. Passing an explicit
   // timeframe (e.g. HigherTimeframe) is what makes multi-timeframe
   // confluence possible without duplicating this whole function.

   ENUM_TIMEFRAMES workingTF = (tf == PERIOD_CURRENT) ? EntryTF : tf;

   // PERFORMANCE: cache the EntryTF result once per decision cycle per
   // symbol - see SwingCacheCycleArr declaration above. Only the EntryTF
   // path is cached; explicit-timeframe (HTF) calls fall through uncached
   // since they run far less often.
   bool cacheable = (workingTF == EntryTF);
   int idx = cacheable ? GetSymbolIndex(BrokerSymbol) : -1;

   if(cacheable && idx >= 0 && idx < ArraySize(SwingHighCacheCycleArr) && SwingHighCacheCycleArr[idx] == (long)g_CycleCounter)
      return SwingHighCacheArr[idx];

   double result = EMPTY_VALUE;

   for(int i = SwingBars; i < StructureLookback; i++)
   {
      bool swing = true;

      double high = iHigh(BrokerSymbol, workingTF, i);
      if(!MathIsValidNumber(high) || high <= 0.0 || high == EMPTY_VALUE)
         continue;

      for(int j = 1; j < SwingBars; j++)
      {
         double hj = iHigh(BrokerSymbol, workingTF, i-j);
         double hk = iHigh(BrokerSymbol, workingTF, i+j);
         if(!MathIsValidNumber(hj) || !MathIsValidNumber(hk) || hj <= 0.0 || hk <= 0.0)
         {
            swing = false;
            break;
         }
         if(high <= hj || high <= hk)
         {
            swing = false;
            break;
         }
      }

      if(swing)
      {
         result = high;
         break;
      }
   }

   if(cacheable && idx >= 0 && idx < ArraySize(SwingHighCacheCycleArr))
   {
      SwingHighCacheCycleArr[idx] = (long)g_CycleCounter;
      SwingHighCacheArr[idx]      = result;
   }

   return result;
}


//================ GET LOW ===========================================//

double GetRecentLow(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   // Same incomplete-candle fix and timeframe-parameter pattern as
   // GetRecentHigh() above.

   ENUM_TIMEFRAMES workingTF = (tf == PERIOD_CURRENT) ? EntryTF : tf;

   bool cacheable = (workingTF == EntryTF);
   int idx = cacheable ? GetSymbolIndex(BrokerSymbol) : -1;

   if(cacheable && idx >= 0 && idx < ArraySize(SwingLowCacheCycleArr) && SwingLowCacheCycleArr[idx] == (long)g_CycleCounter)
      return SwingLowCacheArr[idx];

   double result = EMPTY_VALUE;

   for(int i = SwingBars; i < StructureLookback; i++)
   {
      bool swing = true;

      double low = iLow(BrokerSymbol, workingTF, i);
      if(!MathIsValidNumber(low) || low <= 0.0 || low == EMPTY_VALUE)
         continue;

      for(int j = 1; j < SwingBars; j++)
      {
         double lj = iLow(BrokerSymbol, workingTF, i-j);
         double lk = iLow(BrokerSymbol, workingTF, i+j);
         if(!MathIsValidNumber(lj) || !MathIsValidNumber(lk) || lj <= 0.0 || lk <= 0.0)
         {
            swing = false;
            break;
         }
         if(low >= lj || low >= lk)
         {
            swing = false;
            break;
         }
      }

      if(swing)
      {
         result = low;
         break;
      }
   }

   if(cacheable && idx >= 0 && idx < ArraySize(SwingLowCacheCycleArr))
   {
      SwingLowCacheCycleArr[idx] = (long)g_CycleCounter;
      SwingLowCacheArr[idx]      = result;
   }

   return result;
}


// MULTI-SWING VALIDATION HELPERS (this pass): GetRecentHigh()/GetRecentLow()
// return only the single nearest confirmed swing point. A CHoCH built off
// just that one point can be tripped by one noisy, barely-qualifying swing.
// These walk past the first swing found and return the NEXT one further
// back, so a break can be checked against two independent swing points
// instead of one. Deliberately NOT cached (called far less often than the
// primary swing lookup - only during an actual CHoCH candidate, not every
// cycle).
double GetSecondRecentHigh(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   ENUM_TIMEFRAMES workingTF = (tf == PERIOD_CURRENT) ? EntryTF : tf;
   bool foundFirst = false;

   for(int i = SwingBars; i < StructureLookback; i++)
   {
      bool swing = true;
      double high = iHigh(BrokerSymbol, workingTF, i);

      for(int j = 1; j < SwingBars; j++)
      {
         if(high <= iHigh(BrokerSymbol, workingTF, i-j) || high <= iHigh(BrokerSymbol, workingTF, i+j))
         { swing = false; break; }
      }

      if(swing)
      {
         if(!foundFirst) { foundFirst = true; continue; }
         return high;
      }
   }

   return EMPTY_VALUE;
}

double GetSecondRecentLow(ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   ENUM_TIMEFRAMES workingTF = (tf == PERIOD_CURRENT) ? EntryTF : tf;
   bool foundFirst = false;

   for(int i = SwingBars; i < StructureLookback; i++)
   {
      bool swing = true;
      double low = iLow(BrokerSymbol, workingTF, i);

      for(int j = 1; j < SwingBars; j++)
      {
         if(low >= iLow(BrokerSymbol, workingTF, i-j) || low >= iLow(BrokerSymbol, workingTF, i+j))
         { swing = false; break; }
      }

      if(swing)
      {
         if(!foundFirst) { foundFirst = true; continue; }
         return low;
      }
   }

   return EMPTY_VALUE;
}

//================ PREMIUM / DISCOUNT ZONE ============================//
// NEW (from P.R.I.S.M. manual review): this concept did not exist
// anywhere in the EA before. The idea is simple and well-defined enough
// to add safely as an opt-in filter without recreating the "gate that
// never fires" problem: split the current swing range in half (the
// equilibrium/50% level) and only take buys in the lower (discount)
// half, sells in the upper (premium) half. This avoids buying into an
// already-extended move or selling into an already-cheap one. Off by
// default - turn on deliberately.

input bool EnablePremiumDiscountFilter = false;

// FINE-TUNE (this pass): a flat 50% equilibrium split treats a quiet range
// and a strongly trending leg identically. In a genuine strong trend, price
// spends most of its time in what a static midpoint calls "premium" (for
// an uptrend) simply because it's making higher highs faster than the
// range midpoint can catch up - a strict 50/50 gate would reject most
// continuation entries in exactly the condition SMC trend-following is
// supposed to work best in. During a confirmed strong trend (TrendStrong()
// - ADX/EMA-slope based, already computed elsewhere), the zone boundary
// shifts in the trend's favor instead of staying pinned at the midpoint:
// buys are allowed further up into the range in a strong uptrend, sells
// further down in a strong downtrend. Ranging/weak-trend conditions keep
// the original strict 50/50 split.
input double StrongTrendZoneBiasPercent = 20.0; // how far (in % of range) the accepted zone boundary shifts in the trend's favor during a confirmed strong trend

double GetEquilibrium()
{
   double high = GetRecentHigh();
   double low  = GetRecentLow();

   if(high == EMPTY_VALUE || low == EMPTY_VALUE)
      return EMPTY_VALUE;

   return (high + low) / 2.0;
}

bool InDiscountZone() // lower half of the range - where buys are preferred
{
   double high = GetRecentHigh();
   double low  = GetRecentLow();

   if(high == EMPTY_VALUE || low == EMPTY_VALUE)
      return true; // fail open - don't block trading just because range data isn't ready

   double range = high - low;
   double boundary = (high + low) / 2.0;

   // In a strong uptrend, allow buys further up into the range rather than
   // strictly below the 50% midpoint - continuation entries shouldn't be
   // penalized just for the trend having already moved.
   if(range > 0.0 && TrendStrong() && IsBullTrend())
      boundary = low + range * MathMin(0.95, 0.5 + StrongTrendZoneBiasPercent / 100.0);

   return SymbolInfoDouble(BrokerSymbol, SYMBOL_BID) < boundary;
}

bool InPremiumZone() // upper half of the range - where sells are preferred
{
   double high = GetRecentHigh();
   double low  = GetRecentLow();

   if(high == EMPTY_VALUE || low == EMPTY_VALUE)
      return true;

   double range = high - low;
   double boundary = (high + low) / 2.0;

   // Mirror image for a strong downtrend: allow sells further down into the
   // range rather than strictly above the 50% midpoint.
   if(range > 0.0 && TrendStrong() && IsBearTrend())
      boundary = high - range * MathMin(0.95, 0.5 + StrongTrendZoneBiasPercent / 100.0);

   return SymbolInfoDouble(BrokerSymbol, SYMBOL_BID) > boundary;
}


//================ PRIOR DAY / WEEK LIQUIDITY LEVELS ==================//
// NEW (from P.R.I.S.M. manual review): the EA's liquidity/sweep logic
// only ever looked at swing highs/lows on the entry timeframe. Previous
// day and previous week highs/lows are genuinely different, commonly
// watched liquidity levels that weren't tracked anywhere. Added as a
// small, additive SCORE BONUS (not a hard gate) when price is trading
// close to one of these levels in the trade's direction - same
// "distance to liquidity" idea the manual describes, without adding
// another AND-condition that could choke off trades.

double GetPreviousDayHigh() { return iHigh(BrokerSymbol, PERIOD_D1, 1); }
double GetPreviousDayLow()  { return iLow(BrokerSymbol, PERIOD_D1, 1);  }
double GetPreviousWeekHigh(){ return iHigh(BrokerSymbol, PERIOD_W1, 1); }
double GetPreviousWeekLow() { return iLow(BrokerSymbol, PERIOD_W1, 1);  }

input double LiquidityProximityATRMultiple = 0.5; // how close price must be to a prior D1/W1 level to count as "near liquidity"

int GetLiquidityProximityScore(bool buy)
{
   double atr = GetFilterATR();

   if(atr <= 0.0)
      return 0;

   double threshold = atr * LiquidityProximityATRMultiple;
   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);

   double pdh = GetPreviousDayHigh();
   double pdl = GetPreviousDayLow();
   double pwh = GetPreviousWeekHigh();
   double pwl = GetPreviousWeekLow();

   int score = 0;

   if(buy)
   {
      // Buying near recently-swept sell-side liquidity (a prior low) is
      // the higher-quality location per the manual's liquidity model.
      if(pdl > 0 && MathAbs(price - pdl) <= threshold) score += 5;
      if(pwl > 0 && MathAbs(price - pwl) <= threshold) score += 5; // weekly level carries more weight
   }
   else
   {
      if(pdh > 0 && MathAbs(price - pdh) <= threshold) score += 5;
      if(pwh > 0 && MathAbs(price - pwh) <= threshold) score += 5;
   }

   return score; // 0-10 bonus points
}

// STRENGTHENED: previously any close even a single tick beyond the swing
// level counted as a full break of structure. That's indistinguishable
// from noise/spread wobble right at the level. Now the close has to clear
// the swing level by a minimum ATR-scaled margin, so only decisive breaks
// count - the same standard already applied to the order-block impulse
// filter.

input double BOS_MinBreakATRMultiple = 0.1; // CHANGED: was 0.0, which made this a no-op (any break of any size passed) despite the comment above describing it as a real filter. 0.1 requires a break to actually clear the level by a small but real margin, not just noise.

// FURTHER FINE-TUNE (this pass): the ATR-margin break requirement already
// filters ordinary noise, but a single decisive close beyond the level can
// still be a one-bar spike that immediately gets reclaimed (a false break/
// liquidity grab rather than a genuine structure shift). Optional second
// stage: when enabled, also requires the PREVIOUS closed bar (index 2) to
// already be positioned on the breakout side of the level (not just the
// most recent close), i.e. two consecutive closes confirming the same
// side. Off by default so behavior doesn't change unless deliberately
// tightened.
input bool BOS_RequireTwoBarConfirmation = false; // require 2 consecutive closes beyond the level, not just 1, to further cut false breaks

bool DetectBOS()
{
   int idx = GetSymbolIndex(BrokerSymbol);

   // PERFORMANCE: cache once per decision cycle per symbol - DetectBOS() is
   // called from CalculateTradeScore(), HasStructureConfluence(),
   // diagnostics and signal-snapshot capture, several times per cycle.
   if(idx >= 0 && idx < ArraySize(BOS_CacheCycleArr) && BOS_CacheCycleArr[idx] == (long)g_CycleCounter)
      return BOS_CacheResultArr[idx];

   bool result = false;

   double swingHigh = GetRecentHigh();
   double swingLow  = GetRecentLow();

   if(swingHigh != EMPTY_VALUE && swingLow != EMPTY_VALUE)
   {
      double close1 = iClose(BrokerSymbol, EntryTF, 1);
      double close2 = iClose(BrokerSymbol, EntryTF, 2);
      double close3 = iClose(BrokerSymbol, EntryTF, 3);

      double atr = GetFilterATR();
      double minBreakMargin = (atr > 0.0) ? (atr * BOS_MinBreakATRMultiple) : 0.0;

      // Bullish BOS - with two-bar confirmation on, the "before" reference
      // shifts back one bar (close3) and BOTH of the last two closed bars
      // (close2 and close1) must be beyond the level, instead of just the
      // single most recent close.
      bool bullBreak = !BOS_RequireTwoBarConfirmation
         ? (close2 <= swingHigh && close1 > swingHigh + minBreakMargin)
         : (close3 <= swingHigh && close2 > swingHigh + minBreakMargin && close1 > swingHigh + minBreakMargin);

      if(bullBreak)
      {
         if(EnableVerboseLogging) Print("Bullish BOS confirmed");
         if(idx >= 0 && idx < ArraySize(LastBOSTrueBarTimeArr))
            LastBOSTrueBarTimeArr[idx] = iTime(BrokerSymbol, EntryTF, 1);
         result = true;
      }

      // Bearish BOS
      if(!result)
      {
         bool bearBreak = !BOS_RequireTwoBarConfirmation
            ? (close2 >= swingLow && close1 < swingLow - minBreakMargin)
            : (close3 >= swingLow && close2 < swingLow - minBreakMargin && close1 < swingLow - minBreakMargin);

         if(bearBreak)
         {
            if(EnableVerboseLogging) Print("Bearish BOS confirmed");
            if(idx >= 0 && idx < ArraySize(LastBOSTrueBarTimeArr))
               LastBOSTrueBarTimeArr[idx] = iTime(BrokerSymbol, EntryTF, 1);
            result = true;
         }
      }
   }

   if(idx >= 0 && idx < ArraySize(BOS_CacheCycleArr))
   {
      BOS_CacheCycleArr[idx]  = (long)g_CycleCounter;
      BOS_CacheResultArr[idx] = result;
   }

   return result;
}

//================ MULTI-TIMEFRAME SMC CONFLUENCE (UPGRADE) ===========//
// FIX/UPGRADE: DetectBOS() above only ever looks at EntryTF - a break of
// structure on a 15-minute chart says nothing about whether the higher
// timeframe actually agrees. This adds a genuinely separate, directional
// check: has EntryTF's higher timeframe (HigherTimeframe, already used for
// HTFConfirms' EMA-based trend check) ALSO had a same-direction break of
// structure recently? That's a materially stronger confirmation than
// "price happens to be on the correct side of the HTF EMA" - it requires
// actual HTF structure to have shifted, not just price position.

bool DetectDirectionalBOS(ENUM_TIMEFRAMES tf, bool buy)
{
   double swingHigh = GetRecentHigh(tf);
   double swingLow  = GetRecentLow(tf);

   if(swingHigh == EMPTY_VALUE || swingLow == EMPTY_VALUE)
      return false;

   double close1 = iClose(BrokerSymbol, tf, 1);
   double close2 = iClose(BrokerSymbol, tf, 2);

   double atr = GetFilterATR(); // EntryTF-scaled ATR used as the margin reference even for HTF checks - a reasonable approximation rather than maintaining a second ATR handle per timeframe.
   double minBreakMargin = (atr > 0.0) ? (atr * BOS_MinBreakATRMultiple) : 0.0;

   if(buy)
      return (close2 <= swingHigh && close1 > swingHigh + minBreakMargin);
   else
      return (close2 >= swingLow && close1 < swingLow - minBreakMargin);
}

// BEST-NEXT48: same-direction BOS checked at a specific closed bar (lookback-capable).
bool IsDirectionalBOSAtBar(ENUM_TIMEFRAMES tf, const bool buy, const int bar)
{
   if(bar < 1)
      return false;

   int swingStart = bar + 2;
   int swingEnd = bar + 2 + MathMax(SwingBars * 2, 6);
   if(Bars(BrokerSymbol, tf) <= swingEnd)
      return false;

   double atr = GetFilterATR();
   double minBreakMargin = (atr > 0.0) ? (atr * BOS_MinBreakATRMultiple) : 0.0;
   double close1 = iClose(BrokerSymbol, tf, bar);
   double close2 = iClose(BrokerSymbol, tf, bar + 1);

   if(buy)
   {
      double swingHigh = iHigh(BrokerSymbol, tf, swingStart);
      for(int j = swingStart + 1; j <= swingEnd; j++)
      {
         double h = iHigh(BrokerSymbol, tf, j);
         if(h > swingHigh) swingHigh = h;
      }
      return (close2 <= swingHigh && close1 > swingHigh + minBreakMargin);
   }

   double swingLow = iLow(BrokerSymbol, tf, swingStart);
   for(int j = swingStart + 1; j <= swingEnd; j++)
   {
      double l = iLow(BrokerSymbol, tf, j);
      if(l < swingLow) swingLow = l;
   }
   return (close2 >= swingLow && close1 < swingLow - minBreakMargin);
}

bool RecentDirectionalBOS(const bool buy, const int lookbackBars)
{
   int lb = MathMax(lookbackBars, 1);
   // Prefer current-bar DetectDirectionalBOS (uses confirmed swing helpers)
   if(DetectDirectionalBOS(EntryTF, buy))
      return true;

   for(int i = 1; i <= lb; i++)
   {
      if(IsDirectionalBOSAtBar(EntryTF, buy, i))
         return true;
   }
   return false;
}

// Live Cont/ICE/IMCE structure BOS — lookback when DirectionalBOS_LookbackBars > 1
bool StructureDirectionalBOS(const bool buy)
{
   int lb = DirectionalBOS_LookbackBars;
   if(lb <= 1)
      return DetectDirectionalBOS(EntryTF, buy);
   return RecentDirectionalBOS(buy, lb);
}

input group "MULTI-TIMEFRAME SMC CONFLUENCE"

input bool EnableMTFStructureConfluence = false; // require a same-direction BOS on HigherTimeframe, not just EntryTF

bool HasHTFStructureConfluence(bool buy)
{
   if(!EnableMTFStructureConfluence)
      return true; // neutral when disabled - doesn't block anything

   return DetectDirectionalBOS(HigherTimeframe, buy);
}


//================ LIQUIDITY SWEEP ==================================//

// STRENGTHENED: same issue as BOS above - a wick clearing the prior
// high/low by a hair used to count as a full liquidity sweep. Now requires
// the wick to clear the level by a minimum ATR-scaled depth, so it reflects
// an actual stop-hunt-style spike rather than ordinary noise at the level.

input double LiquiditySweep_MinDepthATRMultiple = 0.1; // CHANGED: was 0.0 - same no-op issue as BOS_MinBreakATRMultiple above.

// FURTHER STRENGTHENED (this pass): depth alone doesn't distinguish a real
// spike-and-reject wick from a bar that simply broke out and kept most of
// its range beyond the level (a strong bar in that direction, not a
// rejection of it). Requiring the piercing wick to be a meaningful share
// of the bar's own total range filters out bars where the "sweep" is
// really just ordinary directional strength.
input double LiquiditySweep_MinWickRatio = 0.33; // the piercing wick must be at least this fraction of the bar's total high-low range

bool IsBuySideLiquiditySweepAtBar(const int bar)
{
   // Sweep of highs → bearish reversal fuel (SELL)
   if(bar < 1)
      return false;

   double currentHigh = iHigh(BrokerSymbol, EntryTF, bar);
   double currentLow  = iLow(BrokerSymbol, EntryTF, bar);
   double close = iClose(BrokerSymbol, EntryTF, bar);
   double barRange = currentHigh - currentLow;
   if(barRange <= 0.0)
      return false;

   // Prior swing high from bars after this bar
   double previousHigh = iHigh(BrokerSymbol, EntryTF, bar + 1);
   for(int j = bar + 2; j <= bar + 6; j++)
   {
      double h = iHigh(BrokerSymbol, EntryTF, j);
      if(h > previousHigh) previousHigh = h;
   }

   double atr = GetFilterATR();
   double minSweepDepth = (atr > 0.0) ? (atr * LiquiditySweep_MinDepthATRMultiple) : 0.0;

   if(!(currentHigh > previousHigh + minSweepDepth && close < previousHigh))
      return false;

   double wick = currentHigh - MathMax(close, previousHigh);
   return (wick / barRange >= LiquiditySweep_MinWickRatio);
}

bool IsSellSideLiquiditySweepAtBar(const int bar)
{
   // Sweep of lows → bullish reversal fuel (BUY)
   if(bar < 1)
      return false;

   double currentHigh = iHigh(BrokerSymbol, EntryTF, bar);
   double currentLow  = iLow(BrokerSymbol, EntryTF, bar);
   double close = iClose(BrokerSymbol, EntryTF, bar);
   double barRange = currentHigh - currentLow;
   if(barRange <= 0.0)
      return false;

   double previousLow = iLow(BrokerSymbol, EntryTF, bar + 1);
   for(int j = bar + 2; j <= bar + 6; j++)
   {
      double l = iLow(BrokerSymbol, EntryTF, j);
      if(l < previousLow) previousLow = l;
   }

   double atr = GetFilterATR();
   double minSweepDepth = (atr > 0.0) ? (atr * LiquiditySweep_MinDepthATRMultiple) : 0.0;

   if(!(currentLow < previousLow - minSweepDepth && close > previousLow))
      return false;

   double wick = MathMin(close, previousLow) - currentLow;
   return (wick / barRange >= LiquiditySweep_MinWickRatio);
}

bool DetectLiquiditySweep()
{
   bool buySide = IsBuySideLiquiditySweepAtBar(1);
   bool sellSide = IsSellSideLiquiditySweepAtBar(1);

   if(buySide || sellSide)
   {
      if(EnableVerboseLogging)
         Print(buySide ? "Buy-side liquidity sweep detected"
                       : "Sell-side liquidity sweep detected");
      int sIdx = GetSymbolIndex(BrokerSymbol);
      if(sIdx >= 0 && sIdx < ArraySize(LastSweepTrueBarTimeArr))
         LastSweepTrueBarTimeArr[sIdx] = iTime(BrokerSymbol, EntryTF, 1);
      return true;
   }
   return false;
}

// Directional sweep recency for CORRECT reversal signals.
// buy=true  → need sell-side liquidity taken (lows swept)
// buy=false → need buy-side liquidity taken (highs swept)
// Returns most-recent bar index of that side sweep, or 0 if none.
int MostRecentCorrectSweepBar(const bool buy, const int lookbackBars)
{
   int lb = MathMax(lookbackBars, 1);
   for(int i = 1; i <= lb; i++)
   {
      if(buy && IsSellSideLiquiditySweepAtBar(i))
         return i;
      if(!buy && IsBuySideLiquiditySweepAtBar(i))
         return i;
   }
   // Stop-hunt is stricter same-side signature (bar 1)
   if(buy && DetectStopHunt(false))
      return 1;
   if(!buy && DetectStopHunt(true))
      return 1;
   return 0;
}

int MostRecentWrongSideSweepBar(const bool buy, const int lookbackBars)
{
   int lb = MathMax(lookbackBars, 1);
   for(int i = 1; i <= lb; i++)
   {
      // Wrong side for BUY entry = highs swept (bearish fuel) — adverse to open longs too
      // Wrong side for SELL entry = lows swept (bullish fuel) — adverse to open shorts too
      if(buy && IsBuySideLiquiditySweepAtBar(i))
         return i;
      if(!buy && IsSellSideLiquiditySweepAtBar(i))
         return i;
   }
   if(buy && DetectStopHunt(true))
      return 1;
   if(!buy && DetectStopHunt(false))
      return 1;
   return 0;
}

bool RecentDirectionalSweep(const bool buy, const int lookbackBars)
{
   return (MostRecentCorrectSweepBar(buy, lookbackBars) > 0);
}

bool ReversalReclaimConfirm(const bool buy, const int rec)
{
   // AUDITFIX49: directional CHoCH only — undirected flip no longer counts as reclaim
   bool choch = RecentDirectionalCHoCH(buy, rec);
   bool disp = (GetDisplacementScore(buy) >= 5);
   bool inducement = DetectInducement(buy);
   bool stopHunt = buy ? DetectStopHunt(false) : DetectStopHunt(true);

   // Strong reclaim signatures (always valid)
   if(choch || disp || inducement || stopHunt)
      return true;

   // Plain reclaim candle alone is weak — only allowed when StrictCorrect is OFF
   if(!ReversalStrictCorrectSignal)
   {
      double o = iOpen(BrokerSymbol, EntryTF, 1);
      double c = iClose(BrokerSymbol, EntryTF, 1);
      if(buy && c > o)
         return true;
      if(!buy && c < o)
         return true;
   }

   return false;
}

// Master validator: correct-side sweep + zone + strong reclaim = CORRECT signal
// Rejects wrong-side / continuation traps so RevSniper does not fire the wrong way.
bool MarketReversalSignalOK(const bool buy, string &detail)
{
   detail = "";
   int rec = (EnableEarlyMarketReversal
              ? MathMax(EffectiveStructureRecency(), ReversalStructureRecencyBars)
              : EffectiveStructureRecency());

   int correctBar = MostRecentCorrectSweepBar(buy, rec);
   int wrongBar = MostRecentWrongSideSweepBar(buy, rec);
   bool correctSweep = (correctBar > 0);
   bool anySweep = RecentSweep(rec);
   bool choch = RecentCHoCH(rec);
   bool zone = ActiveOrderBlock(buy) || ActiveFVG(buy);
   bool reclaim = ReversalReclaimConfirm(buy, rec);
   bool trap = DetectFakeBreakoutTrap(buy);
   bool stopHunt = buy ? DetectStopHunt(false) : DetectStopHunt(true);

   bool sweepOK = ReversalRequireCorrectSideSweep ? correctSweep
                  : (ReversalAcceptCHoCHOrSweep ? (anySweep || choch) : anySweep);
   bool zoneOK = ReversalRequireZone ? zone : true;
   bool reclaimOK = ReversalRequireReclaimConfirm ? reclaim : true;

   if(trap)
   {
      detail = "blocked: fake-breakout trap in trade direction";
      return false;
   }
   if(!sweepOK)
   {
      detail = buy ? "need sell-side sweep (lows taken)" : "need buy-side sweep (highs taken)";
      return false;
   }
   // Anti-continuation: opposite sweep as-recent or more-recent = wrong signal
   if(ReversalRejectWrongSideRecent && wrongBar > 0 &&
      (correctBar == 0 || wrongBar <= correctBar))
   {
      detail = buy
         ? "blocked: wrong-side (highs) sweep recent — continuation not BUY rev"
         : "blocked: wrong-side (lows) sweep recent — continuation not SELL rev";
      return false;
   }
   if(ReversalPreferStopHunt && !stopHunt)
   {
      detail = "need stop-hunt candle (PreferStopHunt=true)";
      return false;
   }
   if(!zoneOK)
   {
      detail = "need OB/FVG zone in trade direction";
      return false;
   }
   if(!reclaimOK)
   {
      detail = ReversalStrictCorrectSignal
         ? "need strong reclaim (CHoCH / displacement / stop-hunt / inducement)"
         : "need reclaim (CHoCH / displacement / reclaim candle)";
      return false;
   }

   if(!ReversalRequireTrendADX)
   {
      detail = StringFormat("OK correctSweep=Y@%d wrongSide=%s zone=%s reclaim=%s CHoCH=%s stopHunt=%s",
                            correctBar,
                            (wrongBar > 0 ? IntegerToString(wrongBar) : "N"),
                            zone ? "Y" : "N",
                            reclaim ? "Y" : "N",
                            choch ? "Y" : "N",
                            stopHunt ? "Y" : "N");
      return true;
   }

   if(buy && !(IsBullTrend() && TrendStrong()))
   {
      detail = "trend+ADX not yet bullish";
      return false;
   }
   if(!buy && !(IsBearTrend() && TrendStrong()))
   {
      detail = "trend+ADX not yet bearish";
      return false;
   }

   detail = "OK with trend+ADX + correct-side stack";
   return true;
}

//================ STOP HUNT DETECTION (NEW) =========================//
// A stop hunt is a stricter, higher-conviction subset of a liquidity
// sweep: not just a wick past the level with a close back inside, but a
// spike beyond the level immediately followed by a decisive reversal close
// on the SAME bar that leaves the close near the opposite end of that
// bar's range - the classic "stop-run candle" signature (long wick, close
// away from the extreme, real body pointing the other way). Distinguishing
// this from a generic sweep matters because it's the pattern most closely
// associated with deliberate liquidity grabs rather than a level simply
// being tested and holding.
input double StopHunt_MinCloseBackFraction = 0.5; // close must be at least this far back from the spike extreme, as a fraction of the bar's range

bool DetectStopHunt(bool buySide)
{
   double high = iHigh(BrokerSymbol, EntryTF, 1);
   double low  = iLow(BrokerSymbol, EntryTF, 1);
   double close = iClose(BrokerSymbol, EntryTF, 1);
   double barRange = high - low;

   if(barRange <= 0.0)
      return false;

   double level = buySide ? GetRecentHigh() : GetRecentLow();
   if(level == EMPTY_VALUE)
      return false;

   double atr = GetFilterATR();
   double minDepth = (atr > 0.0) ? (atr * LiquiditySweep_MinDepthATRMultiple) : 0.0;

   if(buySide)
   {
      if(high <= level + minDepth)
         return false;
      // How far the close has retreated from the high, relative to the
      // whole bar's range - a decisive reversal close sits well below the
      // spike, not just a hair off the top.
      double closeBackFraction = (high - close) / barRange;
      return (close < level && closeBackFraction >= StopHunt_MinCloseBackFraction);
   }
   else
   {
      if(low >= level - minDepth)
         return false;
      double closeBackFraction = (close - low) / barRange;
      return (close > level && closeBackFraction >= StopHunt_MinCloseBackFraction);
   }
}

// UPGRADE - LIQUIDITY ENGINE: graduated scoring by sweep depth, same
// pattern as the FVG quality score above. A wick that barely pokes past
// the prior level and one that spikes well beyond it before reversing are
// different-quality signals - a deeper spike is a more convincing
// stop-hunt; scoring it flat at +10 either way threw that information
// away.

int GetLiquiditySweepQualityScore()
{
   double currentHigh = iHigh(BrokerSymbol, EntryTF, 1);
   double currentLow  = iLow(BrokerSymbol, EntryTF, 1);

   double previousHigh = GetRecentHigh();
   double previousLow  = GetRecentLow();

   if(previousHigh == EMPTY_VALUE || previousLow == EMPTY_VALUE)
      return 0;

   double close = iClose(BrokerSymbol, EntryTF, 1);
   double atr = GetFilterATR();

   double depth = 0.0;

   if(currentHigh > previousHigh && close < previousHigh)
      depth = currentHigh - previousHigh;
   else if(currentLow < previousLow && close > previousLow)
      depth = previousLow - currentLow;
   else
      return 0; // no sweep at all

   if(atr <= 0.0)
      return 5;

   double ratio = depth / atr;

   if(ratio >= 0.5) return 15; // deep, convincing spike beyond the level
   if(ratio >= 0.2) return 10;

   return 5; // shallow poke past the level - still counts, just weakly
}
//==============================================================
// EQUAL HIGHS
//==============================================================

// FIX #4 - TOLERANCE DOESN'T SCALE TO THE INSTRUMENT: a flat "10 points"
// tolerance is the same class of bug as the old fixed StopLossPoints - on
// BTCUSD, 10 points can be a fraction of a dollar of "equal", which almost
// never actually triggers on a genuinely equal high, while on a tighter
// forex pair it's comparatively enormous. Tolerance now scales off ATR
// (falls back to the old point-based tolerance if ATR isn't ready yet).

double EqualLevelTolerance()
{
   double atr = GetFilterATR();

   if(atr > 0.0)
      return atr * 0.1;

   return 10 * SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT);
}

input int EqualLevelLookbackBars = 15; // how many closed bars back to search for a genuine equal-highs/lows liquidity pool

// UPGRADE: scans back over EqualLevelLookbackBars closed candles and counts
// how many highs sit within EqualLevelTolerance() of the most recent closed
// bar's high. 2 touches is the bare minimum SMC definition of "equal
// highs"; 3+ is a much more heavily defended (and more meaningful) pool.
int CountEqualHighTouches()
{
   double refHigh = iHigh(BrokerSymbol, EntryTF, 1);
   double tolerance = EqualLevelTolerance();

   int touches = 1; // the reference bar itself counts as one

   for(int i = 2; i <= EqualLevelLookbackBars; i++)
   {
      if(MathAbs(iHigh(BrokerSymbol, EntryTF, i) - refHigh) <= tolerance)
         touches++;
   }

   return touches;
}

int CountEqualLowTouches()
{
   double refLow = iLow(BrokerSymbol, EntryTF, 1);
   double tolerance = EqualLevelTolerance();

   int touches = 1;

   for(int i = 2; i <= EqualLevelLookbackBars; i++)
   {
      if(MathAbs(iLow(BrokerSymbol, EntryTF, i) - refLow) <= tolerance)
         touches++;
   }

   return touches;
}

bool IsEqualHigh()
{
   return CountEqualHighTouches() >= 2;
}

//==============================================================
// EQUAL LOWS
//==============================================================

bool IsEqualLow()
{
   return CountEqualLowTouches() >= 2;
}

// Graduated version for scoring - a 2-touch pool and a 4+-touch pool are
// not equally significant liquidity, same graduated-scoring pattern used
// for the FVG/sweep quality scorers.
int GetEqualHighPoolScore()
{
   int touches = CountEqualHighTouches();
   if(touches >= 4) return 15;
   if(touches == 3) return 10;
   if(touches == 2) return 5;
   return 0;
}

int GetEqualLowPoolScore()
{
   int touches = CountEqualLowTouches();
   if(touches >= 4) return 15;
   if(touches == 3) return 10;
   if(touches == 2) return 5;
   return 0;
}
//==============================================================
// BULLISH FAIR VALUE GAP
//==============================================================

// FILTER INSIGNIFICANT FVGs (this pass): previously ANY gap greater than
// zero counted as a detected FVG - a one-point gap from spread noise or a
// quiet tick registered exactly the same as a genuine displacement gap.
// GetBullish/BearishFVGQualityScore() already discounted tiny gaps in the
// SCORE, but DetectBullish/BearishFVG() themselves (used by structure
// confluence, FVG tracking, and the FVG+OB strategy setups) still treated
// a microscopic gap as a real, trackable one. This adds a minimum
// ATR-scaled size gate at the source so an insignificant gap is filtered
// out everywhere consistently, not just where scoring happens to touch it.
input double FVG_MinSizeATRMultiple = 0.1; // minimum gap size, as a multiple of ATR, to count as a real FVG at all (0 = no minimum, old behavior)

bool DetectBullishFVG()
{
   double high3 = iHigh(BrokerSymbol, EntryTF, 3);
   double low1  = iLow(BrokerSymbol, EntryTF, 1);

   double gapSize = low1 - high3;
   if(gapSize <= 0)
      return false;

   if(FVG_MinSizeATRMultiple <= 0.0)
      return true;

   double atr = GetFilterATR();
   if(atr <= 0.0)
      return true; // can't scale to volatility yet - don't block on missing data

   return (gapSize >= atr * FVG_MinSizeATRMultiple);
}

//==============================================================
// BEARISH FAIR VALUE GAP
//==============================================================

bool DetectBearishFVG()
{
   double low3  = iLow(BrokerSymbol, EntryTF, 3);
   double high1 = iHigh(BrokerSymbol, EntryTF, 1);

   double gapSize = low3 - high1;
   if(gapSize <= 0)
      return false;

   if(FVG_MinSizeATRMultiple <= 0.0)
      return true;

   double atr = GetFilterATR();
   if(atr <= 0.0)
      return true;

   return (gapSize >= atr * FVG_MinSizeATRMultiple);
}

//==============================================================
// FVG QUALITY SCORING (UPGRADE)
//==============================================================
// FIX/UPGRADE: DetectBullishFVG()/DetectBearishFVG() above are still
// binary - a gap of 1 point and a gap of 50x ATR score identically. A
// three-candle gap that's tiny relative to current volatility is barely
// meaningful (near-certain to get filled immediately and isn't a real
// imbalance); a gap that's large relative to ATR reflects genuine
// displacement. This scores the gap size against ATR instead of just
// checking existence, so CalculateTradeScore() below can weight a strong
// FVG higher than a token one.

int GetBullishFVGQualityScore()
{
   double high3 = iHigh(BrokerSymbol, EntryTF, 3);
   double low1  = iLow(BrokerSymbol, EntryTF, 1);

   double gapSize = low1 - high3;

   if(gapSize <= 0)
      return 0; // no FVG at all

   double atr = GetFilterATR();

   if(atr <= 0.0)
      return 5; // can't scale to volatility yet - modest flat fallback

   double ratio = gapSize / atr;

   if(ratio >= 1.0)  return 15; // large gap relative to current volatility - strong displacement
   if(ratio >= 0.5)  return 10;
   if(ratio >= 0.2)  return 5;

   return 2; // technically an FVG, but tiny - low quality, barely counts
}

int GetBearishFVGQualityScore()
{
   double low3  = iLow(BrokerSymbol, EntryTF, 3);
   double high1 = iHigh(BrokerSymbol, EntryTF, 1);

   double gapSize = low3 - high1;

   if(gapSize <= 0)
      return 0;

   double atr = GetFilterATR();

   if(atr <= 0.0)
      return 5;

   double ratio = gapSize / atr;

   if(ratio >= 1.0)  return 15;
   if(ratio >= 0.5)  return 10;
   if(ratio >= 0.2)  return 5;

   return 2;
}
//==============================================================
// BULLISH ORDER BLOCK
//==============================================================

// FIX #5 - NO IMPULSE-STRENGTH FILTER: the old version only checked that
// bar 1's high cleared bar 2's high after a down candle - true of almost
// any two-candle wiggle, so it fired constantly and added score noise
// rather than flagging a genuine institutional-style impulse move. Now
// requires bar 1's full range to exceed a minimum multiple of ATR, so only
// candles that actually moved with force count.

input double OrderBlockMinATRMultiple = 0.3; // CHANGED: was 0.0 - the comment above describes this as requiring a genuinely forceful impulse candle, but 0.0 meant impulseRange >= atr*0 was true for any candle at all, so the check never actually filtered anything. 0.3 requires the impulse candle to have real range relative to current volatility.

// UPGRADE - BETTER ORDER-BLOCK VALIDATION: impulse strength alone (above)
// still allows a base candle that was itself a big, messy move to count
// as the "order block." The classic definition wants the base candle to
// reflect consolidation/absorption right before the impulse - a tight,
// contained candle, not another wide swing. Adding a max-range check on
// the base candle (bar 2) alongside the existing impulse-strength check
// on bar 1 means both halves of the pattern now have to look right, not
// just the breakout half.

input double OrderBlockMaxBaseATRMultiple = 1.2; // CHANGED: was 999.0 (explicitly a no-op per the old comment). 1.2 actually requires the base candle to be reasonably contained relative to volatility, matching the "tight base" definition described above, while staying loose enough not to reject normal setups.

bool DetectBullishOrderBlock()
{
   double open2  = iOpen(BrokerSymbol, EntryTF, 2);
   double close2 = iClose(BrokerSymbol, EntryTF, 2);
   double high2  = iHigh(BrokerSymbol, EntryTF, 2);
   double low2   = iLow(BrokerSymbol, EntryTF, 2);

   double high1 = iHigh(BrokerSymbol, EntryTF, 1);
   double low1  = iLow(BrokerSymbol, EntryTF, 1);

   double atr = GetFilterATR();
   double impulseRange = high1 - low1;
   double baseRange     = high2 - low2;

   bool impulseStrongEnough = (atr <= 0.0) || (impulseRange >= atr * OrderBlockMinATRMultiple);
   bool baseTightEnough     = (atr <= 0.0) || (baseRange <= atr * OrderBlockMaxBaseATRMultiple);

   // Last bearish candle before a genuinely forceful bullish impulse
   if(close2 < open2 && high1 > high2 && impulseStrongEnough && baseTightEnough)
      return true;

   return false;
}
//==============================================================
// BEARISH ORDER BLOCK
//==============================================================

bool DetectBearishOrderBlock()
{
   double open2  = iOpen(BrokerSymbol, EntryTF, 2);
   double close2 = iClose(BrokerSymbol, EntryTF, 2);
   double high2  = iHigh(BrokerSymbol, EntryTF, 2);
   double low2   = iLow(BrokerSymbol, EntryTF, 2);

   double high1 = iHigh(BrokerSymbol, EntryTF, 1);
   double low1  = iLow(BrokerSymbol, EntryTF, 1);

   double atr = GetFilterATR();
   double impulseRange = high1 - low1;
   double baseRange     = high2 - low2;

   bool impulseStrongEnough = (atr <= 0.0) || (impulseRange >= atr * OrderBlockMinATRMultiple);
   bool baseTightEnough     = (atr <= 0.0) || (baseRange <= atr * OrderBlockMaxBaseATRMultiple);

   // Last bullish candle before a genuinely forceful bearish impulse
   if(close2 > open2 && low1 < low2 && impulseStrongEnough && baseTightEnough)
      return true;

   return false;
}

//================ CHOCH DETECTION ==================================//

// FIX #3 - TICK NOISE + BAD SEED VALUE + MULTI-SYMBOL STATE BLEED:
//   a) The old version called TrendBullish() (live Bid vs EMA) on every
//      tick, so as price oscillated around the EMA it could flip back and
//      forth and fire a "CHoCH" many times within a single bar - noise,
//      not a real change of character.
//   b) `static bool lastBullTrend = TrendBullish();` only runs once, ever,
//      at the first call. If indicators weren't ready yet at that moment,
//      GetEMA() returns EMPTY_VALUE (an astronomically large sentinel), so
//      TrendBullish() would evaluate false regardless of the real trend -
//      seeding the wrong starting state and guaranteeing one bogus CHoCH
//      signal the moment real data arrives.
//   c) FOUND IN THIS REVIEW: all of the state above used to live in
//      function-local `static` variables - meaning ONE shared state for
//      every symbol. In multi-symbol mode, calling this for EURUSD then
//      GBPUSD in the same trading cycle compared GBPUSD's trend against
//      EURUSD's last recorded state, and "already evaluated this bar"
//      was checked against whichever symbol happened to run last -
//      producing false CHoCH signals purely from switching symbols, and
//      silently skipping genuine new-bar evaluations for others. State is
//      now held in the per-symbol arrays declared in Part 1
//      (CHoCH_LastBarTimeArr / CHoCH_LastBullTrendArr /
//      CHoCH_StateInitializedArr), indexed the same way as every other
//      per-symbol tracker in this file.
// Fix: only evaluate once per newly closed bar, per symbol, and skip
// entirely (no state change, no false signal) until GetEMA() returns real
// data.

// FINE-TUNE (this pass): the EMA-cross trend flip below is a genuine,
// stateful, once-per-bar-per-symbol signal (Fix #3), but an EMA cross by
// itself can happen on a shallow pullback that never actually broke any
// real price structure - it's a trend-follow signal wearing a structure
// name. This adds an actual price-structure requirement on top: the flip
// only counts as CHoCH if price has ALSO closed beyond two independent
// recent swing points in the new direction (GetRecentHigh/Low - the
// nearest swing - AND GetSecondRecentHigh/Low - the next one back), not
// just crossed the EMA. Two independent swings have to agree, not one.
// Falls back to the EMA-only signal if a second swing genuinely isn't
// available yet (fresh chart / thin history) rather than blocking forever.
input bool EnableCHoCH_MultiSwingValidation = true; // require 2 independent swing points to agree with the EMA-cross flip, not just the nearest one

bool CHoCH_MultiSwingConfirms(bool bullish)
{
   if(!EnableCHoCH_MultiSwingValidation)
      return true;

   double close1 = iClose(BrokerSymbol, EntryTF, 1);

   if(bullish)
   {
      double swingHigh1 = GetRecentHigh();
      double swingHigh2 = GetSecondRecentHigh();

      if(swingHigh1 == EMPTY_VALUE)
         return true; // no structure data yet - don't block on a missing reference

      bool clearedPrimary = close1 > swingHigh1;
      bool clearedSecondary = (swingHigh2 == EMPTY_VALUE) ? true : (close1 > swingHigh2);

      return clearedPrimary && clearedSecondary;
   }
   else
   {
      double swingLow1 = GetRecentLow();
      double swingLow2 = GetSecondRecentLow();

      if(swingLow1 == EMPTY_VALUE)
         return true;

      bool clearedPrimary = close1 < swingLow1;
      bool clearedSecondary = (swingLow2 == EMPTY_VALUE) ? true : (close1 < swingLow2);

      return clearedPrimary && clearedSecondary;
   }
}

bool DetectCHoCH()
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0)
      return false;

   // FIX (this review): every caller within the same decision cycle must
   // see the same answer. Return the cached result immediately if this
   // symbol has already been evaluated during the current g_CycleCounter
   // tick, instead of re-running the once-per-bar state machine below
   // (which would incorrectly return false for every caller after the
   // first).
   if(idx < ArraySize(CHoCH_CacheCycleArr) && CHoCH_CacheCycleArr[idx] == (long)g_CycleCounter)
      return CHoCH_CacheResultArr[idx];

   bool result = false;

   datetime currentBarTime = iTime(BrokerSymbol, EntryTF, 0);

   if(currentBarTime != CHoCH_LastBarTimeArr[idx])
   {
      double ema = GetEMA();

      if(ema != EMPTY_VALUE) // indicators not ready - don't seed a false state
      {
         CHoCH_LastBarTimeArr[idx] = currentBarTime;

         bool currentBullTrend = (SymbolInfoDouble(BrokerSymbol, SYMBOL_BID) > ema);

         if(!CHoCH_StateInitializedArr[idx])
         {
            // First valid read for this symbol - record the starting state
            // without claiming a "change" happened, since there's nothing
            // to compare against yet.
            CHoCH_StateInitializedArr[idx] = true;
            CHoCH_LastBullTrendArr[idx] = currentBullTrend;
         }
         else if(currentBullTrend != CHoCH_LastBullTrendArr[idx])
         {
            // The EMA state has flipped - record the new state either way
            // (so the next comparison is against the correct baseline), but
            // only report it as a CHoCH result if multi-swing validation
            // (or its "no data yet" fallback) actually agrees that price
            // structure backs it up. A flip that fails validation still
            // updates the trend baseline; it just doesn't fire a signal.
            CHoCH_LastBullTrendArr[idx] = currentBullTrend;

            if(CHoCH_MultiSwingConfirms(currentBullTrend))
            {
               result = true;
               LastCHoCHTrueBarTimeArr[idx] = currentBarTime;
               // AUDITFIX49: lock direction of THIS confirmed CHoCH for reclaim polarity
               if(idx < ArraySize(LastCHoCHWasBullArr))
                  LastCHoCHWasBullArr[idx] = currentBullTrend;

               if(EnableVerboseLogging)
                  Print(currentBullTrend ? "Bullish CHoCH detected" : "Bearish CHoCH detected", " on ", BrokerSymbol);
            }
            else if(EnableVerboseLogging)
            {
               Print("CHoCH candidate (", currentBullTrend ? "bullish" : "bearish", ") on ", BrokerSymbol,
                     " rejected - EMA flipped but structure didn't confirm with multi-swing validation.");
            }
         }
      }
   }

   // Cache this cycle's result for this symbol so every other caller this
   // tick (scoring, confluence, HTF confluence, snapshot, dashboard) reuses
   // it instead of re-triggering the once-per-bar gate above.
   if(idx < ArraySize(CHoCH_CacheCycleArr))
   {
      CHoCH_CacheCycleArr[idx]  = (long)g_CycleCounter;
      CHoCH_CacheResultArr[idx] = result;
   }

   return result;
}

//======================================================================//
//   ORDER BLOCK FRESH / MITIGATED / INVALIDATED TRACKING (NEW)         //
//======================================================================//
// DetectBullishOrderBlock()/DetectBearishOrderBlock() only ever examine the
// last 2 candles, so a caller a few bars later has no way to know whether
// a zone exists at all, is still fresh, has been tapped once (mitigated -
// still worth respecting once, but weaker the second time), or has been
// closed straight through (invalidated - shouldn't count as support/
// resistance anymore). This block gives the zone a persistent lifetime.

input double OB_InvalidationATRMultiple = 0.15; // how far price must close beyond the zone to count as a clean invalidating break, not just a wick poke

// Runs once per newly closed EntryTF bar per symbol. Detects a brand-new
// zone (overwriting the previous one of the same direction - only the most
// recent zone per direction is tracked), then updates mitigation/
// invalidation state for whichever zone is already active.
void UpdateOrderBlockTracking()
{
   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0 || idx >= ArraySize(OB_LastProcessedBarTimeArr))
      return;

   datetime currentBarTime = iTime(BrokerSymbol, EntryTF, 0);
   if(currentBarTime == OB_LastProcessedBarTimeArr[idx])
      return; // already processed this bar for this symbol

   OB_LastProcessedBarTimeArr[idx] = currentBarTime;

   double atr = GetFilterATR();
   double invalidationMargin = (atr > 0.0) ? (atr * OB_InvalidationATRMultiple) : 0.0;

   // --- Bullish zone ---
   if(DetectBullishOrderBlock())
   {
      // New impulse just confirmed - the base candle is bar 2.
      OB_Bull_TopArr[idx]      = iHigh(BrokerSymbol, EntryTF, 2);
      OB_Bull_BottomArr[idx]   = iLow(BrokerSymbol, EntryTF, 2);
      OB_Bull_BarTimeArr[idx]  = iTime(BrokerSymbol, EntryTF, 2);
      OB_Bull_ActiveArr[idx]   = true;
      OB_Bull_MitigatedArr[idx] = false;

      if(EnableVerboseLogging)
         Print("New bullish order block tracked on ", BrokerSymbol, ": ", OB_Bull_BottomArr[idx], " - ", OB_Bull_TopArr[idx]);
   }
   else if(OB_Bull_ActiveArr[idx])
   {
      double low1  = iLow(BrokerSymbol, EntryTF, 1);
      double close1 = iClose(BrokerSymbol, EntryTF, 1);

      // Invalidation first - a decisive close below the zone means it's no
      // longer valid demand and should stop scoring altogether.
      if(close1 < OB_Bull_BottomArr[idx] - invalidationMargin)
      {
         OB_Bull_ActiveArr[idx] = false;
         if(EnableVerboseLogging) Print("Bullish order block invalidated on ", BrokerSymbol);
      }
      // Otherwise, mitigation - price traded back into the zone (wicked or
      // closed into it) without invalidating it. Still respected, but a
      // second-touch zone is weaker than an untouched one.
      else if(low1 <= OB_Bull_TopArr[idx] && !OB_Bull_MitigatedArr[idx])
      {
         OB_Bull_MitigatedArr[idx] = true;
         if(EnableVerboseLogging) Print("Bullish order block mitigated (first tap) on ", BrokerSymbol);
      }
   }

   // --- Bearish zone ---
   if(DetectBearishOrderBlock())
   {
      OB_Bear_TopArr[idx]      = iHigh(BrokerSymbol, EntryTF, 2);
      OB_Bear_BottomArr[idx]   = iLow(BrokerSymbol, EntryTF, 2);
      OB_Bear_BarTimeArr[idx]  = iTime(BrokerSymbol, EntryTF, 2);
      OB_Bear_ActiveArr[idx]   = true;
      OB_Bear_MitigatedArr[idx] = false;

      if(EnableVerboseLogging)
         Print("New bearish order block tracked on ", BrokerSymbol, ": ", OB_Bear_BottomArr[idx], " - ", OB_Bear_TopArr[idx]);
   }
   else if(OB_Bear_ActiveArr[idx])
   {
      double high1  = iHigh(BrokerSymbol, EntryTF, 1);
      double close1 = iClose(BrokerSymbol, EntryTF, 1);

      if(close1 > OB_Bear_TopArr[idx] + invalidationMargin)
      {
         OB_Bear_ActiveArr[idx] = false;
         if(EnableVerboseLogging) Print("Bearish order block invalidated on ", BrokerSymbol);
      }
      else if(high1 >= OB_Bear_BottomArr[idx] && !OB_Bear_MitigatedArr[idx])
      {
         OB_Bear_MitigatedArr[idx] = true;
         if(EnableVerboseLogging) Print("Bearish order block mitigated (first tap) on ", BrokerSymbol);
      }
   }
}

// True only for a zone that is (a) currently tracked, (b) not invalidated,
// and (c) not yet mitigated - a genuinely fresh, untouched order block.
// This is what CalculatePRISMScore() now rewards instead of the old flat
// "was one detected on the last 2 candles" check.
bool IsOrderBlockFreshAndValid(bool buy)
{
   UpdateOrderBlockTracking();

   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0)
      return buy ? DetectBullishOrderBlock() : DetectBearishOrderBlock(); // fallback if symbol isn't tracked

   if(buy)
      return OB_Bull_ActiveArr[idx] && !OB_Bull_MitigatedArr[idx];
   else
      return OB_Bear_ActiveArr[idx] && !OB_Bear_MitigatedArr[idx];
}

// True for a zone that's still valid (not invalidated) but has already
// been tapped once - still usable context (e.g. for tighter stop
// placement or a lower-conviction re-entry), just not full-weight fresh
// supply/demand anymore.
bool IsOrderBlockMitigated(bool buy)
{
   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0) return false;

   if(buy)
      return OB_Bull_ActiveArr[idx] && OB_Bull_MitigatedArr[idx];
   else
      return OB_Bear_ActiveArr[idx] && OB_Bear_MitigatedArr[idx];
}


//======================================================================//
//   FAIR VALUE GAP MITIGATION TRACKING (NEW)                           //
//======================================================================//

// Runs once per newly closed bar per symbol - same pattern as order block
// tracking above. Tracks how much of the most recent gap in each direction
// has since been retraced, and drops it once fully filled.
void UpdateFVGTracking()
{
   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0 || idx >= ArraySize(FVG_LastProcessedBarTimeArr))
      return;

   datetime currentBarTime = iTime(BrokerSymbol, EntryTF, 0);
   if(currentBarTime == FVG_LastProcessedBarTimeArr[idx])
      return;

   FVG_LastProcessedBarTimeArr[idx] = currentBarTime;

   // --- Bullish gap: bottom = bar3 high, top = bar1 low (at time of formation) ---
   if(DetectBullishFVG())
   {
      FVG_Bull_BottomArr[idx]   = iHigh(BrokerSymbol, EntryTF, 3);
      FVG_Bull_TopArr[idx]      = iLow(BrokerSymbol, EntryTF, 1);
      FVG_Bull_BarTimeArr[idx]  = iTime(BrokerSymbol, EntryTF, 1);
      FVG_Bull_ActiveArr[idx]   = true;
      FVG_Bull_FilledPctArr[idx] = 0.0;
   }
   else if(FVG_Bull_ActiveArr[idx])
   {
      double low1 = iLow(BrokerSymbol, EntryTF, 1);
      double top = FVG_Bull_TopArr[idx];
      double bottom = FVG_Bull_BottomArr[idx];
      double range = top - bottom;

      if(range > 0.0 && low1 < top)
      {
         double filled = (top - MathMax(low1, bottom)) / range * 100.0;
         FVG_Bull_FilledPctArr[idx] = MathMax(FVG_Bull_FilledPctArr[idx], MathMin(filled, 100.0));
      }

      if(FVG_Bull_FilledPctArr[idx] >= 100.0)
         FVG_Bull_ActiveArr[idx] = false; // fully filled - no longer live imbalance
   }

   // --- Bearish gap: bottom = bar1 high, top = bar3 low (at time of formation) ---
   if(DetectBearishFVG())
   {
      FVG_Bear_BottomArr[idx]   = iHigh(BrokerSymbol, EntryTF, 1);
      FVG_Bear_TopArr[idx]      = iLow(BrokerSymbol, EntryTF, 3);
      FVG_Bear_BarTimeArr[idx]  = iTime(BrokerSymbol, EntryTF, 1);
      FVG_Bear_ActiveArr[idx]   = true;
      FVG_Bear_FilledPctArr[idx] = 0.0;
   }
   else if(FVG_Bear_ActiveArr[idx])
   {
      double high1 = iHigh(BrokerSymbol, EntryTF, 1);
      double top = FVG_Bear_TopArr[idx];
      double bottom = FVG_Bear_BottomArr[idx];
      double range = top - bottom;

      if(range > 0.0 && high1 > bottom)
      {
         double filled = (MathMin(high1, top) - bottom) / range * 100.0;
         FVG_Bear_FilledPctArr[idx] = MathMax(FVG_Bear_FilledPctArr[idx], MathMin(filled, 100.0));
      }

      if(FVG_Bear_FilledPctArr[idx] >= 100.0)
         FVG_Bear_ActiveArr[idx] = false;
   }
}

double GetFVGFilledPercent(bool buy)
{
   UpdateFVGTracking();

   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0) return 0.0;

   if(buy)
      return FVG_Bull_ActiveArr[idx] ? FVG_Bull_FilledPctArr[idx] : 100.0; // no active/tracked gap = treat as "nothing fresh to lean on"
   else
      return FVG_Bear_ActiveArr[idx] ? FVG_Bear_FilledPctArr[idx] : 100.0;
}

// UPGRADE: combines the existing ATR-scaled gap-size quality score with the
// mitigation state above - a large, untouched gap scores at full weight; a
// large gap that's already 80% filled back in is much weaker supporting
// evidence even though its raw size hasn't changed. This is what
// CalculatePRISMScore() now uses instead of calling the raw per-direction
// quality scorers directly.
int GetFVGQualityScore(bool buy)
{
   int baseScore = buy ? GetBullishFVGQualityScore() : GetBearishFVGQualityScore();
   if(baseScore <= 0)
      return 0;

   double filledPct = GetFVGFilledPercent(buy);
   double remainingFraction = MathMax(0.0, (100.0 - filledPct) / 100.0);

   return (int)MathRound(baseScore * remainingFraction);
}


//======================================================================//
//   FAKE BREAKOUT / TRAP / INDUCEMENT DETECTION (NEW)                  //
//======================================================================//
// Distinguishes "price is breaking out cleanly" from "price already tried
// this break recently and got rejected" - a classic inducement/stop-hunt
// pattern where retail breakout traders get trapped just before a reversal.
// Simplification, stated plainly: this reuses the CURRENT swing high/low
// as the reference level for the whole lookback window rather than
// recomputing the swing level bar-by-bar historically. On a fast-moving
// market the swing level can shift within the lookback window, which would
// under-count older trap attempts - an acceptable tradeoff for a cheap,
// stateless heuristic filter rather than a full historical structure replay.

input int FakeBreakoutLookbackBars = 5;

// STRENGTHENED (this pass): the old reversal check only required the close
// to be back on the wrong side of the level BY ANY AMOUNT, including a
// single point - indistinguishable from noise sitting right at the level.
// Now requires the reversal close to have retreated back past the level by
// a minimum ATR-scaled margin too, matching the same "decisive, not a
// hair" standard already used for BOS/sweep detection.
input double FakeBreakoutReversalATRMultiple = 0.05; // how far back past the level the reversal close must sit to count as a confirmed failed break, not just noise

bool DetectFakeBreakoutTrap(bool buy)
{
   double swingHigh = GetRecentHigh();
   double swingLow  = GetRecentLow();

   if(swingHigh == EMPTY_VALUE || swingLow == EMPTY_VALUE)
      return false;

   double atr = GetFilterATR();
   double margin = (atr > 0.0) ? (atr * BOS_MinBreakATRMultiple) : 0.0;
   double reversalMargin = (atr > 0.0) ? (atr * FakeBreakoutReversalATRMultiple) : 0.0;

   if(buy)
   {
      bool brokeAbove = false;
      for(int i = FakeBreakoutLookbackBars; i >= 2; i--)
      {
         if(iClose(BrokerSymbol, EntryTF, i) > swingHigh + margin) { brokeAbove = true; break; }
      }
      if(!brokeAbove)
         return false;

      // A break happened recently but the most recently closed bar has
      // decisively reclaimed the level, not just poked back below it by a
      // tick. That's a trap for anyone who bought the breakout, and a
      // warning sign against buying now too.
      return (iClose(BrokerSymbol, EntryTF, 1) < swingHigh - reversalMargin);
   }
   else
   {
      bool brokeBelow = false;
      for(int i = FakeBreakoutLookbackBars; i >= 2; i--)
      {
         if(iClose(BrokerSymbol, EntryTF, i) < swingLow - margin) { brokeBelow = true; break; }
      }
      if(!brokeBelow)
         return false;

      return (iClose(BrokerSymbol, EntryTF, 1) > swingLow + reversalMargin);
   }
}

//================ INDUCEMENT DETECTION (NEW) =========================//
// A trap (above) is the general "a breakout failed" pattern. Inducement is
// the specific SMC variant of that idea used as a POSITIVE signal for the
// opposite direction: a shallow, engineered-looking break of a minor level
// that reverses quickly, right before the real move develops the other
// way. Distinguished from the general trap by requiring the failed break
// to have been shallow (a small multiple of ATR beyond the level, not a
// deep push) AND to have reversed within a tight bar count - the "quick
// fakeout that shakes out early entries" signature, rather than a break
// that ran a long way before eventually failing.
input int InducementMaxBreakBars = 2;              // the failed break must reverse within this many bars to count as inducement (tighter than the general trap lookback)
input double InducementMaxDepthATRMultiple = 0.35; // the break beyond the level must stay shallower than this to look "engineered" rather than a genuine strong push

bool DetectInducement(bool reversalDirectionIsBuy)
{
   // reversalDirectionIsBuy = true means: sell-side liquidity was
   // induced/swept and we're now looking for the bullish reversal that
   // typically follows.
   double atr = GetFilterATR();
   if(atr <= 0.0)
      return false;

   double swingLow  = GetRecentLow();
   double swingHigh = GetRecentHigh();

   if(reversalDirectionIsBuy)
   {
      if(swingLow == EMPTY_VALUE)
         return false;

      for(int i = InducementMaxBreakBars; i >= 1; i--)
      {
         double lo = iLow(BrokerSymbol, EntryTF, i);
         double depth = swingLow - lo;

         if(depth > 0.0 && depth <= atr * InducementMaxDepthATRMultiple)
         {
            // Shallow break found - now check it has since reclaimed the
            // level decisively.
            if(iClose(BrokerSymbol, EntryTF, 1) > swingLow)
               return true;
         }
      }
      return false;
   }
   else
   {
      if(swingHigh == EMPTY_VALUE)
         return false;

      for(int i = InducementMaxBreakBars; i >= 1; i--)
      {
         double hi = iHigh(BrokerSymbol, EntryTF, i);
         double depth = hi - swingHigh;

         if(depth > 0.0 && depth <= atr * InducementMaxDepthATRMultiple)
         {
            if(iClose(BrokerSymbol, EntryTF, 1) < swingHigh)
               return true;
         }
      }
      return false;
   }
}

//+------------------------------------------------------------------+
//|              PART 13 - MULTI SYMBOL SCANNER                      |
//+------------------------------------------------------------------+

//================ SYMBOL SETTINGS ==================================//

input string TradeSymbols =
"EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,XAUUSD,BTCUSD";

input group "MULTI-SYMBOL EXECUTION"

// UPGRADE - REAL MULTI-SYMBOL TRADING: TradeSymbols above used to be
// informational only - it preloaded symbols into Market Watch but the EA
// only ever traded BrokerSymbol (the chart's own symbol). With this on,
// the EA actually scans and trades every symbol in TradeSymbols (plus
// whatever chart it's attached to), each with its own indicators, its
// own cooldown/loss tracking, and its own non-scalp treatment where
// applicable (BTC/ETH still get the wider stops and longer holds, other
// symbols don't). Off by default so existing single-symbol setups are
// completely unaffected unless this is explicitly turned on.
//
// IMPORTANT MT5 CONSTRAINT: an EA only receives OnTick() for the symbol
// of the chart it's attached to - there's no way around that. To actually
// evaluate OTHER symbols in the list on a regular basis (not just when
// the chart's own symbol happens to tick), this also starts a timer
// (MultiSymbolTimerSeconds) that runs the same trading cycle on a fixed
// interval. The chart's own symbol gets checked on both real ticks AND
// the timer; every other symbol in the list is only checked via the timer.


//================ SYMBOL ARRAY =====================================//

string SymbolList[];


//================ INITIALIZE SYMBOLS ================================//

void InitializeSymbols()
{

   int count =
   StringSplit(
      TradeSymbols,
      ',',
      SymbolList
   );


   for(int i = 0; i < count; i++)
   {
      string sym = SymbolList[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);

      bool selected = SymbolSelect(sym, true);

      // FIX: this loop never got the suffix auto-detection fix applied to
      // BuildMultiSymbolList() - a broker suffixing every symbol (e.g.
      // "XAUUSD.m" instead of "XAUUSD") made this log falsely report
      // "Symbol unavailable" for symbols that were actually fine, just
      // under a different exact name. Purely cosmetic (this loop doesn't
      // gate trading), but a false "unavailable" is still a real bug in
      // what it reports.
      if(!selected)
      {
         string variant = FindBrokerSymbolVariant(sym);

         if(variant != "" && SymbolSelect(variant, true))
         {
            sym = variant;
            selected = true;
         }
      }

      if(selected)
      {
         Print("Symbol enabled: ", sym);
      }
      else
      {
         Print("Symbol unavailable: ", sym);
      }

   }

   BuildMultiSymbolList();

}

//================ BUILD MULTI-SYMBOL LIST ============================//
// Constructs MultiSymbolList[] - always includes PrimarySymbol (the
// chart's own symbol) first, and additionally every symbol from
// TradeSymbols if EnableMultiSymbolTrading is on. With multi-symbol
// trading off, this ends up as a single-element array containing just the
// chart's symbol - functionally identical to how the EA behaved before
// any of this existed, just routed through the same array-based lookup
// used everywhere else now.

// FIX: this used to call SymbolSelect(sym, true) on the TradeSymbols entry
// exactly as typed - "EURUSD" - and skip it entirely if that exact name
// didn't exist. Many brokers (including the one in your screenshots -
// symbols show up as XAUUSD.m, BTCUSD.m, US30.std) suffix every symbol
// name, so "EURUSD" never matches anything and gets silently dropped,
// leaving MultiSymbolList with only the chart's own symbol regardless of
// how many symbols were listed in TradeSymbols. This is very likely why
// other symbols weren't opening at all. FindBrokerSymbolVariant() below
// scans every symbol the broker actually offers for one that STARTS WITH
// the requested name (case-insensitive) - "EURUSD" now matches
// "EURUSD.m", "EURUSDm", "EURUSD_i", or whatever suffix convention this
// specific broker uses, with no manual suffix configuration needed.

string FindBrokerSymbolVariant(string requestedName)
{
   string reqUpper = requestedName;
   StringToUpper(reqUpper);

   int total = SymbolsTotal(false); // false = every symbol the broker offers, not just Market Watch

   for(int i = 0; i < total; i++)
   {
      string candidate = SymbolName(i, false);
      string candUpper = candidate;
      StringToUpper(candUpper);

      if(StringFind(candUpper, reqUpper) == 0) // candidate starts with the requested name
         return candidate;
   }

   return ""; // genuinely not offered by this broker under any suffix
}

void BuildMultiSymbolList()
{
   ArrayResize(MultiSymbolList, 0);

   int n = ArraySize(MultiSymbolList);
   ArrayResize(MultiSymbolList, n + 1);
   MultiSymbolList[n] = PrimarySymbol;

   if(EnableMultiSymbolTrading)
   {
      for(int i = 0; i < ArraySize(SymbolList); i++)
      {
         string sym = SymbolList[i];
         StringTrimLeft(sym);
         StringTrimRight(sym);

         if(sym == "" || sym == PrimarySymbol)
            continue;

         bool selected = SymbolSelect(sym, true);

         if(!selected)
         {
            string variant = FindBrokerSymbolVariant(sym);

            if(variant != "" && variant != PrimarySymbol)
            {
               if(SymbolSelect(variant, true))
               {
                  Print("TradeSymbols entry '", sym, "' matched to broker symbol '", variant, "' (suffix auto-detected).");
                  sym = variant;
                  selected = true;
               }
            }
         }

         if(!selected)
         {
            Print("TradeSymbols entry '", sym, "' could not be matched to any symbol this broker offers - skipped.");
            continue;
         }

         // Guard against the auto-detected variant turning out to be a
         // duplicate already in the list (e.g. two TradeSymbols entries
         // both resolving to the same broker symbol).
         bool alreadyInList = false;

         for(int j = 0; j < ArraySize(MultiSymbolList); j++)
            if(MultiSymbolList[j] == sym) { alreadyInList = true; break; }

         if(alreadyInList)
            continue;

         n = ArraySize(MultiSymbolList);
         ArrayResize(MultiSymbolList, n + 1);
         MultiSymbolList[n] = sym;
      }
   }

   Print("Multi-symbol list built (", ArraySize(MultiSymbolList), " symbol[s]): ",
         EnableMultiSymbolTrading ? "multi-symbol trading ON" : "single-symbol mode");
}

//================ SYMBOL INDEX LOOKUP ================================//
// Every per-symbol array (indicator handles, cooldown tracking) is
// index-matched to MultiSymbolList - this finds the right index for
// whatever symbol BrokerSymbol currently points to.
// ALLTRADE56: exact → case-insensitive → base-prefix (EURUSD ↔ EURUSD.m)

string SymbolBaseName(string symbol)
{
   string s = symbol;
   StringToUpper(s);
   // Strip common broker suffixes (.m, .i, .pro, _m, etc.) for matching
   int dot = StringFind(s, ".");
   if(dot > 0)
      s = StringSubstr(s, 0, dot);
   int us = StringFind(s, "_");
   if(us > 3) // keep XAU_USD style; only strip trailing _m style if long
   {
      string tail = StringSubstr(s, us + 1);
      if(StringLen(tail) <= 3)
         s = StringSubstr(s, 0, us);
   }
   return s;
}

bool SymbolNamesMatch(string a, string b)
{
   if(a == b)
      return true;
   string au = a, bu = b;
   StringToUpper(au);
   StringToUpper(bu);
   if(au == bu)
      return true;
   string ab = SymbolBaseName(a);
   string bb = SymbolBaseName(b);
   return (ab != "" && ab == bb);
}

int GetSymbolIndex(string symbol)
{
   int n = ArraySize(MultiSymbolList);
   for(int i = 0; i < n; i++)
      if(MultiSymbolList[i] == symbol)
         return i;

   for(int j = 0; j < n; j++)
      if(SymbolNamesMatch(MultiSymbolList[j], symbol))
         return j;

   return -1;
}


// NOTE: this section used to also carry IsSymbolValid() and ScanMarkets() -
// helper functions for looping over TradeSymbols and printing their bid
// prices. Confirmed dead: neither is called from OnInit, OnTick, or
// anywhere else in the file. InitializeSymbols() above still runs (it
// pre-selects the symbols in TradeSymbols so they're visible in Market
// Watch), but the scan/validate step that would have used them for actual
// multi-symbol logic was never wired in. Removed rather than left as an
// unused dead end - if multi-symbol trading is built out later, this is
// where that logic would go.
//+------------------------------------------------------------------+
//|              PART 14 - ADVANCED RISK ENGINE                      |
//+------------------------------------------------------------------+

//================ INITIALIZE RISK =================================//

void InitializeRiskEngine()
{
   // Seed the real daily-loss reference balance (Part 5) immediately
   // instead of waiting for the first tick.
   UpdateDailyReferenceBalance();

   Print("Risk Engine Initialized");
}

//+------------------------------------------------------------------+
//|              PART 15b - MEAN-REVERSION STRATEGY (NEW)             |
//+------------------------------------------------------------------+
// ADDED: the existing SMC engine (BOS/CHoCH/FVG/Order Block/liquidity
// sweep, Part 12) is fundamentally a TREND-FOLLOWING/breakout model - it
// looks for structure breaking and continuing, which is exactly the kind
// of behavior that does NOT happen in a genuinely ranging market. Rather
// than force one model to handle both regimes, this adds a second,
// independent strategy: classic RSI + Bollinger Band mean-reversion,
// which specifically wants the OPPOSITE conditions the SMC engine wants
// (price stretched to an extreme, expected to revert, not continue).
// StrategyMode below controls which one actually trades; ADAPTIVE_REGIME
// (the default) uses GetMarketRegime() (Part 15) to hand entries to
// whichever model actually fits current conditions - SMC during
// REGIME_TRENDING, mean-reversion during REGIME_RANGING - rather than
// running a trend model through chop or a reversion model through a
// genuine trend.

enum ENUM_STRATEGY_MODE
{
   STRATEGY_PRISM   // P.R.I.S.M.: the Strategy Priority Engine (Trend Pullback + Liquidity Sweep + FVG/OB + structure-based Volatility Breakout), hard-gated only - no RSI/BB, no ATR-blocking, no additive score. This is now the EA's only strategy; the legacy SMC/mean-reversion/adaptive-regime/trend-following modes have been removed per request.
};

input group "STRATEGY SELECTION"

input ENUM_STRATEGY_MODE StrategyMode = STRATEGY_PRISM;

input group "MEAN-REVERSION STRATEGY"

input int    RSI_Period      = 14;
input double RSI_Oversold    = 30.0;
input double RSI_Overbought  = 70.0;
input int    BB_Period       = 20;
input double BB_Deviation    = 2.0;
input bool   MeanReversionRequireHTFAgreement = false; // if true, still requires HTFConfirms() in the reversion's direction - off by default since mean-reversion is intentionally counter-trend on the entry timeframe

double GetRSI()
{
   // RSI deliberately removed from the live PRISM stack (no MACD/Stoch either).
   // Kept as a stub so any legacy mean-reversion helper still compiles.
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0 || RSIHandlesArr[idx] == INVALID_HANDLE)
      return EMPTY_VALUE;

   if(idx < ArraySize(RSI_CacheCycleArr) && RSI_CacheCycleArr[idx] == (long)g_CycleCounter)
      return RSI_CacheValueArr[idx];

   double buf[];
   ArraySetAsSeries(buf, true);

   int need = SignalBarIndex() + 1;

   if(CopyBuffer(RSIHandlesArr[idx], 0, 0, need, buf) < need)
      return EMPTY_VALUE;

   double result = buf[SignalBarIndex()];

   if(idx < ArraySize(RSI_CacheCycleArr))
   {
      RSI_CacheCycleArr[idx] = (long)g_CycleCounter;
      RSI_CacheValueArr[idx] = result;
   }

   return result;
}

bool GetBollingerBands(double &upper, double &lower, double &mid)
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0 || BBHandlesArr[idx] == INVALID_HANDLE)
      return false;

   if(idx < ArraySize(BB_CacheCycleArr) && BB_CacheCycleArr[idx] == (long)g_CycleCounter)
   {
      upper = BB_CacheUpperArr[idx];
      lower = BB_CacheLowerArr[idx];
      mid   = BB_CacheMidArr[idx];
      return true;
   }

   double bufMid[], bufUpper[], bufLower[];
   ArraySetAsSeries(bufMid, true);
   ArraySetAsSeries(bufUpper, true);
   ArraySetAsSeries(bufLower, true);

   int need = SignalBarIndex() + 1;

   if(CopyBuffer(BBHandlesArr[idx], 0, 0, need, bufMid)   < need) return false; // BASE_LINE
   if(CopyBuffer(BBHandlesArr[idx], 1, 0, need, bufUpper) < need) return false; // UPPER_BAND
   if(CopyBuffer(BBHandlesArr[idx], 2, 0, need, bufLower) < need) return false; // LOWER_BAND

   int b = SignalBarIndex();
   mid   = bufMid[b];
   upper = bufUpper[b];
   lower = bufLower[b];

   if(idx < ArraySize(BB_CacheCycleArr))
   {
      BB_CacheCycleArr[idx]  = (long)g_CycleCounter;
      BB_CacheUpperArr[idx]  = upper;
      BB_CacheLowerArr[idx]  = lower;
      BB_CacheMidArr[idx]    = mid;
   }

   return true;
}

// Legacy helper only (not on PRISM path). RSI removed — BB stretch alone.
bool MeanReversionBuySetup()
{
   double upper, lower, mid;

   if(!GetBollingerBands(upper, lower, mid))
      return false;

   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);

   if(price > lower)
      return false;

   if(MeanReversionRequireHTFAgreement && !HTFConfirms(true))
      return false;

   return true;
}

bool MeanReversionSellSetup()
{
   double upper, lower, mid;

   if(!GetBollingerBands(upper, lower, mid))
      return false;

   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);

   if(price < upper)
      return false;

   if(MeanReversionRequireHTFAgreement && !HTFConfirms(false))
      return false;

   return true;
}

// Decides which model actually gets to trade this bar, per StrategyMode.
// Returns via out-parameters so InstantExecution() has one single call
// site regardless of which underlying model fired.
//+------------------------------------------------------------------+
//|      PART 15h - STRATEGY PRIORITY ENGINE (SPEC-COMPLIANT) (NEW)  |
//+------------------------------------------------------------------+
// ADDED to actually resolve the conflict between your architecture spec
// and the pre-existing code: the spec forbids ATR-blocking, RSI/BB
// standalone entries, and additive score-based trading - all three exist
// elsewhere in this file (legacy modes, kept for comparison, not deleted).
// This is the genuinely spec-compliant path: a structure-based volatility
// breakout (no ATR gate) plus a real priority engine that checks every
// spec-named strategy, rejects the bar outright if any two valid setups
// disagree on direction, and otherwise picks the one with the most
// independently-confirmed conditions - a tie-break RULE among already-
// fully-valid setups, not a score threshold that decides validity itself.
// Structure is still the boss: nothing here can turn an invalid setup
// into a valid one by accumulating points the way MinimumTradeScore does.

//+------------------------------------------------------------------+
//|   CRITICAL FIX (this pass): SAME-BAR COINCIDENCE BUG              |
//+------------------------------------------------------------------+
// DetectBOS(), DetectCHoCH(), DetectLiquiditySweep() and
// DetectBullish/BearishOrderBlock()/FVG() are each true for ONE bar only -
// the exact bar the event happens on. The PRISM strategy setups below were
// requiring several of these to all be true on that same single bar at
// once (e.g. LiquiditySweepBuySetup wanted a sweep AND a CHoCH AND a fresh
// order block all on one candle) - independent one-bar events essentially
// never coincide like that, which is why real setups were sitting blocked
// for very long stretches. These helpers give BOS/CHoCH/sweep a recency
// window (did it happen within the last few bars, not literally this
// bar), and route order block / FVG checks through the PERSISTENT
// fresh/mitigated/active trackers that already exist elsewhere in the file
// (IsOrderBlockFreshAndValid, FVG_Bull/Bear_ActiveArr) instead of their
// raw one-bar detectors. This is still genuine SMC confluence - sweep,
// then CHoCH, then a trade off the resulting order block, in that
// sequence over a few candles - just no longer requiring all of it to
// physically be the same candle, which was never how these patterns
// actually play out in real price action. Placed here (ahead of
// CountConfirmingConditions/CalculatePRISMScore/the strategy setups
// themselves) so every consumer - the scoring gate included - sees the
// same recency-tolerant picture instead of the scoring gate silently
// undercutting the setups' own fix with a stricter same-bar read.

input group "PRISM STRUCTURE RECENCY WINDOW"

input int PRISM_StructureRecencyBars = 15; // how many recent bars a BOS/CHoCH/sweep event stays "valid" for confluence purposes, instead of requiring the literal current bar


int EffectiveStructureRecency()
{
   if(EnableInstantSniperMode)
      return MathMax(PRISM_StructureRecencyBars, InstantStructureRecencyBars);
   return PRISM_StructureRecencyBars;
}

double EffectivePullbackATRMultiple()
{
   if(EnableInstantSniperMode)
      return MathMax(PullbackMaxATRMultiple, InstantPullbackATRMultiple);
   return PullbackMaxATRMultiple;
}

bool EventQualityModeActive(); // forward
bool PRIME_IsLiveTag(const string tag); // OK93 forward — Ultra live tags
void UltraCoreInit();
double GetWinRatePercent();
double GetProfitFactor();
double GetAverageRR();
bool QualityGatesActive();

int EffectiveMinimumMPIScore()
{
   // Instant open, quality prefer: MPI never gates entries (floor = 0).
   if(AggressiveInstantQuality || AggressiveInstitutionalExecution)
      return 0;

   if(EventQualityModeActive())
      return MathMax(EventQualityMPIScore, QualityMPIScore);
   if(EnableAlwaysQualityMode)
      return MathMax(QualityMPIScore, InstantMinimumMPIScore);
   if(NeverBlockValidSniperEntry)
      return 0;
   if(EnableInstantSniperMode)
      return MathMin(MinimumMPIScore, InstantMinimumMPIScore);
   return MinimumMPIScore;
}

// Shared calendar currency resolver — used by news hard-block + event quality.
void PRISM_GetSymbolCurrencies(string &baseCcy, string &quoteCcy)
{
   baseCcy = StringSubstr(BrokerSymbol, 0, 3);
   if(StringLen(BrokerSymbol) >= 6)
      quoteCcy = StringSubstr(BrokerSymbol, 3, 3);
   else
      quoteCcy = StringSubstr(BrokerSymbol, StringLen(BrokerSymbol) - 3, 3);
}

bool PRISM_CalendarCurrencyRelevant(const string eventCurrency,
                                    const string baseCcy,
                                    const string quoteCcy,
                                    const bool cryptoUsd)
{
   return (eventCurrency == baseCcy) ||
          (eventCurrency == quoteCcy) ||
          (cryptoUsd && eventCurrency == "USD");
}

// High-impact event window detector — does NOT block trading.
// Used only to switch into quality-sniper mode (CPI/NFP/FOMC, etc.).
bool IsHighImpactEventWindow()
{
   string baseCcy, quoteCcy;
   PRISM_GetSymbolCurrencies(baseCcy, quoteCcy);

   bool cryptoUsd = (EventQualityAppliesToCrypto && IsNonScalpSymbol() &&
                     (StringFind(BrokerSymbol, "USD") >= 0 || quoteCcy == "USD"));

   datetime from = TimeCurrent() - EventMinutesAfterNews  * 60;
   datetime to   = TimeCurrent() + EventMinutesBeforeNews * 60;

   MqlCalendarValue values[];
   int total = CalendarValueHistory(values, from, to, NULL, NULL);
   if(total <= 0)
      return false;

   for(int i = 0; i < total; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;
      if(event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;

      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;

      if(PRISM_CalendarCurrencyRelevant(country.currency, baseCcy, quoteCcy, cryptoUsd))
         return true;
   }
   return false;
}

ulong g_EventQualityCycle = 0;
bool  g_EventQualityCached = false;

bool EventQualityModeActive()
{
   return false; // OK67: news awareness must never tighten/block via EventQuality
}

// Regular sessions + events: quality gates stay on when AlwaysQuality is enabled.
bool QualityGatesActive()
{
   return EnableAlwaysQualityMode || EventQualityModeActive();
}

bool QualityWeakPathsDisabled()
{
   if(EventQualityModeActive() && EventDisableWeakPaths)
      return true;
   if(EnableAlwaysQualityMode && QualityDisableWeakPaths)
      return true;
   return false;
}

bool QualityNeedsStructureZone()
{
   if(EventQualityModeActive())
      return EventRequireStructureZone;
   if(EnableAlwaysQualityMode)
      return QualityRequireStructureZone;
   return false;
}

bool QualityNeedsTrendAndADX()
{
   if(EventQualityModeActive())
      return EventRequireTrendAndADX;
   if(EnableAlwaysQualityMode)
      return QualityRequireTrendAndADX;
   return false;
}

// InstantTrend is intentionally weak — off under quality mode.
bool InstantTrendSniperBuySetup()
{
   if(BestPathsOnly)
      return false; // BEST-NEXT48: Cont/Rev only
   if(!EnableInstantSniperMode || !AllowTrendOnlyInstantEntry)
      return false;
   // Aggressive institutional execution: InstantTrend stays alive.
   // Only suppress when user explicitly disables weak paths AND not in aggressive mode.
   if(QualityWeakPathsDisabled() && !AggressiveInstitutionalExecution)
      return false;
   if(!IsBullTrend())
      return false;
   if(!TrendStrong())
      return false;
   return true;
}

bool InstantTrendSniperSellSetup()
{
   if(BestPathsOnly)
      return false; // BEST-NEXT48: Cont/Rev only
   if(!EnableInstantSniperMode || !AllowTrendOnlyInstantEntry)
      return false;
   if(QualityWeakPathsDisabled() && !AggressiveInstitutionalExecution)
      return false;
   if(!IsBearTrend())
      return false;
   if(!TrendStrong())
      return false;
   return true;
}

bool RecentBOS(int lookbackBars)
{
   if(DetectBOS())
      return true;

   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0 || idx >= ArraySize(LastBOSTrueBarTimeArr) || LastBOSTrueBarTimeArr[idx] <= 0)
      return false;

   int bars = iBarShift(BrokerSymbol, EntryTF, LastBOSTrueBarTimeArr[idx]);
   return (bars >= 0 && bars <= lookbackBars);
}

bool RecentCHoCH(int lookbackBars)
{
   if(DetectCHoCH())
      return true;

   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0 || idx >= ArraySize(LastCHoCHTrueBarTimeArr) || LastCHoCHTrueBarTimeArr[idx] <= 0)
      return false;

   int bars = iBarShift(BrokerSymbol, EntryTF, LastCHoCHTrueBarTimeArr[idx]);
   return (bars >= 0 && bars <= lookbackBars);
}

// AUDITFIX49: CHoCH reclaim must match trade direction (bull CHoCH for BUY, bear for SELL)
bool RecentDirectionalCHoCH(const bool buy, const int lookbackBars)
{
   if(!RecentCHoCH(lookbackBars))
      return false;

   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0 || idx >= ArraySize(LastCHoCHWasBullArr))
   {
      // Fallback: require live EMA side if direction history missing
      return buy ? IsBullTrend() : IsBearTrend();
   }

   // If CHoCH is firing THIS cycle, DetectCHoCH already set LastCHoCHWasBullArr
   return buy ? LastCHoCHWasBullArr[idx] : !LastCHoCHWasBullArr[idx];
}

bool RecentSweep(int lookbackBars)
{
   if(DetectLiquiditySweep())
      return true;

   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0 || idx >= ArraySize(LastSweepTrueBarTimeArr) || LastSweepTrueBarTimeArr[idx] <= 0)
      return false;

   int bars = iBarShift(BrokerSymbol, EntryTF, LastSweepTrueBarTimeArr[idx]);
   return (bars >= 0 && bars <= lookbackBars);
}

// Order blocks: use the persistent fresh-OR-mitigated state (still an
// active, non-invalidated zone) rather than the raw one-bar detector -
// this is exactly what IsOrderBlockFreshAndValid()/IsOrderBlockMitigated()
// were already built for, just not actually wired into the live PRISM
// strategies before this fix.
bool ActiveOrderBlock(bool buy)
{
   return IsOrderBlockFreshAndValid(buy) || IsOrderBlockMitigated(buy);
}

// FVGs: same idea, using the persistent Active tracker (drops to false
// once the gap is fully filled/mitigated - see UpdateFVGTracking()).
bool ActiveFVG(bool buy)
{
   UpdateFVGTracking();

   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0)
      return buy ? DetectBullishFVG() : DetectBearishFVG();

   return buy ? FVG_Bull_ActiveArr[idx] : FVG_Bear_ActiveArr[idx];
}

// Path A quality continuation: trend (+ADX) + SAME-DIRECTION structure (BOS/OB/FVG).
bool AggressiveContinuationBuySetup()
{
   if(!AggressiveSniperEntries)
      return false;
   if(!IsBullTrend())
      return false;

   double ema = GetEMA();
   double atr = GetFilterATR();
   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
   bool pulled = (ema != EMPTY_VALUE && atr > 0.0 &&
                  MathAbs(price - ema) <= atr * EffectivePullbackATRMultiple());
   // SIGNAL OK45: Cont BUY needs bullish BOS — not any-direction DetectBOS/RecentBOS
   bool bos = StructureDirectionalBOS(true);
   bool zone = ActiveOrderBlock(true) || ActiveFVG(true);

   if(QualityGatesActive())
   {
      if(QualityNeedsTrendAndADX() && !TrendStrong())
         return false;
      // BEST/SAFE: Cont needs real structure (BOS or OB/FVG) — pullback alone is not enough
      if(BestQualitySetups || QualityNeedsStructureZone())
      {
         if(!(zone || bos))
            return false;
         return true;
      }
      // Legacy aggressive: trend+ADX enough
      if(AggressiveInstitutionalExecution)
         return true;
      if(QualityNeedsStructureZone() && !(zone || bos))
         return false;
      return true;
   }

   return bos || zone || pulled || TrendStrong();
}

bool AggressiveContinuationSellSetup()
{
   if(!AggressiveSniperEntries)
      return false;
   if(!IsBearTrend())
      return false;

   double ema = GetEMA();
   double atr = GetFilterATR();
   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
   bool pulled = (ema != EMPTY_VALUE && atr > 0.0 &&
                  MathAbs(price - ema) <= atr * EffectivePullbackATRMultiple());
   // SIGNAL OK45: Cont SELL needs bearish BOS — not any-direction DetectBOS/RecentBOS
   bool bos = StructureDirectionalBOS(false);
   bool zone = ActiveOrderBlock(false) || ActiveFVG(false);

   if(QualityGatesActive())
   {
      if(QualityNeedsTrendAndADX() && !TrendStrong())
         return false;
      if(BestQualitySetups || QualityNeedsStructureZone())
      {
         if(!(zone || bos))
            return false;
         return true;
      }
      if(AggressiveInstitutionalExecution)
         return true;
      if(QualityNeedsStructureZone() && !(zone || bos))
         return false;
      return true;
   }

   return bos || zone || pulled || TrendStrong();
}

// Path B — CORRECT MARKET REVERSAL sniper (signals only when stack is right).
// BUY  = sell-side liquidity swept (lows) more recently than highs + bullish zone + strong reclaim
// SELL = buy-side liquidity swept (highs) more recently than lows + bearish zone + strong reclaim
// Rejects wrong-side/continuation traps and weak candle-only reclaim.
bool AggressiveReversalBuySetup()
{
   if(!AggressiveSniperEntries)
      return false;

   string detail = "";
   bool ok = MarketReversalSignalOK(true, detail);
   if(ReversalLogValidation && (EnableVerboseLogging || EnableSetupLogging))
      Print("REV VALIDATE BUY: ", (ok ? "PASS" : "FAIL"), " — ", detail, " on ", BrokerSymbol);
   return ok;
}

bool AggressiveReversalSellSetup()
{
   if(!AggressiveSniperEntries)
      return false;

   string detail = "";
   bool ok = MarketReversalSignalOK(false, detail);
   if(ReversalLogValidation && (EnableVerboseLogging || EnableSetupLogging))
      Print("REV VALIDATE SELL: ", (ok ? "PASS" : "FAIL"), " — ", detail, " on ", BrokerSymbol);
   return ok;
}

input group "SPEC-COMPLIANT VOLATILITY BREAKOUT"

input int SpecBreakout_ChannelLookbackBars = 20; // structure reference: recent N-bar high/low channel, same channel logic as the legacy version, just without the ATR-expansion gate

bool SpecVolatilityBreakoutBuySetup()
{
   // BEST QUALITY: suppress weak channel breakouts (Cont/Rev preferred)
   if(BestQualitySetups && QualityDisableWeakPaths)
      return false;
   if(QualityWeakPathsDisabled() && !AggressiveInstitutionalExecution)
      return false;

   if(!TrendStrong())
      return false;

   double channelHigh = GetChannelHigh(SpecBreakout_ChannelLookbackBars);
   if(channelHigh <= 0.0)
      return false;

   double closeBar = iClose(BrokerSymbol, EntryTF, SignalBarIndex());
   if(EnableInstantSniperMode)
   {
      double atr = GetFilterATR();
      double pad = (atr > 0.0 ? atr * InstantChannelBreakATR : 0.0);
      return (closeBar >= channelHigh - pad);
   }
   return (closeBar > channelHigh);
}

bool SpecVolatilityBreakoutSellSetup()
{
   if(BestQualitySetups && QualityDisableWeakPaths)
      return false;
   if(QualityWeakPathsDisabled() && !AggressiveInstitutionalExecution)
      return false;

   if(!TrendStrong())
      return false;

   double channelLow = GetChannelLow(SpecBreakout_ChannelLookbackBars);
   if(channelLow <= 0.0)
      return false;

   double closeBar = iClose(BrokerSymbol, EntryTF, SignalBarIndex());
   if(EnableInstantSniperMode)
   {
      double atr = GetFilterATR();
      double pad = (atr > 0.0 ? atr * InstantChannelBreakATR : 0.0);
      return (closeBar <= channelLow + pad);
   }
   return (closeBar < channelLow);
}

bool IsDuplicateSignal(bool buy);
void MarkSignalApproved(bool buy);

//================ PRISM BEAST: UNIFIED STRUCTURE SNAPSHOT ============//
// Single structure read shared by MPI, ICE, and path ranking — eliminates
// 3-5 duplicate BOS/CHoCH/sweep calls per bar.
// (struct PRISMStructureSnapshot declared near SignalSnapshot above)

//================ PRISM ULTRA CORE v11 — CACHE / BEAST SCORE / SNIPER =//
// Design goals: zero redundant calc, explainable rejects, sniper quality,
// aggressive fire ONLY after approval. One structure + beast score per cycle.

ulong  g_UltraStructCycleBuy  = 0;
ulong  g_UltraStructCycleSell = 0;
string g_UltraStructSymbolBuy  = "";
string g_UltraStructSymbolSell = "";
PRISMStructureSnapshot g_UltraStructBuy;
PRISMStructureSnapshot g_UltraStructSell;

ulong  g_UltraBeastCycleBuy  = 0;
ulong  g_UltraBeastCycleSell = 0;
string g_UltraBeastSymbolBuy  = "";
string g_UltraBeastSymbolSell = "";
string g_UltraBeastTagBuy  = "";
string g_UltraBeastTagSell = "";

string g_UltraLastReject = "";
string g_UltraLastDecision = "IDLE";
string g_UltraLastGrade = "-";
int    g_UltraLastBeastScore = 0;
int    g_UltraLastConfidencePct = 0;
long   g_UltraLastDecisionMs = 0;
long   g_UltraDecisionStartMs = 0;
double g_UltraLastBid = 0.0;
double g_UltraLastAsk = 0.0;
int    g_UltraHealthOK = 1;
int    g_UltraRejectCount = 0;
int    g_UltraApproveCount = 0;

struct PRISMBeastScore
{
   int context;
   int htf;
   int structure;
   int liquidity;
   int smt;
   int bos;
   int choch;
   int orderBlock;
   int fvg;
   int premiumDiscount;
   int momentum;
   int confirmation;
   int executionQuality;
   int institutional;
   int trendStrength;
   int reversalProb;
   int volatility;
   int newsStability;
   int overall;
   int confidencePct;
};

PRISMBeastScore g_UltraBeastBuy;
PRISMBeastScore g_UltraBeastSell;

string g_UltraLastRejectPrinted = "";
datetime g_UltraLastRejectBar = 0;

void UltraSetReject(const string reason)
{
   g_UltraLastReject = reason;
   g_UltraLastDecision = "REJECT";
   g_UltraRejectCount++;

   // Throttle: same reason on same symbol prints at most once per EntryTF bar.
   // Cooldown / wait states must NOT flood Experts (your 17:38 spam).
   if(!(EnableUltraCore && UltraLogRejectReasons && (EnableVerboseLogging || EnableSetupLogging)))
      return;

   datetime bar = iTime(BrokerSymbol, EntryTF, 0);
   string key = BrokerSymbol + "|" + reason;
   if(bar == g_UltraLastRejectBar && key == g_UltraLastRejectPrinted)
      return;

   g_UltraLastRejectBar = bar;
   g_UltraLastRejectPrinted = key;
   Print("ULTRA REJECT: ", reason, " on ", BrokerSymbol);
}

void UltraSetWait(const string reason)
{
   // Silent wait (cooldown / final-check) — updates HUD state, no Experts spam.
   g_UltraLastReject = reason;
   g_UltraLastDecision = "WAIT";
}

void UltraSetApprove(const string tag, const string grade, const int beast, const int confPct)
{
   g_UltraLastDecision = "APPROVE " + tag;
   g_UltraLastGrade = grade;
   g_UltraLastBeastScore = beast;
   g_UltraLastConfidencePct = confPct;
   g_UltraLastReject = "";
   g_UltraApproveCount++;
}

PRISMStructureSnapshot PRISM_GetStructureSnapshot(bool buy, int recency)
{
   if(EnableUltraCore && UltraCycleCache)
   {
      if(buy && g_UltraStructCycleBuy == g_CycleCounter && g_UltraStructSymbolBuy == BrokerSymbol)
         return g_UltraStructBuy;
      if(!buy && g_UltraStructCycleSell == g_CycleCounter && g_UltraStructSymbolSell == BrokerSymbol)
         return g_UltraStructSell;
   }

   PRISMStructureSnapshot s;
   s.rec = (recency >= 0 ? recency : EffectiveStructureRecency());
   // BUGCLEAN46: ICE/MPI snapshot must be SAME-DIRECTION — not any-side BOS/sweep
   s.bos = StructureDirectionalBOS(buy);
   // AUDITFIX49: directional CHoCH in snapshot (HP/ICE polarity)
   s.choch = RecentDirectionalCHoCH(buy, s.rec);
   s.sweep = RecentDirectionalSweep(buy, s.rec);
   s.ob = ActiveOrderBlock(buy);
   s.fvg = ActiveFVG(buy);
   s.trend = (buy ? IsBullTrend() : IsBearTrend());
   s.trendStrong = TrendStrong();
   s.htfConfirms = HTFConfirms(buy);

   if(EnableUltraCore && UltraCycleCache)
   {
      if(buy)
      {
         g_UltraStructBuy = s;
         g_UltraStructCycleBuy = g_CycleCounter;
         g_UltraStructSymbolBuy = BrokerSymbol;
      }
      else
      {
         g_UltraStructSell = s;
         g_UltraStructCycleSell = g_CycleCounter;
         g_UltraStructSymbolSell = BrokerSymbol;
      }
   }
   return s;
}

enum ENUM_IMCE_CONTEXT
{
   IMCE_TREND_CONTINUATION = 0,
   IMCE_REVERSAL_LIQUIDITY = 1,
   IMCE_EXPANSION_BREAKOUT = 2,
   IMCE_MANIPULATION_CHOP  = 3,
   IMCE_NEUTRAL            = 4
};

struct PRISM_MarketIntel
{
   MarketRegime regime;
   ENUM_IMCE_CONTEXT imce;
   bool eventWindow;
   bool volExpanding;
   bool dailyBullBias;
   bool weeklyBullBias;
   bool htfBull;
};

ENUM_IMCE_CONTEXT GetIMCEContext();
string IMCEContextToString(ENUM_IMCE_CONTEXT ctx);
PRISM_MarketIntel PRISM_GetMarketIntel(bool buy);
bool PRISMReversalQualityOK(bool buy);
bool SMTInternalBullish();
bool SMTInternalBearish();
bool SMTCrossAssetBullish();
bool SMTCrossAssetBearish();
bool PRISM_IsReversalTag(const string tag);
bool PRISM_IsContinuationTag(const string tag);
int GetInstitutionalConfidenceScore(bool buy);
int CalculatePRISMScore(bool buy);
int CountConfirmingConditions(bool buy);
int GetDisplacementScore(bool buy);

int UltraSMTScore(bool buy, const string strategyTag)
{
   if(!EnableSMT) return 5;
   if(PRISM_IsContinuationTag(strategyTag) && !SMTBlockContinuationPaths)
      return 8;
   if(buy ? SMTInternalBullish() : SMTInternalBearish())
      return 15;
   if(StringLen(SMTReferenceSymbol) > 0)
   {
      if(buy ? SMTCrossAssetBullish() : SMTCrossAssetBearish())
         return 18;
   }
   if(PRISM_IsReversalTag(strategyTag))
      return 0;
   return 6;
}

PRISMBeastScore UltraComputeBeastScore(bool buy, const string strategyTag)
{
   PRISMBeastScore b;
   b.context = 0;
   b.htf = 0;
   b.structure = 0;
   b.liquidity = 0;
   b.smt = 0;
   b.bos = 0;
   b.choch = 0;
   b.orderBlock = 0;
   b.fvg = 0;
   b.premiumDiscount = 0;
   b.momentum = 0;
   b.confirmation = 0;
   b.executionQuality = 0;
   b.institutional = 0;
   b.trendStrength = 0;
   b.reversalProb = 0;
   b.volatility = 0;
   b.newsStability = 0;
   b.overall = 0;
   b.confidencePct = 0;

   PRISMStructureSnapshot s = PRISM_GetStructureSnapshot(buy);
   PRISM_MarketIntel intel = PRISM_GetMarketIntel(buy);
   int ice = GetInstitutionalConfidenceScore(buy);
   int mpi = CalculatePRISMScore(buy);
   int conf = CountConfirmingConditions(buy);
   int liqQ = GetLiquiditySweepQualityScore();
   int disp = GetDisplacementScore(buy);

   // Context (0-10)
   if(intel.imce == IMCE_TREND_CONTINUATION || intel.imce == IMCE_EXPANSION_BREAKOUT) b.context = 10;
   else if(intel.imce == IMCE_REVERSAL_LIQUIDITY) b.context = 8;
   else if(intel.imce == IMCE_NEUTRAL) b.context = 5;
   else b.context = 2;

   // HTF / Daily-Weekly bias (0-10)
   b.htf = 0;
   if(s.htfConfirms) b.htf += 5;
   if(buy ? intel.dailyBullBias : !intel.dailyBullBias) b.htf += 3;
   if(buy ? intel.weeklyBullBias : !intel.weeklyBullBias) b.htf += 2;
   if(b.htf > 10) b.htf = 10;

   // Structure (0-10)
   b.structure = 0;
   if(s.bos) b.structure += 4;
   if(s.choch) b.structure += 4;
   if(s.trend) b.structure += 2;
   if(b.structure > 10) b.structure = 10;

   b.bos = s.bos ? 8 : 0;
   b.choch = s.choch ? 8 : 0;
   b.orderBlock = s.ob ? (IsOrderBlockFreshAndValid(buy) ? 10 : 5) : 0;
   b.fvg = s.fvg ? MathMin((int)MathRound(GetFVGQualityScore(buy) / 2.0), 10) : 0;

   b.liquidity = MathMin(liqQ, 15);
   if(GetLiquidityProximityScore(buy) > 0) b.liquidity = MathMin(b.liquidity + 3, 15);

   b.smt = UltraSMTScore(buy, strategyTag);
   if(b.smt > 15) b.smt = 15;

   b.premiumDiscount = (buy ? InDiscountZone() : InPremiumZone()) ? 8 : 2;
   b.momentum = (intel.volExpanding ? 8 : 3) + MathMin(disp, 7);
   if(b.momentum > 15) b.momentum = 15;

   b.confirmation = MathMin(conf * 2, 12);
   b.executionQuality = (GetFilterATR() > 0.0) ? 8 : 0;
   double spr = (double)SymbolInfoInteger(BrokerSymbol, SYMBOL_SPREAD);
   if(spr > 0 && spr < 50) b.executionQuality += 2;

   b.institutional = MathMin(ice / 8, 12);
   b.trendStrength = (s.trend ? 5 : 0) + (s.trendStrong ? 5 : 0);

   // Reversal probability — high only when stack is real
   b.reversalProb = 0;
   if(PRISM_IsReversalTag(strategyTag))
   {
      if(s.sweep && (s.choch || s.ob || s.fvg)) b.reversalProb = 12;
      else if(s.sweep) b.reversalProb = 5;
      if(DetectFakeBreakoutTrap(buy)) b.reversalProb = MathMax(0, b.reversalProb - 8);
   }
   else if(s.trend && s.trendStrong)
      b.reversalProb = 3; // continuation preferred

   b.volatility = intel.volExpanding ? 8 : (IsVolatilityContracting() ? 3 : 5);
   b.newsStability = intel.eventWindow ? 4 : 8;

   b.overall =
      b.context + b.htf + b.structure + b.liquidity + b.smt +
      b.bos + b.choch + b.orderBlock + b.fvg + b.premiumDiscount +
      b.momentum + b.confirmation + b.executionQuality + b.institutional +
      b.trendStrength + b.reversalProb + b.volatility + b.newsStability;

   // Normalize confidence % from overall (typical max ~180)
   b.confidencePct = (int)MathRound(100.0 * (double)b.overall / 180.0);
   if(b.confidencePct > 100) b.confidencePct = 100;
   if(b.confidencePct < 0) b.confidencePct = 0;

   // Fold MPI lightly so Beast aligns with existing quality floor
   if(mpi > 0)
      b.confidencePct = MathMin(100, (b.confidencePct + MathMin(mpi, 40)) / 2 + 20);

   return b;
}

PRISMBeastScore UltraGetBeastScore(bool buy, const string strategyTag)
{
   if(EnableUltraCore && UltraCycleCache)
   {
      if(buy && g_UltraBeastCycleBuy == g_CycleCounter &&
         g_UltraBeastSymbolBuy == BrokerSymbol && g_UltraBeastTagBuy == strategyTag)
         return g_UltraBeastBuy;
      if(!buy && g_UltraBeastCycleSell == g_CycleCounter &&
         g_UltraBeastSymbolSell == BrokerSymbol && g_UltraBeastTagSell == strategyTag)
         return g_UltraBeastSell;
   }

   PRISMBeastScore b = UltraComputeBeastScore(buy, strategyTag);

   if(EnableUltraCore && UltraCycleCache)
   {
      if(buy)
      {
         g_UltraBeastBuy = b;
         g_UltraBeastCycleBuy = g_CycleCounter;
         g_UltraBeastSymbolBuy = BrokerSymbol;
         g_UltraBeastTagBuy = strategyTag;
      }
      else
      {
         g_UltraBeastSell = b;
         g_UltraBeastCycleSell = g_CycleCounter;
         g_UltraBeastSymbolSell = BrokerSymbol;
         g_UltraBeastTagSell = strategyTag;
      }
   }
   return b;
}

// Sniper Entry Engine — BEST QUALITY checklist.
// Cont/Rev: structure already in path setup; HP confirmations HARD when BestQualitySetups.
// InstantTrend: Beast/Conf floors HARD; soft gates OFF by default.
// UltraAggressiveFire still means: once quality+engines pass → fire immediately.
bool UltraSniperEntryOK(bool buy, const string strategyTag, string &failReason)
{
   failReason = "";
   if(!EnableUltraCore || !UltraSniperEntryGate)
      return true;

   PRISMBeastScore beast = UltraGetBeastScore(buy, strategyTag);
   bool soft = (UltraInstantTrendSoftGates && strategyTag == "InstantTrend" && !BestQualitySetups);
   bool revTag = PRISM_IsReversalTag(strategyTag);
   bool aggro = UltraAggressiveFire || NeverBlockValidSniperEntry || AggressiveInstantQuality;
   bool lcsTag = (strategyTag == "LCS");
   bool apexTag = (strategyTag == "APEX" || PRIME_IsLiveTag(strategyTag));

   if(GetFilterATR() <= 0.0)
   {
      // ALLTRADE56: Cont/Rev/LCS/APEX already selected — Execute uses fixed-stop fallback.
      if((strategyTag == "ContSniper" || strategyTag == "RevSniper" || strategyTag == "ContFallback" || lcsTag || apexTag) &&
         (NeverBlockValidSniperEntry || UltraAggressiveFire))
      {
         if(EnableVerboseLogging || EnableSetupLogging)
            Print("ATR soft: unavailable on ", BrokerSymbol,
                  " — allowing ", strategyTag, " (fixed SL fallback in Execute)");
      }
      else
      {
         failReason = "risk: ATR unavailable";
         return false;
      }
   }

   // APEX / LCS / ContFallback already passed — NEVER post-FIRE veto
   if(apexTag)
   {
      Print("ULTRA APEX PASS (no post-FIRE veto) on ", BrokerSymbol, " — ", g_APEX_LastDetail);
      return true;
   }
   if(strategyTag == "ContFallback")
   {
      Print("ULTRA CONT FALLBACK PASS (execute) on ", BrokerSymbol, " ", (buy ? "BUY" : "SELL"));
      return true;
   }
   if(lcsTag && (NeverBlockValidSniperEntry || UltraAggressiveFire || !UltraSniperEntryGate))
   {
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("ULTRA LCS PASS on ", BrokerSymbol, " — ", g_LCS_LastDetail);
      return true;
   }

   // CONTFIRE55: Cont/Rev already passed path setups + ICE/IMCE before FIRE.
   // Post-FIRE HP confirm veto was killing A+ ContSniper with silent/throttled
   // ULTRA REJECT — Journal showed FIRE then nothing / no fill.
   // NeverBlockValidSniperEntry / UltraAggressiveFire → HP is informational only.
   if(BestQualitySetups && UltraHP_MinConfirmations > 0 &&
      (strategyTag == "ContSniper" || strategyTag == "RevSniper"))
   {
      int conf = CountConfirmingConditions(buy);
      if(conf < UltraHP_MinConfirmations)
      {
         if(NeverBlockValidSniperEntry || UltraAggressiveFire || AggressiveInstantQuality)
         {
            if(EnableVerboseLogging || EnableSetupLogging)
               Print("HP soft: confirms ", conf, "/", UltraHP_MinConfirmations,
                     " on ", strategyTag, " ", BrokerSymbol,
                     " — allowing (NeverBlock/AggressiveFire, path already selected)");
         }
         else
         {
            failReason = StringFormat("HP quality: confirms %d < %d", conf, UltraHP_MinConfirmations);
            return false;
         }
      }
   }

   // InstantTrend: always apply score floors under BestQuality (fallback only if strong)
   if(strategyTag == "InstantTrend" && BestQualitySetups)
   {
      if(UltraMinBeastScore > 0 && beast.overall < UltraMinBeastScore)
      {
         failReason = "InstantTrend Beast " + IntegerToString(beast.overall) +
                      " < floor " + IntegerToString(UltraMinBeastScore);
         return false;
      }
      if(UltraMinConfidencePct > 0 && beast.confidencePct < UltraMinConfidencePct)
      {
         failReason = "InstantTrend Conf " + IntegerToString(beast.confidencePct) +
                      "% < floor " + IntegerToString(UltraMinConfidencePct);
         return false;
      }
      if(!TrendStrong())
      {
         failReason = "InstantTrend: trend not strong enough for quality fallback";
         return false;
      }
      // SAFE42: HTF confirm before Instant early-return (was dead code after aggro return)
      PRISMStructureSnapshot sIT = PRISM_GetStructureSnapshot(buy);
      if(!sIT.htfConfirms)
      {
         failReason = "InstantTrend: HTF not confirming";
         return false;
      }
   }

   // SAFE42: only ContSniper gets early Ultra pass — not TrendPullback/FVG+OB/VolBreakout
   if(strategyTag == "ContSniper" && aggro)
   {
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("ULTRA QUALITY PASS ContSniper Beast=", beast.overall,
               " Conf=", beast.confidencePct, "% HP=ON on ", BrokerSymbol);
      return true;
   }

   // InstantTrend aggro pass only if BestQuality floors already cleared above
   if(strategyTag == "InstantTrend" && aggro && !BestQualitySetups)
   {
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("ULTRA AGGRO PASS InstantTrend Beast=", beast.overall,
               " Conf=", beast.confidencePct, "% on ", BrokerSymbol);
      return true;
   }
   if(strategyTag == "InstantTrend" && aggro && BestQualitySetups)
   {
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("ULTRA QUALITY FALLBACK InstantTrend Beast=", beast.overall,
               " Conf=", beast.confidencePct, "% on ", BrokerSymbol);
      return true;
   }

   PRISMStructureSnapshot s = PRISM_GetStructureSnapshot(buy);

   if(revTag)
   {
      if(!PRISMReversalQualityOK(buy))
      {
         failReason = "reversal: liquidity+structure stack failed";
         return false;
      }
      // BEST: prefer directional sweep already validated in MarketReversalSignalOK
      if(BestQualitySetups)
      {
         string revDetail = "";
         if(!MarketReversalSignalOK(buy, revDetail))
         {
            failReason = "reversal quality: " + revDetail;
            return false;
         }
      }
      else if(!s.sweep)
      {
         failReason = "liquidity confirmation missing";
         return false;
      }
      if(aggro)
      {
         if(EnableVerboseLogging || EnableSetupLogging)
            Print("ULTRA QUALITY PASS RevSniper Beast=", beast.overall,
                  " Conf=", beast.confidencePct, "% on ", BrokerSymbol);
         return true;
      }
   }

   // Non-aggressive quality path (UltraAggressiveFire=false) — remaining tags
   if(!s.trend)
   {
      failReason = "trend bias not aligned";
      return false;
   }

   if(BestQualitySetups && !s.htfConfirms && strategyTag == "InstantTrend")
   {
      failReason = "InstantTrend: HTF not confirming";
      return false;
   }

   if(!soft && EnableHTFConfirmation && !s.htfConfirms)
   {
      failReason = "HTF confirmation gate failed";
      return false;
   }

   if(!soft)
   {
      if(!(s.bos || s.ob || s.fvg || s.trendStrong))
      {
         failReason = "institutional confluence missing (BOS/OB/FVG/ADX)";
         return false;
      }
   }
   else if(!s.trendStrong && !AllowTrendOnlyInstantEntry)
   {
      failReason = "InstantTrend: trend not strong";
      return false;
   }

   if(EnablePremiumDiscountFilter && !NeverBlockValidSniperEntry)
   {
      if(buy && !InDiscountZone())
      {
         failReason = "premium/discount: buy not in discount";
         return false;
      }
      if(!buy && !InPremiumZone())
      {
         failReason = "premium/discount: sell not in premium";
         return false;
      }
   }

   if(!soft && DetectFakeBreakoutTrap(buy))
   {
      failReason = "entry candle: fake breakout trap in trade direction";
      return false;
   }

   if(UltraMinBeastScore > 0 && beast.overall < UltraMinBeastScore)
   {
      failReason = "BeastScore " + IntegerToString(beast.overall) +
                   " < UltraMinBeastScore " + IntegerToString(UltraMinBeastScore);
      return false;
   }

   if(UltraMinConfidencePct > 0 && beast.confidencePct < UltraMinConfidencePct)
   {
      failReason = "Confidence " + IntegerToString(beast.confidencePct) +
                   "% < UltraMinConfidencePct " + IntegerToString(UltraMinConfidencePct);
      return false;
   }

   return true;
}

bool UltraSmartTickUnchanged()
{
   if(!EnableUltraCore || !UltraSmartTickFilter)
      return false;

   // BUGFIX: must also match current bar — otherwise a new bar at same bid/ask
   // would be skipped and miss the sniper entry window.
   static datetime s_lastBar = 0;
   datetime bar = iTime(BrokerSymbol, EntryTF, 0);
   double bid = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);

   if(bar == s_lastBar && bid == g_UltraLastBid && ask == g_UltraLastAsk &&
      g_UltraLastDecision != "IDLE" && g_UltraLastDecision != "")
      return true;

   s_lastBar = bar;
   g_UltraLastBid = bid;
   g_UltraLastAsk = ask;
   return false;
}

bool PRISM_IsReversalTag(const string tag)
{
   return (tag == "RevSniper" || tag == "LiquiditySweep");
}

bool PRISM_IsContinuationTag(const string tag)
{
   return (tag == "ContSniper" || tag == "TrendPullback" ||
           tag == "InstantTrend" || tag == "VolBreakout(Spec)" ||
           tag == "FVG+OB");
}

// Counts how many independent confirming conditions are true for a given
// direction - used ONLY to break ties among setups that are ALREADY each
// individually fully valid (every one of their own hard gates already
// passed). This never makes an invalid setup valid; it only orders
// several simultaneously-valid setups by how much independent structure
// backs each one, per "rank valid strategies" / "select strongest valid
// setup" in the spec.
int CountConfirmingConditions(bool buy)
{
   PRISMStructureSnapshot s = PRISM_GetStructureSnapshot(buy, PRISM_StructureRecencyBars);
   int n = 0;

   if(s.trend) n++;
   if(s.trendStrong) n++;
   if(s.bos) n++;
   if(s.choch) n++;
   if(s.sweep) n++;
   if(s.fvg) n++;
   if(s.ob) n++;

   if(GetLiquidityProximityScore(buy) > 0) n++;

   return n;
}

//================ MARKET PRESSURE INDEX (real MPI, Part 16) =========//
// This is the actual 100-point scoring system from the manual, built for
// real from your existing detectors - not a placeholder. Deliberately
// used as ONE consolidated score instead of implementing Market
// Integrity/Market Strength/Market DNA/Trade Quality/Entry Confirmation
// etc. as 15 separate required 75+ gates: those systems in the manual
// all score the same 7 underlying things (trend, structure, liquidity,
// momentum, institutional confirmation, entry location, risk) under
// different names. Requiring 15 independent ~70%-likely gates to all
// pass simultaneously has roughly a 0.5% chance of ever happening
// (0.7^15) - this is arithmetic, not caution. One real MPI, gated at a
// sensible threshold, is what actually reflects the manual's Part 52
// decision flow: hard structural gates PLUS one final score check.

input int MinimumMPIScore = 0; // unused under AggressiveInstantQuality (no MPI wait)

// FIX (this pass): this function used to be defined *inside* the body of
// EvaluateSpecCompliantStrategies() below - an illegal nested function
// definition that MQL5 (like C++) does not allow, meaning the whole file
// could not compile. Moved to file scope here, and the missing gate
// against MinimumMPIScore has been restored in EvaluateSpecCompliantStrategies().

int CalculatePRISMScore(bool buy)
{
   PRISMStructureSnapshot s =
      PRISM_GetStructureSnapshot(buy, PRISM_StructureRecencyBars);

   int score = 0;

   if(s.trend) score += 10;
   if(s.trendStrong) score += 5;
   if(s.htfConfirms) score += 5;

   if(s.bos) score += 10;
   if(s.choch) score += 10;

   score += GetLiquiditySweepQualityScore();

   if(IsVolatilityExpanding()) score += 15;

   if(IsOrderBlockFreshAndValid(buy)) score += 5;
   score += (int)MathRound(GetFVGQualityScore(buy) / 3.0);

   if(buy ? InDiscountZone() : InPremiumZone()) score += 5;
   score += MathMin(GetLiquidityProximityScore(buy), 5);

   if(GetFilterATR() > 0.0) score += 10;

   if(DetectFakeBreakoutTrap(buy)) score -= 15;

   return score;
}

//+------------------------------------------------------------------+
//|  SMT + IMCE + INSTITUTIONAL CONFIDENCE ENGINE (PRISM layer)      |
//+------------------------------------------------------------------+

// GetDisplacementScore forward-declared in Ultra Core section above

// ENUM_IMCE_CONTEXT + PRISM_MarketIntel declared above in Ultra Core section

//----- ICE: Institutional Confidence Engine (0-100) ------------------//
int GetInstitutionalConfidenceScore(bool buy)
{
   PRISMStructureSnapshot s = PRISM_GetStructureSnapshot(buy);
   int score = 0;

   if(s.trend) score += 15;
   if(s.trendStrong) score += 15;
   if(s.bos) score += 12;
   if(s.choch) score += 10;
   if(s.sweep) score += 12;
   if(s.ob) score += 12;
   if(s.fvg) score += 10;
   if(GetDisplacementScore(buy) >= 5) score += 8;
   if(s.htfConfirms) score += 5;

   ENUM_IMCE_CONTEXT ctx = GetIMCEContext();
   if((ctx == IMCE_TREND_CONTINUATION || ctx == IMCE_EXPANSION_BREAKOUT) &&
      s.trend && s.trendStrong)
      score += 15;

   // Early market reversal: liquidity stack can score before EMA/ADX fully flips
   if(EnableEarlyMarketReversal)
   {
      int rec = MathMax(EffectiveStructureRecency(), ReversalStructureRecencyBars);
      // BUGCLEAN46: correct-side sweep only (BUY=lows, SELL=highs)
      bool liq = RecentDirectionalSweep(buy, rec) || RecentDirectionalCHoCH(buy, rec);
      bool zone = ActiveOrderBlock(buy) || ActiveFVG(buy);
      if(liq && zone)
         score += 15;
      if(ctx == IMCE_REVERSAL_LIQUIDITY)
         score += 10;
   }

   if(score > 100) score = 100;
   return score;
}

bool InstitutionalConfidenceOK(bool buy)
{
   if(!EnableInstitutionalConfidence || !ICERequireForEntry)
      return true;

   int ice = GetInstitutionalConfidenceScore(buy);
   // #9: soft-tighten ICE floor in event windows (still trades — higher bar only)
   int floor = ICE_MinScore;
   if(EventQualityModeActive() && EventICE_MinScoreBoost > 0)
      floor = ICE_MinScore + EventICE_MinScoreBoost;

   if(ice < floor)
   {
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("ICE HARD-blocked ", (buy ? "BUY" : "SELL"), " on ", BrokerSymbol,
               " — ICE ", ice, " < floor ", floor,
               (EventQualityModeActive() ? " [EVENT]" : ""));
      return false;
   }
   return true;
}

//----- SMT: Smart Money Technique ------------------------------------//
// Cross-asset: primary makes a more extreme swing than the reference
// (bullish: primary lower-low, ref higher-low). Internal: liquidity sweep
// + reclaim / CHoCH in trade direction (single-chart SMT).

bool SMTInternalBullish()
{
   int rec = EffectiveStructureRecency();
   // SIGNAL OK45: directional sell-side sweep (lows), not any-side RecentSweep
   bool swept = RecentDirectionalSweep(true, rec);
   bool reclaim = RecentDirectionalCHoCH(true, rec) || StructureDirectionalBOS(true) ||
                  ActiveOrderBlock(true) || ActiveFVG(true);
   return swept && reclaim && (IsBullTrend() || RecentDirectionalCHoCH(true, rec));
}

bool SMTInternalBearish()
{
   int rec = EffectiveStructureRecency();
   // SIGNAL OK45: directional buy-side sweep (highs), not any-side RecentSweep
   bool swept = RecentDirectionalSweep(false, rec);
   bool reclaim = RecentDirectionalCHoCH(false, rec) || StructureDirectionalBOS(false) ||
                  ActiveOrderBlock(false) || ActiveFVG(false);
   return swept && reclaim && (IsBearTrend() || RecentDirectionalCHoCH(false, rec));
}

bool SMTCrossAssetBullish()
{
   if(SMTReferenceSymbol == "" || SMTReferenceSymbol == BrokerSymbol)
      return false;
   if(!SymbolSelect(SMTReferenceSymbol, true))
      return SMTFailOpenIfNoRefData;

   int lb = MathMax(SMTSwingLookbackBars, 5);
   int need = SignalBarIndex() + lb + 1;
   if(Bars(BrokerSymbol, EntryTF) < need || Bars(SMTReferenceSymbol, EntryTF) < need)
      return SMTFailOpenIfNoRefData;

   int b = SignalBarIndex();
   double pLowNow  = iLow(BrokerSymbol, EntryTF, iLowest(BrokerSymbol, EntryTF, MODE_LOW, lb, b));
   double pLowPast = iLow(BrokerSymbol, EntryTF, iLowest(BrokerSymbol, EntryTF, MODE_LOW, lb, b + lb));
   double rLowNow  = iLow(SMTReferenceSymbol, EntryTF, iLowest(SMTReferenceSymbol, EntryTF, MODE_LOW, lb, b));
   double rLowPast = iLow(SMTReferenceSymbol, EntryTF, iLowest(SMTReferenceSymbol, EntryTF, MODE_LOW, lb, b + lb));

   if(pLowPast <= 0.0 || rLowPast <= 0.0)
      return SMTFailOpenIfNoRefData;

   // Bullish SMT: primary made a lower low, reference made a higher low
   bool primaryLL = (pLowNow < pLowPast);
   bool refHL     = (rLowNow > rLowPast);
   return (primaryLL && refHL);
}

bool SMTCrossAssetBearish()
{
   if(SMTReferenceSymbol == "" || SMTReferenceSymbol == BrokerSymbol)
      return false;
   if(!SymbolSelect(SMTReferenceSymbol, true))
      return SMTFailOpenIfNoRefData;

   int lb = MathMax(SMTSwingLookbackBars, 5);
   int need = SignalBarIndex() + lb + 1;
   if(Bars(BrokerSymbol, EntryTF) < need || Bars(SMTReferenceSymbol, EntryTF) < need)
      return SMTFailOpenIfNoRefData;

   int b = SignalBarIndex();
   double pHighNow  = iHigh(BrokerSymbol, EntryTF, iHighest(BrokerSymbol, EntryTF, MODE_HIGH, lb, b));
   double pHighPast = iHigh(BrokerSymbol, EntryTF, iHighest(BrokerSymbol, EntryTF, MODE_HIGH, lb, b + lb));
   double rHighNow  = iHigh(SMTReferenceSymbol, EntryTF, iHighest(SMTReferenceSymbol, EntryTF, MODE_HIGH, lb, b));
   double rHighPast = iHigh(SMTReferenceSymbol, EntryTF, iHighest(SMTReferenceSymbol, EntryTF, MODE_HIGH, lb, b + lb));

   if(pHighPast <= 0.0 || rHighPast <= 0.0)
      return SMTFailOpenIfNoRefData;

   // Bearish SMT: primary higher high, reference lower high
   bool primaryHH = (pHighNow > pHighPast);
   bool refLH     = (rHighNow < rHighPast);
   return (primaryHH && refLH);
}

bool IsReversalSmtTag(const string strategyTag)
{
   return PRISM_IsReversalTag(strategyTag);
}

bool IsContinuationSmtTag(const string strategyTag)
{
   return PRISM_IsContinuationTag(strategyTag);
}

// SMT gate — tag-aware (no duplicate global veto after InstantTrend already passed).
bool SMTOK(bool buy, const string strategyTag)
{
   if(!EnableSMT || !SMTRequireForEntry)
      return true;

   // Continuation / InstantTrend: do NOT hard-block here.
   // RevSniper already embeds sweep+zone (internal SMT) — applying SMT again
   // on InstantTrend was the bug in your Experts log.
   if(IsContinuationSmtTag(strategyTag) && !SMTBlockContinuationPaths)
      return true;

   // Reversal tags: path already required liq+zone. Extra cross-asset SMT
   // only if a reference symbol is set; otherwise trust the path (no duplicate).
   if(IsReversalSmtTag(strategyTag) || strategyTag == "")
   {
      bool haveRef = (SMTReferenceSymbol != "" && SMTReferenceSymbol != BrokerSymbol);
      if(!haveRef)
         return true; // internal SMT already inside RevSniper/LiquiditySweep

      bool cross = buy ? SMTCrossAssetBullish() : SMTCrossAssetBearish();
      if(cross)
         return true;

      if(SMTAllowInternal && (buy ? SMTInternalBullish() : SMTInternalBearish()))
         return true;

      if(SMTFailOpenIfNoRefData)
         return true;

      if(EnableVerboseLogging || EnableSetupLogging)
         Print("SMT HARD-blocked ", strategyTag, " ", (buy ? "BUY" : "SELL"),
               " on ", BrokerSymbol, " — cross-asset SMT failed");
      return false;
   }

   return true;
}

//----- IMCE: Institutional Market Context Engine ---------------------//
ENUM_IMCE_CONTEXT GetIMCEContext()
{
   int rec = EffectiveStructureRecency();
   bool trapBuy = DetectFakeBreakoutTrap(true);
   bool trapSell = DetectFakeBreakoutTrap(false);
   bool sweep = RecentSweep(rec); // any-side OK for "liquidity event" regime detect
   // BUGCLEAN46: trend/expansion BOS must match trend direction
   bool bull = IsBullTrend();
   bool bear = IsBearTrend();
   bool bos = bull ? StructureDirectionalBOS(true)
                   : (bear ? StructureDirectionalBOS(false) : RecentBOS(rec));
   bool choch = RecentCHoCH(rec);
   bool expanding = IsVolatilityExpanding();
   bool trending = TrendStrong() && (bull || bear);

   // Strong trend wins over chop — avoids classifying BTC bull pullbacks as dead chop.
   if(sweep && choch)
      return IMCE_REVERSAL_LIQUIDITY;

   if(expanding && trending && bos)
      return IMCE_EXPANSION_BREAKOUT;

   if(trending && (bos || ActiveOrderBlock(bull) || ActiveFVG(bull)))
      return IMCE_TREND_CONTINUATION;

   if(EnableRegimeDetection && GetMarketRegime() == REGIME_RANGING && sweep)
      return IMCE_REVERSAL_LIQUIDITY;

   if(trending)
      return IMCE_TREND_CONTINUATION;

   // Directional chop: trap against flow, or any trap when not trending.
   bool chopContext = false;
   if(!bos)
   {
      if(trending)
         chopContext = (IsBullTrend() && trapBuy) || (IsBearTrend() && trapSell);
      else
         chopContext = trapBuy || trapSell;
   }
   if(chopContext)
      return IMCE_MANIPULATION_CHOP;

   return IMCE_NEUTRAL;
}

string IMCEContextToString(ENUM_IMCE_CONTEXT ctx)
{
   if(ctx == IMCE_TREND_CONTINUATION) return "TREND_CONTINUATION";
   if(ctx == IMCE_REVERSAL_LIQUIDITY) return "REVERSAL_LIQUIDITY";
   if(ctx == IMCE_EXPANSION_BREAKOUT) return "EXPANSION_BREAKOUT";
   if(ctx == IMCE_MANIPULATION_CHOP)  return "MANIPULATION_CHOP";
   return "NEUTRAL";
}

//================ MARKET DEFENSE ENGINE ==============================//
// Returns true if the position was CLOSED by defense (caller must continue).
bool MarketDefendOpenPosition(const ulong ticket, const long type, const double openPrice,
                              const double price, double &currentSL, double &currentTP,
                              const int stateIndex)
{
   if(!EnableMarketDefense)
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;

   const bool isBuy = (type == POSITION_TYPE_BUY);
   const bool inProfit = isBuy ? (price > openPrice) : (price < openPrice);
   double atr = GetFilterATR();
   int rec = EffectiveStructureRecency();

   // --- Track peak favorable excursion (MFE) ---
   if(stateIndex >= 0)
   {
      double peak = TradeStates[stateIndex].peakFavorable;
      if(peak <= 0.0)
         peak = openPrice;
      if(isBuy && price > peak)
         peak = price;
      if(!isBuy && price < peak)
         peak = price;
      if(peak != TradeStates[stateIndex].peakFavorable)
      {
         TradeStates[stateIndex].peakFavorable = peak;
         PersistTradeState(stateIndex);
      }
   }

   const bool preTP1 = (stateIndex < 0) || !TradeStates[stateIndex].tp1Taken;
   double adverseMove = isBuy ? (openPrice - price) : (price - openPrice);
   if(adverseMove < 0.0)
      adverseMove = 0.0;

   // AUDITOK52: sticky peak adverse (arms #7 even after price recovers)
   if(stateIndex >= 0 && adverseMove > TradeStates[stateIndex].peakAdverse)
   {
      TradeStates[stateIndex].peakAdverse = adverseMove;
      PersistTradeState(stateIndex);
   }
   double peakAdv = (stateIndex >= 0) ? TradeStates[stateIndex].peakAdverse : adverseMove;

   // --- #8 MAE hard cut before TP1 ---
   if(DefenseMAE_StopEnabled && preTP1 && DefenseMAE_ATR > 0.0 && atr > 0.0)
   {
      if(adverseMove >= atr * DefenseMAE_ATR)
      {
         if(DefenseLogActions)
            Print("DEFEND MAE: adverse ", DoubleToString(adverseMove / atr, 2),
                  " ATR ≥ ", DoubleToString(DefenseMAE_ATR, 2),
                  " — closing ticket ", ticket);
         trade.PositionClose(ticket);
         return true;
      }
   }

   // --- #7 Mid-path BE before TP1 (sticky arm → lock when recovered to entry) ---
   if(DefensePreTP1AdverseBE && preTP1 && atr > 0.0 && DefensePreTP1AdverseATR > 0.0)
   {
      bool armed = (peakAdv >= atr * DefensePreTP1AdverseATR);
      bool atOrAboveEntry = isBuy ? (price >= openPrice) : (price <= openPrice);
      bool profitOK = true;
      if(DefensePreTP1RequireProfitTiny)
         profitOK = inProfit || adverseMove <= atr * 0.10;

      if(armed && atOrAboveEntry && profitOK)
      {
         bool needBE = isBuy ? (currentSL < openPrice) : (currentSL > openPrice || currentSL == 0.0);
         if(needBE && trade.PositionModify(ticket, openPrice, currentTP))
         {
            currentSL = openPrice;
            if(DefenseLogActions)
               Print("DEFEND BE: pre-TP1 adverse recover (armed ",
                     DoubleToString(peakAdv / atr, 2), " ATR) — locked BE ticket ", ticket);
         }
      }
   }

   // --- 1) Hard opposing reversal stack → close ---
   if(DefenseCloseOnHardReversal)
   {
      string detail = "";
      bool oppositeRev = MarketReversalSignalOK(!isBuy, detail);
      if(oppositeRev && (!DefenseRequireInProfitToClose || inProfit))
      {
         if(DefenseLogActions)
            Print("DEFEND CLOSE: hard opposite reversal vs ", (isBuy ? "BUY" : "SELL"),
                  " ticket ", ticket, " — ", detail);
         trade.PositionClose(ticket);
         return true;
      }
   }

   // --- 2) Fake-breakout trap against our direction (pre-TP1) → close ---
   if(DefenseCloseOnTrapAgainst && DetectFakeBreakoutTrap(isBuy))
   {
      if(preTP1)
      {
         if(DefenseLogActions)
            Print("DEFEND CLOSE: fake-breakout trap against ", (isBuy ? "BUY" : "SELL"),
                  " ticket ", ticket);
         trade.PositionClose(ticket);
         return true;
      }
      // After TP1: lock at least BE instead of full close
      if(inProfit)
      {
         bool needBE = isBuy ? (currentSL < openPrice) : (currentSL > openPrice || currentSL == 0.0);
         if(needBE && trade.PositionModify(ticket, openPrice, currentTP))
         {
            currentSL = openPrice;
            if(DefenseLogActions)
               Print("DEFEND BE: trap after TP1 — locked breakeven on ticket ", ticket);
         }
      }
   }

   // --- 3) Adverse (wrong-side) sweep → lock breakeven ---
   if(DefenseLockBEOnAdverseSweep && inProfit)
   {
      int wrongBar = MostRecentWrongSideSweepBar(isBuy, MathMax(rec, 8));
      int correctBar = MostRecentCorrectSweepBar(isBuy, MathMax(rec, 8));
      // Wrong-side more recent than our fuel → market turning against us
      if(wrongBar > 0 && (correctBar == 0 || wrongBar < correctBar))
      {
         bool needBE = isBuy ? (currentSL < openPrice) : (currentSL > openPrice || currentSL == 0.0);
         if(needBE && trade.PositionModify(ticket, openPrice, currentTP))
         {
            currentSL = openPrice;
            if(DefenseLogActions)
               Print("DEFEND BE: adverse sweep vs ", (isBuy ? "BUY" : "SELL"),
                     " — locked breakeven ticket ", ticket);
         }
      }
   }

   // --- 4) Manipulation chop while in profit → lock BE ---
   if(DefenseTightenOnChop && inProfit)
   {
      ENUM_IMCE_CONTEXT ctx = GetIMCEContext();
      if(ctx == IMCE_MANIPULATION_CHOP)
      {
         bool needBE = isBuy ? (currentSL < openPrice) : (currentSL > openPrice || currentSL == 0.0);
         if(needBE && trade.PositionModify(ticket, openPrice, currentTP))
         {
            currentSL = openPrice;
            if(DefenseLogActions)
               Print("DEFEND BE: IMCE chop — locked breakeven ticket ", ticket);
         }
      }
   }

   // --- 5) Retrace from peak MFE → lock fraction of peak profit ---
   if(DefenseRetraceLockFromPeak && stateIndex >= 0 && atr > 0.0)
   {
      double peak = TradeStates[stateIndex].peakFavorable;
      if(peak > 0.0)
      {
         double peakMove = isBuy ? (peak - openPrice) : (openPrice - peak);
         double giveBack = isBuy ? (peak - price) : (price - peak);
         if(peakMove > 0.0 && giveBack >= atr * DefenseRetraceATR)
         {
            double lockMove = peakMove * MathMax(0.0, MathMin(DefenseRetraceLockFraction, 1.0));
            double lockSL = isBuy ? (openPrice + lockMove) : (openPrice - lockMove);
            lockSL = NormalizeTradePrice(lockSL);
            bool better = isBuy
               ? (lockSL > currentSL && lockSL < price)
               : ((currentSL == 0.0 || lockSL < currentSL) && lockSL > price);
            if(better && trade.PositionModify(ticket, lockSL, currentTP))
            {
               currentSL = lockSL;
               if(DefenseLogActions)
                  Print("DEFEND LOCK: peak retrace — SL→", DoubleToString(lockSL,
                        (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)),
                        " ticket ", ticket);
            }
         }
      }
   }

   return false;
}

bool IMCEAllows(bool buy, const string strategyTag)
{
   if(!EnableIMCE || !IMCERequireForEntry)
      return true;

   ENUM_IMCE_CONTEXT ctx = GetIMCEContext();

   bool contTag = PRISM_IsContinuationTag(strategyTag);
   bool revTag  = PRISM_IsReversalTag(strategyTag);

   if(IMCEBlockManipulationChop && ctx == IMCE_MANIPULATION_CHOP)
   {
      bool trendAligned =
         TrendStrong() && contTag && (buy ? IsBullTrend() : IsBearTrend());
      if(IMCEAllowTrendContinuationsInChop && trendAligned)
      {
         if(EnableVerboseLogging || EnableSetupLogging)
            Print("IMCE chop override ", strategyTag, " — trend-aligned continuation on ", BrokerSymbol);
         return true;
      }

      if(EnableVerboseLogging || EnableSetupLogging)
         Print("IMCE HARD-blocked ", strategyTag, " — manipulation/chop on ", BrokerSymbol);
      return false;
   }

   if(ctx == IMCE_TREND_CONTINUATION || ctx == IMCE_EXPANSION_BREAKOUT)
   {
      if(revTag)
      {
         int rec = (EnableEarlyMarketReversal
                    ? MathMax(EffectiveStructureRecency(), ReversalStructureRecencyBars)
                    : EffectiveStructureRecency());
         bool sweep = RecentDirectionalSweep(buy, rec);
         bool choch = RecentDirectionalCHoCH(buy, rec);
         bool zone = ActiveOrderBlock(buy) || ActiveFVG(buy);
         bool reclaim = ReversalReclaimConfirm(buy, rec);
         bool strongStack = sweep && (choch || zone) && reclaim;
         bool softStack = EnableEarlyMarketReversal && ReversalIMCESoftInTrend &&
                          sweep && zone && reclaim;

         if(!(strongStack || softStack))
         {
            if(EnableVerboseLogging || EnableSetupLogging)
               Print("IMCE HARD-blocked reversal in trend/expansion: ", strategyTag);
            return false;
         }
         if(EnableEarlyMarketReversal && (EnableVerboseLogging || EnableSetupLogging))
            Print("IMCE early-reversal PASS ", strategyTag,
                  " sweep=", sweep, " CHoCH=", choch, " zone=", zone,
                  " ctx=", IMCEContextToString(ctx), " on ", BrokerSymbol);
      }
      if(contTag && !(buy ? IsBullTrend() : IsBearTrend()))
      {
         if(EnableVerboseLogging || EnableSetupLogging)
            Print("IMCE HARD-blocked ", strategyTag, " — against trend context");
         return false;
      }
      return true;
   }

   if(ctx == IMCE_REVERSAL_LIQUIDITY)
   {
      // BUGCLEAN46: Cont needs SAME-DIRECTION BOS to survive reversal context
      if(contTag && !StructureDirectionalBOS(buy) && strategyTag != "InstantTrend")
      {
         if(EnableVerboseLogging || EnableSetupLogging)
            Print("IMCE HARD-blocked continuation in reversal context: ", strategyTag);
         return false;
      }
      return true;
   }

   // NEUTRAL: still require direction agreement for continuation tags
   if(contTag && !(buy ? IsBullTrend() : IsBearTrend()))
      return false;
   return true;
}

//----- PRISM BEAST: Market Intelligence + Reversal Quality -------------//
PRISM_MarketIntel PRISM_GetMarketIntel(bool buy)
{
   PRISM_MarketIntel m;
   m.regime = GetMarketRegime();
   m.imce = GetIMCEContext();
   m.eventWindow = EventQualityModeActive();
   m.volExpanding = IsVolatilityExpanding();
   m.htfBull = HTFTrendBullish();

   double price = buy
      ? SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK)
      : SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
   double pdMid = (GetPreviousDayHigh() + GetPreviousDayLow()) / 2.0;
   double pwMid = (GetPreviousWeekHigh() + GetPreviousWeekLow()) / 2.0;
   m.dailyBullBias = (pdMid > 0.0 && price > pdMid);
   m.weeklyBullBias = (pwMid > 0.0 && price > pwMid);
   return m;
}

// Unified reversal stack — CORRECT directional validation.
bool PRISMReversalQualityOK(bool buy)
{
   if(!EnableBeastMode || !BeastRequireReversalStack)
      return true;

   string detail = "";
   if(!MarketReversalSignalOK(buy, detail))
      return false;

   if(BeastMinReversalLiquidityScore > 0)
   {
      int rec = (EnableEarlyMarketReversal
                 ? MathMax(EffectiveStructureRecency(), ReversalStructureRecencyBars)
                 : EffectiveStructureRecency());
      int liq = GetLiquiditySweepQualityScore();
      if(liq == 0 && RecentDirectionalSweep(buy, rec))
         liq = 8;
      if(liq == 0 && RecentCHoCH(rec) && EnableEarlyMarketReversal)
         liq = 6;
      if(liq < BeastMinReversalLiquidityScore)
         return false;
   }

   return true;
}

string PRISMGetTradeGrade(bool buy, const string strategyTag)
{
   int mpi = CalculatePRISMScore(buy);
   int ice = GetInstitutionalConfidenceScore(buy);
   int conf = CountConfirmingConditions(buy);
   int total = mpi + ice + conf * 5;

   if(EnableUltraCore)
   {
      PRISMBeastScore beast = UltraGetBeastScore(buy, strategyTag);
      total = beast.overall + beast.confidencePct;
   }

   if(PRISM_IsReversalTag(strategyTag) && !PRISMReversalQualityOK(buy))
      return "D";

   if(total >= 170) return "A+";
   if(total >= 140) return "A";
   if(total >= 110) return "B";
   if(total >= 80)  return "C";
   return "D";
}

bool PRISMFinalizeApproval(bool buy, const string strategyTag)
{
   if(EnableBeastMode && BeastDuplicateBarGuard && IsDuplicateSignal(buy))
   {
      UltraSetReject("duplicate bar guard");
      Print("BEAST: duplicate bar guard suppressed ", (buy ? "BUY" : "SELL"),
            " on ", BrokerSymbol, " (open position already on this EntryTF bar)");
      return false;
   }

   if(EnableUltraCore && UltraSniperEntryGate)
   {
      string fail = "";
      if(!UltraSniperEntryOK(buy, strategyTag, fail))
      {
         UltraSetReject("sniper entry: " + fail);
         return false;
      }
   }

   // Live APEX/ContFallback/LCS already passed their own checklist — skip PRISM score spam
   bool liveSwing = (strategyTag == "APEX" || strategyTag == "ContFallback" || strategyTag == "LCS" || PRIME_IsLiveTag(strategyTag));
   if(liveSwing)
   {
      UltraSetApprove(strategyTag, "A", 100, 100);
      if(EnableBeastMode && BeastCaptureSignalSnapshot)
         CapturePendingSignalSnapshot(buy, strategyTag);
      return true;
   }

   PRISMBeastScore beast = UltraGetBeastScore(buy, strategyTag);
   string grade = PRISMGetTradeGrade(buy, strategyTag);

   if(EnableBeastMode && EnableSniperMode)
   {
      Print("ULTRA SNIPER ", (buy ? "BUY" : "SELL"), " [", strategyTag, "] grade=",
            grade, " Beast=", beast.overall, " Conf=", beast.confidencePct, "%",
            " MPI=", CalculatePRISMScore(buy),
            " ICE=", GetInstitutionalConfidenceScore(buy),
            " IMCE=", IMCEContextToString(GetIMCEContext()));
   }

   UltraSetApprove(strategyTag, grade, beast.overall, beast.confidencePct);
   if(EnableBeastMode && BeastCaptureSignalSnapshot)
      CapturePendingSignalSnapshot(buy, strategyTag);
   return true;
}

bool PrismInstitutionalEnginesOK(bool buy, const string strategyTag)
{
   // APEX / LCS / ContFallback / PRIME embed own checklist — no ICE/IMCE/SMT re-veto
   if(strategyTag == "APEX" || strategyTag == "LCS" || PRIME_IsLiveTag(strategyTag))
      return true;
   if(strategyTag == "ContFallback" && ContFallbackBypassEngines)
      return true;

   if(EnableBeastMode && PRISM_IsReversalTag(strategyTag) && !PRISMReversalQualityOK(buy))
   {
      UltraSetReject("reversal stack insufficient for " + strategyTag);
      if(EnableVerboseLogging || EnableSetupLogging)
         Print("BEAST: reversal stack insufficient for ", strategyTag, " on ", BrokerSymbol);
      return false;
   }

   // ICE + IMCE hard for all paths.
   // SMT hard only on reversal tags (see SMTOK) — not duplicated on InstantTrend.
   if(!InstitutionalConfidenceOK(buy))
   {
      UltraSetReject("ICE below floor for " + strategyTag);
      return false;
   }
   if(!IMCEAllows(buy, strategyTag))
   {
      UltraSetReject("IMCE blocked " + strategyTag);
      return false;
   }
   if(!SMTOK(buy, strategyTag))
   {
      UltraSetReject("SMT blocked " + strategyTag);
      return false;
   }

   if(EnableVerboseLogging)
      Print("Engines PASSED ", strategyTag, " ", (buy ? "BUY" : "SELL"),
            " ICE=", GetInstitutionalConfidenceScore(buy),
            " Beast=", UltraGetBeastScore(buy, strategyTag).overall,
            " IMCE=", IMCEContextToString(GetIMCEContext()),
            " on ", BrokerSymbol);
   return true;
}

//----- FULL UPGRADE: path quality ranking ----------------------------//
// Lower base priority number = higher structural quality.
// InstantTrend is intentional aggressive fallback (priority 6).
int PathBasePriority(const string tag)
{
   if(!PreferQualityPaths)
   {
      // Aggressive-first order when quality preference is off
      if(tag == "InstantTrend")       return 1;
      if(tag == "ContSniper")         return 2;
      if(tag == "RevSniper")          return 3;
      if(tag == "LiquiditySweep")     return 4;
      if(tag == "FVG+OB")             return 5;
      if(tag == "TrendPullback")      return 6;
      if(tag == "VolBreakout(Spec)")  return 7;
      return 99;
   }

   if(tag == "RevSniper")          return 1; // most stacked SMT path
   if(tag == "ContSniper")         return 2; // trend + structure
   if(tag == "LiquiditySweep")     return 3;
   if(tag == "FVG+OB")             return 4;
   if(tag == "TrendPullback")      return 5;
   if(tag == "InstantTrend")       return 6; // aggressive fallback
   if(tag == "VolBreakout(Spec)")  return 7;
   return 99;
}

int PathQualityRankScore(const string tag, const bool buy)
{
   PRISMStructureSnapshot s = PRISM_GetStructureSnapshot(buy);
   int score = 1000 - PathBasePriority(tag) * 100;
   score += GetInstitutionalConfidenceScore(buy);

   if(s.bos) score += 8;
   if(s.ob || s.fvg) score += 8;
   if(s.sweep || s.choch) score += 6;

   if(PRISM_IsReversalTag(tag) && PRISMReversalQualityOK(buy))
      score += 20;

   if(EnableUltraCore)
      score += UltraGetBeastScore(buy, tag).overall / 2;

   // High-probability / BEST QUALITY: strongly prefer Cont/Rev over InstantTrend
   if(UltraHighProbability || BestQualitySetups)
   {
      if(tag == "RevSniper")
         score += 120;
      else if(tag == "ContSniper")
         score += 100;
      else if(tag == "LiquiditySweep" || tag == "FVG+OB")
         score += 45;
      else if(tag == "InstantTrend")
         score -= (BestQualitySetups ? 45 : 15); // fallback only
      else if(tag == "VolBreakout(Spec)" && QualityDisableWeakPaths)
         score -= 30;
      score += CountConfirmingConditions(buy) * (BestQualitySetups ? 12 : 8);
   }

   if(EnableAdaptivePathRanking)
   {
      int idx = FindStrategyTagIndex(tag);
      if(idx >= 0)
      {
         double w = g_StrategyTagWins[idx];
         double l = g_StrategyTagLosses[idx];
         if((w + l) >= AdaptivePathMinTrades && (w + l) > 0.0)
         {
            double wr = w / (w + l);
            score += (int)MathRound(wr * 50.0); // proven paths climb the rank
         }
      }
   }

   return score;
}

// The Priority Engine itself: evaluates every spec-named strategy for
// both directions, rejects the bar entirely if valid setups disagree on
// direction (a genuine conflict - spec says reject, not pick a side), and
// otherwise returns the single strongest valid setup by confirming-
// condition count.
void EvaluateSpecCompliantStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK93 REMOVED — old ContSniper/Rev/Instant/PRISM live router
   buySignal = false; sellSignal = false; strategyTag = "";
}


bool TrendPullbackBuySetup()
{
   if(!IsBullTrend())
      return false;

   if(!TrendStrong())
      return false;

   double ema = GetEMA();
   double atr = GetFilterATR();

   if(ema == EMPTY_VALUE || atr <= 0.0)
      return false;

   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
   double pullMul = EffectivePullbackATRMultiple();
   bool nearEma = (MathAbs(price - ema) <= atr * pullMul);

   // Quality mode (regular + events): need pullback or SAME-DIRECTION BOS — never trend-only.
   if(EnableInstantSniperMode || NeverBlockValidSniperEntry || QualityGatesActive())
   {
      if(QualityGatesActive())
         return (nearEma || StructureDirectionalBOS(true));
      if(NeverBlockValidSniperEntry)
         return true;
      if(nearEma)
         return true;
      if(StructureDirectionalBOS(true))
         return true;
      return false;
   }

   if(!nearEma)
      return false;
   if(!StructureDirectionalBOS(true))
      return false;
   return true;
}

bool TrendPullbackSellSetup()
{
   if(!IsBearTrend())
      return false;

   if(!TrendStrong())
      return false;

   double ema = GetEMA();
   double atr = GetFilterATR();

   if(ema == EMPTY_VALUE || atr <= 0.0)
      return false;

   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
   double pullMul = EffectivePullbackATRMultiple();
   bool nearEma = (MathAbs(price - ema) <= atr * pullMul);

   if(EnableInstantSniperMode || NeverBlockValidSniperEntry || QualityGatesActive())
   {
      if(QualityGatesActive())
         return (nearEma || StructureDirectionalBOS(false));
      if(NeverBlockValidSniperEntry)
         return true;
      if(nearEma)
         return true;
      if(StructureDirectionalBOS(false))
         return true;
      return false;
   }

   if(!nearEma)
      return false;
   if(!StructureDirectionalBOS(false))
      return false;
   return true;
}

input group "LIQUIDITY SWEEP STRATEGY"

bool LiquiditySweepBuySetup()
{
   int rec = EffectiveStructureRecency();
   bool sweep = RecentDirectionalSweep(true, rec);
   bool choch = RecentCHoCH(rec);
   bool ob = ActiveOrderBlock(true);
   bool dirOK = IsBullTrend() || !UseEMA;

   if(!dirOK)
      return false;

   if(EnableInstantSniperMode && InstantTwoOfThreeLiquidity)
   {
      int hits = (sweep ? 1 : 0) + (choch ? 1 : 0) + (ob ? 1 : 0);
      int need = 2; // quality: always 2 of 3
      if(NeverBlockValidSniperEntry && !QualityGatesActive())
         need = 1;
      return (hits >= need);
   }

   return (sweep && choch && ob);
}

bool LiquiditySweepSellSetup()
{
   int rec = EffectiveStructureRecency();
   bool sweep = RecentDirectionalSweep(false, rec);
   bool choch = RecentCHoCH(rec);
   bool ob = ActiveOrderBlock(false);
   bool dirOK = IsBearTrend() || !UseEMA;

   if(!dirOK)
      return false;

   if(EnableInstantSniperMode && InstantTwoOfThreeLiquidity)
   {
      int hits = (sweep ? 1 : 0) + (choch ? 1 : 0) + (ob ? 1 : 0);
      int need = 2;
      if(NeverBlockValidSniperEntry && !QualityGatesActive())
         need = 1;
      return (hits >= need);
   }

   return (sweep && choch && ob);
}

input group "FVG + ORDER BLOCK STRATEGY"

bool FVGOrderBlockBuySetup()
{
   bool bos = StructureDirectionalBOS(true);
   bool fvg = ActiveFVG(true);
   bool ob = ActiveOrderBlock(true);

   if(QualityGatesActive())
   {
      if(QualityNeedsTrendAndADX() && !(IsBullTrend() && TrendStrong()))
         return false;
      if(QualityNeedsStructureZone() && !(fvg || ob))
         return false;
      return (bos || (fvg && ob));
   }

   if(EnableInstantSniperMode && InstantFvgOrOb)
   {
      if(!(bos || IsBullTrend()))
         return false;
      return (fvg || ob);
   }

   return (bos && fvg && ob);
}

bool FVGOrderBlockSellSetup()
{
   bool bos = StructureDirectionalBOS(false);
   bool fvg = ActiveFVG(false);
   bool ob = ActiveOrderBlock(false);

   if(QualityGatesActive())
   {
      if(QualityNeedsTrendAndADX() && !(IsBearTrend() && TrendStrong()))
         return false;
      if(QualityNeedsStructureZone() && !(fvg || ob))
         return false;
      return (bos || (fvg && ob));
   }

   if(EnableInstantSniperMode && InstantFvgOrOb)
   {
      if(!(bos || IsBearTrend()))
         return false;
      return (fvg || ob);
   }

   return (bos && fvg && ob);
}

//+------------------------------------------------------------------+
//|              PART 15f - CORRELATION CONFIRMATION FILTER (NEW)    |
//+------------------------------------------------------------------+
// ADDED per request (Version A - a confirmation gate, not a standalone
// strategy). Applies to whichever strategy actually fired (SMC, mean-
// reversion, breakout, or trend-following) - before committing to the
// trade, checks that a second reference symbol isn't currently moving in
// a way that contradicts it. Example: a EURUSD long when GBPUSD is
// simultaneously breaking down hard could just be generic USD strength
// rather than EUR-specific weakness being wrong - a weaker case than the
// same EURUSD long with GBPUSD confirming the same move.
//
// Deliberately the SIMPLE version: one manually-specified reference
// symbol, one lookback window, one expected relationship (same-direction
// or inverse). It does not calculate a real statistical correlation
// coefficient, does not detect regime changes in that correlation, and
// does not adapt the reference symbol automatically - all real
// limitations of a lightweight filter versus a true pairs-trading system.
// Correlations between forex/metals/crypto are not stable and can break
// down entirely during the exact volatile conditions where you'd most
// want them to hold - this is a soft confirmation gate, not a guarantee.

input group "CORRELATION CONFIRMATION FILTER"

input bool   EnableCorrelationFilter      = false;
input string CorrelationCheckSymbol       = ""; // e.g. "GBPUSD.m" - leave blank to disable even if EnableCorrelationFilter is true
input int    CorrelationLookbackBars      = 20;
input bool   CorrelationExpectSameDirection = true; // true: reference symbol should move the SAME way (e.g. EURUSD vs GBPUSD); false: expect the OPPOSITE (inverse) relationship

bool CorrelationFilterOK(bool buy)
{
   if(!EnableCorrelationFilter)
      return true;

   if(CorrelationCheckSymbol == "" || CorrelationCheckSymbol == BrokerSymbol)
      return true; // nothing configured to check against - don't block on a missing setting

   if(!SymbolSelect(CorrelationCheckSymbol, true))
   {
      if(EnableVerboseLogging)
         Print("Correlation filter: reference symbol '", CorrelationCheckSymbol, "' unavailable - failing open (not blocking).");
      return true; // fail open - a config/availability problem shouldn't silently block all trading
   }

   int barsAvailable = Bars(CorrelationCheckSymbol, EntryTF);

   if(barsAvailable < SignalBarIndex() + CorrelationLookbackBars + 1)
      return true; // not enough history yet - fail open

   double closeNow  = iClose(CorrelationCheckSymbol, EntryTF, SignalBarIndex());
   double closePast = iClose(CorrelationCheckSymbol, EntryTF, SignalBarIndex() + CorrelationLookbackBars);

   if(closeNow <= 0.0 || closePast <= 0.0)
      return true;

   bool referenceIsBullish = (closeNow > closePast);

   bool agree = CorrelationExpectSameDirection
                ? (referenceIsBullish == buy)
                : (referenceIsBullish != buy);

   if(!agree)
   {
      if(EnableVerboseLogging)
         Print("Correlation filter blocked ", (buy ? "BUY" : "SELL"), " on ", BrokerSymbol,
               " - ", CorrelationCheckSymbol, " contradicts the expected relationship.");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//|              PART 15e - TREND-FOLLOWING STRATEGY (NEW)           |
//+------------------------------------------------------------------+
// ADDED per request: a deliberately simple baseline model - a classic
// fast/slow EMA crossover confirmed by ADX strength. This is NOT meant to
// compete on sophistication with the SMC engine; it's meant to be a
// simple, well-understood reference point. If SMC's added complexity
// (BOS/CHoCH/FVG/Order Block/liquidity sweep) doesn't outperform this
// plain crossover once there's real trade data behind both, that's a
// meaningful signal the complexity isn't earning its keep. If SMC clearly
// beats it, that validates the extra machinery. Either result is useful -
// this exists to be compared against, not to be the "best" strategy.
//
// Honest caveat: EMA crossovers are among the most well-known, widely
// traded signals in retail forex - if this alone reliably made money, it
// wouldn't still be a beginner-tutorial staple. Treat it as a yardstick,
// not a strategy you should expect an edge from.

input group "TREND-FOLLOWING STRATEGY"

input int    TrendFollow_FastEMA_Period = 20;
input int    TrendFollow_SlowEMA_Period = 50;
input double TrendFollow_ADXMinimum     = 20.0;

// Returns fast/slow EMA values at the given bar offset (0 = SignalBarIndex()
// itself, 1 = one bar further back) - used to detect the exact crossover
// bar rather than just "which one is currently on top" (which would keep
// re-triggering every bar the cross stays in place, not just once at the
// actual cross).
bool GetTrendFollowEMAs(int barOffset, double &fastEMA, double &slowEMA)
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0 || FastEMAHandlesArr[idx] == INVALID_HANDLE || SlowEMAHandlesArr[idx] == INVALID_HANDLE)
      return false;

   double fastBuf[], slowBuf[];
   ArraySetAsSeries(fastBuf, true);
   ArraySetAsSeries(slowBuf, true);

   int need = SignalBarIndex() + barOffset + 1;

   if(CopyBuffer(FastEMAHandlesArr[idx], 0, 0, need, fastBuf) < need) return false;
   if(CopyBuffer(SlowEMAHandlesArr[idx], 0, 0, need, slowBuf) < need) return false;

   int b = SignalBarIndex() + barOffset;
   fastEMA = fastBuf[b];
   slowEMA = slowBuf[b];

   return true;
}

bool TrendFollowBuySetup()
{
   if(GetADX() < TrendFollow_ADXMinimum)
      return false;

   double fastNow, slowNow, fastPrev, slowPrev;

   if(!GetTrendFollowEMAs(0, fastNow, slowNow))  return false;
   if(!GetTrendFollowEMAs(1, fastPrev, slowPrev)) return false;

   // A genuine fresh cross THIS bar - fast is above slow now, but was at
   // or below slow the bar before. Requiring the actual cross event (not
   // just "fast is currently above slow") avoids re-firing on every bar
   // while an existing cross just continues to hold.
   return (fastNow > slowNow && fastPrev <= slowPrev);
}

bool TrendFollowSellSetup()
{
   if(GetADX() < TrendFollow_ADXMinimum)
      return false;

   double fastNow, slowNow, fastPrev, slowPrev;

   if(!GetTrendFollowEMAs(0, fastNow, slowNow))  return false;
   if(!GetTrendFollowEMAs(1, fastPrev, slowPrev)) return false;

   return (fastNow < slowNow && fastPrev >= slowPrev);
}

//+------------------------------------------------------------------+
//|              PART 15c - VOLATILITY-BREAKOUT STRATEGY (NEW)       |
//+------------------------------------------------------------------+
// ADDED per request: a third, independent model - unlike SMC (reads
// structure/breaks as continuation signals, can mistake a news spike for
// a genuine structural break) and mean-reversion (fades extremes, can get
// run over by a real trending move), this is a plain volatility-breakout
// momentum model: trade WITH a decisive move once volatility is
// confirmed to be genuinely expanding (reusing IsVolatilityExpanding(),
// Part 11) AND price has actually broken outside its recent trading range
// by a real margin - not fighting the move, not reading pattern intent
// into it, just following confirmed range expansion in whichever
// direction it's already moving. This is the most naturally-suited of the
// three models to a news-driven spike specifically, since it doesn't
// require any structural interpretation of WHY price moved - only that it
// genuinely did, meaningfully, right now. It has not been backtested any
// more than the other two - "naturally suited to the mechanism" is not
// the same claim as "proven to work here."

input group "VOLATILITY-BREAKOUT STRATEGY"

input int    VolBreakout_ChannelLookbackBars = 20;  // rolling high/low channel width, in EntryTF bars
input double VolBreakout_MinBreakATRMultiple = 0.15; // how decisively price must clear the channel edge, scaled by ATR - avoids marginal/noise breaks

// Rolling channel high/low over the N most recent CLOSED bars (excludes
// both the forming bar and the just-closed signal bar itself, so the
// signal bar is being judged against bars strictly before it - a
// Donchian-channel-style breakout reference, deliberately simpler than
// GetRecentHigh()/GetRecentLow()'s swing-point detection since a breakout
// model wants "the edge of recent range," not "the last confirmed swing".
double GetChannelHigh(int lookbackBars)
{
   int startBar = SignalBarIndex() + 1;
   double highest = -1.0;

   for(int i = startBar; i < startBar + lookbackBars; i++)
   {
      double h = iHigh(BrokerSymbol, EntryTF, i);

      if(h > highest)
         highest = h;
   }

   return highest;
}

double GetChannelLow(int lookbackBars)
{
   int startBar = SignalBarIndex() + 1;
   double lowest = -1.0;

   for(int i = startBar; i < startBar + lookbackBars; i++)
   {
      double l = iLow(BrokerSymbol, EntryTF, i);

      if(lowest < 0.0 || l < lowest)
         lowest = l;
   }

   return lowest;
}

bool VolatilityBreakoutBuySetup()
{
   if(!IsVolatilityExpanding())
      return false; // core gate - no genuine expansion, no breakout trade

   double channelHigh = GetChannelHigh(VolBreakout_ChannelLookbackBars);

   if(channelHigh <= 0.0)
      return false;

   double closeBar = iClose(BrokerSymbol, EntryTF, SignalBarIndex());
   double atr = GetFilterATR();
   double margin = (atr > 0.0) ? (atr * VolBreakout_MinBreakATRMultiple) : 0.0;

   return (closeBar > channelHigh + margin);
}

bool VolatilityBreakoutSellSetup()
{
   if(!IsVolatilityExpanding())
      return false;

   double channelLow = GetChannelLow(VolBreakout_ChannelLookbackBars);

   if(channelLow <= 0.0)
      return false;

   double closeBar = iClose(BrokerSymbol, EntryTF, SignalBarIndex());
   double atr = GetFilterATR();
   double margin = (atr > 0.0) ? (atr * VolBreakout_MinBreakATRMultiple) : 0.0;

   return (closeBar < channelLow - margin);
}

//+------------------------------------------------------------------+
//| APEX - WORLD-CLASS LIQUIDITY CONTINUITY (from scratch)           |
//+------------------------------------------------------------------+
// Best path I would build unconstrained:
//   Structural HTF bias (swings + MA) → liquidity pool (equal H/L / swing)
//   → stop-hunt of THAT pool → displacement reclaim + optional tick-vol
//   → unmitigated FVG/OB only → SL beyond sweep (cap MaxSL ATR)
//   → FIRE once. Tag APEX = zero post-FIRE veto.

bool APEX_HourInWindow(const int hour, const int startHour, const int endHour)
{
   // Supports normal windows (7-10) and wrap (e.g. 22-2): start>end means overnight
   if(startHour == endHour)
      return true; // full day if misconfigured equal
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
}

// OK71: always DETECT which session is active (name it). Independent of kill-zone allow flags.
void DetectMarketSession(string &name, string &detail, bool &inLondon, bool &inNY, bool &inAsia, bool &inOverlap, int &hourOut)
{
   name = "OFF";
   detail = "";
   inLondon = false;
   inNY = false;
   inAsia = false;
   inOverlap = false;
   hourOut = -1;

   if(!EnableSessionDetect && !EnableAPEXSessionFilter)
   {
      name = "OFF";
      detail = "session detect OFF (24/7)";
      return;
   }

   datetime now = APEX_UseGMT ? TimeGMT() : TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   hourOut = dt.hour;

   // Detect by clock windows (always — for clean analysis)
   inLondon = APEX_HourInWindow(hourOut, APEX_LondonStartHourGMT, APEX_LondonEndHourGMT);
   inNY     = APEX_HourInWindow(hourOut, APEX_NYStartHourGMT, APEX_NYEndHourGMT);
   inAsia   = APEX_HourInWindow(hourOut, APEX_AsiaStartHourGMT, APEX_AsiaEndHourGMT);
   inOverlap = (inLondon && inNY);

   if(inOverlap)      name = "LONDON+NY";
   else if(inLondon)  name = "LONDON";
   else if(inNY)      name = "NEWYORK";
   else if(inAsia)    name = "ASIA";
   else               name = "OFF";

   string clock = APEX_UseGMT ? "GMT" : "SERVER";
   detail = StringFormat("SESSION=%s hour=%d %s | London %d-%d=%s | NY %d-%d=%s | Asia %d-%d=%s",
                         name, hourOut, clock,
                         APEX_LondonStartHourGMT, APEX_LondonEndHourGMT, inLondon ? "Y" : "N",
                         APEX_NYStartHourGMT, APEX_NYEndHourGMT, inNY ? "Y" : "N",
                         APEX_AsiaStartHourGMT, APEX_AsiaEndHourGMT, inAsia ? "Y" : "N");

   if(SessionLogOnChange && name != g_LastSessionNameLogged)
   {
      g_LastSessionNameLogged = name;
      Print("SESSION DETECT: ", detail, " on ", BrokerSymbol,
            APEX_SessionHardBlock ? " | HardBlock=ON" : " | soft (trade anytime)");
   }
}

bool APEX_InKillZone(string &detail)
{
   detail = "";
   string name = "";
   bool inLondon = false, inNY = false, inAsia = false, inOverlap = false;
   int hour = -1;
   DetectMarketSession(name, detail, inLondon, inNY, inAsia, inOverlap, hour);

   if(!EnableAPEXSessionFilter)
   {
      detail = detail + " | filter OFF (24/7)";
      return true;
   }

   // Crypto: never hard-blocked unless SessionFilterCryptoToo + HardBlock
   if(!APEX_SessionFilterCryptoToo && IsNonScalpSymbol())
   {
      detail = detail + " | crypto anytime";
      return true;
   }

   // Kill-zone membership uses Allow* flags (detect still named session above)
   bool killLondon = APEX_AllowLondon && inLondon;
   bool killNY     = APEX_AllowNewYork && inNY;
   bool killAsia   = APEX_AllowAsia && inAsia;
   bool inZone = (killLondon || killNY || killAsia);

   if(inZone)
   {
      detail = StringFormat("%s | IN kill-zone%s%s%s",
                            detail,
                            killLondon ? " London" : "",
                            killNY ? " NY" : "",
                            killAsia ? " Asia" : "");
      return true;
   }

   detail = StringFormat("%s | OUTSIDE kill-zone%s",
                         detail,
                         APEX_SessionHardBlock ? " HARD-BLOCK" : " soft — still allowed anytime");

   if(APEX_SessionHardBlock)
      return false;

   return true;
}

double APEX_AvgRange(const ENUM_TIMEFRAMES tf, const int bars)
{
   int n = MathMax(bars, 2);
   double sum = 0.0;
   int used = 0;
   for(int i = 1; i <= n; i++)
   {
      double hi = iHigh(BrokerSymbol, tf, i);
      double lo = iLow(BrokerSymbol, tf, i);
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
         continue;
      sum += (hi - lo);
      used++;
   }
   return (used > 0) ? (sum / used) : 0.0;
}

double APEX_BiasSMA()
{
   int p = MathMax(APEX_BiasMA_Period, 10);
   if(Bars(BrokerSymbol, APEX_BiasTF) < p + 5)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < p; i++)
      sum += iClose(BrokerSymbol, APEX_BiasTF, i);
   return sum / p;
}

bool APEX_IsSwingHigh(const int bar)
{
   int s = MathMax(APEX_SwingStrength, 1);
   ENUM_TIMEFRAMES tf = APEX_BiasTF;
   double h = iHigh(BrokerSymbol, tf, bar);
   if(h <= 0.0)
      return false;
   for(int i = 1; i <= s; i++)
   {
      if(iHigh(BrokerSymbol, tf, bar - i) >= h)
         return false;
      if(iHigh(BrokerSymbol, tf, bar + i) > h)
         return false;
   }
   return true;
}

bool APEX_IsSwingLow(const int bar)
{
   int s = MathMax(APEX_SwingStrength, 1);
   ENUM_TIMEFRAMES tf = APEX_BiasTF;
   double l = iLow(BrokerSymbol, tf, bar);
   if(l <= 0.0)
      return false;
   for(int i = 1; i <= s; i++)
   {
      if(iLow(BrokerSymbol, tf, bar - i) <= l && iLow(BrokerSymbol, tf, bar - i) > 0.0)
         return false;
      if(iLow(BrokerSymbol, tf, bar + i) < l)
         return false;
   }
   return true;
}

bool APEX_StructureBull(string &detail)
{
   ENUM_TIMEFRAMES tf = APEX_BiasTF;
   int lb = MathMax(APEX_SwingLookback, 20);
   int sh1 = 0, sh2 = 0, sl1 = 0, sl2 = 0;
   for(int i = APEX_SwingStrength + 1; i <= lb; i++)
   {
      if(sh1 == 0 && APEX_IsSwingHigh(i)) sh1 = i;
      else if(sh1 > 0 && sh2 == 0 && APEX_IsSwingHigh(i)) sh2 = i;
      if(sl1 == 0 && APEX_IsSwingLow(i)) sl1 = i;
      else if(sl1 > 0 && sl2 == 0 && APEX_IsSwingLow(i)) sl2 = i;
      if(sh1 > 0 && sh2 > 0 && sl1 > 0 && sl2 > 0)
         break;
   }
   if(sh1 == 0 || sh2 == 0 || sl1 == 0 || sl2 == 0)
   {
      detail = "APEX struct: not enough BiasTF swings";
      return false;
   }
   double h1 = iHigh(BrokerSymbol, tf, sh1);
   double h2 = iHigh(BrokerSymbol, tf, sh2);
   double l1 = iLow(BrokerSymbol, tf, sl1);
   double l2 = iLow(BrokerSymbol, tf, sl2);
   // Bullish structure: most recent swing high > prior, most recent swing low > prior
   // (sh1 is more recent than sh2)
   bool hh = (h1 > h2);
   bool hl = (l1 > l2);
   if(!(hh && hl))
   {
      detail = "APEX struct: no HH+HL bull structure";
      return false;
   }
   detail = "APEX struct: BULL HH+HL";
   return true;
}

bool APEX_StructureBear(string &detail)
{
   ENUM_TIMEFRAMES tf = APEX_BiasTF;
   int lb = MathMax(APEX_SwingLookback, 20);
   int sh1 = 0, sh2 = 0, sl1 = 0, sl2 = 0;
   for(int i = APEX_SwingStrength + 1; i <= lb; i++)
   {
      if(sh1 == 0 && APEX_IsSwingHigh(i)) sh1 = i;
      else if(sh1 > 0 && sh2 == 0 && APEX_IsSwingHigh(i)) sh2 = i;
      if(sl1 == 0 && APEX_IsSwingLow(i)) sl1 = i;
      else if(sl1 > 0 && sl2 == 0 && APEX_IsSwingLow(i)) sl2 = i;
      if(sh1 > 0 && sh2 > 0 && sl1 > 0 && sl2 > 0)
         break;
   }
   if(sh1 == 0 || sh2 == 0 || sl1 == 0 || sl2 == 0)
   {
      detail = "APEX struct: not enough BiasTF swings";
      return false;
   }
   double h1 = iHigh(BrokerSymbol, tf, sh1);
   double h2 = iHigh(BrokerSymbol, tf, sh2);
   double l1 = iLow(BrokerSymbol, tf, sl1);
   double l2 = iLow(BrokerSymbol, tf, sl2);
   bool lh = (h1 < h2);
   bool ll = (l1 < l2);
   if(!(lh && ll))
   {
      detail = "APEX struct: no LH+LL bear structure";
      return false;
   }
   detail = "APEX struct: BEAR LH+LL";
   return true;
}

bool APEX_BiasBull(string &detail)
{
   string sDetail = "";
   bool structOK = true;
   if(APEX_RequireStructureBias || APEX_BiasNeedStructOrMA)
      structOK = APEX_StructureBull(sDetail);

   bool maOK = true;
   if(APEX_RequireMAAlign || APEX_BiasNeedStructOrMA)
   {
      double sma = APEX_BiasSMA();
      double c0 = iClose(BrokerSymbol, APEX_BiasTF, 0);
      double c1 = iClose(BrokerSymbol, APEX_BiasTF, 1);
      maOK = (sma > 0.0 && c0 > sma && c1 > sma);
      if(!maOK)
         sDetail = (sDetail == "" ? "APEX bias: price not clearly above Bias MA" : sDetail);
   }

   // OK60: if StructOrMA — pass when either qualifies (and required flags don't both hard-fail)
   if(APEX_BiasNeedStructOrMA && (APEX_RequireStructureBias || APEX_RequireMAAlign || true))
   {
      if(structOK || maOK)
      {
         detail = structOK && maOK ? "APEX bias: BULL struct+MA"
                : (structOK ? "APEX bias: BULL structure" : "APEX bias: BULL MA");
         return true;
      }
      detail = (sDetail != "" ? sDetail : "APEX bias: no bull structure or MA");
      return false;
   }

   if(APEX_RequireStructureBias && !structOK)
   {
      detail = sDetail;
      return false;
   }
   if(APEX_RequireMAAlign && !maOK)
   {
      detail = "APEX bias: price not clearly above Bias MA";
      return false;
   }
   detail = "APEX bias: BULL";
   return true;
}

bool APEX_BiasBear(string &detail)
{
   string sDetail = "";
   bool structOK = true;
   if(APEX_RequireStructureBias || APEX_BiasNeedStructOrMA)
      structOK = APEX_StructureBear(sDetail);

   bool maOK = true;
   if(APEX_RequireMAAlign || APEX_BiasNeedStructOrMA)
   {
      double sma = APEX_BiasSMA();
      double c0 = iClose(BrokerSymbol, APEX_BiasTF, 0);
      double c1 = iClose(BrokerSymbol, APEX_BiasTF, 1);
      maOK = (sma > 0.0 && c0 < sma && c1 < sma);
      if(!maOK)
         sDetail = (sDetail == "" ? "APEX bias: price not clearly below Bias MA" : sDetail);
   }

   if(APEX_BiasNeedStructOrMA)
   {
      if(structOK || maOK)
      {
         detail = structOK && maOK ? "APEX bias: BEAR struct+MA"
                : (structOK ? "APEX bias: BEAR structure" : "APEX bias: BEAR MA");
         return true;
      }
      detail = (sDetail != "" ? sDetail : "APEX bias: no bear structure or MA");
      return false;
   }

   if(APEX_RequireStructureBias && !structOK)
   {
      detail = sDetail;
      return false;
   }
   if(APEX_RequireMAAlign && !maOK)
   {
      detail = "APEX bias: price not clearly below Bias MA";
      return false;
   }
   detail = "APEX bias: BEAR";
   return true;
}

// Map liquidity pool on EntryTF: equal highs (sell pool) or equal lows (buy pool)
bool APEX_FindBuyPool(double &poolLevel)   // sell-side liquidity = lows
{
   poolLevel = 0.0;
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double atr = APEX_AvgRange(tf, 14);
   double tol = (atr > 0.0) ? (atr * APEX_EqualTolATR) : (SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT) * 20.0);
   int lb = MathMax(APEX_PoolLookback, 10);

   // Prefer equal lows (two distinct lows within tolerance)
   for(int i = 2; i <= lb - 2; i++)
   {
      double l1 = iLow(BrokerSymbol, tf, i);
      if(l1 <= 0.0) continue;
      for(int j = i + 2; j <= lb; j++)
      {
         double l2 = iLow(BrokerSymbol, tf, j);
         if(l2 <= 0.0) continue;
         if(MathAbs(l1 - l2) <= tol)
         {
            poolLevel = MathMin(l1, l2);
            return true;
         }
      }
   }
   // Fallback: most recent swing-ish low (lowest of last N excluding bar0/1)
   double lowest = iLow(BrokerSymbol, tf, 3);
   for(int k = 4; k <= lb; k++)
   {
      double l = iLow(BrokerSymbol, tf, k);
      if(l > 0.0 && l < lowest) lowest = l;
   }
   if(lowest > 0.0)
   {
      poolLevel = lowest;
      return true;
   }
   return false;
}

bool APEX_FindSellPool(double &poolLevel)  // buy-side liquidity = highs
{
   poolLevel = 0.0;
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double atr = APEX_AvgRange(tf, 14);
   double tol = (atr > 0.0) ? (atr * APEX_EqualTolATR) : (SymbolInfoDouble(BrokerSymbol, SYMBOL_POINT) * 20.0);
   int lb = MathMax(APEX_PoolLookback, 10);

   for(int i = 2; i <= lb - 2; i++)
   {
      double h1 = iHigh(BrokerSymbol, tf, i);
      if(h1 <= 0.0) continue;
      for(int j = i + 2; j <= lb; j++)
      {
         double h2 = iHigh(BrokerSymbol, tf, j);
         if(h2 <= 0.0) continue;
         if(MathAbs(h1 - h2) <= tol)
         {
            poolLevel = MathMax(h1, h2);
            return true;
         }
      }
   }
   double highest = iHigh(BrokerSymbol, tf, 3);
   for(int k = 4; k <= lb; k++)
   {
      double h = iHigh(BrokerSymbol, tf, k);
      if(h > highest) highest = h;
   }
   if(highest > 0.0)
   {
      poolLevel = highest;
      return true;
   }
   return false;
}

bool APEX_SweepOfPool(const bool buy, const double poolLevel, int &sweepBar, double &sweepExtreme)
{
   sweepBar = 0;
   sweepExtreme = 0.0;
   if(poolLevel <= 0.0)
      return false;
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double atr = APEX_AvgRange(tf, 14);
   double minDepth = (atr > 0.0) ? (atr * APEX_MinSweepDepthATR) : 0.0;
   int lb = MathMax(APEX_SweepLookback, 3);

   for(int i = 1; i <= lb; i++)
   {
      double hi = iHigh(BrokerSymbol, tf, i);
      double lo = iLow(BrokerSymbol, tf, i);
      double cl = iClose(BrokerSymbol, tf, i);
      double range = hi - lo;
      if(range <= 0.0)
         continue;

      if(buy)
      {
         // Sell-side pool swept (lows taken) then close back above pool
         if(lo < poolLevel - minDepth && cl > poolLevel)
         {
            double wick = MathMin(cl, poolLevel) - lo;
            if(wick / range >= APEX_MinSweepWickRatio)
            {
               sweepBar = i;
               sweepExtreme = lo;
               return true;
            }
         }
      }
      else
      {
         if(hi > poolLevel + minDepth && cl < poolLevel)
         {
            double wick = hi - MathMax(cl, poolLevel);
            if(wick / range >= APEX_MinSweepWickRatio)
            {
               sweepBar = i;
               sweepExtreme = hi;
               return true;
            }
         }
      }
   }
   return false;
}

bool APEX_HasDisplacement(const bool buy)
{
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double o = iOpen(BrokerSymbol, tf, 1);
   double c = iClose(BrokerSymbol, tf, 1);
   double h = iHigh(BrokerSymbol, tf, 1);
   double l = iLow(BrokerSymbol, tf, 1);
   double range = h - l;
   if(range <= 0.0)
      return false;
   if(buy && !(c > o))
      return false;
   if(!buy && !(c < o))
      return false;
   if(MathAbs(c - o) / range < APEX_DispMinBodyRatio)
      return false;
   double atr = APEX_AvgRange(tf, 14);
   if(atr > 0.0 && (range / atr) < APEX_DispMinATR)
      return false;

   // Tick volume expansion (soft or hard)
   if(APEX_TickVolExpansion > 1.0)
   {
      long v1 = iTickVolume(BrokerSymbol, tf, 1);
      double avg = 0.0;
      int n = 0;
      for(int i = 2; i <= 15; i++)
      {
         long v = iTickVolume(BrokerSymbol, tf, i);
         if(v > 0) { avg += (double)v; n++; }
      }
      if(n > 0)
      {
         avg /= n;
         bool expanded = (avg > 0.0 && (double)v1 >= avg * APEX_TickVolExpansion);
         if(APEX_RequireTickVol && !expanded)
            return false;
      }
   }
   return true;
}

bool APEX_HasReclaim(const bool buy, const double poolLevel)
{
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double c1 = iClose(BrokerSymbol, tf, 1);
   double o1 = iOpen(BrokerSymbol, tf, 1);
   if(buy)
      return (c1 > o1 && c1 > poolLevel);
   return (c1 < o1 && c1 < poolLevel);
}

bool APEX_BullishFVG_Unmitigated()
{
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double low1 = iLow(BrokerSymbol, tf, 1);
   double high3 = iHigh(BrokerSymbol, tf, 3);
   if(!(low1 > 0.0 && high3 > 0.0 && low1 > high3))
      return false;
   // Unmitigated: current price has not fully traded through the gap bottom
   double bid = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
   return (bid >= high3);
}

bool APEX_BearishFVG_Unmitigated()
{
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double high1 = iHigh(BrokerSymbol, tf, 1);
   double low3 = iLow(BrokerSymbol, tf, 3);
   if(!(high1 > 0.0 && low3 > 0.0 && high1 < low3))
      return false;
   double ask = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
   return (ask <= low3);
}

bool APEX_BullishOB_Unmitigated()
{
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double o2 = iOpen(BrokerSymbol, tf, 2);
   double c2 = iClose(BrokerSymbol, tf, 2);
   double o1 = iOpen(BrokerSymbol, tf, 1);
   double c1 = iClose(BrokerSymbol, tf, 1);
   if(!(c2 < o2 && c1 > o1))
      return false;
   double bid = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
   double obLow = iLow(BrokerSymbol, tf, 2);
   double obHigh = iHigh(BrokerSymbol, tf, 2);
   // Still in/above OB — not closed fully below
   return (bid >= obLow && iClose(BrokerSymbol, tf, 0) >= obLow && bid <= obHigh * 1.01);
}

bool APEX_BearishOB_Unmitigated()
{
   ENUM_TIMEFRAMES tf = APEX_EntryTF;
   double o2 = iOpen(BrokerSymbol, tf, 2);
   double c2 = iClose(BrokerSymbol, tf, 2);
   double o1 = iOpen(BrokerSymbol, tf, 1);
   double c1 = iClose(BrokerSymbol, tf, 1);
   if(!(c2 > o2 && c1 < o1))
      return false;
   double ask = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
   double obLow = iLow(BrokerSymbol, tf, 2);
   double obHigh = iHigh(BrokerSymbol, tf, 2);
   return (ask <= obHigh && iClose(BrokerSymbol, tf, 0) <= obHigh && ask >= obLow * 0.99);
}

bool APEX_HasUnmitigatedZone(const bool buy)
{
   if(buy)
   {
      if(APEX_BullishFVG_Unmitigated() || APEX_BullishOB_Unmitigated())
         return true;
      // OK60 soft fallback: existing Active FVG/OB trackers
      return (ActiveFVG(true) || ActiveOrderBlock(true));
   }
   if(APEX_BearishFVG_Unmitigated() || APEX_BearishOB_Unmitigated())
      return true;
   return (ActiveFVG(false) || ActiveOrderBlock(false));
}

//================ SNIPER IDP - BUILT INTO EA ===========================//
// Same pulse math as SNIPER_IDP.mq5, computed inside the bot on EntryTF.

double IDP_ClampPulse(double v)
{
   if(v > 100.0) return 100.0;
   if(v < -100.0) return -100.0;
   return v;
}

double IDP_BarATR(const int shift)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   int period = (IDP_ATR_Period > 1 ? IDP_ATR_Period : 1);
   double sum = 0.0;
   int n = 0;
   for(int i = shift; i < shift + period; i++)
   {
      double h = iHigh(BrokerSymbol, tf, i);
      double l = iLow(BrokerSymbol, tf, i);
      double pc = iClose(BrokerSymbol, tf, i + 1);
      if(h <= 0.0 || l <= 0.0 || pc <= 0.0)
         continue;
      double tr = MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
      sum += tr;
      n++;
   }
   return (n > 0) ? (sum / n) : 0.0;
}

double IDP_BarEMA(const int shift)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   int period = (IDP_EMA_Period > 1 ? IDP_EMA_Period : 1);
   double k = 2.0 / (period + 1.0);
   int seedShift = shift + period;
   double sma = 0.0;
   int n = 0;
   for(int i = seedShift; i < seedShift + period; i++)
   {
      double c = iClose(BrokerSymbol, tf, i);
      if(c <= 0.0) continue;
      sma += c;
      n++;
   }
   if(n == 0)
      return 0.0;
   double ema = sma / n;
   for(int i = seedShift - 1; i >= shift; i--)
   {
      double c = iClose(BrokerSymbol, tf, i);
      if(c <= 0.0) continue;
      ema = c * k + ema * (1.0 - k);
   }
   return ema;
}

double IDP_PriorSwingHigh(const int shift)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   double h = iHigh(BrokerSymbol, tf, shift + 1);
   for(int j = shift + 2; j <= shift + 1 + IDP_SwingLookback; j++)
   {
      double v = iHigh(BrokerSymbol, tf, j);
      if(v > h) h = v;
   }
   return h;
}

double IDP_PriorSwingLow(const int shift)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   double l = iLow(BrokerSymbol, tf, shift + 1);
   for(int j = shift + 2; j <= shift + 1 + IDP_SwingLookback; j++)
   {
      double v = iLow(BrokerSymbol, tf, j);
      if(v > 0.0 && v < l) l = v;
   }
   return l;
}

double IDP_SweepScore(const int shift, const double atr)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   double hi = iHigh(BrokerSymbol, tf, shift);
   double lo = iLow(BrokerSymbol, tf, shift);
   double cl = iClose(BrokerSymbol, tf, shift);
   double range = hi - lo;
   if(range <= 0.0 || atr <= 0.0)
      return 0.0;

   double priorHigh = IDP_PriorSwingHigh(shift);
   double priorLow  = IDP_PriorSwingLow(shift);
   double minDepth  = atr * IDP_SweepMinDepthATR;
   double score = 0.0;

   if(lo < priorLow - minDepth && cl > priorLow)
   {
      double wick = MathMin(cl, priorLow) - lo;
      double ratio = wick / range;
      if(ratio >= IDP_SweepMinWickRatio)
         score += 25.0 * MathMin(ratio / 0.6, 1.5);
   }
   if(hi > priorHigh + minDepth && cl < priorHigh)
   {
      double wick = hi - MathMax(cl, priorHigh);
      double ratio = wick / range;
      if(ratio >= IDP_SweepMinWickRatio)
         score -= 25.0 * MathMin(ratio / 0.6, 1.5);
   }
   return score;
}

double IDP_DisplacementScore(const int shift, const double atr)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   double o = iOpen(BrokerSymbol, tf, shift);
   double c = iClose(BrokerSymbol, tf, shift);
   double h = iHigh(BrokerSymbol, tf, shift);
   double l = iLow(BrokerSymbol, tf, shift);
   double range = h - l;
   if(range <= 0.0)
      return 0.0;

   double body = MathAbs(c - o);
   double bodyRatio = body / range;
   if(bodyRatio < IDP_DispMinBodyRatio)
      return 0.0;
   if(atr > 0.0 && range < atr * IDP_DispMinATR)
      return 0.0;

   double mag = 35.0 * MathMin(bodyRatio / 0.7, 1.4);
   if(atr > 0.0)
      mag *= MathMin(range / (atr * 0.8), 1.5);
   return (c > o) ? mag : -mag;
}

double IDP_BosScore(const int shift, const double atr)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   double c1 = iClose(BrokerSymbol, tf, shift);
   double c2 = iClose(BrokerSymbol, tf, shift + 1);
   double swingHigh = IDP_PriorSwingHigh(shift);
   double swingLow  = IDP_PriorSwingLow(shift);
   double margin = (atr > 0.0) ? (atr * 0.10) : 0.0;

   if(c2 <= swingHigh && c1 > swingHigh + margin)
      return 20.0;
   if(c2 >= swingLow && c1 < swingLow - margin)
      return -20.0;
   return 0.0;
}

double IDP_TrendSideScore(const int shift)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   double ema = IDP_BarEMA(shift);
   double c = iClose(BrokerSymbol, tf, shift);
   if(ema <= 0.0 || c <= 0.0)
      return 0.0;
   if(c > ema) return 10.0;
   if(c < ema) return -10.0;
   return 0.0;
}

double IDP_ExpansionScore(const int shift)
{
   ENUM_TIMEFRAMES tf = EntryTF;
   double r0 = iHigh(BrokerSymbol, tf, shift) - iLow(BrokerSymbol, tf, shift);
   double r1 = iHigh(BrokerSymbol, tf, shift + 1) - iLow(BrokerSymbol, tf, shift + 1);
   if(r1 <= 0.0 || r0 <= 0.0)
      return 0.0;
   if(r0 < r1 * 1.15)
      return 0.0;
   double c = iClose(BrokerSymbol, tf, shift);
   double o = iOpen(BrokerSymbol, tf, shift);
   double boost = 10.0 * MathMin(r0 / r1, 2.0);
   return (c > o) ? boost : -boost;
}

double IDP_ComputePulse(const int shift)
{
   double atr = IDP_BarATR(shift);
   double pulse = 0.0;
   pulse += IDP_SweepScore(shift, atr);
   pulse += IDP_DisplacementScore(shift, atr);
   pulse += IDP_BosScore(shift, atr);
   pulse += IDP_TrendSideScore(shift);
   pulse += IDP_ExpansionScore(shift);
   return IDP_ClampPulse(pulse);
}

bool IDP_GetPulse(double &pulse, string &detail)
{
   int shift;
   pulse = 0.0;
   detail = "";
   if(!EnableIDPConfluence)
   {
      detail = "IDP off";
      return false;
   }

   shift = (IDP_PulseShift > 0 ? IDP_PulseShift : 0);
   if(iBars(BrokerSymbol, EntryTF) < IDP_ATR_Period + IDP_EMA_Period + IDP_SwingLookback + 5)
   {
      detail = "IDP: not enough bars";
      return false;
   }

   pulse = IDP_ComputePulse(shift);
   detail = StringFormat("IDP built-in pulse=%.1f shift=%d", pulse, shift);
   return true;
}

bool IDP_ConfluenceOK(const bool buy, string &detail)
{
   // OK93: IDP retired as live gate — ULTRA confluence owns decisions
   detail = "IDP retired soft-pass OK93";
   return true;
}



bool APEX_SetupOK(const bool buy, string &detail, double &invalidation)
{
   // OK93 REMOVED — old APEX live strategy deleted
   detail = "APEX retired OK93";
   invalidation = 0.0;
   return false;
}


void EvaluateAPEXStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK93 REMOVED — never opens trades
   buySignal = false; sellSignal = false; strategyTag = "";
}


//+------------------------------------------------------------------+
//| LCS - LIQUIDITY CONTINUITY SNIPER (high-prob live engine)        |
//+------------------------------------------------------------------+
// From-scratch path (OK57):
//   1) BiasTF (H4) clear SMA bias
//   2) EntryTF (H1) stop-hunt sweep AGAINST bias (sell-side for BUY, buy-side for SELL)
//   3) Reclaim + displacement in bias direction
//   4) Price interacting with FVG or OB from that move
//   5) Invalidation = sweep extreme (used as SL when LCS_UseSweepSL)

double LCS_AvgRange(const ENUM_TIMEFRAMES tf, const int bars)
{
   int n = MathMax(bars, 2);
   double sum = 0.0;
   int used = 0;
   for(int i = 1; i <= n; i++)
   {
      double hi = iHigh(BrokerSymbol, tf, i);
      double lo = iLow(BrokerSymbol, tf, i);
      if(hi <= 0.0 || lo <= 0.0 || hi < lo)
         continue;
      sum += (hi - lo);
      used++;
   }
   return (used > 0) ? (sum / used) : 0.0;
}

double LCS_BiasSMA()
{
   int p = MathMax(LCS_BiasMA_Period, 10);
   if(Bars(BrokerSymbol, LCS_BiasTF) < p + 5)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < p; i++)
      sum += iClose(BrokerSymbol, LCS_BiasTF, i);
   return sum / p;
}

bool LCS_BiasBull(string &detail)
{
   double sma = LCS_BiasSMA();
   double c0 = iClose(BrokerSymbol, LCS_BiasTF, 0);
   double c1 = iClose(BrokerSymbol, LCS_BiasTF, 1);
   if(sma <= 0.0 || c0 <= 0.0)
   {
      detail = "bias: BiasTF history/SMA unavailable";
      return false;
   }
   // Clear bull bias: price and prior close above SMA (no chop hug required beyond side)
   if(!(c0 > sma && c1 > sma))
   {
      detail = "bias: not clear bull (close vs SMA200 H4)";
      return false;
   }
   detail = "bias: BULL";
   return true;
}

bool LCS_BiasBear(string &detail)
{
   double sma = LCS_BiasSMA();
   double c0 = iClose(BrokerSymbol, LCS_BiasTF, 0);
   double c1 = iClose(BrokerSymbol, LCS_BiasTF, 1);
   if(sma <= 0.0 || c0 <= 0.0)
   {
      detail = "bias: BiasTF history/SMA unavailable";
      return false;
   }
   if(!(c0 < sma && c1 < sma))
   {
      detail = "bias: not clear bear (close vs SMA200 H4)";
      return false;
   }
   detail = "bias: BEAR";
   return true;
}

bool LCS_IsBuySideSweepAt(const int bar, double &sweepExtreme)
{
   sweepExtreme = 0.0;
   if(bar < 1)
      return false;
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   double currentHigh = iHigh(BrokerSymbol, tf, bar);
   double currentLow  = iLow(BrokerSymbol, tf, bar);
   double close = iClose(BrokerSymbol, tf, bar);
   double barRange = currentHigh - currentLow;
   if(barRange <= 0.0)
      return false;

   double previousHigh = iHigh(BrokerSymbol, tf, bar + 1);
   int pad = MathMax(LCS_SwingPadBars, 2);
   for(int j = bar + 2; j <= bar + pad + 1; j++)
   {
      double h = iHigh(BrokerSymbol, tf, j);
      if(h > previousHigh) previousHigh = h;
   }

   double atr = LCS_AvgRange(tf, 14);
   double minDepth = (atr > 0.0) ? (atr * LCS_MinSweepDepthATR) : 0.0;
   if(!(currentHigh > previousHigh + minDepth && close < previousHigh))
      return false;

   double wick = currentHigh - MathMax(close, previousHigh);
   if(wick / barRange < LCS_MinSweepWickRatio)
      return false;

   sweepExtreme = currentHigh;
   return true;
}

bool LCS_IsSellSideSweepAt(const int bar, double &sweepExtreme)
{
   sweepExtreme = 0.0;
   if(bar < 1)
      return false;
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   double currentHigh = iHigh(BrokerSymbol, tf, bar);
   double currentLow  = iLow(BrokerSymbol, tf, bar);
   double close = iClose(BrokerSymbol, tf, bar);
   double barRange = currentHigh - currentLow;
   if(barRange <= 0.0)
      return false;

   double previousLow = iLow(BrokerSymbol, tf, bar + 1);
   int pad = MathMax(LCS_SwingPadBars, 2);
   for(int j = bar + 2; j <= bar + pad + 1; j++)
   {
      double l = iLow(BrokerSymbol, tf, j);
      if(l < previousLow && l > 0.0) previousLow = l;
   }

   double atr = LCS_AvgRange(tf, 14);
   double minDepth = (atr > 0.0) ? (atr * LCS_MinSweepDepthATR) : 0.0;
   if(!(currentLow < previousLow - minDepth && close > previousLow))
      return false;

   double wick = MathMin(close, previousLow) - currentLow;
   if(wick / barRange < LCS_MinSweepWickRatio)
      return false;

   sweepExtreme = currentLow;
   return true;
}

int LCS_FindCorrectSweep(const bool buy, double &sweepExtreme)
{
   sweepExtreme = 0.0;
   int lb = MathMax(LCS_SweepLookbackBars, 2);
   for(int i = 1; i <= lb; i++)
   {
      double ext = 0.0;
      if(buy && LCS_IsSellSideSweepAt(i, ext))
      {
         sweepExtreme = ext;
         return i;
      }
      if(!buy && LCS_IsBuySideSweepAt(i, ext))
      {
         sweepExtreme = ext;
         return i;
      }
   }
   return 0;
}

bool LCS_HasDisplacement(const bool buy)
{
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   double o = iOpen(BrokerSymbol, tf, 1);
   double c = iClose(BrokerSymbol, tf, 1);
   double h = iHigh(BrokerSymbol, tf, 1);
   double l = iLow(BrokerSymbol, tf, 1);
   double range = h - l;
   if(range <= 0.0)
      return false;
   if(buy && !(c > o))
      return false;
   if(!buy && !(c < o))
      return false;
   double bodyRatio = MathAbs(c - o) / range;
   if(bodyRatio < LCS_DispMinBodyRatio)
      return false;
   double atr = LCS_AvgRange(tf, 14);
   if(atr <= 0.0)
      return true;
   return ((range / atr) >= LCS_DispMinATR);
}

bool LCS_HasReclaim(const bool buy, const int sweepBar)
{
   // After sweep, price must be back on the correct side of the swept level
   // and print a directional closed bar (bar 1).
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   double c1 = iClose(BrokerSymbol, tf, 1);
   double o1 = iOpen(BrokerSymbol, tf, 1);
   if(buy)
   {
      if(!(c1 > o1))
         return false;
      // reclaim above the sweep low extreme already implied by sell-side sweep close
      // also require close above midpoint of sweep bar
      double mid = 0.5 * (iHigh(BrokerSymbol, tf, sweepBar) + iLow(BrokerSymbol, tf, sweepBar));
      return (c1 >= mid);
   }
   if(!(c1 < o1))
      return false;
   double midS = 0.5 * (iHigh(BrokerSymbol, tf, sweepBar) + iLow(BrokerSymbol, tf, sweepBar));
   return (c1 <= midS);
}

bool LCS_BullishFVG()
{
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   // Classic 3-candle imbalance: low[1] > high[3]
   double low1 = iLow(BrokerSymbol, tf, 1);
   double high3 = iHigh(BrokerSymbol, tf, 3);
   return (low1 > 0.0 && high3 > 0.0 && low1 > high3);
}

bool LCS_BearishFVG()
{
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   double high1 = iHigh(BrokerSymbol, tf, 1);
   double low3 = iLow(BrokerSymbol, tf, 3);
   return (high1 > 0.0 && low3 > 0.0 && high1 < low3);
}

bool LCS_BullishOB()
{
   // Last opposing (bearish) candle before bullish displacement, still relevant
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   double o2 = iOpen(BrokerSymbol, tf, 2);
   double c2 = iClose(BrokerSymbol, tf, 2);
   double o1 = iOpen(BrokerSymbol, tf, 1);
   double c1 = iClose(BrokerSymbol, tf, 1);
   if(!(c2 < o2 && c1 > o1))
      return false;
   double bid = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);
   double obLow = iLow(BrokerSymbol, tf, 2);
   double obHigh = iHigh(BrokerSymbol, tf, 2);
   // Price still at/above OB (not fully traded through below)
   return (bid >= obLow && bid <= obHigh * 1.002);
}

bool LCS_BearishOB()
{
   ENUM_TIMEFRAMES tf = LCS_EntryTF;
   double o2 = iOpen(BrokerSymbol, tf, 2);
   double c2 = iClose(BrokerSymbol, tf, 2);
   double o1 = iOpen(BrokerSymbol, tf, 1);
   double c1 = iClose(BrokerSymbol, tf, 1);
   if(!(c2 > o2 && c1 < o1))
      return false;
   double ask = SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
   double obLow = iLow(BrokerSymbol, tf, 2);
   double obHigh = iHigh(BrokerSymbol, tf, 2);
   return (ask <= obHigh && ask >= obLow * 0.998);
}

bool LCS_HasZone(const bool buy)
{
   if(buy)
      return (LCS_BullishFVG() || LCS_BullishOB() || ActiveFVG(true) || ActiveOrderBlock(true));
   return (LCS_BearishFVG() || LCS_BearishOB() || ActiveFVG(false) || ActiveOrderBlock(false));
}

bool LCS_SetupOK(const bool buy, string &detail, double &invalidation)
{
   detail = "";
   invalidation = 0.0;
   g_LCS_LastDetail = "";

   if(!EnableLCSStrategy)
   {
      detail = "LCS disabled";
      return false;
   }

   if(Bars(BrokerSymbol, LCS_BiasTF) < LCS_BiasMA_Period + 5 ||
      Bars(BrokerSymbol, LCS_EntryTF) < LCS_SweepLookbackBars + 10)
   {
      detail = "LCS: insufficient Bias/Entry TF bars";
      return false;
   }

   string biasDetail = "";
   if(buy)
   {
      if(!LCS_BiasBull(biasDetail))
      {
         detail = biasDetail;
         return false;
      }
   }
   else
   {
      if(!LCS_BiasBear(biasDetail))
      {
         detail = biasDetail;
         return false;
      }
   }

   double sweepExt = 0.0;
   int sweepBar = LCS_FindCorrectSweep(buy, sweepExt);
   if(sweepBar <= 0 || sweepExt <= 0.0)
   {
      detail = buy ? "LCS: need sell-side sweep (lows taken) on EntryTF"
                   : "LCS: need buy-side sweep (highs taken) on EntryTF";
      return false;
   }

   if(!LCS_HasReclaim(buy, sweepBar))
   {
      detail = "LCS: need reclaim after sweep";
      return false;
   }

   bool disp = LCS_HasDisplacement(buy);
   if(LCS_RequireDisplacement && !disp)
   {
      detail = "LCS: need displacement candle in bias direction";
      return false;
   }

   bool zone = LCS_HasZone(buy);
   if(LCS_RequireZone && !zone)
   {
      detail = "LCS: need FVG/OB zone in trade direction";
      return false;
   }

   // Invalidation = beyond sweep extreme
   double atr = LCS_AvgRange(LCS_EntryTF, 14);
   double buf = (atr > 0.0) ? (atr * LCS_SL_BufferATR) : 0.0;
   invalidation = buy ? (sweepExt - buf) : (sweepExt + buf);
   // For BUY, SL below sweep low; sweepExt IS the low. Subtract buffer.
   // For SELL, SL above sweep high; add buffer. Already set.

   detail = StringFormat("LCS OK %s sweep@%d zone=%s disp=%s inv=%s",
                         buy ? "BUY" : "SELL",
                         sweepBar,
                         zone ? "Y" : "N",
                         disp ? "Y" : "N",
                         DoubleToString(invalidation, (int)SymbolInfoInteger(BrokerSymbol, SYMBOL_DIGITS)));
   return true;
}

bool LCSBuySetup()
{
   string detail = "";
   double inv = 0.0;
   bool ok = LCS_SetupOK(true, detail, inv);
   g_LCS_LastDetail = detail;
   if(ok)
   {
      g_LCS_InvalidationPrice = inv;
      g_LCS_SweepBarTime = iTime(BrokerSymbol, LCS_EntryTF, 1);
      if(LCS_LogValidation)
         Print("LCS VALIDATE BUY: PASS - ", detail, " on ", BrokerSymbol);
      return true;
   }
   if(LCS_LogValidation && (EnableVerboseLogging || EnableSetupLogging))
      Print("LCS VALIDATE BUY: FAIL - ", detail, " on ", BrokerSymbol);
   return false;
}

bool LCSSellSetup()
{
   string detail = "";
   double inv = 0.0;
   bool ok = LCS_SetupOK(false, detail, inv);
   g_LCS_LastDetail = detail;
   if(ok)
   {
      g_LCS_InvalidationPrice = inv;
      g_LCS_SweepBarTime = iTime(BrokerSymbol, LCS_EntryTF, 1);
      if(LCS_LogValidation)
         Print("LCS VALIDATE SELL: PASS - ", detail, " on ", BrokerSymbol);
      return true;
   }
   if(LCS_LogValidation && (EnableVerboseLogging || EnableSetupLogging))
      Print("LCS VALIDATE SELL: FAIL - ", detail, " on ", BrokerSymbol);
   return false;
}

void EvaluateLCSStrategies(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK93 REMOVED — LCS deleted from live path
   buySignal = false; sellSignal = false; strategyTag = "";
}


void MarkContFallbackFillIfNeeded()
{
   if(g_PendingStrategyTag == "ContFallback" || g_PendingStrategyTag == "APEX" || g_PendingStrategyTag == "LCS" || PRIME_IsLiveTag(g_PendingStrategyTag))
   {
      g_ContFallbackLastFillTime = TimeCurrent();
      datetime barTime = iTime(BrokerSymbol, EntryTF, 0);
      if(barTime > 0)
         g_ContFallbackLastSignalBar = barTime;
   }
}

int CountOpenContFallbackPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != BrokerSymbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      int st = FindTradeState(ticket);
      if(st >= 0 && TradeStates[st].strategyTag == "ContFallback")
         count++;
   }
   return count;
}

bool ContFallbackAntiScalpGatesPass(string &failReason)
{
   failReason = "";
   // OK81: InstantQualityMode never ContFallbackCooldown / OncePerBar blocks
   if(InstantQualityMode)
   {
      if(ContFallbackMaxOpen > 0 && CountOpenContFallbackPositions() >= ContFallbackMaxOpen)
      {
         failReason = "ContFallbackMaxOpen";
         return false;
      }
      return true;
   }
   if(ContFallbackMaxOpen > 0 && CountOpenContFallbackPositions() >= ContFallbackMaxOpen)
   {
      failReason = "ContFallbackMaxOpen";
      return false;
   }
   if(ContFallbackCooldownMinutes > 0 && g_ContFallbackLastFillTime > 0)
   {
      int waited = (int)(TimeCurrent() - g_ContFallbackLastFillTime);
      if(waited < ContFallbackCooldownMinutes * 60)
      {
         failReason = "ContFallbackCooldown";
         return false;
      }
   }
   if(EnableAntiScalpMode || ContFallbackOncePerBar)
   {
      datetime barTime = iTime(BrokerSymbol, EntryTF, 0);
      if(barTime > 0 && g_ContFallbackLastSignalBar == barTime)
      {
         failReason = "ContFallbackOncePerBar";
         return false;
      }
   }
   return true;
}

//================ CONT STRUCTURE BEST (OK68) ========================//
// World-class continuation structure — not PRISM ContSniper leftovers.
// Stack: clear trend → recent directional BOS → FRESH OB or quality FVG
// → price interacting with that zone → displacement impulse → optional HTF BOS.

bool ContStruct_TwoBarDirectionalBOS(const bool buy)
{
   double swingHigh = GetRecentHigh();
   double swingLow  = GetRecentLow();
   if(swingHigh == EMPTY_VALUE || swingLow == EMPTY_VALUE)
      return false;

   double close1 = iClose(BrokerSymbol, EntryTF, 1);
   double close2 = iClose(BrokerSymbol, EntryTF, 2);
   double close3 = iClose(BrokerSymbol, EntryTF, 3);
   double atr = GetFilterATR();
   double margin = (atr > 0.0) ? (atr * BOS_MinBreakATRMultiple) : 0.0;

   if(buy)
      return (close3 <= swingHigh &&
              close2 > swingHigh + margin &&
              close1 > swingHigh + margin);
   return (close3 >= swingLow &&
           close2 < swingLow - margin &&
           close1 < swingLow - margin);
}

bool ContStruct_HasQualityBOS(const bool buy)
{
   // Best: two-bar confirmation. Soft fallback: very fresh single-bar BOS still held.
   if(ContStruct_RequireTwoBarBOS)
   {
      if(ContStruct_TwoBarDirectionalBOS(buy))
         return true;
      return DetectDirectionalBOS(EntryTF, buy) && RecentDirectionalBOS(buy, 3);
   }
   return RecentDirectionalBOS(buy, ContStruct_BOS_MaxBars);
}

bool ContStruct_GetFreshZone(const bool buy, double &zTop, double &zBot, string &kind)
{
   zTop = 0.0;
   zBot = 0.0;
   kind = "";

   UpdateOrderBlockTracking();
   UpdateFVGTracking();

   int idx = GetSymbolIndex(BrokerSymbol);
   double atr = GetFilterATR();

   // 1) Fresh (unmitigated) order block — best demand/supply
   bool freshOB = IsOrderBlockFreshAndValid(buy);
   if(!freshOB && !ContStruct_FreshOBOnly)
      freshOB = ActiveOrderBlock(buy); // only if user allows mitigated

   if(freshOB && idx >= 0)
   {
      if(buy)
      {
         zTop = OB_Bull_TopArr[idx];
         zBot = OB_Bull_BottomArr[idx];
         kind = OB_Bull_MitigatedArr[idx] ? "OB-mitigated" : "OB-fresh";
      }
      else
      {
         zTop = OB_Bear_TopArr[idx];
         zBot = OB_Bear_BottomArr[idx];
         kind = OB_Bear_MitigatedArr[idx] ? "OB-mitigated" : "OB-fresh";
      }
      if(zTop > zBot && zBot > 0.0)
         return true;
   }
   else if(freshOB)
   {
      // untracked symbol fallback — use last 2-bar OB geometry
      zTop = iHigh(BrokerSymbol, EntryTF, 2);
      zBot = iLow(BrokerSymbol, EntryTF, 2);
      kind = "OB-detect";
      if(zTop > zBot)
         return true;
   }

   // 2) Quality FVG — active, not mostly filled, meaningful size
   if(idx >= 0)
   {
      bool fvgOn = buy ? FVG_Bull_ActiveArr[idx] : FVG_Bear_ActiveArr[idx];
      if(!fvgOn)
         fvgOn = ActiveFVG(buy);
      if(fvgOn)
      {
         double fill = buy ? FVG_Bull_FilledPctArr[idx] : FVG_Bear_FilledPctArr[idx];
         zTop = buy ? FVG_Bull_TopArr[idx] : FVG_Bear_TopArr[idx];
         zBot = buy ? FVG_Bull_BottomArr[idx] : FVG_Bear_BottomArr[idx];
         double gap = zTop - zBot;
         if(gap <= 0.0)
            return false;
         if(fill > ContStruct_MaxFVGFillPct)
            return false;
         if(atr > 0.0 && gap < atr * ContStruct_MinFVG_ATR)
            return false;
         kind = StringFormat("FVG(fill=%.0f%%)", fill);
         return true;
      }
   }
   else if(ActiveFVG(buy))
   {
      // fallback detect sizes
      if(buy)
      {
         zBot = iHigh(BrokerSymbol, EntryTF, 3);
         zTop = iLow(BrokerSymbol, EntryTF, 1);
      }
      else
      {
         zTop = iLow(BrokerSymbol, EntryTF, 3);
         zBot = iHigh(BrokerSymbol, EntryTF, 1);
         // bearish gap: top > bottom after swap
         double tmp = zTop; zTop = MathMax(tmp, zBot); zBot = MathMin(tmp, zBot);
      }
      double gap = zTop - zBot;
      if(gap > 0.0 && (atr <= 0.0 || gap >= atr * ContStruct_MinFVG_ATR))
      {
         kind = "FVG-detect";
         return true;
      }
   }

   return false;
}

bool ContStruct_PriceNearZone(const bool buy, const double zTop, const double zBot)
{
   if(zTop <= zBot)
      return false;
   double atr = GetFilterATR();
   double prox = (atr > 0.0) ? (atr * ContStruct_ZoneProximityATR) : 0.0;
   double price = buy ? SymbolInfoDouble(BrokerSymbol, SYMBOL_BID)
                      : SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
   if(price <= 0.0)
      return false;
   // Must be interacting with the zone band (not miles away after BOS)
   return (price <= zTop + prox && price >= zBot - prox);
}

bool ContStruct_InDiscountPremium(const bool buy)
{
   if(!ContStruct_PreferDiscountPrem)
      return true;
   int lb = 20;
   double hi = iHigh(BrokerSymbol, EntryTF, 1);
   double lo = iLow(BrokerSymbol, EntryTF, 1);
   for(int i = 2; i <= lb; i++)
   {
      double h = iHigh(BrokerSymbol, EntryTF, i);
      double l = iLow(BrokerSymbol, EntryTF, i);
      if(h > hi) hi = h;
      if(l < lo && l > 0.0) lo = l;
   }
   if(hi <= lo)
      return true;
   double mid = (hi + lo) * 0.5;
   double price = buy ? SymbolInfoDouble(BrokerSymbol, SYMBOL_BID)
                      : SymbolInfoDouble(BrokerSymbol, SYMBOL_ASK);
   if(buy)
      return (price <= mid); // discount half for continuation buys into demand
   return (price >= mid);    // premium half for continuation sells into supply
}

bool ContStruct_HasDisplacement(const bool buy)
{
   double o = iOpen(BrokerSymbol, EntryTF, 1);
   double c = iClose(BrokerSymbol, EntryTF, 1);
   double h = iHigh(BrokerSymbol, EntryTF, 1);
   double l = iLow(BrokerSymbol, EntryTF, 1);
   double range = h - l;
   if(range <= 0.0)
      return false;
   double body = MathAbs(c - o);
   if(body / range < ContStruct_MinDispBodyRatio)
      return false;
   if(buy && c <= o)
      return false;
   if(!buy && c >= o)
      return false;
   double atr = GetFilterATR();
   if(atr > 0.0 && range < atr * ContStruct_MinDispATR)
      return false;
   return true;
}

bool ContStruct_HTF_OK(const bool buy)
{
   if(!ContStruct_RequireHTF_BOS)
      return true;
   if(DetectDirectionalBOS(APEX_BiasTF, buy))
      return true;
   if(DetectDirectionalBOS(HigherTimeframe, buy))
      return true;
   return RecentDirectionalBOS(buy, ContStruct_BOS_MaxBars) &&
          ((buy && IsBullTrend()) || (!buy && IsBearTrend()));
}

int ContStruct_Score(const bool buy)
{
   // Higher = stronger quality (conflict resolve + MinScore gate)
   int s = 0;
   if(ContStruct_HasQualityBOS(buy)) s += 40;
   if(TrendStrong()) s += 10;
   double zTop, zBot; string kind;
   if(ContStruct_GetFreshZone(buy, zTop, zBot, kind))
   {
      s += (StringFind(kind, "OB-fresh") >= 0) ? 35 : 22;
      bool near = ContStruct_PriceNearZone(buy, zTop, zBot);
      bool disp = ContStruct_HasDisplacement(buy);
      if(near) s += 15;
      if(disp) s += 15;
      if(near && disp) s += 10; // STRONG confluence bonus
   }
   if(ContStruct_InDiscountPremium(buy)) s += 5;
   return s;
}

string ContStruct_Grade(const bool buy)
{
   double zTop, zBot; string kind;
   bool zone = ContStruct_GetFreshZone(buy, zTop, zBot, kind);
   bool near = zone && ContStruct_PriceNearZone(buy, zTop, zBot);
   bool disp = ContStruct_HasDisplacement(buy);
   bool freshOB = (StringFind(kind, "OB-fresh") >= 0);
   if(near && disp && freshOB && TrendStrong())
      return "STRONG";
   if(ContStruct_Score(buy) >= ContStruct_MinScore + 15)
      return "STRONG";
   return "QUALITY";
}

bool ContFallbackBestStructureOK(const bool buy, string &detail)
{
   detail = "";
   double zTop = 0.0, zBot = 0.0;
   string kind = "";
   bool bos = false;
   bool hasZone = false;
   bool near = false;
   bool disp = false;
   int score = 0;

   // OK81 INSTANT OPEN: no trend / ranging / opposite-trend HARD blocks when InstantQualityMode.
   // Quality = prefer BOS + zone + displacement stack; open if ANY structural edge exists.
   if(InstantQualityMode)
   {
      bos = ContStruct_HasQualityBOS(buy);
      hasZone = ContStruct_GetFreshZone(buy, zTop, zBot, kind);
      near = hasZone && ContStruct_PriceNearZone(buy, zTop, zBot);
      disp = ContStruct_HasDisplacement(buy);
      score = ContStruct_Score(buy);

      // Must have at least one real edge (not random)
      if(!bos && !hasZone && !disp)
      {
         detail = "no bos/zone/disp edge yet";
         return false;
      }

      // Soft score: if two+ edges, allow even below MinScore
      int edges = (bos ? 1 : 0) + (hasZone ? 1 : 0) + (disp ? 1 : 0);
      if(ContStruct_MinScore > 0 && score < ContStruct_MinScore && edges < 2)
      {
         detail = StringFormat("score %d < %d and edges=%d", score, ContStruct_MinScore, edges);
         return false;
      }

      if(!ContStruct_HTF_OK(buy))
      {
         // soft: do not block in InstantQualityMode
      }

      detail = StringFormat("%s INSTANT edges=%d bos=%s zone=%s near=%s disp=%s score=%d",
                            ContStruct_Grade(buy),
                            edges,
                            bos ? "Y" : "N",
                            hasZone ? kind : "N",
                            near ? "Y" : "N",
                            disp ? "Y" : "N",
                            score);
      return true;
   }

   // Strict mode (InstantQualityMode=false)
   if(buy && !IsBullTrend()) { detail = "no bull trend"; return false; }
   if(!buy && !IsBearTrend()) { detail = "no bear trend"; return false; }

   if(ContStruct_RequireTrendADX && !TrendStrong())
   {
      detail = "trend not strong (ADX)";
      return false;
   }

   if(ContStruct_SkipRanging && EnableRegimeDetection && GetMarketRegime() == REGIME_RANGING)
   {
      detail = "ranging regime - wait strong trend";
      return false;
   }

   if(!ContStruct_HasQualityBOS(buy))
   {
      detail = "no quality directional BOS";
      return false;
   }

   if(!ContStruct_GetFreshZone(buy, zTop, zBot, kind))
   {
      detail = "no fresh OB / quality FVG";
      return false;
   }

   near = ContStruct_PriceNearZone(buy, zTop, zBot);
   disp = ContStruct_HasDisplacement(buy);

   if(ContStruct_ZoneOrDisplacement)
   {
      if(!near && !disp)
      {
         detail = "need price-at-zone OR displacement (" + kind + ")";
         return false;
      }
   }
   else
   {
      if(!near)
      {
         detail = "price not at structure zone (" + kind + ")";
         return false;
      }
      if(ContStruct_RequireDisplacement && !disp)
      {
         detail = "no displacement impulse";
         return false;
      }
   }

   if(!ContStruct_HTF_OK(buy))
   {
      detail = "HTF BOS missing";
      return false;
   }

   score = ContStruct_Score(buy);
   if(ContStruct_MinScore > 0 && score < ContStruct_MinScore)
   {
      detail = StringFormat("score %d < min %d (need stronger setup)", score, ContStruct_MinScore);
      return false;
   }

   if(IDP_ApplyToContFallback)
   {
      string idpDetail = "";
      if(!IDP_ConfluenceOK(buy, idpDetail))
      {
         detail = "IDP block: " + idpDetail;
         return false;
      }
   }

   string grade = ContStruct_Grade(buy);
   string idpNote = "";
   if(EnableIDPConfluence && IDP_ApplyToContFallback)
   {
      double p = 0.0;
      string pd = "";
      if(IDP_GetPulse(p, pd))
         idpNote = StringFormat(" | %s", pd);
   }
   detail = StringFormat("%s %s + %s%s%s score=%d%s",
                         grade,
                         ContStruct_RequireTwoBarBOS ? "BOS2" : "BOS",
                         kind,
                         near ? " + near" : "",
                         disp ? " + disp" : "",
                         score,
                         idpNote);
   return true;
}

bool ContFallbackSwingBuySetup()
{
   string d = "";
   return ContFallbackBestStructureOK(true, d);
}

bool ContFallbackSwingSellSetup()
{
   string d = "";
   return ContFallbackBestStructureOK(false, d);
}

void EvaluateContFallback(bool &buySignal, bool &sellSignal, string &strategyTag)
{
   // OK93 REMOVED — never opens trades
   buySignal = false; sellSignal = false; strategyTag = "";
}



//====================================================================//




//+------------------------------------------------------------------+
//|         DISPLACEMENT / MOMENTUM EXHAUSTION / DYNAMIC S&R (NEW)   |
//+------------------------------------------------------------------+

//================ DISPLACEMENT STRENGTH ==============================//
// "Displacement" in SMC terms is a forceful, wide-range, mostly-one-
// direction candle (or short run of them) that shows real institutional
// participation - it's the move that LEAVES the FVGs and order blocks
// behind, not just any candle. Previously nothing measured this directly;
// FVG/OB quality scoring approximated it indirectly through gap/impulse
// size. This scores the most recent closed bar's own range against ATR
// AND its body-to-range ratio (a wide bar that's mostly wick is chop, not
// displacement) so a genuine forceful move can be rewarded on its own
// merits, independent of whether it happened to also leave a gap.

input double DisplacementMinBodyRatio = 0.55; // body must be at least this fraction of the bar's total range to count as a real directional push, not an indecisive wick-heavy bar

int GetDisplacementScore(bool buy)
{
   double open1  = iOpen(BrokerSymbol, EntryTF, 1);
   double close1 = iClose(BrokerSymbol, EntryTF, 1);
   double high1  = iHigh(BrokerSymbol, EntryTF, 1);
   double low1   = iLow(BrokerSymbol, EntryTF, 1);

   double range = high1 - low1;
   if(range <= 0.0)
      return 0;

   bool bullishBar = close1 > open1;
   if(buy != bullishBar)
      return 0; // last bar didn't even close in the requested direction - no displacement credit

   double body = MathAbs(close1 - open1);
   double bodyRatio = body / range;

   if(bodyRatio < DisplacementMinBodyRatio)
      return 0; // wide but wick-heavy / indecisive - not real displacement

   double atr = GetFilterATR();
   if(atr <= 0.0)
      return 5;

   double ratio = range / atr;

   if(ratio >= 1.5) return 15; // a genuinely forceful, wide displacement bar
   if(ratio >= 1.0) return 10;
   if(ratio >= 0.6) return 5;

   return 0; // directionally correct and reasonably clean, but not actually wide relative to volatility
}

//================ MOMENTUM EXHAUSTION =================================//
// Momentum exhaustion without RSI/MACD/Stoch: shrinking candle bodies only.
input int MomentumExhaustionBars = 3;

bool IsMomentumExhausted(bool buy)
{
   // Directional check: last closed bar should still be in trade direction
   double o1 = iOpen(BrokerSymbol, EntryTF, 1);
   double c1 = iClose(BrokerSymbol, EntryTF, 1);
   if(buy && c1 <= o1)
      return false;
   if(!buy && c1 >= o1)
      return false;

   double bodies[];
   ArrayResize(bodies, MomentumExhaustionBars);

   for(int i = 0; i < MomentumExhaustionBars; i++)
   {
      double o = iOpen(BrokerSymbol, EntryTF, i+1);
      double c = iClose(BrokerSymbol, EntryTF, i+1);
      bodies[i] = MathAbs(c - o);
   }

   int shrinkCount = 0;
   for(int i = 0; i < MomentumExhaustionBars-1; i++)
   {
      if(bodies[i] < bodies[i+1])
         shrinkCount++;
   }

   return (shrinkCount >= (MomentumExhaustionBars-1+1)/2);
}

//================ DYNAMIC SUPPORT / RESISTANCE REACTIONS (NEW) =======//
// Rewards price currently sitting near a level that has PROVEN itself
// reactive recently - the EMA acting as dynamic S/R, or a still-active
// order block zone - rather than treating "near the EMA" as meaningful
// regardless of whether price has actually respected it lately. Counts how
// many of the last few closed bars reversed direction (a high followed by
// a lower close, or a low followed by a higher close) within one ATR of
// the EMA, as a cheap proxy for "this level has been getting real
// reactions," then checks whether price is currently back at it.

input int    DynamicSRLookbackBars   = 10;
input double DynamicSRProximityATRMultiple = 0.3;

int GetDynamicSRReactionScore(bool buy)
{
   double ema = GetEMA();
   double atr = GetFilterATR();

   if(ema == EMPTY_VALUE || atr <= 0.0)
      return 0;

   double proximity = atr * DynamicSRProximityATRMultiple;
   double price = SymbolInfoDouble(BrokerSymbol, SYMBOL_BID);

   // Only worth scoring if price is actually near the level right now.
   if(MathAbs(price - ema) > proximity)
      return 0;

   int reactions = 0;

   for(int i = 2; i <= DynamicSRLookbackBars; i++)
   {
      double hi = iHigh(BrokerSymbol, EntryTF, i);
      double lo = iLow(BrokerSymbol, EntryTF, i);
      double cl = iClose(BrokerSymbol, EntryTF, i);
      double clPrev = iClose(BrokerSymbol, EntryTF, i+1);

      bool nearLevel = (MathAbs(hi - ema) <= proximity) || (MathAbs(lo - ema) <= proximity);
      if(!nearLevel)
         continue;

      if(buy && lo <= ema + proximity && cl > clPrev)
         reactions++;
      else if(!buy && hi >= ema - proximity && cl < clPrev)
         reactions++;
   }

   if(reactions >= 3) return 10;
   if(reactions >= 1) return 5;
   return 0;
}

//+------------------------------------------------------------------+
//|              PART 15 - AI DECISION LAYER                         |
//+------------------------------------------------------------------+

//================ AI SETTINGS =====================================//

input int MinimumTradeScore = 20;

input group "SNIPER ENTRY FILTER"

// FIX/UPGRADE: the original score system is purely additive - any
// combination of signals that adds up to MinimumTradeScore passes, even
// if none of them actually agree with each other (e.g. a liquidity sweep
// with no real structure break behind it). "Sniper" entries here means
// requiring genuine confluence: a structure event (BOS or CHoCH) AND a
// supporting pattern (FVG or order block in the same direction) both
// present at once, on top of the existing score threshold - not instead
// of it. Turn this off to fall back to the original score-only behavior.

input bool RequireStructureConfluence = false; // OFF for aggressive sniper - was a stacked hard block on legacy confirmations

// FIX (this review): this used to require DetectBOS()/DetectCHoCH() to be
// true on the EXACT SAME BAR as everything else being checked (score
// clearing, a supporting FVG/OB pattern) - but both of those are one-bar-
// only events (true only on the single bar the break happens, false every
// other bar). Requiring all of that to land on one identical candle is
// almost never satisfied in practice, which is why real setups like
// score:25/20 + trend:true + HTF:true were still coming back
// confluence:false and getting blocked. "Structure confluence" now means
// a genuine BOS or CHoCH happened within the last StructureConfluenceLookbackBars
// bars (still real market structure, not stale) plus a supporting
// pattern present right now - matching how this concept is normally used
// in SMC-style analysis (break, then a pullback/retest a few bars later),
// instead of requiring literally the same candle.

input int StructureConfluenceLookbackBars = 5;

bool HasStructureConfluence(bool buy)
{
   int idx = GetSymbolIndex(BrokerSymbol);

   // Still call both so their per-bar detection/recording logic runs even
   // if nothing else does this cycle.
   bool bosNow   = DetectBOS();
   bool chochNow = DetectCHoCH();

   bool structureEvent = bosNow || chochNow;

   if(!structureEvent && idx >= 0 && idx < ArraySize(LastBOSTrueBarTimeArr))
   {
      int barsSinceBOS   = (LastBOSTrueBarTimeArr[idx]   > 0) ? iBarShift(BrokerSymbol, EntryTF, LastBOSTrueBarTimeArr[idx])   : INT_MAX;
      int barsSinceCHoCH = (LastCHoCHTrueBarTimeArr[idx] > 0) ? iBarShift(BrokerSymbol, EntryTF, LastCHoCHTrueBarTimeArr[idx]) : INT_MAX;

      structureEvent = (barsSinceBOS >= 0 && barsSinceBOS <= StructureConfluenceLookbackBars) ||
                        (barsSinceCHoCH >= 0 && barsSinceCHoCH <= StructureConfluenceLookbackBars);
   }

   bool supportingPattern;

   if(buy)
      supportingPattern = DetectBullishFVG() || DetectBullishOrderBlock();
   else
      supportingPattern = DetectBearishFVG() || DetectBearishOrderBlock();

   return (structureEvent && supportingPattern);
}


//================ MARKET REGIME DETECTION (UPGRADE) =================//
// Classifies the market as trending or ranging using ADX (already
// computed, no new indicator needed). SMC-style trend-following signals
// are inherently less reliable during chop - a "bullish" order block in a
// ranging market is a much weaker signal than the same pattern during a
// genuine trend. This doesn't block trades on its own; it feeds into
// adaptive scoring below, which raises the bar during ranging conditions
// rather than refusing to trade in them outright.

input group "MARKET REGIME DETECTION"

input bool   EnableRegimeDetection = true;
input double RegimeADXThreshold    = 22.0;

// FINE-TUNE (this pass): a raw ADX-vs-threshold read flips regime on every
// bar where ADX is oscillating near RegimeADXThreshold - literally the
// "regime switching accuracy" problem. Adds a buffer band: once a regime
// is confirmed, ADX has to clear the threshold by RegimeHysteresisBand in
// the OPPOSITE direction before the regime is allowed to flip again. A
// reading that stays within the band of the threshold keeps the
// last-confirmed regime instead of relabeling. Falls back to a plain
// threshold read (old behavior) the first time a symbol is evaluated,
// since there's no prior confirmed state to hold onto yet.
input double RegimeHysteresisBand = 3.0; // ADX must clear the threshold by this much, in the new direction, to flip an already-confirmed regime

MarketRegime GetMarketRegime()
{
   double adx = GetADX();

   if(adx == EMPTY_VALUE)
      return REGIME_RANGING; // unknown - treat as the more cautious case

   int idx = GetSymbolIndex(BrokerSymbol);
   int lastState = (idx >= 0 && idx < ArraySize(RegimeLastStateArr)) ? RegimeLastStateArr[idx] : -1;

   MarketRegime result;

   if(lastState == -1)
   {
      // No confirmed prior state yet - plain threshold read to seed it.
      result = (adx >= RegimeADXThreshold) ? REGIME_TRENDING : REGIME_RANGING;
   }
   else if((MarketRegime)lastState == REGIME_TRENDING)
   {
      // Already trending - only drop back to ranging if ADX has fallen
      // clearly below the threshold, not just touched it.
      result = (adx < RegimeADXThreshold - RegimeHysteresisBand) ? REGIME_RANGING : REGIME_TRENDING;
   }
   else
   {
      // Already ranging - only promote to trending once ADX has cleared
      // the threshold with margin, not just poked above it.
      result = (adx > RegimeADXThreshold + RegimeHysteresisBand) ? REGIME_TRENDING : REGIME_RANGING;
   }

   if(idx >= 0 && idx < ArraySize(RegimeLastStateArr))
      RegimeLastStateArr[idx] = (int)result;

   return result;
}


//================ ADAPTIVE SCORING (UPGRADE) =========================//
// Raises the effective score threshold above MinimumTradeScore when
// conditions call for more caution: a ranging market (per the regime
// detection above) and/or a recent losing streak (from the trade
// statistics in Part 18). This is real adaptation - the bar a setup has
// to clear moves based on current market conditions and recent
// performance, not a fixed number regardless of context. The loss-streak
// penalty is capped so it can't spiral into requiring an impossible score
// after a bad run.

input group "ADAPTIVE SCORING"

input bool EnableAdaptiveScoring        = true;
input int  RangingRegimeScorePenalty    = 5; // REDUCED from 10 - your GBPUSD log showed a SELL scoring 25 blocked by a 30 threshold, where the +10 from this penalty was the entire gap. At +5, that same 25 would clear a 25 threshold instead.
input int  ConsecutiveLossScorePenalty  = 5;
input int  MaxConsecutiveLossPenaltySteps = 3;

int GetEffectiveMinimumScore()
{
   int effective = MinimumTradeScore;

   if(!EnableAdaptiveScoring)
      return effective;

   if(EnableRegimeDetection && GetMarketRegime() == REGIME_RANGING)
      effective += RangingRegimeScorePenalty;

   // FIX: this used to read the single global Stat_ConsecutiveLosses -
   // shared across every symbol - so a BTC losing streak raised the score
   // bar for EURUSD (and vice versa) even though the two have no relation
   // to each other. Now reads this symbol's own consecutive-loss count
   // (tracked in OnTradeTransaction), falling back to the old global
   // behavior only if this symbol somehow isn't in the tracked list.
   int idx = GetSymbolIndex(BrokerSymbol);
   int consecutiveLosses = (idx >= 0 && idx < ArraySize(ConsecutiveLossesPerSymbolArr))
                           ? ConsecutiveLossesPerSymbolArr[idx]
                           : Stat_ConsecutiveLosses;

   int lossSteps = MathMin(consecutiveLosses, MaxConsecutiveLossPenaltySteps);
   effective += lossSteps * ConsecutiveLossScorePenalty;

   return effective;
}


//================ CALCULATE TRADE SCORE ============================//

int CalculateTradeScore(bool buy)
{
   int score = 0;

   // Trend
   if(buy)
   {
      if(IsBullTrend())
         score += 20;
   }
   else
   {
      if(IsBearTrend())
         score += 20;
   }

   // Structure - each component's raw contribution is now scaled by
   // SignalWeightMultiplier(), which reads that signal type's live,
   // persisted win/loss record (SigStat_*) and nudges its weight up or
   // down accordingly once there's enough sample to trust it. Neutral
   // (1.0x, i.e. no behavior change) until then, or if
   // EnableAdaptiveWeighting is off.
   if(DetectBOS())
      score += (int)MathRound(15 * SignalWeightMultiplier(SigStat_BOS_Win, SigStat_BOS_Loss));

   if(DetectCHoCH())
      score += (int)MathRound(15 * SignalWeightMultiplier(SigStat_CHoCH_Win, SigStat_CHoCH_Loss));

   if(DetectLiquiditySweep())
      score += (int)MathRound(GetLiquiditySweepQualityScore() * SignalWeightMultiplier(SigStat_Sweep_Win, SigStat_Sweep_Loss));

   // NEW: stop hunt is a stricter subset of a generic sweep - scored as an
   // additional bonus on top (not instead of) the sweep score above, since
   // a confirmed stop-hunt candle is stronger evidence than an ordinary
   // sweep. Shares the sweep win/loss stat since it's the same underlying
   // signal family, just a higher-conviction variant of it.
   // BUGFIX40: DetectStopHunt(true)=buy-side (highs). For a BUY score we need
   // sell-side (lows) hunt — was rewarding the wrong polarity.
   if(DetectStopHunt(buy ? false : true))
      score += (int)MathRound(10 * SignalWeightMultiplier(SigStat_Sweep_Win, SigStat_Sweep_Loss));

   // NEW: inducement - a shallow, fast-reversing liquidity grab in the
   // OPPOSITE direction, used here as supporting evidence FOR this trade's
   // direction (buy-side inducement = sell-side liquidity was induced and
   // swept, supporting a bullish reversal).
   if(DetectInducement(buy))
      score += 8;

   // NEW: displacement strength - a genuinely forceful, mostly-body
   // directional candle, independent of whether it happened to leave a
   // gap behind (see GetDisplacementScore()).
   score += GetDisplacementScore(buy);

   // NEW: dynamic support/resistance - price currently sitting at a level
   // (the EMA) that has demonstrably produced real reactions recently, not
   // just "near the EMA" on its own.
   score += GetDynamicSRReactionScore(buy);

   // Direction-specific confirmations
   if(buy)
   {
      // UPGRADE: was a flat +10 for any 2-bar "equal low"; now graduated by
      // how many bars actually cluster at that level - see
      // GetEqualLowPoolScore()/CountEqualLowTouches().
      score += GetEqualLowPoolScore();

      // UPGRADE: was a flat FVG size score with no mitigation awareness -
      // GetFVGQualityScore() discounts a gap that's already been partly or
      // fully traded back into (see FVG mitigation tracking above).
      score += (int)MathRound(GetFVGQualityScore(true) * SignalWeightMultiplier(SigStat_FVG_Win, SigStat_FVG_Loss));

      // UPGRADE: was a flat +15 for any OB detected in the last 2 candles
      // (impossible to tell fresh from already-tapped-and-invalid). Now
      // uses the persistent fresh/mitigated/invalidated tracker.
      double obWeight = SignalWeightMultiplier(SigStat_OB_Win, SigStat_OB_Loss);
      if(IsOrderBlockFreshAndValid(true))
         score += (int)MathRound(15 * obWeight);
      else if(IsOrderBlockMitigated(true))
         score += (int)MathRound(7 * obWeight); // still real support, just already tapped once - half credit
   }
   else
   {
      score += GetEqualHighPoolScore();

      score += (int)MathRound(GetFVGQualityScore(false) * SignalWeightMultiplier(SigStat_FVG_Win, SigStat_FVG_Loss));

      double obWeight = SignalWeightMultiplier(SigStat_OB_Win, SigStat_OB_Loss);
      if(IsOrderBlockFreshAndValid(false))
         score += (int)MathRound(15 * obWeight);
      else if(IsOrderBlockMitigated(false))
         score += (int)MathRound(7 * obWeight);
   }

   if(MarketConditionOK())
      score += 5;

   // UPGRADE: volatility expansion bonus - only contributes when the
   // filter is actually enabled (see IsVolatilityExpanding()).
   if(IsVolatilityExpanding())
      score += (int)MathRound(10 * SignalWeightMultiplier(SigStat_VolExp_Win, SigStat_VolExp_Loss));

   // NEW: bonus for trading near a prior D1/W1 liquidity level in the
   // trade's favor (see GetLiquidityProximityScore() above). Additive
   // only - never blocks a trade on its own, just nudges the score for
   // setups located at genuinely significant liquidity.
   score += GetLiquidityProximityScore(buy);

   // NEW: penalize a direction that just had a failed breakout/trap in it -
   // see DetectFakeBreakoutTrap() above.
   if(DetectFakeBreakoutTrap(buy))
      score -= 15;

   // NEW: momentum exhaustion penalty - RSI extreme + decelerating candle
   // bodies suggests this move is running out of conviction. Doesn't block
   // the trade on its own, just makes it need more support elsewhere to
   // clear the bar.
   if(IsMomentumExhausted(buy))
      score -= 10;

   return score;
}


//================ MANDATORY CONFIRMATIONS (formalized, this pass) ====//
// These are the institutional-structure gates that MUST pass before the
// optional, additive AI score (CalculateTradeScore) is even computed:
// trend direction, HTF agreement, structure confluence, MTF structure
// confluence, and premium/discount positioning. Previously this order
// lived as two separate, hand-copied sequences of if-checks in
// StrongBuySetup()/StrongSellSetup() - correct today, but nothing stopped
// a future edit to one from drifting out of sync with the other. Bundling
// them into a single function makes "mandatory confirmations always run
// before optional scoring, and both directions use the identical gate
// order" a structural guarantee instead of a convention that has to be
// remembered.
bool MandatoryConfirmationsPassed(bool buy)
{
   if(buy ? !IsBullTrend() : !IsBearTrend())
      return false;

   if(!HTFConfirms(buy))
      return false;

   if(RequireStructureConfluence && !HasStructureConfluence(buy))
      return false;

   if(EnableMTFStructureConfluence && !HasHTFStructureConfluence(buy))
      return false;

   if(EnablePremiumDiscountFilter && !(buy ? InDiscountZone() : InPremiumZone()))
      return false;

   return true;
}

//================ DUPLICATE SIGNAL FILTER (NEW, this pass) ===========//
// See LastApprovedBuyBarTimeArr/LastApprovedSellBarTimeArr declaration
// (Part 1) for the full rationale: CooldownFinished() only throttles by
// elapsed time since the last FILLED trade, which says nothing about
// whether THIS approval is a re-fire of the same signal that already
// filled earlier on the same still-forming bar (possible with
// EnableTickLevelSignalDetection on and a short TradeCooldownMinutes).
// TRADEFIRE54: never treat unset (0) bar times as a match — that was
// suppressing ContSniper on every tick when EntryTF history was not ready
// (iTime==0 == LastApproved init 0). Also do not suppress if the prior
// fill on this bar was already closed (defense/SL) — allow a fresh fire.
bool HasOpenEADirectionPosition(bool buy)
{
   ENUM_POSITION_TYPE want = buy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != BrokerSymbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == want)
         return true;
   }
   return false;
}

bool IsDuplicateSignal(bool buy)
{
   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0)
      return false;

   datetime currentBarTime = iTime(BrokerSymbol, EntryTF, 0);
   // No valid bar identity → never suppress (was 0==0 false positive)
   if(currentBarTime <= 0)
      return false;

   datetime lastApproved = 0;
   if(buy)
   {
      if(idx < ArraySize(LastApprovedBuyBarTimeArr))
         lastApproved = LastApprovedBuyBarTimeArr[idx];
   }
   else
   {
      if(idx < ArraySize(LastApprovedSellBarTimeArr))
         lastApproved = LastApprovedSellBarTimeArr[idx];
   }

   // Never approved this symbol/direction, or different bar → not a duplicate
   if(lastApproved <= 0 || lastApproved != currentBarTime)
      return false;

   // Same bar was marked after a fill — only suppress while that position is still open
   if(!HasOpenEADirectionPosition(buy))
      return false;

   return true;
}

void MarkSignalApproved(bool buy)
{
   int idx = GetSymbolIndex(BrokerSymbol);
   if(idx < 0)
      return;

   datetime currentBarTime = iTime(BrokerSymbol, EntryTF, 0);
   // Do not stamp 0 — would re-create the 0==0 suppress bug
   if(currentBarTime <= 0)
      return;

   if(buy)
   {
      if(idx < ArraySize(LastApprovedBuyBarTimeArr))
         LastApprovedBuyBarTimeArr[idx] = currentBarTime;
   }
   else
   {
      if(idx < ArraySize(LastApprovedSellBarTimeArr))
         LastApprovedSellBarTimeArr[idx] = currentBarTime;
   }
}


//================ STRONG BUY SETUP ================================//

bool StrongBuySetup()
{
   return false; // OK67 RETIRED — not on live path

   // MANDATORY confirmations first, always - see MandatoryConfirmationsPassed().
   // The optional, additive score below never even runs if these don't
   // clear, by construction.
   if(!MandatoryConfirmationsPassed(true))
      return false;

   int score = CalculateTradeScore(true);
   int requiredScore = GetEffectiveMinimumScore();

   if(EnableVerboseLogging)
      Print("BUY AI Score: ", score, " / required: ", requiredScore,
            " (regime: ", EnumToString(GetMarketRegime()), ")");

   bool approved = (score >= requiredScore);

   // NEW: duplicate-signal guard - see IsDuplicateSignal() above. Checked
   // only once the setup has otherwise fully qualified, so it never masks
   // a genuinely fresh signal; it only blocks re-approving the identical
   // bar's signal a second time.
   if(approved && IsDuplicateSignal(true))
   {
      if(EnableVerboseLogging) Print("BUY approval suppressed - duplicate signal on the same bar.");
      approved = false;
   }

   // FIX #6: capture the exact snapshot (score + every signal flag) at the
   // moment the decision is actually made - before ExecuteBuy() runs and
   // potentially spends time on retries/requotes during which price and
   // indicators can move on. RecordSignalSnapshot() (Part 6) uses this
   // instead of recalculating everything fresh after the fact.
   if(approved)
   {
      MarkSignalApproved(true);
      CapturePendingSignalSnapshot(true);
   }

   return approved;
}


//================ STRONG SELL SETUP ===============================//

bool StrongSellSetup()
{
   return false; // OK67 RETIRED — not on live path

   if(!MandatoryConfirmationsPassed(false))
      return false;

   int score = CalculateTradeScore(false);
   int requiredScore = GetEffectiveMinimumScore();

   if(EnableVerboseLogging)
      Print("SELL AI Score: ", score, " / required: ", requiredScore,
            " (regime: ", EnumToString(GetMarketRegime()), ")");

   bool approved = (score >= requiredScore);

   if(approved && IsDuplicateSignal(false))
   {
      if(EnableVerboseLogging) Print("SELL approval suppressed - duplicate signal on the same bar.");
      approved = false;
   }

   if(approved)
   {
      MarkSignalApproved(false);
      CapturePendingSignalSnapshot(false);
   }

   return approved;
}
//+------------------------------------------------------------------+
//|              PART 16 - CHART DASHBOARD & THEME                   |
//+------------------------------------------------------------------+

//================ DASHBOARD SETTINGS ===============================//

input group "DASHBOARD"


// FIX/SIMPLIFY: the previous dashboard displayed a "win rate"/AI-score
// style accuracy figure that had no reliable, verifiable basis (a handful
// of trades can show 80%+ "accuracy" that means nothing statistically,
// and it invites over-trusting the EA). Per request, the dashboard is
// stripped down to exactly three things that are always simply, directly
// true: which chart/timeframe this is, which bot is running it, and how
// many trades it currently has open.

//================ CREATE DASHBOARD =================================//


// CreateDashboard -> HITMAN_ULTRA/08_Dashboard.mqh




//================ UPDATE DASHBOARD =================================//

// FIX: UpdateDashboard() ran CreateDashboard() (which calls
// CountOpenTrades() - a PositionsTotal() loop - plus a Comment() call)
// on every single OnTick(), regardless of how fast ticks were arriving.
// Throttled to at most once per second - the dashboard doesn't need
// tick-level refresh to be useful, and this cuts needless repeated work
// on fast-ticking symbols.


long g_LastDashboardUpdateMs = 0;

void UpdateDashboard()
{
   long nowMs = (long)GetTickCount();

   if(nowMs - g_LastDashboardUpdateMs < DashboardRefreshMillis)
      return;

   g_LastDashboardUpdateMs = nowMs;

   CreateDashboard();
}

//================ CHART THEME (white background / pink candles) =====//

input group "CHART THEME"

input bool  EnableCustomChartTheme = false;
input color ChartThemeBackground   = clrWhite;
input color ChartThemeForeground   = clrBlack;
input color ChartThemeGrid         = clrGainsboro;
input color ChartThemeBullCandle   = clrDeepPink;   // up candle body
input color ChartThemeBearCandle   = clrPink;        // down candle body - a lighter pink so bull/bear stay visually distinct while both reading as "pink"
input color ChartThemeCandleBorder = clrMediumVioletRed;
input color ChartThemeBidLine      = clrDeepPink;
input color ChartThemeAskLine      = clrHotPink;

void ApplyChartTheme()
{
   if(!EnableCustomChartTheme)
      return;

   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);

   ChartSetInteger(0, CHART_COLOR_BACKGROUND, ChartThemeBackground);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, ChartThemeForeground);
   ChartSetInteger(0, CHART_COLOR_GRID, ChartThemeGrid);

   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, ChartThemeBullCandle);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, ChartThemeBearCandle);
   ChartSetInteger(0, CHART_COLOR_CHART_UP,   ChartThemeCandleBorder);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, ChartThemeCandleBorder);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, ChartThemeCandleBorder);

   ChartSetInteger(0, CHART_COLOR_VOLUME, ChartThemeCandleBorder);
   ChartSetInteger(0, CHART_COLOR_BID, ChartThemeBidLine);
   ChartSetInteger(0, CHART_COLOR_ASK, ChartThemeAskLine);
   ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, clrGray);

   ChartSetInteger(0, CHART_SHOW_GRID, true);

   ChartRedraw();
}
//+------------------------------------------------------------------+
//|              PART 17 - FINAL INTEGRATION SYSTEM                  |
//+------------------------------------------------------------------+

// NOTE: StartFinalSystem()/RunFinalAnalysis() used to live here as wrappers
// around InitializeRiskEngine()/InitializeSymbols()/UpdateDashboard()/
// ScanMarkets()/ManageOpenTrades() - but were never called by OnInit/OnTick,
// which call those functions directly. Removed as dead code. ScanMarkets()
// itself (along with IsSymbolValid()) was later removed too, for the same
// reason - see Part 13.
//
// Also note: TradeSymbols/InitializeSymbols() preload and print
// availability for the listed symbols; with EnableMultiSymbolTrading on,
// ExecuteBuy()/ExecuteSell() run for every symbol in the list via
// RunTradingCycle() (Part 1) - see Part 13's notes for the mechanics.

//================ FINAL TRADE VALIDATION ============================//

bool FinalTradeCheck()
{
   if(!TradeProtectionOK())
   {
      if(EnableVerboseLogging) Print("FAILED: Trade Protection");
      return false;
   }

   if(!RiskManagementOK())
   {
      if(EnableVerboseLogging) Print("FAILED: Risk Engine");
      return false;
   }

   if(!MarketConditionOK())
   {
      if(EnableVerboseLogging) Print("FAILED: Market Condition");
      return false;
   }

   if(EnableVerboseLogging) Print("FINAL CHECK PASSED");

   return true;
}
//+------------------------------------------------------------------+
//|              INSTANT AI EXECUTION ENGINE                         |
//+------------------------------------------------------------------+

// FIX: "No valid setup" on its own gives no way to tell whether it's the
// trend filter, HTF confirmation, the structure confluence gate, or the
// score threshold that's blocking entries - which makes a quiet EA
// impossible to diagnose from the Journal alone. This prints a one-line
// breakdown of every gate for both directions, once per new bar PER
// SYMBOL (not every tick, to avoid flooding the log), so it's immediately
// visible which specific condition is holding back a trade.


//================ CLEAN LIVE MARKET ANALYSIS (OK70) =================//
// One read of what matters for APEX + ContFallback — no ContSniper/PRISM noise.

void AnalyzeLiveMarket(const bool force)
{
   if(!force && g_LiveMktCycle == g_CycleCounter && g_LiveMkt.valid)
      return;

   g_LiveMktCycle = g_CycleCounter;
   LiveMarketAnalysis m;
   m.valid = true;
   m.barTime = iTime(BrokerSymbol, EntryTF, 0);
   m.bull = IsBullTrend();
   m.bear = IsBearTrend();
   m.trendStrong = TrendStrong();
   m.regime = GetMarketRegime();

   // Refresh zone trackers once so analysis matches ContFallback
   UpdateOrderBlockTracking();
   UpdateFVGTracking();

   m.bosBuy  = ContStruct_HasQualityBOS(true);
   m.bosSell = ContStruct_HasQualityBOS(false);

   double zTop = 0.0, zBot = 0.0;
   string kind = "";
   m.zoneBuy  = ContStruct_GetFreshZone(true,  zTop, zBot, kind);
   m.nearBuy  = m.zoneBuy  && ContStruct_PriceNearZone(true,  zTop, zBot);
   m.dispBuy  = ContStruct_HasDisplacement(true);

   zTop = 0.0; zBot = 0.0; kind = "";
   m.zoneSell = ContStruct_GetFreshZone(false, zTop, zBot, kind);
   m.nearSell = m.zoneSell && ContStruct_PriceNearZone(false, zTop, zBot);
   m.dispSell = ContStruct_HasDisplacement(false);

   m.contBuyDetail = "";
   m.contSellDetail = "";
   // OK93: live analysis from ULTRA only (old ContFallback/APEX probes removed)
   {
      UltraSnap us;
      UltraBuildSnapshot(BrokerSymbol, us);
      UltraSignal ub = UltraStrat_ContSniper(us);
      UltraSignal usw = UltraStrat_FlashSweep(us);
      m.contBuyOK = (ub.buy || usw.buy);
      m.contSellOK = (ub.sell || usw.sell);
      m.contBuyDetail  = m.contBuyOK  ? "ULTRA READY" : ("ULTRA confB=" + IntegerToString(UltraConfluenceBuy(us)));
      m.contSellDetail = m.contSellOK ? "ULTRA READY" : ("ULTRA confS=" + IntegerToString(UltraConfluenceSell(us)));
      g_APEX_LastBuyFail  = us.bos.buy  ? "" : "no ULTRA BOS buy";
      g_APEX_LastSellFail = us.bos.sell ? "" : "no ULTRA BOS sell";
   }

   string sess = "", sessName = "";
   bool inL = false, inN = false, inA = false, inO = false;
   int hourS = -1;
   DetectMarketSession(sessName, sess, inL, inN, inA, inO, hourS);
   // also annotate kill-zone soft/hard via APEX_InKillZone (does not change detect)
   string kz = "";
   APEX_InKillZone(kz);
   m.session = sess;
   m.sessionName = sessName;
   m.inLondon = inL;
   m.inNewYork = inN;
   m.inAsia = inA;
   m.inOverlap = inO;
   m.sessionHour = hourS;

   string newsDetail = "";
   bool newsWin = false;
   if(EnableNewsAwareness)
      newsWin = NewsAwarenessInWindow(newsDetail);
   m.news = newsWin ? newsDetail : (EnableNewsAwareness ? "news clear" : "news awareness off");

   m.apexBuy  = (g_APEX_LastBuyFail  == "" ? "ready/checking" : g_APEX_LastBuyFail);
   m.apexSell = (g_APEX_LastSellFail == "" ? "ready/checking" : g_APEX_LastSellFail);

   if(m.bull && !m.bear) m.bias = "BULL";
   else if(m.bear && !m.bull) m.bias = "BEAR";
   else if(m.bull && m.bear) m.bias = "MIXED";
   else m.bias = "FLAT";

   m.summary = StringFormat(
      "%s | SESSION=%s h%d | %s%s | BOS B/S=%s/%s | Zone B/S=%s/%s | Near=%s/%s | Disp=%s/%s | Cont B/S=%s/%s",
      m.bias,
      m.sessionName,
      m.sessionHour,
      EnumToString(m.regime),
      m.trendStrong ? "+ADX" : "",
      m.bosBuy ? "Y" : "N",
      m.bosSell ? "Y" : "N",
      m.zoneBuy ? "Y" : "N",
      m.zoneSell ? "Y" : "N",
      m.nearBuy ? "Y" : "N",
      m.nearSell ? "Y" : "N",
      m.dispBuy ? "Y" : "N",
      m.dispSell ? "Y" : "N",
      m.contBuyOK ? "READY" : "wait",
      m.contSellOK ? "READY" : "wait");

   g_LiveMkt = m;
}

string LiveMarketSummary()
{
   AnalyzeLiveMarket(false);
   return g_LiveMkt.summary;
}

void PrintLiveMarketAnalysis()
{
   AnalyzeLiveMarket(true);
   Print("---- MARKET ANALYSIS BUILD=HA_ULTRA_93 (", BrokerSymbol, ") ----");
   Print("SESSION=", g_LiveMkt.sessionName,
         " hour=", g_LiveMkt.sessionHour,
         (APEX_UseGMT ? " GMT" : " SERVER"),
         " London=", g_LiveMkt.inLondon,
         " NY=", g_LiveMkt.inNewYork,
         " Asia=", g_LiveMkt.inAsia,
         " Overlap=", g_LiveMkt.inOverlap);
   Print("Bias=", g_LiveMkt.bias,
         " Regime=", EnumToString(g_LiveMkt.regime),
         " ADXstrong=", g_LiveMkt.trendStrong,
         " | ", g_LiveMkt.session);
   Print("Structure BUY : BOS=", g_LiveMkt.bosBuy,
         " Zone=", g_LiveMkt.zoneBuy,
         " Near=", g_LiveMkt.nearBuy,
         " Disp=", g_LiveMkt.dispBuy,
         " Cont=", (g_LiveMkt.contBuyOK ? "READY" : g_LiveMkt.contBuyDetail));
   Print("Structure SELL: BOS=", g_LiveMkt.bosSell,
         " Zone=", g_LiveMkt.zoneSell,
         " Near=", g_LiveMkt.nearSell,
         " Disp=", g_LiveMkt.dispSell,
         " Cont=", (g_LiveMkt.contSellOK ? "READY" : g_LiveMkt.contSellDetail));
   Print("APEX BUY wait : ", g_LiveMkt.apexBuy);
   Print("APEX SELL wait: ", g_LiveMkt.apexSell);
   Print("News: ", g_LiveMkt.news);
   Print("SUMMARY: ", g_LiveMkt.summary);
   Print("NOTE: ANYTIME + STRONG/QUALITY ContFallback | session detect soft | spread/news never hard-block");
}


void PrintSetupDiagnostics()
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0 || idx >= ArraySize(DiagLastBarTimeArr))
      return;

   datetime barTime = iTime(BrokerSymbol, EntryTF, 0);

   if(barTime == DiagLastBarTimeArr[idx])
      return;

   DiagLastBarTimeArr[idx] = barTime;

   // OK70: clean market analysis only (no ContSniper/PRISM spam)
   PrintLiveMarketAnalysis();
}

input bool EnableSetupLogging = true; // CHANGED default to true - "silent when nothing fires" was indistinguishable from "broken" with no way to tell the difference. Prints once per new bar only, not per-tick, so it won't flood the Journal.

// FIX/UPGRADE - NEW CANDLE CONFIRMATION: entry evaluation used to run on
// every single tick. On a fast-moving symbol like BTCUSD, price can cross
// back and forth over a trigger level many times within one bar, which
// can produce open/close churn - a trade opens, conditions flicker back
// the other way a few ticks later, and something closes it again. Gating
// entry evaluation to once per newly closed bar removes that tick-level
// noise. Trade MANAGEMENT (SL/TP, trailing, trend exit in ManageOpenTrades)
// still runs every tick as before - that part needs to react immediately,
// only new entries are bar-gated.
//
// FIX (found in this review): this bar-gate used to be a single global
// datetime (LastEntryEvalBarTime) shared across every symbol - see the
// note on DetectCHoCH()/PrintSetupDiagnostics() above for the same class
// of bug. Now uses LastEntryEvalBarTimeArr (Part 1), indexed per symbol.
//
// CHANGED per request: EnableTickLevelSignalDetection lets you evaluate
// on every tick instead of waiting for a new closed bar. Real tradeoff,
// not a free upgrade - this reopens the exact churn risk described above
// (price wobbling across a trigger level can open/re-evaluate rapidly).
// AttemptCooldownSeconds and the trade cooldowns still throttle actual
// EXECUTION, so this won't spam orders, but the signal check itself will
// now re-run continuously rather than once per bar. Default true per
// request; set back to false to restore the original once-per-bar gate.

input bool EnableTickLevelSignalDetection = true;

void InstantExecution()
{
   int idx = GetSymbolIndex(BrokerSymbol);

   if(idx < 0)
   {
      Print("InstantExecution: symbol not tracked: ", BrokerSymbol,
            " — skip (check DetectBrokerSymbol / MultiSymbolList)");
      return;
   }

   // OK70: news aware + clean market analysis (never refuse on news/spread)
   UpdateNewsAwareness();
   AnalyzeLiveMarket(false);

   if(EnableUltraCore && UltraHealthMonitor)
      g_UltraDecisionStartMs = (long)GetTickCount();

   // Every symbol gets its own trading-cycle "tick" for the indicator
   // cache (Part 2) - incremented once per RunTradingCycle() call so
   // GetEMA()/GetADX()/GetATR() only re-fetch buffers once per symbol per
   // cycle instead of once per call.
   g_CycleCounter++;

   datetime currentBarTime = iTime(BrokerSymbol, EntryTF, 0);

   // ALLTRADE56: iTime==0 must not equal LastEntryEval init 0 forever
   if(currentBarTime <= 0)
   {
      static datetime lastHistWarn = 0;
      if(TimeCurrent() - lastHistWarn >= 60)
      {
         lastHistWarn = TimeCurrent();
         Print("EntryTF history not ready for ", BrokerSymbol,
               " TF=", EnumToString(EntryTF), " — evaluating anyway (tick path)");
      }
   }
   else if(!EnableTickLevelSignalDetection)
   {
      if(currentBarTime == LastEntryEvalBarTimeArr[idx])
         return; // already evaluated this bar for this symbol - wait for the next one
   }

   // Ultra smart tick filter: same bid/ask + already decided this price → skip
   if(EnableTickLevelSignalDetection && UltraSmartTickUnchanged())
      return;

   if(currentBarTime > 0)
      LastEntryEvalBarTimeArr[idx] = currentBarTime;

   if(EnableVerboseLogging)
      Print("Instant Execution Running (", BrokerSymbol, ")");

   if(!FinalTradeCheck())
   {
      UltraSetWait("FinalTradeCheck wait");
      if(EnableVerboseLogging) Print("Final trade check failed");
      return;
   }

   if(!CooldownFinished())
   {
      UltraSetWait("trade cooldown wait");
      if(EnableVerboseLogging) Print("Trade cooldown active");
      return;
   }

   // EvaluateStrategySignals() = OK93 HITMAN AI complete architecture.
   bool buySignal, sellSignal;
   string strategyTag;
   EvaluateStrategySignals(buySignal, sellSignal, strategyTag);

   // Correlation confirmation filter (Part 15f) - applies to whichever
   // strategy fired above, regardless of which one it was. Off by default
   // (EnableCorrelationFilter=false), so no behavior change unless
   // deliberately turned on.
   if(buySignal && !CorrelationFilterOK(true))
   {
      UltraSetReject("correlation filter blocked BUY");
      buySignal = false;
   }

   if(sellSignal && !CorrelationFilterOK(false))
   {
      UltraSetReject("correlation filter blocked SELL");
      sellSignal = false;
   }

   if(buySignal)
   {
      if((EnableBeastMode || EnableUltraCore) && !PRISMFinalizeApproval(true, strategyTag))
      {
         Print("FIRE BLOCKED after ", strategyTag, " BUY select: ",
               (g_UltraLastReject == "" ? "FinalizeApproval failed" : g_UltraLastReject),
               " on ", BrokerSymbol);
         return;
      }

      Print("BUY approved (", BrokerSymbol, ") [", strategyTag, "]");
      g_PendingStrategyTag = strategyTag;
      if(ExecuteBuy())
      {
         if(EnableBeastMode && BeastDuplicateBarGuard)
            MarkSignalApproved(true);
      }
      else
         Print("BUY approved but ExecuteBuy FAILED on ", BrokerSymbol, " [", strategyTag, "]");
      if(EnableUltraCore && UltraHealthMonitor)
      {
         g_UltraLastDecisionMs = (long)GetTickCount() - g_UltraDecisionStartMs;
         g_UltraHealthOK = (g_UltraLastDecisionMs < 500) ? 1 : 0;
      }
      return;
   }

   if(sellSignal)
   {
      if((EnableBeastMode || EnableUltraCore) && !PRISMFinalizeApproval(false, strategyTag))
      {
         Print("FIRE BLOCKED after ", strategyTag, " SELL select: ",
               (g_UltraLastReject == "" ? "FinalizeApproval failed" : g_UltraLastReject),
               " on ", BrokerSymbol);
         return;
      }

      Print("SELL approved (", BrokerSymbol, ") [", strategyTag, "]");
      g_PendingStrategyTag = strategyTag;
      if(ExecuteSell())
      {
         if(EnableBeastMode && BeastDuplicateBarGuard)
            MarkSignalApproved(false);
      }
      else
         Print("SELL approved but ExecuteSell FAILED on ", BrokerSymbol, " [", strategyTag, "]");
      if(EnableUltraCore && UltraHealthMonitor)
      {
         g_UltraLastDecisionMs = (long)GetTickCount() - g_UltraDecisionStartMs;
         g_UltraHealthOK = (g_UltraLastDecisionMs < 500) ? 1 : 0;
      }
      return;
   }

   if(g_UltraLastReject == "" && EnableUltraCore)
   {
      AnalyzeLiveMarket(false);
      string wait = StringFormat("ULTRA WAIT | %s | ContB=%s ContS=%s | conf=%d prec=%d prob=%d | %s",
                             g_LiveMkt.summary,
                             g_LiveMkt.contBuyOK ? "READY" : g_LiveMkt.contBuyDetail,
                             g_LiveMkt.contSellOK ? "READY" : g_LiveMkt.contSellDetail,
                             g_UltraLastSnap.score.confidence,
                             g_UltraLastSnap.score.precision,
                             g_UltraLastSnap.score.probability,
                             g_UltraLastSignal.reason == "" ? UltraRegimeName(g_UltraLastSnap.regime) : g_UltraLastSignal.reason);
      g_UltraLastReject = wait;
      g_UltraLastDecision = "WAIT";
   }

   if(EnableUltraCore && UltraHealthMonitor)
      g_UltraLastDecisionMs = (long)GetTickCount() - g_UltraDecisionStartMs;

   if(EnableSetupLogging)
   {
      if(idx < ArraySize(DiagLastBarTimeArr) && DiagLastBarTimeArr[idx] != currentBarTime)
      {
         if(EnableUltraCore && g_UltraLastReject != "")
            Print("No valid setup (", BrokerSymbol, ") — ", g_UltraLastReject);
         else
            Print("No valid setup (", BrokerSymbol, ")");
      }

      PrintSetupDiagnostics();
   }
}
// (Long-term-holding, ATR-trailing, trend-exit, HTF-confirmation and
// news-filter inputs were moved to the top INPUTS block - they're read by
// functions defined earlier in the file, e.g. InitializeIndicators() and
// ManageOpenTrades(), and MQL5 requires global variables/inputs to be
// declared before their first point of use.)

//================ NEWS FILTER SYSTEM (real implementation) =================//
// Uses MQL5's built-in Economic Calendar (CalendarValueHistory), not a
// third-party API. Blocks trading in a window around high/medium impact
// events for the currencies in the traded symbol (e.g. EUR/USD events for
// EURUSD). If the calendar isn't available on this account/server, it
// fails safe (returns true / trading allowed) rather than blocking forever.

// OK66: ONE news path — awareness log only. Never hard-blocks trades.
bool NewsAwarenessInWindow(string &detail)
{
   detail = "";
   string baseCcy, quoteCcy;
   PRISM_GetSymbolCurrencies(baseCcy, quoteCcy);

   datetime from = TimeCurrent() - MinutesAfterNews  * 60;
   datetime to   = TimeCurrent() + MinutesBeforeNews * 60;

   MqlCalendarValue values[];
   int total = CalendarValueHistory(values, from, to, NULL, NULL);
   if(total <= 0)
   {
      detail = "news: calendar clear / unavailable";
      return false;
   }

   string names = "";
   int hit = 0;
   for(int i = 0; i < total; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;
      if(event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;

      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;
      if(!PRISM_CalendarCurrencyRelevant(country.currency, baseCcy, quoteCcy, false))
         continue;

      hit++;
      if(StringLen(names) < 120)
      {
         if(names != "") names += "; ";
         names += country.currency + " " + event.name;
      }
   }

   if(hit <= 0)
   {
      detail = "news: no relevant high-impact in window";
      return false;
   }

   detail = StringFormat("news AWARE high-impact x%d [%s] — NOT blocking trades", hit, names);
   return true;
}

void UpdateNewsAwareness()
{
   if(!EnableNewsAwareness)
      return;

   datetime barTime = iTime(BrokerSymbol, EntryTF, 0);
   if(NewsAwarenessLogOncePerBar && barTime > 0 && barTime == g_NewsAwareLastLogBar)
      return;

   string detail = "";
   bool inWin = NewsAwarenessInWindow(detail);
   if(barTime > 0)
      g_NewsAwareLastLogBar = barTime;

   if(inWin)
      Print("NEWS AWARE: ", detail, " on ", BrokerSymbol, " | spread never blocks");
   else if(EnableVerboseLogging)
      Print("NEWS AWARE: ", detail, " on ", BrokerSymbol);
}

bool NewsTradingAllowed()
{
   return true; // OK66: hard news block retired — awareness only
}

void DebugSignals()
{
   Print("================ SIGNAL DEBUG ================");

   Print("Bull Trend: ", IsBullTrend());
   Print("Bear Trend: ", IsBearTrend());

   Print("EMA: ", GetEMA());
   Print("ADX: ", GetADX());
   Print("ATR: ", GetATR());

   Print("BOS: ", DetectBOS());
   Print("CHoCH: ", DetectCHoCH());

   Print("Liquidity Sweep: ", DetectLiquiditySweep());

   Print("Bullish FVG: ", DetectBullishFVG());
   Print("Bearish FVG: ", DetectBearishFVG());

   Print("Bullish OB (this bar): ", DetectBullishOrderBlock(), " | fresh&valid: ", IsOrderBlockFreshAndValid(true), " | mitigated: ", IsOrderBlockMitigated(true));
   Print("Bearish OB (this bar): ", DetectBearishOrderBlock(), " | fresh&valid: ", IsOrderBlockFreshAndValid(false), " | mitigated: ", IsOrderBlockMitigated(false));

   Print("Bullish FVG filled%: ", DoubleToString(GetFVGFilledPercent(true), 1), " | Bearish FVG filled%: ", DoubleToString(GetFVGFilledPercent(false), 1));

   Print("Equal High touches: ", CountEqualHighTouches(), " | Equal Low touches: ", CountEqualLowTouches());

   Print("Fake breakout trap (buy side): ", DetectFakeBreakoutTrap(true), " | (sell side): ", DetectFakeBreakoutTrap(false));

   Print("MPI Score (buy): ", CalculatePRISMScore(true), " | (sell): ", CalculatePRISMScore(false), " | Minimum required: ", MinimumMPIScore);

   Print("Trade Score: ", CalculateTradeScore(true));

   Print("---- Aggregate Trade Stats ----");
   Print("Win Rate: ", DoubleToString(GetWinRatePercent(),1), "% (", Stat_TotalTrades, " trades)");
   Print("Profit Factor: ", DoubleToString(GetProfitFactor(),2));
   Print("Average R:R: ", DoubleToString(GetAverageRR(),2));

   Print("=============================================");

   PrintSignalPerformanceReport();
}
//+------------------------------------------------------------------+
//|              PART 18 - TRADE STATISTICS                          |
//+------------------------------------------------------------------+
// Tracks win rate, average R:R, profit factor, and consecutive win/loss
// streaks - persisted via GlobalVariable (same mechanism as the TP1 state
// in Part 6) so the numbers survive an EA reload or terminal restart
// instead of resetting to zero every time. (Not shown on the simplified
// dashboard per request, but still tracked/persisted and available via
// DebugSignals()/PrintSignalPerformanceReport() and the Journal.)

// NOTE: Stat_TotalTrades/Stat_WinTrades/etc are aggregate counters shared
// across every symbol this EA instance trades (not broken out per symbol)
// - this reflects overall EA performance. The persistence key below
// deliberately does NOT include BrokerSymbol, to match that - keying it
// per-symbol while the in-memory counters stay shared would mean a
// restart only reloads one symbol's numbers into a bucket that's actually
// aggregate, silently losing the rest.

string StatsGVPrefix()
{
   return "HitmanAI_" + IntegerToString(MagicNumber) + "_Stats_Aggregate";
}

void SaveTradeStatistics()
{
   string prefix = StatsGVPrefix();

   GlobalVariableSet(prefix + "_total",  Stat_TotalTrades);
   GlobalVariableSet(prefix + "_wins",   Stat_WinTrades);
   GlobalVariableSet(prefix + "_losses", Stat_LossTrades);
   GlobalVariableSet(prefix + "_gprofit",Stat_GrossProfit);
   GlobalVariableSet(prefix + "_gloss",  Stat_GrossLoss);
   GlobalVariableSet(prefix + "_cwins",  Stat_ConsecutiveWins);
   GlobalVariableSet(prefix + "_closs",  Stat_ConsecutiveLosses);
}

void RestoreTradeStatistics()
{
   string prefix = StatsGVPrefix();

   if(!GlobalVariableCheck(prefix + "_total"))
      return; // nothing persisted yet - leave everything at zero

   Stat_TotalTrades       = (int)GlobalVariableGet(prefix + "_total");
   Stat_WinTrades         = (int)GlobalVariableGet(prefix + "_wins");
   Stat_LossTrades        = (int)GlobalVariableGet(prefix + "_losses");
   Stat_GrossProfit       = GlobalVariableGet(prefix + "_gprofit");
   Stat_GrossLoss         = GlobalVariableGet(prefix + "_gloss");
   Stat_ConsecutiveWins   = (int)GlobalVariableGet(prefix + "_cwins");
   Stat_ConsecutiveLosses = (int)GlobalVariableGet(prefix + "_closs");

   Print("Restored trade statistics: ", Stat_TotalTrades, " trades (",
         Stat_WinTrades, "W / ", Stat_LossTrades, "L)");
}

// Called from OnTradeTransaction whenever a position closes (profit
// already includes swap + commission).
void RecordTradeStatistic(double profit)
{
   Stat_TotalTrades++;

   if(profit >= 0)
   {
      Stat_WinTrades++;
      Stat_GrossProfit += profit;
      Stat_ConsecutiveWins++;
      Stat_ConsecutiveLosses = 0;
   }
   else
   {
      Stat_LossTrades++;
      Stat_GrossLoss += MathAbs(profit);
      Stat_ConsecutiveLosses++;
      Stat_ConsecutiveWins = 0;
   }

   SaveTradeStatistics();
}

double GetWinRatePercent()
{
   if(Stat_TotalTrades <= 0)
      return 0.0;

   return (double)Stat_WinTrades / (double)Stat_TotalTrades * 100.0;
}

double GetProfitFactor()
{
   if(Stat_GrossLoss <= 0.0)
      return (Stat_GrossProfit > 0.0) ? 999.0 : 0.0; // no losses yet - avoid divide-by-zero

   return Stat_GrossProfit / Stat_GrossLoss;
}

double GetAverageRR()
{
   if(Stat_WinTrades <= 0 || Stat_LossTrades <= 0)
      return 0.0;

   double avgWin  = Stat_GrossProfit / Stat_WinTrades;
   double avgLoss = Stat_GrossLoss / Stat_LossTrades;

   if(avgLoss <= 0.0)
      return 0.0;

   return avgWin / avgLoss;
}
#endif
