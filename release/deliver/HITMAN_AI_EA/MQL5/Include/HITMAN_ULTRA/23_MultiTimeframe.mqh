#ifndef HITMAN_ULTRA_23_MULTITIMEFRAME_MQH
#define HITMAN_ULTRA_23_MULTITIMEFRAME_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 23_MULTI_TIMEFRAME — MN..M1 · Bias · Sync · Lock     |
//| Monthly · Weekly · Daily · H4 · H1 · M30 · M15 · M5 · M1         |
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

string UltraMTF_Label(const int idx)
{
   switch(idx)
   {
      case 0: return "MN";
      case 1: return "W1";
      case 2: return "D1";
      case 3: return "H4";
      case 4: return "H1";
      case 5: return "M30";
      case 6: return "M15";
      case 7: return "M5";
      case 8: return "M1";
   }
   return "?";
}

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

// ROADMAP P4/P10 — HTF majority (MN/W1/D1/H4) + hysteresis (no flicker)
string   g_UltraMTF_HystSym = "";
int      g_UltraMTF_HystDir = 0;
int      g_UltraMTF_HystCount = 0;
datetime g_UltraMTF_HystBar = 0;

int UltraMTF_MasterDirRaw(const string s)
{
   int score = 0;
   ENUM_TIMEFRAMES htf[4];
   htf[0] = PERIOD_MN1; htf[1] = PERIOD_W1; htf[2] = PERIOD_D1; htf[3] = UltraTF_Bias;
   for(int i = 0; i < 4; i++)
   {
      if(UltraMTF_Bull(s, htf[i])) score++;
      if(UltraMTF_Bear(s, htf[i])) score--;
   }
   if(score > 0) return 1;
   if(score < 0) return -1;
   return 0;
}

// Master trend. Returns +1 buy, -1 sell, 0 unknown.
// Higher timeframe decides direction; hysteresis prevents bar-to-bar flicker.
int UltraMTF_MasterDir(const string s)
{
   int raw = UltraMTF_MasterDirRaw(s);
   int need = UltraMasterHysteresisBars;
   if(need < 1) need = 1;

   datetime bar = iTime(s, UltraTF_Bias, 0);
   if(g_UltraMTF_HystSym != s)
   {
      g_UltraMTF_HystSym = s;
      g_UltraMTF_HystDir = raw;
      g_UltraMTF_HystCount = need;
      g_UltraMTF_HystBar = bar;
      return raw;
   }

   if(raw == 0)
      return g_UltraMTF_HystDir; // keep last known master when stack is mixed

   if(raw == g_UltraMTF_HystDir)
   {
      g_UltraMTF_HystCount = need;
      g_UltraMTF_HystBar = bar;
      return raw;
   }

   // opposing vote — require N bars before flip
   if(bar > 0 && bar != g_UltraMTF_HystBar)
   {
      g_UltraMTF_HystCount++;
      g_UltraMTF_HystBar = bar;
   }
   else if(g_UltraMTF_HystCount == 0)
      g_UltraMTF_HystCount = 1;

   if(g_UltraMTF_HystCount >= need)
   {
      g_UltraMTF_HystDir = raw;
      g_UltraMTF_HystCount = 0;
      return raw;
   }
   return g_UltraMTF_HystDir;
}

// Timeframe synchronization: count agreement across MN→M5 ladder for side.
int UltraMTF_SyncAgree(const string s, const bool buySide, int &known)
{
   known = 0;
   int agree = 0;
   for(int i = 0; i < 8; i++) // MN..M5 (skip optional M1)
   {
      ENUM_TIMEFRAMES tf = UltraMTF_List(i);
      if(i == 5 && !UltraUseM30) continue;
      if(i == 6 && !UltraUseM15) continue;
      if(i == 7 && !UltraUseM5) continue;
      double sma = UltraSMA(s, tf, 20, 1);
      if(sma <= 0.0) continue;
      known++;
      bool bull = (iClose(s, tf, 1) > sma);
      bool bear = (iClose(s, tf, 1) < sma);
      if(buySide ? bull : bear) agree++;
   }
   return agree;
}

// No timeframe conflicts: LTF must not fight H4 master (strict) / soft allows mild mix.
bool UltraMTF_NoConflict(const string s, const bool buySide, string &why)
{
   why = "";
   int master = UltraMTF_MasterDir(s);
   if(master == 0) return true; // unknown master — fail-open
   if(buySide && master < 0)
   {
      why = "MTF conflict: H4 master SELL vs BUY";
      return false;
   }
   if(!buySide && master > 0)
   {
      why = "MTF conflict: H4 master BUY vs SELL";
      return false;
   }

   // Higher TF stack (MN/W1/D1) should not be strongly opposite in strict mode
   int htfOpp = 0;
   int htfKnown = 0;
   ENUM_TIMEFRAMES htf[3];
   htf[0] = PERIOD_MN1; htf[1] = PERIOD_W1; htf[2] = PERIOD_D1;
   for(int i = 0; i < 3; i++)
   {
      double sma = UltraSMA(s, htf[i], 20, 1);
      if(sma <= 0.0) continue;
      htfKnown++;
      bool bull = (iClose(s, htf[i], 1) > sma);
      bool bear = (iClose(s, htf[i], 1) < sma);
      if(buySide && bear) htfOpp++;
      if(!buySide && bull) htfOpp++;
   }
   if(!InstantQualityMode && UltraDisciplineStrict && htfKnown >= 2 && htfOpp >= 2)
   {
      why = "MTF conflict: higher TF stack against thesis";
      return false;
   }
   return true;
}

string UltraMTF_Dashboard(const string s)
{
   int known = 0;
   int ab = UltraMTF_SyncAgree(s, true, known);
   int k2 = 0;
   int asell = UltraMTF_SyncAgree(s, false, k2);
   string t = "MTF: BUY ";
   t += IntegerToString(ab);
   t += " SELL ";
   t += IntegerToString(asell);
   t += " master=";
   int m = UltraMTF_MasterDir(s);
   if(m > 0) t += "BUY";
   else if(m < 0) t += "SELL";
   else t += "-";
   return t;
}

#endif // HITMAN_ULTRA_23_MULTITIMEFRAME_MQH
