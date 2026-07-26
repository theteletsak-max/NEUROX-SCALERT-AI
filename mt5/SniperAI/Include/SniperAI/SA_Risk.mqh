//+------------------------------------------------------------------+
//| SA_Risk.mqh — sizing, SL/TP/BE, trade caps (no vol/session block)  |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_RISK_MQH
#define SNIPER_AI_SA_RISK_MQH

#include "SA_Util.mqh"
#include <Trade/Trade.mqh>

class CSniperRisk
  {
private:
   long   m_magic;
   double m_lot;
   double m_atrMult;
   double m_rr;
   double m_beR;
   int    m_maxTrades;

public:
                     CSniperRisk(void)
                        : m_magic(20260726), m_lot(0.01), m_atrMult(1.5),
                          m_rr(2.0), m_beR(1.0), m_maxTrades(3) {}

   void Configure(const long magic, const double lot, const double atrMult,
                  const double rr, const double beR, const int maxTrades)
     {
      m_magic = magic;
      m_lot = lot;
      m_atrMult = atrMult;
      m_rr = rr;
      m_beR = beR;
      m_maxTrades = maxTrades;
     }

   int CountMagicPositions(const string symbolFilter = "")
     {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
         if(symbolFilter != "" && PositionGetString(POSITION_SYMBOL) != symbolFilter) continue;
         count++;
        }
      return count;
     }

   bool CanOpen(const string symbol, string &reason)
     {
      // NO session filter, NO spread filter, NO volatility filter — trade 24/7 including events
      if(CountMagicPositions() >= m_maxTrades)
        {
         reason = "max account trades (3)";
         return false;
        }
      if(CountMagicPositions(symbol) >= m_maxTrades)
        {
         reason = "max symbol trades";
         return false;
        }
      reason = "ok";
      return true;
     }

   double Lots(const string symbol) const
     {
      return SA_NormLots(symbol, m_lot);
     }

   bool BuildSLTP(const string symbol, const ENUM_SA_SIGNAL side,
                  double &entry, double &sl, double &tp, string &reason)
     {
      double atr = SA_ATR(symbol, PERIOD_H1, 14, 1);
      // Even if ATR tiny/huge (news), still trade — floor to small pip distance only for broker stops
      double pip = SA_PipSize(symbol);
      double stopDist = atr * m_atrMult;
      if(stopDist < pip * 3.0)
         stopDist = pip * 3.0;

      long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minDist = stopsLevel * SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(stopDist < minDist)
         stopDist = minDist;

      if(side == SA_SIG_BUY)
        {
         entry = SymbolInfoDouble(symbol, SYMBOL_ASK);
         sl = SA_NormPrice(symbol, entry - stopDist);
         tp = SA_NormPrice(symbol, entry + stopDist * m_rr);
        }
      else if(side == SA_SIG_SELL)
        {
         entry = SymbolInfoDouble(symbol, SYMBOL_BID);
         sl = SA_NormPrice(symbol, entry + stopDist);
         tp = SA_NormPrice(symbol, entry - stopDist * m_rr);
        }
      else
        {
         reason = "no side";
         return false;
        }
      reason = "ok";
      return true;
     }

   void ManageBreakEven()
     {
      CTrade trade;
      trade.SetExpertMagicNumber((ulong)m_magic);

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         string symbol = PositionGetString(POSITION_SYMBOL);
         double open = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         long type = PositionGetInteger(POSITION_TYPE);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

         double risk = 0.0;
         if(type == POSITION_TYPE_BUY)
            risk = open - sl;
         else
            risk = sl - open;
         if(risk <= 0.0)
            continue;

         // Already BE?
         if(type == POSITION_TYPE_BUY && sl >= open - point)
            continue;
         if(type == POSITION_TYPE_SELL && sl > 0.0 && sl <= open + point)
            continue;

         bool hit = false;
         if(type == POSITION_TYPE_BUY && bid >= open + risk * m_beR)
            hit = true;
         if(type == POSITION_TYPE_SELL && ask <= open - risk * m_beR)
            hit = true;

         if(hit)
           {
            double newSL = SA_NormPrice(symbol, open);
            trade.PositionModify(ticket, newSL, tp);
           }
        }
     }
  };

#endif
//+------------------------------------------------------------------+
