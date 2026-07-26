//+------------------------------------------------------------------+
//| SniperAI.mq5                                                      |
//| SNIPER AI — aggressive institutional sniper EA                    |
//| Instant execution • 24/7 • events ON • no session filter          |
//| Watermark background • right HUD • chart symbol hunter            |
//+------------------------------------------------------------------+
#property copyright   "Sniper AI"
#property link        "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version     "1.00"
#property description "SNIPER AI — institutional sniper robot with instant execution"
#property description "Trades 24/7 including news/high volatility. No session filter."
#property strict

// Watermark image (candles render above via OBJPROP_BACK)
#resource "Images\\SniperAI_Watermark.bmp"

#include "Include/SniperAI/SA_Util.mqh"
#include "Include/SniperAI/SA_Signal.mqh"
#include "Include/SniperAI/SA_Risk.mqh"
#include "Include/SniperAI/SA_Trade.mqh"
#include "Include/SniperAI/SA_Watermark.mqh"
#include "Include/SniperAI/SA_Dashboard.mqh"

//----------------------------- inputs --------------------------------
input group "=== SNIPER AI CORE ==="
input double   InpLot              = 0.01;      // Lot size (changeable)
input int      InpMaxTrades        = 3;         // Max open trades (account)
input long     InpMagic            = 20260726;  // Magic number
input int      InpSlippagePoints   = 50;        // Slippage (points) — wide for news

input group "=== RISK ==="
input double   InpAtrMultSL        = 1.5;       // SL = ATR(H1) * this
input double   InpRewardRatio      = 2.0;       // Take profit R multiple (2R)
input double   InpBreakEvenR       = 1.0;       // Move BE at +R

input group "=== ENGINE ==="
input bool     InpTradeOnChartOnly = true;      // Trade attached chart symbol
input bool     InpAllowContinuation= true;      // Path A continuation
input bool     InpAllowReversal    = true;      // Path B reversal
input int      InpMinScore         = 3;         // Minimum setup score to fire
input bool     InpOnePerBar        = true;      // One new entry per M5 bar

input group "=== UI ==="
input bool     InpShowWatermark    = false;     // Show SNIPER AI watermark (off for now)
input bool     InpShowDashboard    = true;      // Show right-corner dashboard
input bool     InpLogTrades        = true;      // Journal to Experts log

//----------------------------- state ---------------------------------
CSniperSignal    g_signal;
CSniperRisk      g_risk;
CSniperTrade     g_trade;
CSniperWatermark g_watermark;
CSniperDashboard g_dash;

datetime g_lastM5Bar   = 0;
datetime g_lastEntryBar= 0;
string   g_lastAction  = "booting";
SASetup  g_lastSetup;

//----------------------------- helpers -------------------------------
bool SA_IsNewM5Bar(const string symbol)
  {
   datetime t[];
   if(CopyTime(symbol, PERIOD_M5, 0, 1, t) != 1)
      return false;
   // For chart symbol we track global bar time; multi-symbol fires on chart M5
   if(symbol == _Symbol)
     {
      if(t[0] != g_lastM5Bar)
        {
         g_lastM5Bar = t[0];
         return true;
        }
      return false;
     }
   return true;
  }

bool SA_IsForexSymbol(const string symbol)
  {
   string path = SymbolInfoString(symbol, SYMBOL_PATH);
   StringToLower(path);
   if(StringFind(path, "forex") >= 0)
      return true;
   // Fallback: 6-letter FX names
   if(StringLen(symbol) >= 6)
     {
      string base = StringSubstr(symbol, 0, 6);
      // crude but effective for EURUSD / EURUSDm
      return (StringFind(base, "USD") >= 0 || StringFind(base, "EUR") >= 0 ||
              StringFind(base, "GBP") >= 0 || StringFind(base, "JPY") >= 0 ||
              StringFind(base, "AUD") >= 0 || StringFind(base, "NZD") >= 0 ||
              StringFind(base, "CAD") >= 0 || StringFind(base, "CHF") >= 0);
     }
   return false;
  }

void SA_RefreshUI()
  {
   if(InpShowDashboard)
      g_dash.Update(_Symbol,
                    g_lastSetup,
                    g_risk.CountMagicPositions(),
                    InpLot,
                    g_lastAction,
                    AccountInfoDouble(ACCOUNT_BALANCE),
                    AccountInfoDouble(ACCOUNT_EQUITY));
  }

bool SA_Fire(const string symbol, const SASetup &setup)
  {
   if(setup.signal == SA_SIG_NONE)
      return false;
   if(setup.score < InpMinScore)
     {
      g_lastAction = "score too low";
      return false;
     }
   if(setup.path == "CONTINUATION" && !InpAllowContinuation)
      return false;
   if(setup.path == "REVERSAL" && !InpAllowReversal)
      return false;

   string reason;
   if(!g_risk.CanOpen(symbol, reason))
     {
      g_lastAction = reason;
      return false;
     }

   double entry = 0, sl = 0, tp = 0;
   if(!g_risk.BuildSLTP(symbol, setup.signal, entry, sl, tp, reason))
     {
      g_lastAction = reason;
      return false;
     }

   double lots = g_risk.Lots(symbol);
   string comment = StringFormat("SNIPER|%s|%d", setup.path, setup.score);
   string err;
   bool ok = false;

   // INSTANT MARKET EXECUTION — no pending orders, no “wait out volatility”
   if(setup.signal == SA_SIG_BUY)
      ok = g_trade.InstantBuy(symbol, lots, sl, tp, comment, err);
   else
      ok = g_trade.InstantSell(symbol, lots, sl, tp, comment, err);

   if(ok)
     {
      g_lastEntryBar = g_lastM5Bar;
      g_lastAction = StringFormat("%s %s %s", symbol, SA_SigText(setup.signal), setup.path);
      if(InpLogTrades)
         PrintFormat("SNIPER AI KILL => %s %s | %s | score=%d | SL=%.5f TP=%.5f | %s",
                     symbol, SA_SigText(setup.signal), setup.path, setup.score, sl, tp, setup.reason);
      return true;
     }

   g_lastAction = err;
   Print("SNIPER AI order error: ", err);
   return false;
  }

