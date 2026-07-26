//+------------------------------------------------------------------+
//| SA_Trade.mqh — instant market execution                            |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_TRADE_MQH
#define SNIPER_AI_SA_TRADE_MQH

#include "SA_Util.mqh"
#include <Trade/Trade.mqh>

class CSniperTrade
  {
private:
   CTrade m_trade;
   long   m_magic;
   int    m_slippage;

public:
                     CSniperTrade(void): m_magic(20260726), m_slippage(50) {}

   void Configure(const long magic, const int slippage)
     {
      m_magic = magic;
      m_slippage = slippage;
      m_trade.SetExpertMagicNumber((ulong)magic);
      m_trade.SetDeviationInPoints(slippage);
      m_trade.SetAsyncMode(false);
     }

   CTrade *Trade() { return GetPointer(m_trade); }

   bool InstantBuy(const string symbol, const double lots, const double sl, const double tp,
                   const string comment, string &err)
     {
      m_trade.SetExpertMagicNumber((ulong)m_magic);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFillingBySymbol(symbol);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      // Instant market execution — no pending, no delay
      if(!m_trade.Buy(lots, symbol, ask, sl, tp, comment))
        {
         err = StringFormat("BUY fail %d %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
         return false;
        }
      err = "ok";
      return true;
     }

   bool InstantSell(const string symbol, const double lots, const double sl, const double tp,
                    const string comment, string &err)
     {
      m_trade.SetExpertMagicNumber((ulong)m_magic);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFillingBySymbol(symbol);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(!m_trade.Sell(lots, symbol, bid, sl, tp, comment))
        {
         err = StringFormat("SELL fail %d %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
         return false;
        }
      err = "ok";
      return true;
     }
  };

#endif
//+------------------------------------------------------------------+
