SNIPER AI — compile-safe single file
====================================

USE THIS FILE ONLY:
  SNIPER_AI.mq5
  BUILD_ID: SA_COMPILE_OK_9

Install in MetaTrader 5
-----------------------
1. MT5 → File → Open Data Folder → MQL5/Experts/
2. DELETE any old files named:
     SniperAI.mq5, SNIPER_AI.mq5, SNIPER_AI_FIXED.mq5,
     SNIPER_AI_OK9.mq5, SniperAI_v2_SINGLEFILE.mq5
3. Copy THIS SNIPER_AI.mq5 into MQL5/Experts/
4. Open it in MetaEditor → Compile (F7)
5. Attach to a chart → enable Algo Trading

If MetaEditor still shows old errors:
- Confirm the top of the file says BUILD_ID: SA_COMPILE_OK_9
- Fully close MetaEditor/MT5, reopen, compile again
- Do not keep multiple Sniper .mq5 files in Experts/

What was fixed vs older pastes
------------------------------
- Removed #property strict (MQL4-only; breaks MQL5)
- Removed input group (older builds reject it)
- Enums use 0/1/2 (no negative values)
- Filling via SetTypeFillingBySymbol (portable)
- No TRADE_RETCODE_* constants that some builds lack
