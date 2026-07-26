# SNIPER AI V3 — Engineering Audit & Rebuild Notes

`BUILD_ID: SA_INSTITUTIONAL_V3`

## Audit findings (pre-rebuild) and resolutions

| Finding | Resolution |
|---------|------------|
| Rate buffers deep-copied every dashboard tick | Full kill-chain only on new M5; dash throttle updates quotes only |
| ATR buffer recopied every tick | ATR refresh gated on H1 bar stamp |
| Zone engine mixed Disp/FVG/OB | Split into Displacement / FVG / OB engines + compositor |
| FVG scored even when weak | Freshness/mitigation check before full score |
| OB only bar[2] | Search last opposing candle in [2..6] before impulse |
| BE/trail broke after BE (risk≈0) | Recover R from TP / reward ratio |
| `#property strict` / `input group` / neg enums | Removed (MetaEditor portability) |
| Custom filling bitmasks / retcode enums | `SetTypeFillingBySymbol` + portable retry |
| Multiple deliverable filenames | Canonical `SNIPER_AI.mq5` only; OK9/FIXED/v2 copies removed |
| Comment pollution | Exact comment `SNIPER AI` |

## Strategy preserved

H4 bias → H1 structure / liquidity / zones → M5 confirmation  
Continuation + Reversal · max 3 · lot 0.01 · 1.5×ATR · 2R · BE +1R · 24/7 adaptive (no news block)

## Architecture (single .mq5)

Config · Symbol · MarketData · Swing · Structure · Liquidity · Displacement · FVG · OB · Volatility · Entry · Decision · Risk · Money · Position · Execution · Statistics · Dashboard · System Core pipeline
