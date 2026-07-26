//+------------------------------------------------------------------+
//| SA_Dashboard.mqh — premium right-corner HUD                        |
//+------------------------------------------------------------------+
#property copyright "Sniper AI"
#ifndef SNIPER_AI_SA_DASHBOARD_MQH
#define SNIPER_AI_SA_DASHBOARD_MQH

#include "SA_Util.mqh"
#include "SA_Signal.mqh"

#define SA_UI_PREFIX "SniperAI_UI_"

class CSniperDashboard
  {
private:
   int m_x;
   int m_y;
   int m_w;
   int m_h;

   void Rect(const string id, const int x, const int y, const int w, const int h,
             const color bg, const color border)
     {
      string name = SA_UI_PREFIX + id;
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, border);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
     }

   void Label(const string id, const int x, const int y, const string text,
              const color clr, const int size = 9, const string font = "Consolas")
     {
      string name = SA_UI_PREFIX + id;
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 101);
     }

public:
                     CSniperDashboard(void): m_x(16), m_y(18), m_w(280), m_h(320) {}

   void Create()
     {
      // Panel shell
      Rect("bg", m_x, m_y, m_w, m_h, C'18,18,22', C'180,20,40');
      Rect("hdr", m_x, m_y, m_w, 42, C'140,10,30', C'220,40,60');
      Label("title", m_x + 14, m_y + 10, "SNIPER AI", clrWhite, 14, "Arial Bold");
      Label("sub", m_x + 14, m_y + 46, "24/7  |  INSTANT EXEC", C'220,180,180', 8, "Arial");
     }

   void Update(const string symbol,
               const SASetup &setup,
               const int openTrades,
               const double lot,
               const string lastAction,
               const double balance,
               const double equity)
     {
      Create();

      color sigClr = clrSilver;
      if(setup.signal == SA_SIG_BUY) sigClr = C'40,220,120';
      if(setup.signal == SA_SIG_SELL) sigClr = C'255,70,70';

      // XDISTANCE from right edge (panel padding)
      int x = m_x + 14;
      int y = m_y + 70;

      Label("sym", x, y, "SYMBOL   " + symbol, clrWhite, 10); y += 20;
      Label("bias", x, y, "H4 BIAS  " + SA_BiasText(setup.bias), clrAqua, 10); y += 20;
      Label("sig", x, y, "SIGNAL   " + SA_SigText(setup.signal), sigClr, 11, "Arial Bold"); y += 20;
      Label("path", x, y, "PATH     " + setup.path, clrGold, 10); y += 20;
      Label("score", x, y, StringFormat("SCORE    %d", setup.score), clrOrange, 10); y += 20;
      Label("open", x, y, StringFormat("OPEN     %d / 3", openTrades), clrWhite, 10); y += 20;
      Label("lot", x, y, StringFormat("LOT      %.2f", lot), clrWhite, 10); y += 20;
      Label("bal", x, y, StringFormat("BALANCE  %.2f", balance), C'180,220,255', 9); y += 18;
      Label("eq", x, y, StringFormat("EQUITY   %.2f", equity), C'180,220,255', 9); y += 22;

      Label("mode", x, y, "MODE     EVENTS ON | NO SESSION FILTER", C'160,255,160', 8); y += 18;
      Label("exec", x, y, "EXEC     MARKET INSTANT", C'255,120,120', 8); y += 20;

      string reason = setup.reason;
      if(StringLen(reason) > 42)
         reason = StringSubstr(reason, 0, 42) + "...";
      Label("why", x, y, "STATUS", clrSilver, 8); y += 14;
      Label("why2", x, y, reason, clrSilver, 8); y += 20;
      Label("last", x, y, "LAST     " + lastAction, clrGray, 8);

      ChartRedraw(0);
     }

   void Delete()
     {
      int total = ObjectsTotal(0, 0, -1);
      for(int i = total - 1; i >= 0; --i)
        {
         string name = ObjectName(0, i, 0, -1);
         if(StringFind(name, SA_UI_PREFIX) == 0)
            ObjectDelete(0, name);
        }
     }
  };

#endif
//+------------------------------------------------------------------+
