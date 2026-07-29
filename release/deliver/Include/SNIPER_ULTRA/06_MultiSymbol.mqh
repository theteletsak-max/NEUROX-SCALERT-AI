#ifndef SNIPER_ULTRA_06_MULTISYM_MQH
#define SNIPER_ULTRA_06_MULTISYM_MQH
//+------------------------------------------------------------------+
//| 06. Ultra Multi Symbol Engine                                    |
//| Scanner · Sync · Independent analysis · Symbol statistics        |
//+------------------------------------------------------------------+

int UltraMulti_SymbolCount()
{
   return ArraySize(MultiSymbolList);
}

string UltraMulti_SymbolAt(const int idx)
{
   if(idx < 0 || idx >= ArraySize(MultiSymbolList)) return "";
   return MultiSymbolList[idx];
}

bool UltraMulti_IsTracked(const string s)
{
   return (GetSymbolIndex(s) >= 0);
}

void UltraMulti_ScanSummary(string &out)
{
   out = "symbols=" + IntegerToString(UltraMulti_SymbolCount());
   if(EnableMultiSymbolTrading)
      out += " multi=ON timer=" + IntegerToString(MultiSymbolTimerSeconds) + "s";
   else
      out += " multi=OFF primary=" + BrokerSymbol;
}

bool UltraMulti_AnalyzeSymbol(const string s, UltraSnap &u)
{
   if(!UltraMulti_IsTracked(s) && s != BrokerSymbol && s != _Symbol)
      return false;
   return UltraBuildSnapshot(s, u);
}

#endif
