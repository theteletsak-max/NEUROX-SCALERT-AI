//+------------------------------------------------------------------+
//| NX_Trade.mqh                                                      |
//| Order execution wrapper around CTrade                             |
//+------------------------------------------------------------------+
#property copyright "NEUROX"
#property strict

#ifndef NEUROX_NX_TRADE_MQH
#define NEUROX_NX_TRADE_MQH

#include <Trade/Trade.mqh>
#include "NX_Config.mqh"

class CNeuroxTrade
  {
private:
   CTrade m_trade;
   long   m_magic;
   int    m_slippagePoints;
   string m_comment;

public:
                     CNeuroxTrade(void);
   void              Configure(const long magic,
                               const int slippagePoints,
                               const string comment);

   bool              OpenBuy(const double lots, const double sl, const double tp, string &error);
   bool              OpenSell(const double lots, const double sl, const double tp, string &error);
  };

CNeuroxTrade::CNeuroxTrade(void)
   : m_magic(260726),
     m_slippagePoints(20),
     m_comment("NEUROX")
  {
  }

void CNeuroxTrade::Configure(const long magic,
                             const int slippagePoints,
                             const string comment)
  {
   m_magic = magic;
   m_slippagePoints = slippagePoints;
   m_comment = comment;
   m_trade.SetExpertMagicNumber((ulong)m_magic);
   m_trade.SetDeviationInPoints(m_slippagePoints);
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetAsyncMode(false);
  }

bool CNeuroxTrade::OpenBuy(const double lots, const double sl, const double tp, string &error)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(!m_trade.Buy(lots, _Symbol, ask, sl, tp, m_comment))
     {
      error = StringFormat("Buy failed retcode=%d (%s)",
                           m_trade.ResultRetcode(),
                           m_trade.ResultRetcodeDescription());
      return false;
     }
   error = "ok";
   return true;
  }

bool CNeuroxTrade::OpenSell(const double lots, const double sl, const double tp, string &error)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!m_trade.Sell(lots, _Symbol, bid, sl, tp, m_comment))
     {
      error = StringFormat("Sell failed retcode=%d (%s)",
                           m_trade.ResultRetcode(),
                           m_trade.ResultRetcodeDescription());
      return false;
     }
   error = "ok";
   return true;
  }

#endif
//+------------------------------------------------------------------+
