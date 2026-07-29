#ifndef SNIPER_ULTRA_01_CORE_MQH
#define SNIPER_ULTRA_01_CORE_MQH
//+------------------------------------------------------------------+
//| 01. Ultra Core System                                            |
//| Init · Config · Validation · Error · Memory · Logging · Recovery |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES UltraETF()
{
   return (EntryTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)Period() : EntryTF;
}

void UltraLog(const string msg)
{
   if(UltraLoggingEnabled)
      Print("ULTRA| ", msg);
}

void UltraSetError(const string e)
{
   if(!UltraErrorHandlingEnabled) return;
   g_UltraCore.errorCount++;
   g_UltraCore.lastError = e;
   UltraLog("ERR " + e);
}

void UltraRecover(const string why)
{
   if(!UltraRecoveryEnabled) return;
   g_UltraCore.recoveryCount++;
   UltraLog("RECOVERY " + why);
   g_UltraCore.healthy = true;
}

bool UltraConfigOK()
{
   if(!UltraConfigEngineEnabled) return true;
   if(TradeComment != "SNIPER AI") return false;
   if(MaxOpenTrades < 1) return false;
   if(UltraMinConfluence < 1 || UltraMinConfluence > 100) return false;
   return true;
}

bool UltraValidateSymbol(const string s)
{
   if(!UltraValidationEnabled) return true;
   if(s == "" || !SymbolInfoInteger(s, SYMBOL_SELECT)) return false;
   if(Bars(s, UltraETF()) < 60) return false;
   return true;
}

double UltraATR(const string s, const int period=14)
{
   int p = MathMax(period, 5);
   ENUM_TIMEFRAMES tf = UltraETF();
   if(Bars(s, tf) < p + 5) return 0.0;
   double sum = 0.0;
   for(int i = 1; i <= p; i++)
   {
      double h = iHigh(s, tf, i), l = iLow(s, tf, i), pc = iClose(s, tf, i + 1);
      sum += MathMax(h - l, MathMax(MathAbs(h - pc), MathAbs(l - pc)));
   }
   return sum / p;
}

double UltraSMA(const string s, const ENUM_TIMEFRAMES tf, const int period, const int shift=1)
{
   if(Bars(s, tf) < period + shift + 2) return 0.0;
   double a = 0.0;
   for(int i = shift; i < shift + period; i++) a += iClose(s, tf, i);
   return a / period;
}

bool UltraSwingHighAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double h = iHigh(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iHigh(s, tf, bar - i) >= h || iHigh(s, tf, bar + i) >= h) return false;
   return true;
}

bool UltraSwingLowAt(const string s, const ENUM_TIMEFRAMES tf, const int bar, const int strength)
{
   int bars = Bars(s, tf);
   if(bar - strength < 0 || bar + strength >= bars) return false;
   double l = iLow(s, tf, bar);
   for(int i = 1; i <= strength; i++)
      if(iLow(s, tf, bar - i) <= l || iLow(s, tf, bar + i) <= l) return false;
   return true;
}

bool UltraFindSwings(const string s, const ENUM_TIMEFRAMES tf, const int lb, const int strength,
                     int &iH1, int &iH2, int &iL1, int &iL2)
{
   iH1 = iH2 = iL1 = iL2 = 0;
   int sw = MathMax(strength, 1), look = MathMax(lb, 20);
   for(int i = sw + 1; i <= look; i++)
   {
      if(iH1 == 0 && UltraSwingHighAt(s, tf, i, sw)) iH1 = i;
      else if(iH1 > 0 && iH2 == 0 && UltraSwingHighAt(s, tf, i, sw)) iH2 = i;
      if(iL1 == 0 && UltraSwingLowAt(s, tf, i, sw)) iL1 = i;
      else if(iL1 > 0 && iL2 == 0 && UltraSwingLowAt(s, tf, i, sw)) iL2 = i;
      if(iH1 && iH2 && iL1 && iL2) break;
   }
   return (iH1 && iH2 && iL1 && iL2);
}

void UltraCoreInit()
{
   g_UltraCore.loaded = false;
   g_UltraCore.configOK = false;
   g_UltraCore.dataOK = false;
   g_UltraCore.validated = false;
   g_UltraCore.healthy = false;
   g_UltraCore.lastCycleMs = 0;
   g_UltraCore.lastLatencyMs = 0;
   g_UltraCore.errorCount = 0;
   g_UltraCore.recoveryCount = 0;
   g_UltraCore.lastError = "";
   g_UltraMem.trades = 0;
   g_UltraMem.wins = 0;
   g_UltraMem.profitSum = 0;
   g_UltraMem.lossSum = 0;
   g_UltraMem.avgRR = 0;
   g_UltraMem.winRate = 0;
   g_UltraMem.profitFactor = 0;
   g_UltraMem.expectancy = 0;
   g_UltraMem.lastSave = 0;
   g_UltraCore.loaded = true;
   g_UltraCore.configOK = UltraConfigOK();
   g_UltraCore.healthy = g_UltraCore.configOK;
   UltraLog("CORE loaded configOK=" + (string)g_UltraCore.configOK);
}

//--------------------------------------------------------------------//
// 2. MARKET STRUCTURE / BOS / CHoCH / LIQUIDITY / FIB / ICT / TREND /
//    MOMENTUM / VOL / REGIME
//--------------------------------------------------------------------//

#endif
