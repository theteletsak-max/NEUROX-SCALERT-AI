//+------------------------------------------------------------------+
//| NeuroX_Scalper_AI.mq5                                             |
//| NEUROX Scalper AI — forex scalping Expert Advisor (from scratch)  |
//|                                                                   |
//| Strategy (built bar-by-bar, no repaint on closed candles):        |
//|   1. Fast EMA crosses Slow EMA                                    |
//|   2. RSI filter (avoid chasing extremes)                          |
//|   3. ATR-based stop-loss and take-profit                          |
//|   4. Optional London/NY UTC session window                        |
//|   5. Risk % position sizing + daily loss / spread guards          |
//+------------------------------------------------------------------+
#property copyright   "NEUROX"
#property link        "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version     "1.00"
#property description "NEUROX Scalper AI — EMA/RSI/ATR forex scalper"
#property strict

#include <NeuroX/NX_Config.mqh>
#include <NeuroX/NX_Session.mqh>
#include <NeuroX/NX_Indicators.mqh>
#include <NeuroX/NX_Signals.mqh>
#include <NeuroX/NX_Risk.mqh>
#include <NeuroX/NX_Trade.mqh>

//----------------------------- inputs --------------------------------
input group "=== Strategy ==="
input int      InpFastEMA          = 9;       // Fast EMA period
input int      InpSlowEMA          = 21;      // Slow EMA period
input int      InpRSIPeriod        = 14;      // RSI period
input double   InpRSIBuyMax        = 65.0;    // Max RSI for BUY
input double   InpRSISellMin       = 35.0;    // Min RSI for SELL
input int      InpATRPeriod        = 14;      // ATR period
input double   InpStopATRMult      = 1.2;     // Stop-loss = ATR * this
input double   InpTakeATRMult      = 1.8;     // Take-profit = ATR * this
input double   InpMinATRPips       = 2.0;     // Skip if ATR below (pips)

input group "=== Risk ==="
input double   InpRiskPercent      = 0.5;     // Risk per trade (% balance)
input double   InpMaxDailyLossPct  = 3.0;     // Max daily loss (% day start)
input int      InpMaxOpenTrades    = 1;       // Max open positions
input double   InpMaxSpreadPips    = 2.0;     // Max allowed spread (pips)
input long     InpMagic            = 260726;  // Magic number
input int      InpSlippagePoints   = 20;      // Max slippage (points)

input group "=== Session (UTC) ==="
input bool     InpUseSession       = true;    // Filter by session
input int      InpSessionStartHour = 12;      // Session start hour UTC
input int      InpSessionEndHour   = 16;      // Session end hour UTC

input group "=== General ==="
input bool     InpOneTradePerBar   = true;    // At most one new trade per bar
input bool     InpLogSignals       = true;    // Print signal / skip reasons

//----------------------------- state ---------------------------------
CNeuroxIndicators g_indicators;
CNeuroxSignals    g_signals;
CNeuroxRisk       g_risk;
CNeuroxTrade      g_trade;
datetime          g_lastBarTime = 0;
datetime          g_lastTradeBar = 0;

//----------------------------- helpers -------------------------------
bool NX_IsNewBar()
  {
   datetime t[];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, t) != 1)
      return false;
   if(t[0] != g_lastBarTime)
     {
      g_lastBarTime = t[0];
      return true;
     }
   return false;
  }

bool NX_ValidateInputs()
  {
   if(InpFastEMA < 2 || InpSlowEMA < 3 || InpFastEMA >= InpSlowEMA)
     {
      Print("NEUROX: Fast EMA must be < Slow EMA");
      return false;
     }
   if(InpRSIPeriod < 2 || InpATRPeriod < 2)
     {
      Print("NEUROX: RSI/ATR periods invalid");
      return false;
     }
   if(InpRiskPercent <= 0.0 || InpRiskPercent > 10.0)
     {
      Print("NEUROX: Risk percent must be in (0, 10]");
      return false;
     }
   if(InpStopATRMult <= 0.0 || InpTakeATRMult <= 0.0)
     {
      Print("NEUROX: ATR multiples must be > 0");
      return false;
     }
   return true;
  }

