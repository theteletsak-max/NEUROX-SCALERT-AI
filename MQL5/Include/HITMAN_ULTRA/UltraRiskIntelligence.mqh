#ifndef HITMAN_ULTRA_RISK_INTELLIGENCE_MQH
#define HITMAN_ULTRA_RISK_INTELLIGENCE_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — MASTER SPEC CHAPTER 7 · RISK INTELLIGENCE ENGINE     |
//| Protect capital · size · exposure · margin · drawdown · portfolio|
//| NEVER creates signals · NEVER reads market structure             |
//| NEVER executes trades — Mission receives final risk assessment   |
//+------------------------------------------------------------------+

// Shell_B deep risk (defined later in assemble — same pattern as CountOpenTrades)
bool   RiskManagementOK();
int    CountOpenTrades();
double CalculateLotSize(const double slDistance = 0.0);
bool   HasSufficientMargin(ENUM_ORDER_TYPE orderType, double lot, double price);
bool   PortfolioExposureOK();
bool   MarginLevelProtection();

struct UltraRiskIntelState
{
   bool   booted;
   bool   approved;
   string status;              // APPROVED | REJECTED
   string detail;
   // Account analysis
   double balance;
   double equity;
   double freeMargin;
   double usedMargin;
   double marginLevel;
   double floatingPL;
   double dailyLossPct;
   double drawdownPct;
   // Position size
   double approvedLot;
   double maxRiskMoney;
   double riskPctEffective;
   double slDistance;
   // Status strings
   string exposureStatus;      // OK | HIGH | BLOCKED
   string marginStatus;        // OK | TIGHT | BLOCKED
   string portfolioStatus;     // OK | HEAVY | BLOCKED
   string ddStatus;            // OK | WARN | BLOCKED
   // Flags
   bool   capitalOK;
   bool   sizeOK;
   bool   marginOK;
   bool   exposureOK;
   bool   portfolioOK;
   bool   ddOK;
   int    openCount;
   int    consecLoss;
   double riskScale;           // adaptation ≤ 1.0 (never increase after wins)
   long   lastMs;
   ulong  approveCount;
   ulong  rejectCount;
};

UltraRiskIntelState g_UltraRiskIntel;

//--------------------------------------------------------------------//
void UltraRiskIntel_Boot()
{
   g_UltraRiskIntel.booted = true;
   g_UltraRiskIntel.approved = false;
   g_UltraRiskIntel.status = "INIT";
   g_UltraRiskIntel.detail = "boot";
   g_UltraRiskIntel.balance = g_UltraRiskIntel.equity = 0.0;
   g_UltraRiskIntel.freeMargin = g_UltraRiskIntel.usedMargin = 0.0;
   g_UltraRiskIntel.marginLevel = g_UltraRiskIntel.floatingPL = 0.0;
   g_UltraRiskIntel.dailyLossPct = g_UltraRiskIntel.drawdownPct = 0.0;
   g_UltraRiskIntel.approvedLot = g_UltraRiskIntel.maxRiskMoney = 0.0;
   g_UltraRiskIntel.riskPctEffective = g_UltraRiskIntel.slDistance = 0.0;
   g_UltraRiskIntel.exposureStatus = "OK";
   g_UltraRiskIntel.marginStatus = "OK";
   g_UltraRiskIntel.portfolioStatus = "OK";
   g_UltraRiskIntel.ddStatus = "OK";
   g_UltraRiskIntel.capitalOK = g_UltraRiskIntel.sizeOK = false;
   g_UltraRiskIntel.marginOK = g_UltraRiskIntel.exposureOK = false;
   g_UltraRiskIntel.portfolioOK = g_UltraRiskIntel.ddOK = false;
   g_UltraRiskIntel.openCount = g_UltraRiskIntel.consecLoss = 0;
   g_UltraRiskIntel.riskScale = 1.0;
   g_UltraRiskIntel.lastMs = 0;
   g_UltraRiskIntel.approveCount = g_UltraRiskIntel.rejectCount = 0;
}

bool UltraRiskIntel_Approved()
{
   return g_UltraRiskIntel.approved;
}