void SA_HuntChartSymbol(const bool newBar)
  {
   g_lastSetup = g_signal.Evaluate(_Symbol);
   if(newBar && !(InpOnePerBar && g_lastEntryBar == g_lastM5Bar))
      SA_Fire(_Symbol, g_lastSetup);
  }

void SA_HuntAllForex(const bool newBar)
  {
   if(!newBar)
     {
      g_lastSetup = g_signal.Evaluate(_Symbol);
      return;
     }

   // Collect candidates, score-rank, fill remaining slots (A+B allocation)
   string syms[];
   int scores[];
   ENUM_SA_SIGNAL sigs[];
   SASetup setups[];
   ArrayResize(syms, 0);

   int total = SymbolsTotal(true);
   for(int i = 0; i < total; i++)
     {
      string sym = SymbolName(i, true);
      if(!SA_IsForexSymbol(sym))
         continue;
      if(!SymbolSelect(sym, true))
         continue;

      SASetup s = g_signal.Evaluate(sym);
      if(s.signal == SA_SIG_NONE || s.score < InpMinScore)
         continue;

      int n = ArraySize(syms);
      ArrayResize(syms, n + 1);
      ArrayResize(scores, n + 1);
      ArrayResize(sigs, n + 1);
      ArrayResize(setups, n + 1);
      syms[n] = sym;
      scores[n] = s.score;
      sigs[n] = s.signal;
      setups[n] = s;
     }

   // Also always refresh dashboard from chart symbol
   g_lastSetup = g_signal.Evaluate(_Symbol);

   // Sort by score descending (simple swap)
   int n = ArraySize(syms);
   for(int a = 0; a < n; a++)
      for(int b = a + 1; b < n; b++)
         if(scores[b] > scores[a])
           {
            int ts = scores[a]; scores[a] = scores[b]; scores[b] = ts;
            string tsy = syms[a]; syms[a] = syms[b]; syms[b] = tsy;
            SASetup tu = setups[a]; setups[a] = setups[b]; setups[b] = tu;
           }

   for(int k = 0; k < n; k++)
     {
      if(g_risk.CountMagicPositions() >= InpMaxTrades)
         break;
      SA_Fire(syms[k], setups[k]);
     }
  }

//----------------------------- lifecycle -----------------------------
int OnInit()
  {
   if(InpLot <= 0)
     {
      Print("SNIPER AI: invalid lot");
      return INIT_PARAMETERS_INCORRECT;
     }

   // Ensure chart symbol is ready for fast reads
   SymbolSelect(_Symbol, true);

   g_risk.Configure(InpMagic, InpLot, InpAtrMultSL, InpRewardRatio, InpBreakEvenR, InpMaxTrades);
   g_trade.Configure(InpMagic, InpSlippagePoints);

   // Includes resolve from MQL5/Include/SniperAI — copy folder on install
   // Watermark resource is compiled into the EX5 from Images\\ next to this EA

   g_watermark.Create(InpShowWatermark);
   g_lastSetup.signal = SA_SIG_NONE;
   g_lastSetup.score = 0;
   g_lastSetup.path = "-";
   g_lastSetup.reason = "armed — scanning " + _Symbol;
   g_lastSetup.bias = SA_BIAS_NONE;
   g_lastAction = "online 24/7";

   SA_RefreshUI();

   PrintFormat("SNIPER AI ONLINE | %s | lot=%.2f | max=%d | 24/7 events ON | instant market",
               _Symbol, InpLot, InpMaxTrades);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   g_watermark.Delete();
   g_dash.Delete();
   Comment("");
   Print("SNIPER AI stopped. reason=", reason);
  }

void OnTick()
  {
   // Always manage BE every tick — sniper protection
   g_risk.ManageBreakEven();

   // Fast structure read on each new M5 bar (entry timeframe)
   bool newBar = SA_IsNewM5Bar(_Symbol);

   // Refresh setup frequently for dashboard; fire only on new bar
   static int tickPulse = 0;
   tickPulse++;
   bool scanNow = newBar || (tickPulse % 25 == 0);

   if(scanNow)
     {
      if(InpTradeOnChartOnly)
         SA_HuntChartSymbol(newBar);
      else
         SA_HuntAllForex(newBar);
      SA_RefreshUI();
     }
  }

void OnTimer()
  {
   // reserved for multi-symbol expansion
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE && InpShowWatermark)
      g_watermark.Create(true);
  }
//+------------------------------------------------------------------+
