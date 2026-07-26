//+------------------------------------------------------------------+
//| NX_Risk.mqh                                                       |
//| Position sizing and daily loss / spread guards                    |
//+------------------------------------------------------------------+
#property copyright "NEUROX"
#property strict

#ifndef NEUROX_NX_RISK_MQH
#define NEUROX_NX_RISK_MQH

#include "NX_Config.mqh"

class CNeuroxRisk
  {
private:
   double   m_riskPct;
   double   m_maxDailyLossPct;
   int      m_maxOpenTrades;
   double   m_maxSpreadPips;
   long     m_magic;
   datetime m_dayStamp;
   double   m_dayStartBalance;

   void     RollDay(void);

public:
                     CNeuroxRisk(void);
   void              Configure(const double riskPct,
                               const double maxDailyLossPct,
                               const int maxOpenTrades,
                               const double maxSpreadPips,
                               const long magic);

   int               CountOpenPositions(void) const;
   double            CurrentSpreadPips(void) const;
   bool              CanOpen(string &reason);
   double            LotsForStop(const double stopDistance) const;
   void              StopTakePrices(const ENUM_NX_SIGNAL direction,
                                   const double entry,
                                   const double stopDist,
                                   const double takeDist,
                                   double &sl,
                                   double &tp) const;
  };

CNeuroxRisk::CNeuroxRisk(void)
   : m_riskPct(0.5),
     m_maxDailyLossPct(3.0),
     m_maxOpenTrades(1),
     m_maxSpreadPips(2.0),
     m_magic(260726),
     m_dayStamp(0),
     m_dayStartBalance(0.0)
  {
  }

void CNeuroxRisk::Configure(const double riskPct,
                            const double maxDailyLossPct,
                            const int maxOpenTrades,
                            const double maxSpreadPips,
                            const long magic)
  {
   m_riskPct          = riskPct;
   m_maxDailyLossPct  = maxDailyLossPct;
   m_maxOpenTrades    = maxOpenTrades;
   m_maxSpreadPips    = maxSpreadPips;
   m_magic            = magic;
  }

void CNeuroxRisk::RollDay(void)
  {
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   datetime day = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(day != m_dayStamp)
     {
      m_dayStamp = day;
      m_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
     }
  }

int CNeuroxRisk::CountOpenPositions(void) const
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != m_magic)
         continue;
      count++;
     }
   return count;
  }

double CNeuroxRisk::CurrentSpreadPips(void) const
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pip = NX_PipSize();
   if(pip <= 0.0)
      return 1e9;
   return (ask - bid) / pip;
  }

bool CNeuroxRisk::CanOpen(string &reason)
  {
   RollDay();

   if(CountOpenPositions() >= m_maxOpenTrades)
     {
      reason = "max open trades reached";
      return false;
     }

   double spread = CurrentSpreadPips();
   if(spread > m_maxSpreadPips)
     {
      reason = StringFormat("spread too wide (%.2f pips)", spread);
      return false;
     }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0 || m_dayStartBalance <= 0.0)
     {
      reason = "invalid balance";
      return false;
     }

   double dailyPnl = balance - m_dayStartBalance;
   double maxLoss  = m_dayStartBalance * (m_maxDailyLossPct / 100.0);
   if(dailyPnl <= -maxLoss)
     {
      reason = "daily loss limit hit";
      return false;
     }

   reason = "ok";
   return true;
  }

double CNeuroxRisk::LotsForStop(const double stopDistance) const
  {
   if(stopDistance <= 0.0)
      return 0.0;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (m_riskPct / 100.0);

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

   double lossPerLot = (stopDistance / tickSize) * tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   return NX_NormalizeLots(riskMoney / lossPerLot);
  }

void CNeuroxRisk::StopTakePrices(const ENUM_NX_SIGNAL direction,
                                 const double entry,
                                 const double stopDist,
                                 const double takeDist,
                                 double &sl,
                                 double &tp) const
  {
   if(direction == NX_SIGNAL_BUY)
     {
      sl = NX_NormalizePrice(entry - stopDist);
      tp = NX_NormalizePrice(entry + takeDist);
     }
   else
     {
      sl = NX_NormalizePrice(entry + stopDist);
      tp = NX_NormalizePrice(entry - takeDist);
     }
  }

#endif
//+------------------------------------------------------------------+