string UltraRiskIntel_Detail()
{
   return g_UltraRiskIntel.detail;
}

string UltraRiskIntel_Status()
{
   return g_UltraRiskIntel.status;
}

double UltraRiskIntel_Lot()
{
   return g_UltraRiskIntel.approvedLot;
}

double UltraRiskIntel_MaxRisk()
{
   return g_UltraRiskIntel.maxRiskMoney;
}

void UltraRiskIntel_Log(const string verb)
{
   string line = "RISK_INTEL ";
   line += verb;
   line += " status=";
   line += g_UltraRiskIntel.status;
   line += " lot=";
   line += DoubleToString(g_UltraRiskIntel.approvedLot, 2);
   line += " risk$=";
   line += DoubleToString(g_UltraRiskIntel.maxRiskMoney, 2);
   line += " risk%=";
   line += DoubleToString(g_UltraRiskIntel.riskPctEffective, 2);
   line += " eq=";
   line += DoubleToString(g_UltraRiskIntel.equity, 2);
   line += " fm=";
   line += DoubleToString(g_UltraRiskIntel.freeMargin, 2);
   line += " ml=";
   line += DoubleToString(g_UltraRiskIntel.marginLevel, 1);
   line += " open=";
   line += IntegerToString(g_UltraRiskIntel.openCount);
   line += " exp=";
   line += g_UltraRiskIntel.exposureStatus;
   line += " mgn=";
   line += g_UltraRiskIntel.marginStatus;
   line += " port=";
   line += g_UltraRiskIntel.portfolioStatus;
   line += " dd=";
   line += g_UltraRiskIntel.ddStatus;
   line += " | ";
   line += g_UltraRiskIntel.detail;
   UltraLog(line);
}

void UltraRiskIntel_Reject(const string why)
{
   g_UltraRiskIntel.approved = false;
   g_UltraRiskIntel.status = "REJECTED";
   g_UltraRiskIntel.detail = why;
   g_UltraRiskIntel.rejectCount++;
   g_UltraRiskIntel.lastMs = (long)GetTickCount();
   UltraRiskIntel_Log("REJECT");
}

void UltraRiskIntel_Approve(const string detail)
{
   g_UltraRiskIntel.approved = true;
   g_UltraRiskIntel.status = "APPROVED";
   g_UltraRiskIntel.detail = detail;
   g_UltraRiskIntel.approveCount++;
   g_UltraRiskIntel.lastMs = (long)GetTickCount();
   UltraRiskIntel_Log("APPROVE");
}

//--------------------------------------------------------------------//
// §2 ACCOUNT ANALYSIS                                                //
//--------------------------------------------------------------------//
void UltraRiskIntel_ReadAccount()
{
   g_UltraRiskIntel.balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_UltraRiskIntel.equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_UltraRiskIntel.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_UltraRiskIntel.usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   g_UltraRiskIntel.floatingPL = g_UltraRiskIntel.equity - g_UltraRiskIntel.balance;
   if(g_UltraRiskIntel.usedMargin > 0.0)
      g_UltraRiskIntel.marginLevel =
         (g_UltraRiskIntel.equity / g_UltraRiskIntel.usedMargin) * 100.0;
   else
      g_UltraRiskIntel.marginLevel = 0.0;

   // Daily performance proxy vs day's start (Shell tracks DailyStartBalance when DD on)
   g_UltraRiskIntel.dailyLossPct = 0.0;
   if(g_UltraRiskIntel.balance > 0.0 && g_UltraRiskIntel.floatingPL < 0.0)
      g_UltraRiskIntel.dailyLossPct =
         (-g_UltraRiskIntel.floatingPL / g_UltraRiskIntel.balance) * 100.0;

   // Overall DD proxy from peak equity GV if present
   g_UltraRiskIntel.drawdownPct = 0.0;
   string peakKey = "HitmanAI_" + IntegerToString((int)MagicNumber) + "_PeakEquity";
   if(GlobalVariableCheck(peakKey))
   {
      double peak = GlobalVariableGet(peakKey);
      if(peak > 0.0 && g_UltraRiskIntel.equity < peak)
         g_UltraRiskIntel.drawdownPct = ((peak - g_UltraRiskIntel.equity) / peak) * 100.0;
   }

   g_UltraRiskIntel.openCount = CountOpenTrades();
   g_UltraRiskIntel.consecLoss = Stat_ConsecutiveLosses;
}

