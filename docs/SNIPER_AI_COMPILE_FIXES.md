# SNIPER AI — MetaEditor compile surface

Canonical: `release/deliver/SNIPER_AI.mq5` (`BUILD_ID: SA_INSTITUTIONAL_V3`)

Deliberately avoided (common F7 failures on older pastes):

| Pattern | Why avoided |
|---------|-------------|
| `#property strict` | MQL4-only |
| `input group` | Missing on older builds |
| Negative enum literals | Some compilers reject |
| Manual `SYMBOL_FILLING_*` bit tests | Prefer `SetTypeFillingBySymbol` |
| Hard-coded `TRADE_RETCODE_*` switches | Prefer portable retry |

Expect **0 errors / 0 warnings** on a current MetaTrader 5 MetaEditor build.
