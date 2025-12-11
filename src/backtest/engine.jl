# src/backtest/engine.jl
"""
Backtest engine for trading strategy based on signals.

Expectations for input:
- `market_df`  : DataFrame with market data. Must contain at least:
    :QUOTE_DATE (Date), :STRIKE, :EXPIRE_DATE (Date), :C_MID (market option mid price),
    :UNDERLYING_LAST (S), :STRIKE, :DTE, optional columns used by signals.
- `signals_df` : DataFrame with signals. Must contain at least:
    :QUOTE_DATE (Date), :STRIKE, :EXPIRE_DATE (Date), :signal (String or Symbol),
    :price (the tradeable price for that contract on that date), :confidence (0-1) optional.

Returns:
  NamedTuple with :trades (Vector{Trade}), :equity_curve (Vector{Float64}), :dates (Vector{Date}), :final_cash (Float64), :open_positions (Dict)
"""
module BacktestEngine

using Dates, Statistics
using DataFrames

export Position, Trade, backtest_strategy, get_current_price, force_close_expired

# ---------------------------
# Structures
# ---------------------------
struct Position
    entry_date::Date
    strike::Float64
    expiry::Date
    entry_price::Float64
    quantity::Int
    option_key::String
    signal_type::String
end

struct Trade
    entry_date::Date
    exit_date::Date
    strike::Float64
    entry_price::Float64
    exit_price::Float64
    quantity::Int
    pnl::Float64
    pnl_pct::Float64
    holding_period::Int
    signal_type::String
end

# ---------------------------
# Helpers
# ---------------------------

"""
Create a deterministic contract key for matching positions/signals.
"""
contract_key(row) = string(row.STRIKE) * "_" * string(row.EXPIRE_DATE)

"""
Get current price for a given position on a given date using market_df.
If price not available, returns last available price <= date; if none, returns NaN.
"""
function get_current_price(market_df::DataFrame, date::Date, pos::Position)
    # Filter market_df for same strike & expiry up to date
    rows = filter(r -> r.STRIKE == pos.strike && r.EXPIRE_DATE == pos.expiry && r.QUOTE_DATE <= date, market_df)
    if nrow(rows) == 0
        return NaN
    end
    # Use most recent quote
    idx = findmax(rows.QUOTE_DATE)[2]  # index of latest
    return rows[idx, :C_MID]
end

"""
Force close expired positions at intrinsic value or last market price.
"""
function force_close_expired!(market_df::DataFrame, positions::Dict{String,Position},
                             trades::Vector{Trade}, date::Date; transaction_cost::Float64=0.0)
    to_remove = String[]
    for (k,pos) in pairs(positions)
        if date >= pos.expiry
            # attempt to get market mid at expiry
            price = get_current_price(market_df, pos.expiry, pos)
            if isnan(price)
                # intrinsic value fallback (assume call positions only here)
                # We don't have option type field; use intrinsic for calls
                # This is conservative: intrinsic = max(S-K,0)
                # Find underlying price on expiry
                Srow = filter(r -> r.QUOTE_DATE == pos.entry_date, market_df)
                S = nrow(Srow) > 0 ? Srow[1, :UNDERLYING_LAST] : NaN
                if isnan(S)
                    price = 0.0
                else
                    price = max(S - pos.strike, 0.0)
                end
            end
            proceeds = pos.quantity * (price - transaction_cost)
            entry_cost = pos.quantity * (pos.entry_price + transaction_cost)
            pnl = proceeds - entry_cost
            push!(trades, Trade(pos.entry_date, pos.expiry, pos.strike, pos.entry_price,
                                price, pos.quantity, pnl, 100 * pnl / (pos.quantity * pos.entry_price),
                                Dates.value(pos.expiry - pos.entry_date), pos.signal_type))
            push!(to_remove, k)
        end
    end
    for k in to_remove
        delete!(positions, k)
    end
end

