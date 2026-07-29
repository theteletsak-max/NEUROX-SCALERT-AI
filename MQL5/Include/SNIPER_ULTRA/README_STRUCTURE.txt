SNIPER AI ULTRA v1 BLUEPRINT

Root:
  SNIPER_AI.mq5
  SNIPER_AI_OK93.mq5

Include/SNIPER_ULTRA/
  00_Types.mqh … 31_Inputs.mqh
  Shell_A_InputsGlobals.mqh
  Shell_B_TradeSystem.mqh
  SNIPER_ULTRA.mqh

Optional extension (not in v1 master):
  32-40 + SNIPER_ULTRA_EXT.mqh

BUILD_ID: SA_ULTRA_93
System flow:
  Load → Config → Data → Structure → BOS → CHoCH → Liquidity → Fib →
  Institutional → Trend → Momentum → Volatility → Regime → Session →
  News → Confluence → Probability → Precision → AI → Capital →
  Execution → Trade Management → Dashboard → Statistics → Logger → Recovery
