# SNIPER AI - MetaEditor compile surface

Canonical download: `SNIPER_AI_OK12.mq5` (`BUILD_ID: SA_COMPILE_OK_12`)

Also mirrored as `SNIPER_AI.mq5` / `release/deliver/SNIPER_AI.mq5`.

Deliberately avoided:

| Pattern | Why avoided |
|---------|-------------|
| `#include <Trade/Trade.mqh>` / `CTrade` | Eliminated; raw `OrderSend` only |
| `#property strict` | MQL4-only |
| `input group` | Missing on older builds |
| Hard-coded `TRADE_RETCODE_*` (incl. BUSY) | Not portable |
| Non-ASCII punctuation | Encoding issues |
| `SetAsyncMode` / `SetTypeFillingBySymbol` | Avoid optional CTrade APIs |
| `OnTradeTransaction` | Reduced compile surface |

Expect **0 errors** on MetaTrader 5 MetaEditor.
