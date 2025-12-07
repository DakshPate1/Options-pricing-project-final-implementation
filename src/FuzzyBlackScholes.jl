module FuzzyBlackScholes

# Core Black-Scholes
include("black_scholes/bs_pricing.jl")
include("black_scholes/implied_vol.jl")
include("black_scholes/greeks.jl")

# Fuzzy logic
include("fuzzy/fuzzy_numbers.jl")
include("fuzzy/alpha_cuts.jl")
include("fuzzy/propagation.jl")

# Decision layer
include("signals/decision_rules.jl")
include("signals/signal_generation.jl")

# Backtesting
include("backtest/backtest_engine.jl")
include("backtest/performance.jl")

# Exports
export black_scholes_call, black_scholes_put
export implied_volatility
export delta, gamma, vega, theta, rho
export TriangularFuzzy, TrapezoidalFuzzy
export alpha_cut, propagate_fuzzy_bs
export generate_signal, backtest

end # module
