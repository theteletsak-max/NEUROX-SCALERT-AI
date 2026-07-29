#ifndef SNIPER_ULTRA_35_SIGNAL_MQH
#define SNIPER_ULTRA_35_SIGNAL_MQH
//+------------------------------------------------------------------+
//| 35_SignalEngine — buy/sell generation · score · filter · validate|
//+------------------------------------------------------------------+

struct UltraRawSignal
{
   bool   buy;
   bool   sell;
   int    score;
   string tag;
   string reason;
   bool   valid;
};

UltraRawSignal UltraSignal_Generate(const string s)
{
   UltraRawSignal out;
   out.buy = out.sell = false; out.score = 0; out.tag = "NONE"; out.reason = ""; out.valid = false;

   UltraSnap snap;
   if(!UltraBuildSnapshot(s, snap))
   {
      out.reason = "snapshot fail";
      return out;
   }

   UltraSignal best;
   string why = "";
   if(!UltraAIDecide(s, snap, best, why))
   {
      out.reason = why;
      out.score = snap.score.confidence;
      return out;
   }

   out.buy = best.buy; out.sell = best.sell;
   out.score = best.score; out.tag = best.tag; out.reason = best.reason;
   out.valid = (out.buy || out.sell);
   return out;
}

bool UltraSignal_Filter(const UltraRawSignal &sig, const int minScore)
{
   if(!sig.valid) return false;
   if(!(sig.buy || sig.sell)) return false;
   if(sig.score < minScore) return false;
   return true;
}

bool UltraSignal_Validate(const string s, const UltraRawSignal &sig, string &why)
{
   why = "";
   if(!UltraSignal_Filter(sig, UltraMinConfluence) && sig.score < UltraInstantFireConf)
   { why = "score filter"; return false; }
   if(UltraBlockOppositeSameSym)
   {
      int d = UltraSymDir(s);
      if(sig.buy && d < 0){ why = "opposite sell open"; return false; }
      if(sig.sell && d > 0){ why = "opposite buy open"; return false; }
   }
   return true;
}

#endif
