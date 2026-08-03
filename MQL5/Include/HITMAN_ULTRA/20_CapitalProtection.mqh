#ifndef HITMAN_ULTRA_20_CAPITALPROTECTION_MQH
#define HITMAN_ULTRA_20_CAPITALPROTECTION_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 20_CAPITAL_PROTECTION — Equity · Margin · Exposure · Sizing
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 05. Capital Protection Engine                                    |
//| Equity · Margin · Exposure · Sizing bridge · Profit protection   |
//+------------------------------------------------------------------+
bool UltraCapitalOK(string &why)
{
   why = "";
   if(!UltraCapitalProtectEnabled) return true;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double fm = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(eq <= 0){ why = "bad equity"; return false; }
   if(fm / eq < 0.08){ why = "free margin < 8%"; return false; }
   if(EnforceOpenTradeCaps && MaxOpenTrades > 0 && CountOpenTrades() >= MaxOpenTrades)
   { why = "max open trades"; return false; }
   return true;
}


// Deep capital rules also live in Shell_B (RiskManagementOK / Drawdown / lots).

#endif // HITMAN_ULTRA_20_CAPITALPROTECTION_MQH
