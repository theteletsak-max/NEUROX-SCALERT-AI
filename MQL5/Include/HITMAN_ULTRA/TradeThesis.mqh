#ifndef HITMAN_ULTRA_TRADE_THESIS_MQH
#define HITMAN_ULTRA_TRADE_THESIS_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — LEVEL 11 TRADE THESIS ENGINE                         |
//| Store entry thesis · revalidate each new candle                  |
//+------------------------------------------------------------------+

#define ULTRA_THESIS_MAX 64

struct UltraTradeThesis
{
   ulong    ticket;
   string   symbol;
   bool     isBuy;
   string   tag;
   string   reason;
   int      conf, prec, prob;
   int      trendStr, structQ, bosScore, chochConf;
   bool     hadLiq, hadFib, hadMom;
   int      epoch;
   datetime openBar;
   datetime lastCheckBar;
   bool     valid;
   bool     stillValid;
   string   status;
};

UltraTradeThesis g_Thesis[ULTRA_THESIS_MAX];
int g_ThesisN = 0;

int UltraThesis_Find(const ulong ticket)
{
   for(int i = 0; i < g_ThesisN; i++)
      if(g_Thesis[i].ticket == ticket && g_Thesis[i].valid) return i;
   return -1;
}

int UltraThesis_Alloc()
{
   for(int i = 0; i < g_ThesisN; i++)
      if(!g_Thesis[i].valid) return i;
   if(g_ThesisN >= ULTRA_THESIS_MAX) return 0;
   return g_ThesisN++;
}

void UltraThesis_Store(const ulong ticket, const string s, const bool isBuy,
                       const string tag, const UltraSnap &u, const string reason)
{
   if(!UltraUpgradeEnabled || !UltraThesisEnabled) return;
   if(ticket == 0) return;
   int idx = UltraThesis_Find(ticket);
   if(idx < 0) idx = UltraThesis_Alloc();

   g_Thesis[idx].ticket = ticket;
   g_Thesis[idx].symbol = s;
   g_Thesis[idx].isBuy = isBuy;
   g_Thesis[idx].tag = tag;
   g_Thesis[idx].reason = reason;
   g_Thesis[idx].conf = u.score.confidence;
   g_Thesis[idx].prec = u.score.precision;
   g_Thesis[idx].prob = u.score.probability;
   g_Thesis[idx].trendStr = u.trend.strength;
   g_Thesis[idx].structQ = u.st.quality;
   g_Thesis[idx].bosScore = u.bos.score;
   g_Thesis[idx].chochConf = u.choch.confidence;
   g_Thesis[idx].hadLiq = isBuy ? (u.liq.sweepBuy || u.liq.grabBuy) : (u.liq.sweepSell || u.liq.grabSell);
   g_Thesis[idx].hadFib = isBuy ? u.fib.atBuyZone : u.fib.atSellZone;
   g_Thesis[idx].hadMom = isBuy ? (u.mom.momBuy || u.mom.impulse) : (u.mom.momSell || u.mom.impulse);
   g_Thesis[idx].epoch = UltraDisc_StructEpoch(u);
   g_Thesis[idx].openBar = iTime(s, UltraETF(), 0);
   g_Thesis[idx].lastCheckBar = 0;
   g_Thesis[idx].valid = true;
   g_Thesis[idx].stillValid = true;
   g_Thesis[idx].status = "ACTIVE";

   // Market memory note
   UltraMemory_NoteDecision(tag, u.score.confidence);
   if(UltraUpgradeLog)
   {
      string t = "THESIS STORE ticket=";
      t += IntegerToString((int)ticket);
      t += " ";
      if(isBuy) t += "BUY"; else t += "SELL";
      t += " ["; t += tag; t += "] conf=";
      t += IntegerToString(u.score.confidence);
      UltraLogTrade(t);
   }
}

void UltraThesis_StoreLatest(const string s, const bool isBuy, const string tag,
                             const UltraSnap &u, const string reason)
{
   if(!UltraUpgradeEnabled || !UltraThesisEnabled) return;
   ulong best = 0;
   datetime newest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      long ty = PositionGetInteger(POSITION_TYPE);
      if(isBuy && ty != POSITION_TYPE_BUY) continue;
      if(!isBuy && ty != POSITION_TYPE_SELL) continue;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot >= newest){ newest = ot; best = t; }
   }
   if(best != 0)
      UltraThesis_Store(best, s, isBuy, tag, u, reason);
}

bool UltraThesis_Revalidate(const ulong ticket, const UltraSnap &u, string &why)
{
   why = "";
   if(!UltraUpgradeEnabled || !UltraThesisEnabled) return true;
   int idx = UltraThesis_Find(ticket);
   if(idx < 0) return true; // fail-open

   datetime bar = iTime(g_Thesis[idx].symbol, UltraETF(), 0);
   if(bar == g_Thesis[idx].lastCheckBar) return g_Thesis[idx].stillValid;
   g_Thesis[idx].lastCheckBar = bar;

   bool isBuy = g_Thesis[idx].isBuy;
   // Ask: is original thesis still valid?
   bool trendOK = isBuy
      ? (u.trend.bull || u.trend.htfBull || u.trend.macroBull || (!UltraUpgradeStrict && !u.trend.bear))
      : (u.trend.bear || u.trend.htfBear || u.trend.macroBear || (!UltraUpgradeStrict && !u.trend.bull));
   bool structOK = (u.st.quality >= 15 || u.st.continuation || UltraUSM2_Clamp(u.st.strength) >= 15);
   bool hardInvalid = isBuy
      ? ((u.bos.sell && u.bos.confirmed && u.bos.strong) || (u.choch.sell && u.choch.majorC && u.trend.exhaustion))
      : ((u.bos.buy && u.bos.confirmed && u.bos.strong) || (u.choch.buy && u.choch.majorC && u.trend.exhaustion));

   if(hardInvalid)
   {
      g_Thesis[idx].stillValid = false;
      g_Thesis[idx].status = "INVALIDATED";
      why = "thesis invalidated by confirmed adverse break";
      return false;
   }
   if(!trendOK && UltraUpgradeStrict)
   {
      g_Thesis[idx].stillValid = false;
      g_Thesis[idx].status = "TREND_BROKEN";
      why = "thesis trend broken";
      return false;
   }

   g_Thesis[idx].stillValid = true;
   g_Thesis[idx].status = "VALID";
   return true;
}

void UltraThesis_Clear(const ulong ticket)
{
   int idx = UltraThesis_Find(ticket);
   if(idx < 0) return;
   g_Thesis[idx].valid = false;
   g_Thesis[idx].status = "CLOSED";
}

string UltraThesis_Dashboard()
{
   int active = 0;
   for(int i = 0; i < g_ThesisN; i++)
      if(g_Thesis[i].valid) active++;
   string t = "THESIS: ";
   t += IntegerToString(active);
   t += " active";
   return t;
}

#endif
