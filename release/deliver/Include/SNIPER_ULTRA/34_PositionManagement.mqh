#ifndef SNIPER_ULTRA_34_POSMGMT_MQH
#define SNIPER_ULTRA_34_POSMGMT_MQH
//+------------------------------------------------------------------+
//| 34_PositionManagement — track · sync · monitor · stats           |
//+------------------------------------------------------------------+

struct UltraPosInfo
{
   ulong  ticket;
   string symbol;
   long   type;
   double volume;
   double profit;
   double sl;
   double tp;
   string comment;
};

int UltraPos_CountMagic()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      n++;
   }
   return n;
}

int UltraPos_CountSymbol(const string s)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != s) continue;
      n++;
   }
   return n;
}

bool UltraPos_Get(const ulong ticket, UltraPosInfo &p)
{
   p.ticket=0; p.symbol=""; p.type=0; p.volume=0; p.profit=0; p.sl=0; p.tp=0; p.comment="";
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) return false;
   p.ticket  = ticket;
   p.symbol  = PositionGetString(POSITION_SYMBOL);
   p.type    = PositionGetInteger(POSITION_TYPE);
   p.volume  = PositionGetDouble(POSITION_VOLUME);
   p.profit  = PositionGetDouble(POSITION_PROFIT);
   p.sl      = PositionGetDouble(POSITION_SL);
   p.tp      = PositionGetDouble(POSITION_TP);
   p.comment = PositionGetString(POSITION_COMMENT);
   return true;
}

double UltraPos_TotalProfitMagic()
{
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return sum;
}

string UltraPos_Summary()
{
   return "open=" + IntegerToString(UltraPos_CountMagic()) +
          " pnl=" + DoubleToString(UltraPos_TotalProfitMagic(), 2);
}

#endif
