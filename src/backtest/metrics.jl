# src/backtest/metrics.jl
"""
Performance metrics and fuzzy coverage helpers for Person 4 backtest.
"""
module BacktestMetrics

using Statistics
using Dates
export total_pnl, win_rate, average_win, average_loss, sharpe_ratio, sortino_ratio, max_drawdown,
       interval_coverage, calibration_error, calculate_drawdown_series

# ---------------------------
# Basic trade metrics
# ---------------------------
function total_pnl(trades)
    return sum(t.pnl for t in trades)
end

function win_rate(trades)
    if isempty(trades) return 0.0 end
    return 100 * count(t -> t.pnl > 0, trades) / length(trades)
end

function average_win(trades)
    wins = filter(t -> t.pnl > 0, trades)
    return isempty(wins) ? 0.0 : mean(t.pnl for t in wins)
end

function average_loss(trades)
    losses = filter(t -> t.pnl < 0, trades)
    return isempty(losses) ? 0.0 : mean(t.pnl for t in losses)
end

# ---------------------------
# Risk-adjusted metrics
# ---------------------------
"""
sharpe_ratio(equity_curve; risk_free_rate=0.0)

equity_curve: vector of daily portfolio values (Float64)
Returns annualized Sharpe ratio (risk-free rate in decimal)
"""
function sharpe_ratio(equity_curve::Vector{Float64}; risk_free_rate::Float64=0.02)
    if length(equity_curve) < 2 return 0.0 end
    rets = diff(equity_curve) ./ equity_curve[1:end-1]
    mean_ann = mean(rets) * 252
    std_ann = std(rets) * sqrt(252)
    if std_ann == 0.0
        return 0.0
    end
    return (mean_ann - risk_free_rate) / std_ann
end

function sortino_ratio(equity_curve::Vector{Float64}; risk_free_rate::Float64=0.02)
    if length(equity_curve) < 2 return 0.0 end
    rets = diff(equity_curve) ./ equity_curve[1:end-1]
    downside = filter(x -> x < 0, rets)
    if isempty(downside) return Inf end
    downside_std = std(downside) * sqrt(252)
    mean_ann = mean(rets) * 252
    return (mean_ann - risk_free_rate) / downside_std
end

function max_drawdown(equity_curve::Vector{Float64})
    peak = -Inf
    max_dd = 0.0
    for v in equity_curve
        peak = max(peak, v)
        dd = (peak - v) / peak
        max_dd = max(max_dd, dd)
    end
    return 100 * max_dd
end

# drawdown series (for plotting)
function calculate_drawdown_series(equity_curve::Vector{Float64})
    peak = -Inf
    drawdowns = Float64[]
    for v in equity_curve
        peak = max(peak, v)
        push!(drawdowns, 100 * (peak - v) / peak)
    end
    return drawdowns
end

# ---------------------------
# Fuzzy-specific coverage helpers
# ---------------------------

"""
interval_coverage(df, alpha_levels)

df is expected to have columns:
- :market_price
- :fuzzy_lower (Dict or NamedTuple keyed by alpha)
- :fuzzy_upper

If fuzzy bounds are stored as arrays aligned with alpha_levels, adjust code accordingly.
Returns Dict(alpha => coverage_percent)
"""
function interval_coverage(df, alpha_levels)
    coverage = Dict{Float64,Float64}()
    for α in alpha_levels
        inside = 0
        n = 0
        for row in eachrow(df)
            if haskey(row, :market_price) && haskey(row, :fuzzy_lower) && haskey(row, :fuzzy_upper)
                n += 1
                low = row.fuzzy_lower[α]
                high = row.fuzzy_upper[α]
                if low <= row.market_price <= high
                    inside += 1
                end
            end
        end
        coverage[α] = n == 0 ? NaN : 100 * inside / n
    end
    return coverage
end

function calibration_error(coverage::Dict{Float64,Float64})
    errors = Float64[]
    for (α,actual) in coverage
        expected = (1 - α) * 100
        if !isnan(actual)
            push!(errors, abs(actual - expected))
        end
    end
    return isempty(errors) ? NaN : mean(errors)
end

end # module
