#ifndef HITMAN_ULTRA_27_LOGGER_MQH
#define HITMAN_ULTRA_27_LOGGER_MQH
//+------------------------------------------------------------------+
//| HITMAN AI — 27_LOGGER — Error · Trade · AI · Execution · System  |
//| ROADMAP P20 — structured decision fields                         |
//+------------------------------------------------------------------+
void UltraLog(const string msg)
{
   if(UltraLoggingEnabled)
      Print("ULTRA| ", msg);
}
void UltraSetError(const string e)
{
   if(!UltraErrorHandlingEnabled) return;
   g_UltraCore.errorCount++;
   g_UltraCore.lastError = e;
   UltraLog("ERR " + e);
}

void UltraLogTrade(const string msg){ UltraLog("TRADE| " + msg); }
void UltraLogAI(const string msg){ UltraLog("AI| " + msg); }
void UltraLogExec(const string msg){ UltraLog("EXEC| " + msg); }
void UltraLogPerf(const string msg){ UltraLog("PERF| " + msg); }

// Structured decision log: entry / exit / replace / hold / wait
void UltraLogDecision(const string action,
                      const ulong ticket,
                      const string side,
                      const string tag,
                      const int conf,
                      const int score,
                      const string thesis,
                      const string newsPhase,
                      const double spread,
                      const double slip,
                      const string why)
{
   string t = "DECISION action=";
   t += action;
   t += " ticket=";
   t += IntegerToString((int)ticket);
   t += " side=";
   t += side;
   t += " tag=";
   t += tag;
   t += " conf=";
   t += IntegerToString(conf);
   t += " score=";
   t += IntegerToString(score);
   t += " thesis=";
   t += thesis;
   t += " news=";
   t += newsPhase;
   t += " spread=";
   t += DoubleToString(spread, 1);
   t += " slip=";
   t += DoubleToString(slip, 1);
   t += " | ";
   t += why;
   UltraLog(t);
}

void UltraLogDecisionFromSnap(const string action, const ulong ticket,
                              const string side, const string tag,
                              const UltraSnap &u, const string why)
{
   UltraLogDecision(action, ticket, side, tag,
                    u.score.confidence, u.score.confluence,
                    (StringLen(u.st.cycleName) > 0 ? u.st.cycleName : "THESIS"),
                    (StringLen(u.ctx.newsPhase) > 0 ? u.ctx.newsPhase : "NONE"),
                    u.ctx.spreadPts, u.ctx.slipProxy, why);
}

#endif // HITMAN_ULTRA_27_LOGGER_MQH
