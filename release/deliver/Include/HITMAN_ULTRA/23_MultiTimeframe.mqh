#ifndef HITMAN_ULTRA_23_MULTITIMEFRAME_MQH
#define HITMAN_ULTRA_23_MULTITIMEFRAME_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 23_MULTI_TIMEFRAME — MN..M1 · Bias · Voting · Weighting
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 07. Ultra Multi Timeframe Engine                                 |
//| MN / W1 / D1 / H4 / H1 / M30 / M15 / M5 / M1                     |
//+------------------------------------------------------------------+

ENUM_TIMEFRAMES UltraMTF_List(const int idx)
{
   switch(idx)
   {
      case 0: return PERIOD_MN1;
      case 1: return PERIOD_W1;
      case 2: return PERIOD_D1;
      case 3: return PERIOD_H4;
      case 4: return PERIOD_H1;
      case 5: return PERIOD_M30;
      case 6: return PERIOD_M15;
      case 7: return PERIOD_M5;
      case 8: return PERIOD_M1;
   }
   return PERIOD_CURRENT;
}

int UltraMTF_Count() { return 9; }

bool UltraMTF_Bull(const string s, const ENUM_TIMEFRAMES tf, const int smaPeriod=20)
{
   double sma = UltraSMA(s, tf, smaPeriod);
   if(sma <= 0.0) return false;
   return (iClose(s, tf, 1) > sma);
}

bool UltraMTF_Bear(const string s, const ENUM_TIMEFRAMES tf, const int smaPeriod=20)
{
   double sma = UltraSMA(s, tf, smaPeriod);
   if(sma <= 0.0) return false;
   return (iClose(s, tf, 1) < sma);
}

void UltraMTF_Vote(const string s, int &votesBuy, int &votesSell)
{
   votesBuy = 0; votesSell = 0;
   ENUM_TIMEFRAMES core[4] = {UltraTF_Month, UltraTF_Week, UltraTF_Macro, UltraTF_Bias};
   for(int i = 0; i < 4; i++)
   {
      if(UltraMTF_Bull(s, core[i])) votesBuy++;
      if(UltraMTF_Bear(s, core[i])) votesSell++;
   }
   if(UltraUseM30){ if(UltraMTF_Bull(s, PERIOD_M30)) votesBuy++; if(UltraMTF_Bear(s, PERIOD_M30)) votesSell++; }
   if(UltraUseM15){ if(UltraMTF_Bull(s, PERIOD_M15)) votesBuy++; if(UltraMTF_Bear(s, PERIOD_M15)) votesSell++; }
   if(UltraUseM5){  if(UltraMTF_Bull(s, PERIOD_M5))  votesBuy++; if(UltraMTF_Bear(s, PERIOD_M5))  votesSell++; }
   if(UltraUseM1Optional){ if(UltraMTF_Bull(s, PERIOD_M1)) votesBuy++; if(UltraMTF_Bear(s, PERIOD_M1)) votesSell++; }
}

double UltraMTF_WeightBias(const int votesBuy, const int votesSell)
{
   int d = votesBuy - votesSell;
   return MathMax(-1.0, MathMin(1.0, d / 6.0));
}

#endif // HITMAN_ULTRA_23_MULTITIMEFRAME_MQH
