//+------------------------------------------------------------------+
//| NX_Signals.mqh                                                    |
//| EMA cross + RSI filter signal engine                              |
//+------------------------------------------------------------------+
#property copyright "NEUROX"
#property strict

#ifndef NEUROX_NX_SIGNALS_MQH
#define NEUROX_NX_SIGNALS_MQH

#include "NX_Config.mqh"

struct NXSignal
  {
   ENUM_NX_SIGNAL direction;
   double         stopDistance;
   double         takeDistance;
   string         reason;
  };

class CNeuroxSignals
  {
private:
   double m_rsiBuyMax;
   double m_rsiSellMin;
   double m_stopAtrMult;
   double m_takeAtrMult;
   double m_minAtrPips;

public:
                     CNeuroxSignals(void);
   void              Configure(const double rsiBuyMax,
                               const double rsiSellMin,
                               const double stopAtrMult,
                               const double takeAtrMult,
                               const double minAtrPips);
   NXSignal          Evaluate(const double &emaFast[],
                              const double &emaSlow[],
                              const double &rsi[],
                              const double &atr[]);
  };

CNeuroxSignals::CNeuroxSignals(void)
   : m_rsiBuyMax(65.0),
     m_rsiSellMin(35.0),
     m_stopAtrMult(1.2),
     m_takeAtrMult(1.8),
     m_minAtrPips(2.0)
  {
  }

void CNeuroxSignals::Configure(const double rsiBuyMax,
                               const double rsiSellMin,
                               const double stopAtrMult,
                               const double takeAtrMult,
                               const double minAtrPips)
  {
   m_rsiBuyMax   = rsiBuyMax;
   m_rsiSellMin  = rsiSellMin;
   m_stopAtrMult = stopAtrMult;
   m_takeAtrMult = takeAtrMult;
   m_minAtrPips  = minAtrPips;
  }

NXSignal CNeuroxSignals::Evaluate(const double &emaFast[],
                                  const double &emaSlow[],
                                  const double &rsi[],
                                  const double &atr[])
  {
   NXSignal signal;
   signal.direction    = NX_SIGNAL_NONE;
   signal.stopDistance = 0.0;
   signal.takeDistance = 0.0;
   signal.reason       = "no setup";

   // Use closed bar [1] vs previous closed bar [2] to avoid repaint
   double atr1 = atr[1];
   double pip  = NX_PipSize();
   if(pip <= 0.0 || atr1 <= 0.0)
     {
      signal.reason = "invalid ATR";
      return signal;
     }

   double atrPips = atr1 / pip;
   if(atrPips < m_minAtrPips)
     {
      signal.reason = "ATR too low";
      return signal;
     }

   bool crossUp = (emaFast[2] <= emaSlow[2] && emaFast[1] > emaSlow[1]);
   bool crossDn = (emaFast[2] >= emaSlow[2] && emaFast[1] < emaSlow[1]);

   signal.stopDistance = atr1 * m_stopAtrMult;
   signal.takeDistance = atr1 * m_takeAtrMult;

   if(crossUp && rsi[1] <= m_rsiBuyMax)
     {
      signal.direction = NX_SIGNAL_BUY;
      signal.reason    = "EMA cross up + RSI filter";
      return signal;
     }

   if(crossDn && rsi[1] >= m_rsiSellMin)
     {
      signal.direction = NX_SIGNAL_SELL;
      signal.reason    = "EMA cross down + RSI filter";
      return signal;
     }

   return signal;
  }

#endif
//+------------------------------------------------------------------+
