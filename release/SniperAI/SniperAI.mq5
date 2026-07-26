//+------------------------------------------------------------------+
//| SNIPER_AI_OK12.mq5                                                |
//| BUILD_ID: SA_COMPILE_OK_12                                        |
//| SNIPER AI                                                         |
//| ZERO includes. Raw OrderSend only. Put in Experts, press F7.      |
//+------------------------------------------------------------------+
#property copyright "SNIPER AI"
#property link      "https://github.com/theteletsak-max/NEUROX-SCALERT-AI"
#property version   "1.00"
#property description "SNIPER AI institutional sniper EA"
#property description "H4 H1 M5 high precision 24/7"

#define SA_NAME "SNIPER AI"
#define SA_UI   "SA_UI_"

//--- inputs
input double InpLot                = 0.01;
input int    InpMaxTrades          = 3;
input long   InpMagic              = 20260726;
input int    InpSlippage           = 80;
input int    InpMaxRetries         = 3;
input int    InpSwingStrength      = 2;
input int    InpMinScore           = 14;
input int    InpMinConfluence      = 4;
input bool   InpAllowContinuation  = true;
input bool   InpAllowReversal      = true;
input bool   InpRequireZoneTouch   = true;
input bool   InpOnePerM5           = true;
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
input bool   InpShowDashboard      = true;
input bool   InpLogEvents          = true;
input int    InpDashEveryTicks     = 8;

//--- globals
int      g_atrHandle = INVALID_HANDLE;
datetime g_lastM5 = 0;
datetime g_lastEntryM5 = 0;
datetime g_dayStamp = 0;
double   g_dayStartEquity = 0.0;
int      g_consecLoss = 0;
int      g_tick = 0;
string   g_lastAction = "boot";
string   g_eaStatus = "init";
string   g_execStatus = "idle";
string   g_reason = "armed";
int      g_side = 0;      // 1 buy, -1 sell, 0 flat
int      g_path = 0;      // 1 cont, 2 rev
int      g_bias = 0;      // 1 bull, -1 bear, 0 flat
int      g_mkt = 1;       // 0 low,1 normal,2 high,3 extreme
int      g_score = 0;
double   g_atr = 0.0;
double   g_spreadPts = 0.0;

//+------------------------------------------------------------------+
void SaLog(string msg)
  {
   if(InpLogEvents)
      Print(SA_NAME, " | ", msg);
  }

//+------------------------------------------------------------------+
double SaPip()
  {
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

//+------------------------------------------------------------------+
double SaNormPrice(double price)
  {
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

//+------------------------------------------------------------------+
double SaNormLots(double lots)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   lots = MathFloor(lots / step + 1e-12) * step;
   if(lots < minLot)
      lots = minLot;
   if(lots > maxLot)
      lots = maxLot;
   return NormalizeDouble(lots, (step < 0.01 ? 3 : 2));
  }

//+------------------------------------------------------------------+
bool SaCopyRates(ENUM_TIMEFRAMES tf, int count, MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   return (CopyRates(_Symbol, tf, 0, count, rates) >= count);
  }

//+------------------------------------------------------------------+
bool SaIsSwingHigh(MqlRates &r[], int i, int strength, int n)
  {
   if(i - strength < 0 || i + strength >= n)
      return false;
   for(int k = 1; k <= strength; k++)
     {
      if(r[i].high < r[i - k].high || r[i].high < r[i + k].high)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
bool SaIsSwingLow(MqlRates &r[], int i, int strength, int n)
  {
   if(i - strength < 0 || i + strength >= n)
      return false;
   for(int k = 1; k <= strength; k++)
     {
      if(r[i].low > r[i - k].low || r[i].low > r[i + k].low)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
int SaBiasH4(MqlRates &r[], int n, int strength)
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

//+------------------------------------------------------------------+
void SaRecentSwings(MqlRates &r[], int n, int strength, double &swingHigh, double &swingLow)
  {
   swingHigh = 0;
   swingLow = 0;
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

//+------------------------------------------------------------------+
bool SaM5Buy(MqlRates &m5[], int n)
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

//+------------------------------------------------------------------+
bool SaM5Sell(MqlRates &m5[], int n)
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

//+------------------------------------------------------------------+
int SaCountMagic()
  {
   int c = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      c++;
     }
   return c;
  }

//+------------------------------------------------------------------+
double SaFloating()
  {
   double p = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return p;
  }

//+------------------------------------------------------------------+
void SaRollDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeTradeServer(), dt);
   string s = StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day);
   datetime day = StringToTime(s);
   if(day != g_dayStamp)
     {
      g_dayStamp = day;
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
     }
  }

//+------------------------------------------------------------------+
bool SaCanOpen(string &why)
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
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      why = "trading disabled";
      return false;
     }
   why = "ok";
   return true;
  }

