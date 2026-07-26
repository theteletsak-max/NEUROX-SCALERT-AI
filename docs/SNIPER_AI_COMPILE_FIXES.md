# SNIPER AI - compile / execution surface

Canonical: `SNIPER_AI_OK14.mq5` (`BUILD_ID: SA_TRADE_READY_14`)

Execution:
- Market deal via OrderSend
- Fallback: open without stops, then TRADE_ACTION_SLTP
- Multi filling mode retry (IOC/FOK/RETURN)
- Trade comment locked: `SNIPER AI`
- No chart dashboard