//--------------------------------------------------------------------//
// §11 DYNAMIC RISK ADAPTATION — never increase after wins            //
//--------------------------------------------------------------------//
double UltraRiskIntel_AdaptScale()
{
   double scale = 1.0;
   // Soft adaptive (P12) — clamp so profitable periods never raise risk
   scale = UltraAdaptive_RiskScale();
   if(scale > 1.0) scale = 1.0;
   if(scale < 0.25) scale = 0.25;
   // Floating profit → do not expand risk
   if(g_UltraRiskIntel.floatingPL > 0.0 && scale > 1.0)
      scale = 1.0;
   // Consecutive losses → reduce (protect capital)
   if(g_UltraRiskIntel.consecLoss >= 3)
      scale = MathMin(scale, 0.70);
   else if(g_UltraRiskIntel.consecLoss >= 2)
      scale = MathMin(scale, 0.85);
   g_UltraRiskIntel.riskScale = scale;
   return scale;
}

//--------------------------------------------------------------------//
// §3 POSITION SIZE (one calculation via Shell sizing)                //
//--------------------------------------------------------------------//
void UltraRiskIntel_ComputeSize(const string s, const double entry, const double sl)
{
   g_UltraRiskIntel.slDistance = 0.0;
   if(entry > 0.0 && sl > 0.0)
      g_UltraRiskIntel.slDistance = MathAbs(entry - sl);

   double scale = UltraRiskIntel_AdaptScale();
   double basePct = RiskPercent;
   if(UseFixedLot) basePct = 0.0; // informational
   g_UltraRiskIntel.riskPctEffective = basePct * scale;
   if(g_UltraRiskIntel.riskPctEffective > RiskPercent)
      g_UltraRiskIntel.riskPctEffective = RiskPercent; // never increase above input

   g_UltraRiskIntel.maxRiskMoney =
      g_UltraRiskIntel.equity * (g_UltraRiskIntel.riskPctEffective / 100.0);
   if(UseFixedLot)
   {
      // Fixed lot — max risk is estimated from SL if known
      g_UltraRiskIntel.approvedLot = CalculateLotSize(g_UltraRiskIntel.slDistance);
      if(g_UltraRiskIntel.slDistance > 0.0)
      {
         double tickValue = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(s, SYMBOL_TRADE_TICK_SIZE);
         if(tickValue > 0.0 && tickSize > 0.0)
            g_UltraRiskIntel.maxRiskMoney =
               (g_UltraRiskIntel.slDistance / tickSize) * tickValue * g_UltraRiskIntel.approvedLot;
      }
   }
   else
   {
      g_UltraRiskIntel.approvedLot = CalculateLotSize(g_UltraRiskIntel.slDistance);
      // Re-assert money risk from effective %
      g_UltraRiskIntel.maxRiskMoney =
         g_UltraRiskIntel.equity * (g_UltraRiskIntel.riskPctEffective / 100.0);
   }
   g_UltraRiskIntel.sizeOK = (g_UltraRiskIntel.approvedLot > 0.0);
}

//--------------------------------------------------------------------//
// §5–8 EXPOSURE · MARGIN · DRAWDOWN · PORTFOLIO                      //
//--------------------------------------------------------------------//
bool UltraRiskIntel_CheckExposure(string &why)
{
   why = "";
   g_UltraRiskIntel.exposureStatus = "OK";
   g_UltraRiskIntel.exposureOK = true;
   if(EnforceOpenTradeCaps && MaxOpenTrades > 0 &&
      g_UltraRiskIntel.openCount >= MaxOpenTrades)
   {
      g_UltraRiskIntel.exposureOK = false;
      g_UltraRiskIntel.exposureStatus = "BLOCKED";
      why = "symbol/account exposure: max open trades";
      return false;
   }
   if(MaxOpenTrades > 0 &&
      g_UltraRiskIntel.openCount >= MathMax(1, MaxOpenTrades - 1))
      g_UltraRiskIntel.exposureStatus = "HIGH";
   return true;
}

