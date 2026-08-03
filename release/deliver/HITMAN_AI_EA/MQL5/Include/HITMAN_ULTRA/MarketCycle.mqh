#ifndef HITMAN_ULTRA_MARKET_CYCLE_MQH
#define HITMAN_ULTRA_MARKET_CYCLE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MARKET CYCLE ENGINE                                  |
//| Accumulation · Markup · Distribution · Markdown                  |
//+------------------------------------------------------------------+

enum ENUM_MARKET_CYCLE
{
   CYCLE_ACCUMULATION = 0,
   CYCLE_MARKUP,
   CYCLE_DISTRIBUTION,
   CYCLE_MARKDOWN,
   CYCLE_UNKNOWN
};

string UltraCycle_Name(const ENUM_MARKET_CYCLE c)
{
   if(c == CYCLE_ACCUMULATION) return "ACCUMULATION";
   if(c == CYCLE_MARKUP) return "MARKUP";
   if(c == CYCLE_DISTRIBUTION) return "DISTRIBUTION";
   if(c == CYCLE_MARKDOWN) return "MARKDOWN";
   return "UNKNOWN";
}

void UltraEngCycle(UltraSnap &u)
{
   ENUM_MARKET_CYCLE c = CYCLE_UNKNOWN;
   bool bullExt = u.st.externalBull;
   bool bearExt = u.st.externalBear;
   bool rangeLike = (u.regime == UREG_RANGE || u.regime == UREG_COMPRESSION || u.regime == UREG_ACCUMULATION);
   bool expand = (u.vol.expansion || u.regime == UREG_EXPANSION || u.regime == UREG_BREAKOUT);
   bool exhaust = u.trend.exhaustion || (u.regime == UREG_EXHAUSTION);

   if(bullExt && expand && !exhaust)
      c = CYCLE_MARKUP;
   else if(bearExt && expand && !exhaust)
      c = CYCLE_MARKDOWN;
   else if(bullExt && (exhaust || u.regime == UREG_DISTRIBUTION || u.ict.inPremium))
      c = CYCLE_DISTRIBUTION;
   else if(bearExt && (exhaust || u.regime == UREG_ACCUMULATION || u.ict.inDiscount))
      c = CYCLE_ACCUMULATION;
   else if(rangeLike && (u.liq.poolBuy || u.liq.equalLows || u.ict.inDiscount))
      c = CYCLE_ACCUMULATION;
   else if(rangeLike && (u.liq.poolSell || u.liq.equalHighs || u.ict.inPremium))
      c = CYCLE_DISTRIBUTION;
   else if(u.st.continuation && bullExt)
      c = CYCLE_MARKUP;
   else if(u.st.continuation && bearExt)
      c = CYCLE_MARKDOWN;

   u.st.cycle = (int)c;
   u.st.cycleName = UltraCycle_Name(c);
}

bool UltraCycle_SupportsBuy(const UltraSnap &u)
{
   return (u.st.cycle == (int)CYCLE_ACCUMULATION || u.st.cycle == (int)CYCLE_MARKUP ||
           u.st.cycle == (int)CYCLE_UNKNOWN);
}

bool UltraCycle_SupportsSell(const UltraSnap &u)
{
   return (u.st.cycle == (int)CYCLE_DISTRIBUTION || u.st.cycle == (int)CYCLE_MARKDOWN ||
           u.st.cycle == (int)CYCLE_UNKNOWN);
}

#endif
