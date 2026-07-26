SNIPER AI — EXEC FIX V4
=======================
File: SNIPER_AI.mq5
BUILD_ID: SA_EXEC_FIX_V4

Why trades were not firing (V3 bug)
-----------------------------------
Entry required BOS + displacement + FVG/OB on the SAME H1 bar.
Real sniper entries happen on the PULLBACK after displacement.
V4 persists structure/zones across the lookback window.

Install
-------
1. Delete old Sniper EA files from MQL5/Experts/
2. Copy SNIPER_AI.mq5 (header must say SA_EXEC_FIX_V4)
3. MetaEditor F7
4. Attach chart → enable Algo Trading