bool UltraRiskIntel_CheckMargin(const string s, const bool isBuy,
                                const double price, string &why)
{
   why = "";
   g_UltraRiskIntel.marginOK = true;
   g_UltraRiskIntel.marginStatus = "OK";

   if(g_UltraRiskIntel.equity > 0.0 &&
      g_UltraRiskIntel.freeMargin / g_UltraRiskIntel.equity < 0.08)
   {
      g_UltraRiskIntel.marginOK = false;
      g_UltraRiskIntel.marginStatus = "BLOCKED";
      why = "free margin < 8% equity";
      return false;
   }

   if(!MarginLevelProtection())
   {
      g_UltraRiskIntel.marginOK = false;
      g_UltraRiskIntel.marginStatus = "BLOCKED";
      why = "margin level protection";
      return false;
   }

   if(g_UltraRiskIntel.approvedLot > 0.0 && price > 0.0)
   {
      ENUM_ORDER_TYPE ot = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!HasSufficientMargin(ot, g_UltraRiskIntel.approvedLot, price))
      {
         g_UltraRiskIntel.marginOK = false;
         g_UltraRiskIntel.marginStatus = "BLOCKED";
         why = "insufficient free margin for lot";
         return false;
      }
   }

   if(g_UltraRiskIntel.usedMargin > 0.0 && g_UltraRiskIntel.marginLevel > 0.0 &&
      g_UltraRiskIntel.marginLevel < 250.0)
      g_UltraRiskIntel.marginStatus = "TIGHT";

   return true;
}

bool UltraRiskIntel_CheckDrawdown(string &why)
{
   why = "";
   g_UltraRiskIntel.ddOK = true;
   g_UltraRiskIntel.ddStatus = "OK";

   // Delegate to Shell master risk (DD / daily / weekly / monthly)
   if(!RiskManagementOK())
   {
      g_UltraRiskIntel.ddOK = false;
      g_UltraRiskIntel.ddStatus = "BLOCKED";
      why = "drawdown / period loss / portfolio risk block";
      return false;
   }

   if(g_UltraRiskIntel.drawdownPct >= 5.0)
      g_UltraRiskIntel.ddStatus = "WARN";
   if(g_UltraRiskIntel.consecLoss >= 3)
      g_UltraRiskIntel.ddStatus = "WARN";
   return true;
}

bool UltraRiskIntel_CheckPortfolio(string &why)
{
   why = "";
   g_UltraRiskIntel.portfolioOK = true;
   g_UltraRiskIntel.portfolioStatus = "OK";

   if(!PortfolioExposureOK())
   {
      g_UltraRiskIntel.portfolioOK = false;
      g_UltraRiskIntel.portfolioStatus = "BLOCKED";
      why = "portfolio exposure concentration";
      return false;
   }

   if(MaxOpenTrades > 0 && g_UltraRiskIntel.openCount >= MaxOpenTrades)
   {
      g_UltraRiskIntel.portfolioOK = false;
      g_UltraRiskIntel.portfolioStatus = "BLOCKED";
      why = "portfolio max open";
      return false;
   }

   if(g_UltraRiskIntel.openCount >= 2)
      g_UltraRiskIntel.portfolioStatus = "HEAVY";
   return true;
}