//+------------------------------------------------------------------+
bool SaBuildStops(int side, int mkt, double atr, double &entry, double &sl, double &tp, string &why)
  {
   double boost = 1.0;
   if(mkt == 2)
      boost = InpSLBoostHigh;
   if(mkt == 3)
      boost = InpSLBoostExtreme;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freeze = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDist = MathMax((double)stops, (double)freeze) * point;
   double stopDist = atr * InpAtrMultSL * boost;
   double floorDist = MathMax(minDist, SaPip() * 3.0);
   if(stopDist < floorDist)
      stopDist = floorDist;

   if(side == 1)
     {
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = SaNormPrice(entry - stopDist);
      tp = SaNormPrice(entry + stopDist * InpRR);
      if(sl >= entry || tp <= entry)
        {
         why = "bad buy stops";
         return false;
        }
      if(entry - sl < minDist)
         sl = SaNormPrice(entry - minDist);
      if(tp - entry < minDist)
         tp = SaNormPrice(entry + minDist);
     }
   else if(side == -1)
     {
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = SaNormPrice(entry + stopDist);
      tp = SaNormPrice(entry - stopDist * InpRR);
      if(sl <= entry || tp >= entry)
        {
         why = "bad sell stops";
         return false;
        }
      if(sl - entry < minDist)
         sl = SaNormPrice(entry + minDist);
      if(entry - tp < minDist)
         tp = SaNormPrice(entry - minDist);
     }
   else
     {
      why = "no side";
      return false;
     }
   why = "ok";
   return true;
  }


//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING SaFilling()
  {
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

//+------------------------------------------------------------------+
bool SaModify(ulong ticket, string symbol, double sl, double tp)
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
   return OrderSend(req, res);
  }

