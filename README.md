Fuzzy Black–Scholes Option Pricing Project
Overview:
The idea is to model option prices in uncertain markets using fuzzy logic, giving traders not one price but a range that reflects real-world ambiguity. 

Project Flow:
Market data is first priced using the Black–Scholes model.
Uncertainty in pricing is then modeled using fuzzy logic.
The fuzzy prices are converted into trading signals using decision rules.
Finally, the signals are tested using a backtesting engine to evaluate performance.

Module:
Black–Scholes Engine
Implements standard Black–Scholes call and put pricing along with option Greeks.
Used as the baseline pricing model and for validation against market data.

Fuzzy Logic Engine:
Represents pricing uncertainty using fuzzy numbers and α-cuts.
Propagates uncertainty through the Black–Scholes model to produce price ranges.

Signal Generation:
Uses fuzzy rule-based logic to convert fuzzy price ranges into trading signals:
StrongBuy, Buy, Hold, Sell, and StrongSell.

Backtesting & Analysis:
Simulates trades using the generated signals.
Calculates performance metrics such as returns, Sharpe ratio, and drawdowns.


Purpose:
The project demonstrates how uncertainty-aware pricing can be combined with interpretable decision rules to build a complete and testable trading framework.
