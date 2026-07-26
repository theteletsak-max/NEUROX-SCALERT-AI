//+------------------------------------------------------------------+
//| NX_Indicators.mqh                                                 |
//| Indicator handle management for EMA / RSI / ATR                   |
//+------------------------------------------------------------------+
#property copyright "NEUROX"
#property strict

#ifndef NEUROX_NX_INDICATORS_MQH
#define NEUROX_NX_INDICATORS_MQH

class CNeuroxIndicators
  {
private:
   int m_emaFastHandle;
   int m_emaSlowHandle;
   int m_rsiHandle;
   int m_atrHandle;
   int m_fastPeriod;
   int m_slowPeriod;
   int m_rsiPeriod;
   int m_atrPeriod;

public:
                     CNeuroxIndicators(void);
                    ~CNeuroxIndicators(void);

   bool              Init(const int fastEma,
                          const int slowEma,
                          const int rsiPeriod,
                          const int atrPeriod);
   void              Release(void);

   bool              Ready(void) const;
   bool              CopyBuffers(double &emaFast[],
                                 double &emaSlow[],
                                 double &rsi[],
                                 double &atr[],
                                 const int bars = 3);
  };

CNeuroxIndicators::CNeuroxIndicators(void)
   : m_emaFastHandle(INVALID_HANDLE),
     m_emaSlowHandle(INVALID_HANDLE),
     m_rsiHandle(INVALID_HANDLE),
     m_atrHandle(INVALID_HANDLE),
     m_fastPeriod(9),
     m_slowPeriod(21),
     m_rsiPeriod(14),
     m_atrPeriod(14)
  {
  }

CNeuroxIndicators::~CNeuroxIndicators(void)
  {
   Release();
  }

bool CNeuroxIndicators::Init(const int fastEma,
                             const int slowEma,
                             const int rsiPeriod,
                             const int atrPeriod)
  {
   Release();
   m_fastPeriod = fastEma;
   m_slowPeriod = slowEma;
   m_rsiPeriod  = rsiPeriod;
   m_atrPeriod  = atrPeriod;

   m_emaFastHandle = iMA(_Symbol, PERIOD_CURRENT, m_fastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_emaSlowHandle = iMA(_Symbol, PERIOD_CURRENT, m_slowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_rsiHandle     = iRSI(_Symbol, PERIOD_CURRENT, m_rsiPeriod, PRICE_CLOSE);
   m_atrHandle     = iATR(_Symbol, PERIOD_CURRENT, m_atrPeriod);

   return Ready();
  }

void CNeuroxIndicators::Release(void)
  {
   if(m_emaFastHandle != INVALID_HANDLE)
      IndicatorRelease(m_emaFastHandle);
   if(m_emaSlowHandle != INVALID_HANDLE)
      IndicatorRelease(m_emaSlowHandle);
   if(m_rsiHandle != INVALID_HANDLE)
      IndicatorRelease(m_rsiHandle);
   if(m_atrHandle != INVALID_HANDLE)
      IndicatorRelease(m_atrHandle);

   m_emaFastHandle = INVALID_HANDLE;
   m_emaSlowHandle = INVALID_HANDLE;
   m_rsiHandle     = INVALID_HANDLE;
   m_atrHandle     = INVALID_HANDLE;
  }

bool CNeuroxIndicators::Ready(void) const
  {
   return (m_emaFastHandle != INVALID_HANDLE &&
           m_emaSlowHandle != INVALID_HANDLE &&
           m_rsiHandle     != INVALID_HANDLE &&
           m_atrHandle     != INVALID_HANDLE);
  }

bool CNeuroxIndicators::CopyBuffers(double &emaFast[],
                                    double &emaSlow[],
                                    double &rsi[],
                                    double &atr[],
                                    const int bars)
  {
   if(!Ready())
      return false;

   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(m_emaFastHandle, 0, 0, bars, emaFast) < bars)
      return false;
   if(CopyBuffer(m_emaSlowHandle, 0, 0, bars, emaSlow) < bars)
      return false;
   if(CopyBuffer(m_rsiHandle, 0, 0, bars, rsi) < bars)
      return false;
   if(CopyBuffer(m_atrHandle, 0, 0, bars, atr) < bars)
      return false;

   return true;
  }

#endif
//+------------------------------------------------------------------+
