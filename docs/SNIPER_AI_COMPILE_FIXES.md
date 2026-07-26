# SNIPER AI - MetaEditor compile surface

Canonical download: `SNIPER_AI_OK11.mq5` (`BUILD_ID: SA_COMPILE_OK_11`)

Also mirrored as `SNIPER_AI.mq5` / `release/deliver/SNIPER_AI.mq5`.

Deliberately avoided (common F7 failures):

| Pattern | Why avoided |
|---------|-------------|
| `#property strict` | MQL4-only |
| `input group` | Missing on older builds |
| Negative enum literals | Some compilers reject |
| Manual `SYMBOL_FILLING_*` bit tests | Prefer `SetTypeFillingBySymbol` |
| Hard-coded `TRADE_RETCODE_*` (incl. BUSY) | Not portable; portable retry + `ResultComment` |
| Non-ASCII punctuation in source | Encoding issues in some MetaEditor installs |
| Heavy const-ref class graphs | Triggered prior `const` method errors |

Expect **0 errors** on a current MetaTrader 5 MetaEditor build.
