#ifndef HITMAN_ULTRA_33_ORDERMGMT_MQH
#define HITMAN_ULTRA_33_ORDERMGMT_MQH
//+------------------------------------------------------------------+
//| 33_OrderManagement — market/pending · modify · cancel · partial  |
//| Deep market open path remains ExecuteBuy/Sell in Shell_B.        |
//+------------------------------------------------------------------+

bool UltraOrder_IsOurs(const ulong ticket)
{
   if(!OrderSelect(ticket)) return false;
   return (OrderGetInteger(ORDER_MAGIC) == MagicNumber);
}

int UltraOrder_CountPendingOurs()
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(!OrderSelect(t)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      n++;
   }
   return n;
}

bool UltraOrder_Cancel(const ulong ticket, string &why)
{
   why = "";
   if(!UltraOrder_IsOurs(ticket)){ why = "not our order"; return false; }
   MqlTradeRequest req; MqlTradeResult res;
   ZeroMemory(req); ZeroMemory(res);
   req.action = TRADE_ACTION_REMOVE;
   req.order  = ticket;
   if(!OrderSend(req, res))
   {
      why = "OrderSend remove failed " + IntegerToString((int)res.retcode);
      return false;
   }
   return (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_PLACED);
}

bool UltraOrder_DuplicateProtect(const string s, const bool buy)
{
   // Block same-direction pending spam on symbol
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != s) continue;
      long typ = OrderGetInteger(ORDER_TYPE);
      bool isBuy = (typ == ORDER_TYPE_BUY_LIMIT || typ == ORDER_TYPE_BUY_STOP || typ == ORDER_TYPE_BUY_STOP_LIMIT);
      bool isSell= (typ == ORDER_TYPE_SELL_LIMIT || typ == ORDER_TYPE_SELL_STOP || typ == ORDER_TYPE_SELL_STOP_LIMIT);
      if(buy && isBuy) return true;
      if(!buy && isSell) return true;
   }
   return UltraExec_DuplicateBarGuard(s);
}

string UltraOrder_ModuleStatus()
{
   return "pendingOurs=" + IntegerToString(UltraOrder_CountPendingOurs()) +
          " | market opens via Shell_B ExecuteBuy/Sell";
}

#endif