//+------------------------------------------------------------------+
bool SaSend(int side, double lots, double sl, double tp, string &why)
  {
   for(int attempt = 1; attempt <= InpMaxRetries; attempt++)
     {
      ResetLastError();
      MqlTradeRequest req;
      MqlTradeResult res;
      ZeroMemory(req);
      ZeroMemory(res);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0)
        {
         why = "no quotes";
         g_execStatus = why;
         if(attempt < InpMaxRetries)
           {
            Sleep(150 * attempt);
            continue;
           }
         return false;
        }

      req.action       = TRADE_ACTION_DEAL;
      req.symbol       = _Symbol;
      req.volume       = lots;
      req.type         = (side == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      req.price        = (side == 1 ? ask : bid);
      req.sl           = sl;
      req.tp           = tp;
      req.deviation    = InpSlippage;
      req.magic        = (ulong)InpMagic;
      req.comment      = SA_NAME;
      req.type_filling = SaFilling();

      bool ok = OrderSend(req, res);
      if(ok)
        {
         why = "filled";
         g_execStatus = "FILLED";
         return true;
        }

      why = StringFormat("retcode=%d err=%d", (int)res.retcode, GetLastError());
      g_execStatus = why;
      if(attempt < InpMaxRetries)
        {
         Sleep(150 * attempt);
         continue;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
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
      if(point <= 0.0)
         continue;

      double risk = (type == POSITION_TYPE_BUY ? (open - sl) : (sl - open));
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
            double newSL = NormalizeDouble(open, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
            SaModify(ticket, symbol, newSL, tp);
            sl = newSL;
           }
        }

      if(InpUseTrailing)
        {
         bool armed = false;
         if(type == POSITION_TYPE_BUY && bid >= open + risk * InpTrailStartR)
            armed = true;
         if(type == POSITION_TYPE_SELL && ask <= open - risk * InpTrailStartR)
            armed = true;
         if(armed)
           {
            double step = risk * InpTrailStepR;
            int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            if(type == POSITION_TYPE_BUY)
              {
               double nsl = NormalizeDouble(bid - step, digits);
               if(nsl > sl + point)
                  SaModify(ticket, symbol, nsl, tp);
              }
            else
              {
               double nsl = NormalizeDouble(ask + step, digits);
               if(sl == 0.0 || nsl < sl - point)
                  SaModify(ticket, symbol, nsl, tp);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
void SaUiBox(string id, int x, int y, int w, int h, int bg, int border)
  {
   string name = SA_UI + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void SaUiLbl(string id, int x, int y, string text, int clr, int size)
  {
   string name = SA_UI + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void SaDashboard()
  {
   if(!InpShowDashboard)
      return;

   int x0 = 14, y0 = 16, w = 300, h = 410;
   SaUiBox("bg", x0, y0, w, h, 1314832, 2955710);
   SaUiBox("hdr", x0, y0, w, 42, 1837186, 4271590);

   int x = x0 + 12;
   int y = y0 + 10;
   SaUiLbl("t", x, y, SA_NAME, clrWhite, 14);
   y = y0 + 48;
   SaUiLbl("sub", x, y, "24/7 | HIGH PRECISION", 12500710, 8);

   string bias = "NEUTRAL";
   if(g_bias == 1)
      bias = "BULLISH";
   if(g_bias == -1)
      bias = "BEARISH";

   string sig = "FLAT";
   int sigClr = (int)clrSilver;
   if(g_side == 1)
     {
      sig = "BUY";
      sigClr = 8578605;
     }
   if(g_side == -1)
     {
      sig = "SELL";
      sigClr = 4934655;
     }

   string path = "-";
   if(g_path == 1)
      path = "CONTINUATION";
   if(g_path == 2)
      path = "REVERSAL";

   string mkt = "NORMAL";
   if(g_mkt == 0)
      mkt = "LOW VOL";
   if(g_mkt == 2)
      mkt = "HIGH VOL";
   if(g_mkt == 3)
      mkt = "EXTREME VOL";

   y = y0 + 70;
   SaUiLbl("sym", x, y, "SYMBOL      " + _Symbol, clrWhite, 10); y += 17;
   SaUiLbl("tf", x, y, "STACK       H4 / H1 / M5", 14469300, 9); y += 17;
   SaUiLbl("bias", x, y, "BIAS        " + bias, clrAqua, 10); y += 17;
   SaUiLbl("sig", x, y, "SIGNAL      " + sig, sigClr, 11); y += 17;
   SaUiLbl("path", x, y, "ENTRY TYPE  " + path, clrGold, 10); y += 17;
   SaUiLbl("score", x, y, StringFormat("SETUP SCORE %d", g_score), clrOrange, 10); y += 17;
   SaUiLbl("open", x, y, StringFormat("OPEN        %d / %d", SaCountMagic(), InpMaxTrades), clrWhite, 10); y += 17;
   SaUiLbl("lot", x, y, StringFormat("LOT         %.2f", InpLot), clrWhite, 10); y += 17;
   SaUiLbl("bal", x, y, StringFormat("BALANCE     %.2f", AccountInfoDouble(ACCOUNT_BALANCE)), 16768180, 9); y += 16;
   SaUiLbl("eq", x, y, StringFormat("EQUITY      %.2f", AccountInfoDouble(ACCOUNT_EQUITY)), 16768180, 9); y += 16;
   double fl = SaFloating();
   int flClr = 6579455;
   if(fl >= 0.0)
      flClr = 9231440;
   SaUiLbl("fl", x, y, StringFormat("FLOATING    %.2f", fl), flClr, 9); y += 16;
   SaUiLbl("spr", x, y, StringFormat("SPREAD      %.1f pts", g_spreadPts), clrSilver, 9); y += 16;
   SaUiLbl("atr", x, y, StringFormat("ATR(H1)     %.5f", g_atr), clrSilver, 9); y += 16;
   SaUiLbl("mkt", x, y, "MARKET      " + mkt, 11206560, 9); y += 16;
   SaUiLbl("exec", x, y, "EXECUTION   " + g_execStatus, 9211135, 8); y += 15;
   SaUiLbl("ea", x, y, "EA STATUS   " + g_eaStatus, 13813960, 8); y += 15;
   SaUiLbl("br", x, y, "BROKER      " + AccountInfoString(ACCOUNT_COMPANY), 11182240, 8); y += 15;
   SaUiLbl("srv", x, y, "SERVER      " + TimeToString(TimeTradeServer(), (TIME_DATE|TIME_SECONDS)), 9866380, 8); y += 16;
   string rs = g_reason;
   if(StringLen(rs) > 44)
      rs = StringSubstr(rs, 0, 44) + "...";
   SaUiLbl("st", x, y, "TRADE STATUS", clrSilver, 8); y += 14;
   SaUiLbl("st2", x, y, rs, clrSilver, 8); y += 16;
   SaUiLbl("last", x, y, "LAST  " + g_lastAction, clrGray, 8);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void SaClearUI()
  {
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, SA_UI) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
void SaEvaluateAndMaybeTrade(bool allowEntry)
  {
   g_side = 0;
   g_path = 0;
   g_score = 0;
   g_reason = "scanning";

   MqlRates h4[], h1[], m5[];
   if(!SaCopyRates(PERIOD_H4, 160, h4))
     {
      g_reason = "no H4";
      return;
     }
   if(!SaCopyRates(PERIOD_H1, 160, h1))
     {
      g_reason = "no H1";
      return;
     }
   if(!SaCopyRates(PERIOD_M5, 40, m5))
     {
      g_reason = "no M5";
      return;
     }

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(g_atrHandle, 0, 1, 40, atrBuf) < 40)
     {
      g_reason = "no ATR";
      return;
     }
   g_atr = atrBuf[0];
   double atrSum = 0.0;
   for(int i = 0; i < 40; i++)
      atrSum += atrBuf[i];
   double atrAvg = atrSum / 40.0;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_spreadPts = (point > 0.0 ? (ask - bid) / point : 0.0);

   g_mkt = 1;
   if(atrAvg > 0.0)
     {
      if(g_atr >= atrAvg * InpExtremeVolMult)
         g_mkt = 3;
      else if(g_atr >= atrAvg * InpHighVolMult)
         g_mkt = 2;
      else if(g_atr <= atrAvg * 0.55)
         g_mkt = 0;
     }

   int strength = InpSwingStrength;
   if(strength < 1)
      strength = 1;
   if(strength > 5)
      strength = 5;

   g_bias = SaBiasH4(h4, ArraySize(h4), strength);

   double swingHigh = 0, swingLow = 0;
   SaRecentSwings(h1, ArraySize(h1), strength, swingHigh, swingLow);

   bool bosBull = false, bosBear = false, chochBull = false, chochBear = false;
   double c1 = h1[1].close;
   if(swingHigh > 0.0 && c1 > swingHigh)
     {
      if(g_bias == 1 || g_bias == 0)
         bosBull = true;
      if(g_bias == -1)
         chochBull = true;
     }
   if(swingLow > 0.0 && c1 < swingLow)
     {
      if(g_bias == -1 || g_bias == 0)
         bosBear = true;
      if(g_bias == 1)
         chochBear = true;
     }

   // liquidity
   double pip = SaPip();
   double tol = MathMax(pip * 2.0, g_atr * 0.05);
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
   bool eqH = false, eqL = false;
   int eqhc = 0, eqlc = 0;
   int limEq = (n1 < 30 ? n1 : 30);
   for(int i = 3; i < limEq; i++)
     {
      if(MathAbs(h1[i].high - h1[2].high) <= tol)
         eqhc++;
      if(MathAbs(h1[i].low - h1[2].low) <= tol)
         eqlc++;
     }
   eqH = (eqhc >= 1);
   eqL = (eqlc >= 1);

   // zones
   double b1 = MathAbs(h1[1].close - h1[1].open);
   double b2 = MathAbs(h1[2].close - h1[2].open);
   double b3 = MathAbs(h1[3].close - h1[3].open);
   double b4 = MathAbs(h1[4].close - h1[4].open);
   double avg = (b2 + b3 + b4) / 3.0;
   if(avg <= 0.0)
      avg = b1;

   bool bullDisp = (h1[1].close > h1[1].open && b1 >= avg * 1.7);
   bool bearDisp = (h1[1].close < h1[1].open && b1 >= avg * 1.7);
   bool bullFVG = (h1[3].high < h1[1].low);
   bool bearFVG = (h1[3].low > h1[1].high);
   bool bullOB = (bullDisp && h1[2].close < h1[2].open);
   bool bearOB = (bearDisp && h1[2].close > h1[2].open);

   double zLo = 0, zHi = 0;
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

   bool bullTouch = false, bearTouch = false;
   if(zHi > zLo)
     {
      double pad = (zHi - zLo) * 0.35;
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
   if(g_bias != 0)
      score += 2;

   int need = InpMinScore;
   if(g_mkt == 2)
      need = InpMinScore + 1;
   if(g_mkt == 3)
      need = InpMinScore + 3;

   bool m5buy = SaM5Buy(m5, ArraySize(m5));
   bool m5sell = SaM5Sell(m5, ArraySize(m5));

   // continuation buy
   if(InpAllowContinuation && g_bias == 1)
     {
      int conf = 0;
      if(g_bias == 1)
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
         g_side = 1;
         g_path = 1;
         g_score = score + 8 + conf;
         g_reason = "CONT precision";
        }
     }

   // continuation sell
   if(g_side == 0 && InpAllowContinuation && g_bias == -1)
     {
      int conf = 0;
      if(g_bias == -1)
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
         g_side = -1;
         g_path = 1;
         g_score = score + 8 + conf;
         g_reason = "CONT precision";
        }
     }

   // reversal buy
   if(g_side == 0 && InpAllowReversal && sellSweep && chochBull && (bullDisp || bullFVG || bullOB) && m5buy)
     {
      int conf = 4;
      if(bullTouch || bullFVG)
         conf++;
      if(bullDisp)
         conf++;
      g_side = 1;
      g_path = 2;
      g_score = score + 10 + conf;
      if(conf >= InpMinConfluence)
         g_reason = "REV precision";
      else
        {
         g_side = 0;
         g_path = 0;
         g_score = score;
         g_reason = "rev conf low";
        }
     }

   // reversal sell
   if(g_side == 0 && InpAllowReversal && buySweep && chochBear && (bearDisp || bearFVG || bearOB) && m5sell)
     {
      int conf = 4;
      if(bearTouch || bearFVG)
         conf++;
      if(bearDisp)
         conf++;
      g_side = -1;
      g_path = 2;
      g_score = score + 10 + conf;
      if(conf >= InpMinConfluence)
         g_reason = "REV precision";
      else
        {
         g_side = 0;
         g_path = 0;
         g_score = score;
         g_reason = "rev conf low";
        }
     }

   if(g_side == 0)
     {
      g_score = score;
      if(StringFind(g_reason, "precision") < 0)
         g_reason = "awaiting setup";
     }

   if(!allowEntry)
      return;
   if(g_side == 0 || g_score < need)
      return;

   string why;
   if(!SaCanOpen(why))
     {
      g_lastAction = why;
      g_eaStatus = "blocked";
      return;
     }

   double entry = 0, sl = 0, tp = 0;
   if(!SaBuildStops(g_side, g_mkt, g_atr, entry, sl, tp, why))
     {
      g_lastAction = why;
      return;
     }

   double lots = SaNormLots(InpLot);
   double margin = 0.0;
   ENUM_ORDER_TYPE ot = (g_side == 1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double px = (g_side == 1 ? ask : bid);
   if(!OrderCalcMargin(ot, _Symbol, lots, px, margin))
     {
      g_lastAction = "margin calc fail";
      return;
     }
   if(margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      g_lastAction = "insufficient margin";
      return;
     }

   if(!SaSend(g_side, lots, sl, tp, why))
     {
      g_lastAction = why;
      g_eaStatus = "exec fail";
      SaLog("order failed: " + why);
      return;
     }

   g_lastEntryM5 = g_lastM5;
   g_lastAction = (g_side == 1 ? "BUY filled" : "SELL filled");
   g_eaStatus = "in market";
   SaLog(g_lastAction);
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpLot <= 0.0 || InpMaxTrades < 1 || InpAtrMultSL <= 0.0 || InpRR <= 0.0)
     {
      Print(SA_NAME, " invalid inputs");
      return INIT_PARAMETERS_INCORRECT;
     }

   SymbolSelect(_Symbol, true);
   g_atrHandle = iATR(_Symbol, PERIOD_H1, 14);
   if(g_atrHandle == INVALID_HANDLE)
     {
      Print(SA_NAME, " ATR init failed");
      return INIT_FAILED;
     }

   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_eaStatus = "online";
   g_lastAction = "online 24/7";
   g_reason = "armed";
   SaDashboard();
   SaLog(StringFormat("ONLINE %s lot=%.2f", _Symbol, InpLot));
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_atrHandle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
     }
   SaClearUI();
   Comment("");
   SaLog(StringFormat("stopped reason=%d", reason));
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   g_tick++;
   SaManagePositions();

   datetime t[];
   if(CopyTime(_Symbol, PERIOD_M5, 0, 1, t) != 1)
     {
      g_eaStatus = "data wait";
      if(g_tick % InpDashEveryTicks == 0)
         SaDashboard();
      return;
     }

   bool newM5 = false;
   if(t[0] != g_lastM5)
     {
      g_lastM5 = t[0];
      newM5 = true;
     }

   if(newM5 || (g_tick % InpDashEveryTicks == 0))
     {
      bool allow = newM5;
      if(allow && InpOnePerM5 && g_lastEntryM5 == g_lastM5)
         allow = false;
      SaEvaluateAndMaybeTrade(allow);
      g_eaStatus = "scanning";
      SaDashboard();
     }
  }

//+------------------------------------------------------------------+
