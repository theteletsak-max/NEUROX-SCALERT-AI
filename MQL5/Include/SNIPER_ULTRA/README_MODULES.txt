SNIPER AI ULTRA — Modular layout

Main: SNIPER_AI_OK93.mq5

Include/SNIPER_ULTRA/
  00_Types.mqh           shared types/structs
  10_Inputs.mqh          Ultra inputs
  01_Core.mqh            Ultra Core System
  02_Market.mqh          Market Analysis Engine
  03_AI.mqh              AI Decision Core + EvaluateStrategySignals
  04_Execution.mqh       Execution helpers
  05_Capital.mqh         Capital protection bridge
  06_MultiSymbol.mqh     Multi-symbol engine
  07_MTF.mqh             Multi-timeframe engine
  08_Dashboard.mqh       Dashboard
  09_Diagnostics.mqh     Diagnostics & analytics
  SNIPER_ULTRA.mqh       master include
  Shell_A_InputsGlobals.mqh
  Shell_B_TradeSystem.mqh

Load order (in main):
  Shell_A -> SNIPER_ULTRA.mqh -> Shell_B
