# SNIPER AI - BabFX PRISM build

Canonical: `SNIPER_AI_OK15.mq5` (`BUILD_ID: SA_BABFX_TRADE_15`)

Source: user's BabFX Sniper AI / PRISM engine.

Portability edits:
- Removed `#property strict` (MQL4-only)
- Removed `#resource` watermark BMP dependency
- `TradeComment` default/lock: `SNIPER AI`
- Dashboard default off
- Kept `CTrade` execution (ConfigureFillingMode + invalid-stops open-then-attach)