//----------------------------- lifecycle -----------------------------
int OnInit()
  {
   if(!NX_ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   if(!g_indicators.Init(InpFastEMA, InpSlowEMA, InpRSIPeriod, InpATRPeriod))
     {
      Print("NEUROX: failed to create indicator handles");
      return INIT_FAILED;
     }

   g_signals.Configure(InpRSIBuyMax, InpRSISellMin, InpStopATRMult, InpTakeATRMult, InpMinATRPips);
   g_risk.Configure(InpRiskPercent, InpMaxDailyLossPct, InpMaxOpenTrades, InpMaxSpreadPips, InpMagic);
   g_trade.Configure(InpMagic, InpSlippagePoints, "NEUROX_Scalper_AI");

   PrintFormat("NEUROX Scalper AI initialized on %s | TF=%s | magic=%d",
               _Symbol,
               EnumToString(_Period),
               InpMagic);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_indicators.Release();
   Print("NEUROX Scalper AI stopped. reason=", reason);
  }

void OnTick()
  {
   // Evaluate once per new bar (scalper uses closed-bar signals)
   if(!NX_IsNewBar())
      return;

   if(!NX_InSession(InpUseSession, InpSessionStartHour, InpSessionEndHour))
     {
      if(InpLogSignals)
         Print("NEUROX: outside session window");
      return;
     }

   if(InpOneTradePerBar && g_lastTradeBar == g_lastBarTime)
      return;

   double emaFast[], emaSlow[], rsi[], atr[];
   if(!g_indicators.CopyBuffers(emaFast, emaSlow, rsi, atr, 3))
     {
      if(InpLogSignals)
         Print("NEUROX: indicator buffers not ready");
      return;
     }

   NXSignal signal = g_signals.Evaluate(emaFast, emaSlow, rsi, atr);
   if(signal.direction == NX_SIGNAL_NONE)
     {
      if(InpLogSignals)
         Print("NEUROX: ", signal.reason);
      return;
     }

   string riskReason;
   if(!g_risk.CanOpen(riskReason))
     {
      if(InpLogSignals)
         Print("NEUROX: risk block — ", riskReason);
      return;
     }

   double lots = g_risk.LotsForStop(signal.stopDistance);
   if(lots <= 0.0)
     {
      Print("NEUROX: lot size computed as 0");
      return;
     }

   double entry = (signal.direction == NX_SIGNAL_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl = 0.0, tp = 0.0;
   g_risk.StopTakePrices(signal.direction, entry, signal.stopDistance, signal.takeDistance, sl, tp);

   // Respect broker stop level
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist  = stopsLevel * _Point;
   if(minDist > 0.0)
     {
      if(signal.direction == NX_SIGNAL_BUY)
        {
         if(entry - sl < minDist)
            sl = NX_NormalizePrice(entry - minDist);
         if(tp - entry < minDist)
            tp = NX_NormalizePrice(entry + minDist);
        }
      else
        {
         if(sl - entry < minDist)
            sl = NX_NormalizePrice(entry + minDist);
         if(entry - tp < minDist)
            tp = NX_NormalizePrice(entry - minDist);
        }
     }

   string err;
   bool ok = false;
   if(signal.direction == NX_SIGNAL_BUY)
      ok = g_trade.OpenBuy(lots, sl, tp, err);
   else
      ok = g_trade.OpenSell(lots, sl, tp, err);

   if(ok)
     {
      g_lastTradeBar = g_lastBarTime;
      PrintFormat("NEUROX: opened %s lots=%.2f SL=%.5f TP=%.5f | %s",
                  (signal.direction == NX_SIGNAL_BUY ? "BUY" : "SELL"),
                  lots, sl, tp, signal.reason);
     }
   else
     {
      Print("NEUROX: order rejected — ", err);
     }
  }
//+------------------------------------------------------------------+
