HITMAN AI v1 BLUEPRINT
PROFESSIONAL MODULAR PROJECT STRUCTURE
════════════════════════════════════════════════════════════════════════

ROOT PROJECT
════════════════════════════════════════════════════════════════════════

SNIPER_AI.mq5
SNIPER_AI_OK93.mq5

Include/
└── HITMAN_ULTRA/
    ├── 00_Types.mqh
    ├── 01_Core.mqh
    ├── 02_Data.mqh
    ├── 03_MarketStructure.mqh
    ├── 04_BOS.mqh
    ├── 05_CHoCH.mqh
    ├── 06_Liquidity.mqh
    ├── 07_Fibonacci.mqh
    ├── 08_Institutional.mqh
    ├── 09_Trend.mqh
    ├── 10_Momentum.mqh
    ├── 11_Volatility.mqh
    ├── 12_MarketRegime.mqh
    ├── 13_Precision.mqh
    ├── 14_Probability.mqh
    ├── 15_Confluence.mqh
    ├── 16_AI_Core.mqh
    ├── 17_SessionIntelligence.mqh
    ├── 18_NewsIntelligence.mqh
    ├── 19_Execution.mqh
    ├── 20_CapitalProtection.mqh
    ├── 21_TradeManagement.mqh
    ├── 22_MultiSymbol.mqh
    ├── 23_MultiTimeframe.mqh
    ├── 24_Dashboard.mqh
    ├── 25_Statistics.mqh
    ├── 26_Diagnostics.mqh
    ├── 27_Logger.mqh
    ├── 28_Utilities.mqh
    ├── 29_MarketMemory.mqh
    ├── 30_Recovery.mqh
    ├── 31_Inputs.mqh
    ├── Shell_A_InputsGlobals.mqh
    ├── Shell_B_TradeSystem.mqh
    └── HITMAN_ULTRA.mqh

Optional (NOT in v1 master): HITMAN_ULTRA_EXT.mqh + modules 32-40

BUILD_ID: HA_ULTRA_93
Comment:  HITMAN AI
MaxOpen:  3

Load order: Shell_A → HITMAN_ULTRA.mqh (00-31) → Shell_B

════════════════════════════════════════════════════════════════════════
MODULE RESPONSIBILITIES
════════════════════════════════════════════════════════════════════════

00_TYPES
• Enumerations · Structures · Constants · Shared Types · Global Definitions

01_CORE
• EA Initialization · EA Shutdown · Module Loader · Configuration Manager
• Global State · System Controller

02_DATA
• Tick / Candle / Historical / Market Data · Symbol / Broker / Spread Info
• Cache Manager

03_MARKET_STRUCTURE
• HH / HL / LH / LL · Swing High / Low · Internal / External / Trend Structure

04_BOS
• Proprietary Break of Structure · Detection · Strength · Quality · Confirmation

05_CHOCH
• Proprietary Change of Character · Internal / External · Major / Minor
• CHoCH Confidence

06_LIQUIDITY
• Proprietary Liquidity Sweep · Buy/Sell-side · Pools · Stop Hunts · Grab
• Sweep Confirmation

07_FIBONACCI
• Proprietary Fibonacci · Swing / Impulse · Retracement / Extension
• Fibonacci Confluence

08_INSTITUTIONAL
• Order Blocks · Breaker Blocks · Mitigation Blocks · Fair Value Gaps
• Institutional Zones

09_TREND
• Adaptive Trend · Direction · Strength · Quality

10_MOMENTUM
• Sniper Momentum Index · Strength · Direction · Acceleration

11_VOLATILITY
• ATR Expansion / Compression · Relative Volatility · Classification

12_MARKET_REGIME
• Trending · Ranging · Compression · Expansion · Accumulation
• Distribution · Reversal

13_PRECISION
• Entry / Exit Precision · Signal Validation · Trade Quality · Precision Score

14_PROBABILITY
• Probability Score · Confidence Score · Success Estimation

15_CONFLUENCE
Combines: Structure · BOS · CHoCH · Liquidity · Fibonacci · Institutional
         · Trend · Momentum · Volatility · Session · News
Produces: AI Confidence Score

16_AI_CORE
• AI Decision Engine · Buy / Sell Decision · Trade Approval / Rejection

17_SESSION_INTELLIGENCE
• Asian · London · New York · Overlap · Session Liquidity
• Context Only · Trades 24/5

18_NEWS_INTELLIGENCE
• Economic Calendar proxy · News / Volatility Analysis
• Context Only · Trades Before / During / After News

19_EXECUTION
• Ultra Fast Execution · Order Validation · Fill / Execution Mode Detection
• Retry Logic · Duplicate Protection

20_CAPITAL_PROTECTION
• Capital Preservation · Equity Protection · Position Sizing
• Exposure Control · Profit Protection

21_TRADE_MANAGEMENT
• Ultra Long Holding · Dynamic SL / TP · Break-even
• Adaptive Trailing Stop · Intelligent Exit
• (deep path in Shell_B ManageOpenTrades)

22_MULTI_SYMBOL
• Symbol Scanner · Synchronization · Independent Symbol Analysis

23_MULTI_TIMEFRAME
Uses: MN · W1 · D1 · H4 · H1 · M30 · M15 · M5 · M1
Features: Higher TF Bias · Lower TF Precision · Timeframe Voting

24_DASHBOARD
• AI Confidence · Precision · Probability · Regime · Trend · Momentum
• Volatility · Session · News · Capital · Open Positions · Statistics

25_STATISTICS
• Win Rate · Profit Factor · Expectancy · Avg R:R
• Symbol / Timeframe Statistics

26_DIAGNOSTICS
• Tick / Memory / Connection / Broker / Health Monitor

27_LOGGER
• Error · Trade · AI · Execution · System Logs

28_UTILITIES
• Math · Time · Price · String · Helper Functions

29_MARKET_MEMORY
• Historical / Symbol / Strategy Analytics · Market Behaviour

30_RECOVERY
• Restart · Connection · VPS · Position Recovery

31_INPUTS
• Trading · Risk · Dashboard · Strategy · Session · News
• Execution · Capital Protection Inputs

════════════════════════════════════════════════════════════════════════
SYSTEM FLOW
════════════════════════════════════════════════════════════════════════

Load System → Load Configuration → Load Market Data → Market Structure →
BOS → CHoCH → Liquidity → Fibonacci → Institutional → Trend → Momentum →
Volatility → Market Regime → Session Intelligence → News Intelligence →
Confluence → Probability → Precision → AI Decision → Capital Protection →
Execution → Trade Management → Dashboard → Statistics → Logger → Recovery