//--------------------------------------------------------------------//
// §1 / §9 PRE-MISSION RISK (no order · no market structure)          //
//--------------------------------------------------------------------//
bool UltraRiskIntel_AssessPreMission(string &why)
{
   why = "";
   UltraRiskIntel_ReadAccount();
   UltraRiskIntel_AdaptScale();

   g_UltraRiskIntel.capitalOK = UltraCapitalOK(why);
   if(!g_UltraRiskIntel.capitalOK)
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   if(!UltraRiskIntel_CheckExposure(why))
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   if(!UltraRiskIntel_CheckDrawdown(why))
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   if(!UltraRiskIntel_CheckPortfolio(why))
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   // Soft margin status without lot (lot finalized at exec)
   g_UltraRiskIntel.marginOK = true;
   g_UltraRiskIntel.marginStatus = "OK";
   if(g_UltraRiskIntel.equity > 0.0 &&
      g_UltraRiskIntel.freeMargin / g_UltraRiskIntel.equity < 0.12)
      g_UltraRiskIntel.marginStatus = "TIGHT";

   g_UltraRiskIntel.approvedLot = 0.0;
   g_UltraRiskIntel.maxRiskMoney =
      g_UltraRiskIntel.equity * (RiskPercent * g_UltraRiskIntel.riskScale / 100.0);
   if(g_UltraRiskIntel.maxRiskMoney >
      g_UltraRiskIntel.equity * (RiskPercent / 100.0))
      g_UltraRiskIntel.maxRiskMoney =
         g_UltraRiskIntel.equity * (RiskPercent / 100.0);
   g_UltraRiskIntel.riskPctEffective = RiskPercent * g_UltraRiskIntel.riskScale;
   if(g_UltraRiskIntel.riskPctEffective > RiskPercent)
      g_UltraRiskIntel.riskPctEffective = RiskPercent;

   UltraRiskIntel_Approve("pre-mission risk OK");
   return true;
}

//--------------------------------------------------------------------//
// §9 / §10 FULL VALIDATION WITH LOT (exec path · still never executes)//
//--------------------------------------------------------------------//
bool UltraRiskIntel_Validate(const string s, const bool isBuy,
                             const double entry, const double sl, string &why)
{
   why = "";
   UltraRiskIntel_ReadAccount();

   g_UltraRiskIntel.capitalOK = UltraCapitalOK(why);
   if(!g_UltraRiskIntel.capitalOK)
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   UltraRiskIntel_ComputeSize(s, entry, sl);
   if(!g_UltraRiskIntel.sizeOK || g_UltraRiskIntel.approvedLot <= 0.0)
   {
      UltraRiskIntel_Reject("invalid position size");
      why = g_UltraRiskIntel.detail;
      return false;
   }

   if(!UltraRiskIntel_CheckExposure(why))
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   double px = entry;
   if(px <= 0.0)
      px = isBuy ? SymbolInfoDouble(s, SYMBOL_ASK) : SymbolInfoDouble(s, SYMBOL_BID);

   if(!UltraRiskIntel_CheckMargin(s, isBuy, px, why))
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   if(!UltraRiskIntel_CheckDrawdown(why))
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   if(!UltraRiskIntel_CheckPortfolio(why))
   {
      UltraRiskIntel_Reject(why);
      return false;
   }

   UltraRiskIntel_Approve(StringFormat("lot=%.2f risk$=%.2f",
                                       g_UltraRiskIntel.approvedLot,
                                       g_UltraRiskIntel.maxRiskMoney));
   return true;
}

string UltraRiskIntel_Dashboard()
{
   string t = "RISK: ";
   t += g_UltraRiskIntel.status;
   t += " lot=";
   t += DoubleToString(g_UltraRiskIntel.approvedLot, 2);
   t += " risk%=";
   t += DoubleToString(g_UltraRiskIntel.riskPctEffective, 2);
   t += " exp=";
   t += g_UltraRiskIntel.exposureStatus;
   t += " mgn=";
   t += g_UltraRiskIntel.marginStatus;
   t += " port=";
   t += g_UltraRiskIntel.portfolioStatus;
   t += " dd=";
   t += g_UltraRiskIntel.ddStatus;
   t += " open=";
   t += IntegerToString(g_UltraRiskIntel.openCount);
   if(StringLen(g_UltraRiskIntel.detail) > 0 && g_UltraRiskIntel.status == "REJECTED")
   {
      t += " | ";
      t += g_UltraRiskIntel.detail;
   }
   return t;
}

#endif // HITMAN_ULTRA_RISK_INTELLIGENCE_MQH
