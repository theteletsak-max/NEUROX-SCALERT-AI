# SNIPER AI - MetaEditor / execution surface

Canonical: `SNIPER_AI_OK13.mq5` (`BUILD_ID: SA_TRADE_READY_13`)

## Hard rules in this build
- No `#include` / no `CTrade`
- Raw `OrderSend` with portable numeric retcodes
- Trade comment locked to exactly `SNIPER AI`
- Dashboard removed (user request)
- ASCII-only source

## Strategy preserved
H4 bias -> H1 structure/liquidity/zones -> M5 confirm
Continuation + Reversal | max 3 | lot 0.01 | 1.5xATR | 2R | BE +1R | 24/7