# ---------------------------
# Main backtest function
# ---------------------------
"""
backtest_strategy(market_df, signals_df; kwargs...)

Parameters:
- initial_capital: starting cash
- position_size: allocation per trade in $ (not number of contracts)
- transaction_cost: cost per contract (dollars)
- max_positions: maximum concurrently open positions
- close_on_expiry: if true, force close at expiry
- allow_partial_fill: if true, allows buying fractional number of contracts (defaults false)
"""
function backtest_strategy(market_df::DataFrame, signals_df::DataFrame;
                           initial_capital::Float64=10000.0,
                           position_size::Float64=1000.0,
                           transaction_cost::Float64=0.50,
                           max_positions::Int=10,
                           close_on_expiry::Bool=true,
                           allow_partial_fill::Bool=false)

    # Prepare
    dates = sort(unique(market_df.QUOTE_DATE))
    positions = Dict{String, Position}()
    trades = Trade[]
    cash = initial_capital
    equity_curve = Float64[]
    equity_dates = Date[]

    # index signals by date for speed
    bydate_signals = groupby(signals_df, :QUOTE_DATE, sort=true)

    for date in dates
        # 1) Force close expired positions at start of day if requested
        if close_on_expiry
            force_close_expired!(market_df, positions, trades, date; transaction_cost=transaction_cost)
        end

        # 2) Process signals for the date (if any)
        if haskey(bydate_signals, date)
            todays = bydate_signals[date]
            for row in eachrow(todays)
                key = string(row.STRIKE) * "_" * string(row.EXPIRE_DATE)
                sig = String(row.signal)
                # determine trade price
                price = hasproperty(row, :price) ? row.price : row.C_MID
                if price === nothing || isnan(price)
                    continue
                end

                if (sig == "Buy" || sig == "StrongBuy")
                    # enter position if capacity and cash allow
                    if length(positions) < max_positions && cash >= 1.0
                        # determine number of contracts
                        ncontracts = floor(Int, position_size / (price + transaction_cost))
                        if ncontracts == 0 && allow_partial_fill
                            # buy 1 contract (small account), or allow fractional policy
                            ncontracts = 1
                        elseif ncontracts == 0
                            continue
                        end
                        cost = ncontracts * (price + transaction_cost)
                        if cost > cash
                            ncontracts = floor(Int, cash / (price + transaction_cost))
                            if ncontracts == 0
                                continue
                            end
                            cost = ncontracts * (price + transaction_cost)
                        end
                        # create position
                        pos = Position(date, row.STRIKE, row.EXPIRE_DATE, price, ncontracts, key, sig)
                        positions[key] = pos
                        cash -= cost
                    end

                elseif (sig == "Sell" || sig == "StrongSell")
                    # close existing position if present
                    if haskey(positions, key)
                        pos = positions[key]
                        # get today's price for exit (use row.price if provided)
                        exit_price = price
                        proceeds = pos.quantity * (exit_price - transaction_cost)
                        entry_cost = pos.quantity * (pos.entry_price + transaction_cost)
                        pnl = proceeds - entry_cost
                        push!(trades, Trade(pos.entry_date, date, pos.strike, pos.entry_price,
                                            exit_price, pos.quantity, pnl, 100 * pnl / (pos.quantity * pos.entry_price),
                                            Dates.value(date - pos.entry_date), pos.signal_type))
                        cash += proceeds
                        delete!(positions, key)
                    end
                end
            end
        end

        # 3) compute portfolio value today: cash + market value of open positions
        open_value = 0.0
        for pos in values(positions)
            price = get_current_price(market_df, date, pos)
            if isnan(price)
                # assume previous known price or zero if missing
                price = pos.entry_price
            end
            open_value += pos.quantity * price
        end
        total_equity = cash + open_value
        push!(equity_curve, total_equity)
        push!(equity_dates, date)
    end

    # Final: close any remaining positions at last available quotes
    final_date = last(dates)
    force_close_expired!(market_df, positions, trades, final_date; transaction_cost=transaction_cost)
    # if still positions exist, attempt to close them at last date
    for (k,pos) in pairs(positions)
        price = get_current_price(market_df, final_date, pos)
        if isnan(price)
            price = pos.entry_price
        end
        proceeds = pos.quantity * (price - transaction_cost)
        entry_cost = pos.quantity * (pos.entry_price + transaction_cost)
        pnl = proceeds - entry_cost
        push!(trades, Trade(pos.entry_date, final_date, pos.strike, pos.entry_price, price, pos.quantity,
                            pnl, 100 * pnl / (pos.quantity * pos.entry_price), Dates.value(final_date - pos.entry_date), pos.signal_type))
    end
    empty!(positions)

    return (trades=trades, equity_curve=equity_curve, dates=equity_dates, final_cash=cash, open_positions=positions)
end

end # module
