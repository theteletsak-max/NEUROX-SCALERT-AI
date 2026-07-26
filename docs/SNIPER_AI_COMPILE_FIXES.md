# SNIPER AI — why some pastes fail MetaEditor

If your local `SniperAI.mq5` still has these lines, MetaEditor can error:

| Pattern | Problem | Fix in `SA_COMPILE_OK_9` |
|---------|---------|--------------------------|
| `#property strict` | MQL4-only; unknown/invalid in MQL5 | Removed |
| `input group "..."` | Not supported on older MT5 builds | Removed (plain `input`s) |
| `SA_BIAS_BEAR = -1` / `SA_SIDE_SELL = -1` | Negative enum literals trip some compilers | Use `= 2` |
| Custom `SYMBOL_FILLING_*` bit checks | Filling-mode constants differ by build | `SetTypeFillingBySymbol` |
| `TRADE_RETCODE_BUSY` / similar | Missing on some builds | Portable retry without those constants |

Canonical file: `release/deliver/SNIPER_AI.mq5` (`BUILD_ID: SA_COMPILE_OK_9`).
