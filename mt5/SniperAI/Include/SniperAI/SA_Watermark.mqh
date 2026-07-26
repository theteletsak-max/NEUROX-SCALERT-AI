//+------------------------------------------------------------------+
//| SA_Watermark.mqh — chart background watermark (candles on top)     |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_WATERMARK_MQH
#define SNIPER_AI_SA_WATERMARK_MQH

#define SA_WM_NAME "SniperAI_WM_Bitmap"
#define SA_WM_TITLE "SniperAI_WM_Title"

class CSniperWatermark
  {
private:
   bool m_enabled;

public:
                     CSniperWatermark(void): m_enabled(true) {}

   bool Create(const bool enabled = true)
     {
      m_enabled = enabled;
      Delete();
      if(!m_enabled)
         return true;

      // Bitmap behind candles — ALGO-NOVA style left watermark
      if(!ObjectCreate(0, SA_WM_NAME, OBJ_BITMAP_LABEL, 0, 0, 0))
        {
         Print("Sniper AI: watermark object create failed");
         return false;
        }

      ObjectSetString(0, SA_WM_NAME, OBJPROP_BMPFILE, "::Images\\SniperAI_Watermark.bmp");
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_XDISTANCE, 8);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_YDISTANCE, 8);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_XSIZE, 420);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_YSIZE, 630);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_BACK, true);      // CRITICAL: behind candles
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, SA_WM_NAME, OBJPROP_ZORDER, 0);

      // Extra bold label (in case BMP font is soft on some builds)
      if(ObjectCreate(0, SA_WM_TITLE, OBJ_LABEL, 0, 0, 0))
        {
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_XDISTANCE, 90);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_YDISTANCE, 28);
         ObjectSetString(0, SA_WM_TITLE, OBJPROP_TEXT, "SNIPER AI");
         ObjectSetString(0, SA_WM_TITLE, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_FONTSIZE, 22);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_BACK, true);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, SA_WM_TITLE, OBJPROP_HIDDEN, true);
        }

      ChartRedraw(0);
      return true;
     }

   void Delete()
     {
      ObjectDelete(0, SA_WM_NAME);
      ObjectDelete(0, SA_WM_TITLE);
     }
  };

#endif
//+------------------------------------------------------------------+
