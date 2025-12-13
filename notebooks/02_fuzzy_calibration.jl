# -*- coding: utf-8 -*-
# ---
# jupyter:
#   jupytext:
#     formats: jl:percent
#     text_representation:
#       extension: .jl
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.18.1
#   kernelspec:
#     display_name: Julia 1.12
#     language: julia
#     name: julia-1.12
# ---

# %% [markdown]
# This notebook loads the market dataset we are using,  
# calibrates fuzzy inputs (σ, r, q), builds α-cut intervals,  
# and propagates fuzzy inputs through the Black–Scholes engine.

# %%
using JLD2
using DataFrames
using Statistics
using Distributions
using Plots


# %%
@load "../data/spy_ready_for_bs.jld2"

# %%
first(df, 5)
describe(df)


# %%
struct TriangularFuzzy
    low::Float64
    mid::Float64
    high::Float64
end

function alpha_cut(f::TriangularFuzzy, α::Float64)
    left  = f.low  + α*(f.mid - f.low)
    right = f.high - α*(f.high - f.mid)
    return (left, right)
end


# %%
# Volatility calibration
σ_mid = mean(df.C_IV)
σ_spread = std(df.C_IV)
σ_fuzzy = TriangularFuzzy(σ_mid - σ_spread,
                          σ_mid,
                          σ_mid + σ_spread)

# Rate calibration
r_mid = mean(df.r)
r_fuzzy = TriangularFuzzy(r_mid - 0.005,
                          r_mid,
                          r_mid + 0.005)

# Dividend yield (SPY ~ stable)
q_mid = 0.018
q_fuzzy = TriangularFuzzy(q_mid - 0.001,
                          q_mid,
                          q_mid + 0.001)

σ_fuzzy, r_fuzzy, q_fuzzy


# %%
alphas = [0, 0.25, 0.5, 0.75, 1.0]

function fuzzy_table(name, fz)
    rows = DataFrame(alpha=Float64[], low=Float64[], high=Float64[])
    for α in alphas
        l, h = alpha_cut(fz, α)
        push!(rows, (α, l, h))
    end
    rename!(rows, Dict(:low => "$(name)_low", :high => "$(name)_high"))
    return rows
end

display(fuzzy_table("σ", σ_fuzzy))
display(fuzzy_table("r", r_fuzzy))
display(fuzzy_table("q", q_fuzzy))


# %%
include("../src/black_scholes/pricing.jl")
include("../src/black_scholes/greeks.jl")


# %%
function propagate_fuzzy_bs(S, K, T, σ_f::TriangularFuzzy,
                            r_f::TriangularFuzzy, q_f::TriangularFuzzy)

    rows = DataFrame(alpha=Float64[], low=Float64[], high=Float64[])

    for α in alphas
        σl, σh = alpha_cut(σ_f, α)
        rl, rh = alpha_cut(r_f, α)
        ql, qh = alpha_cut(q_f, α)

        prices = Float64[]

        for σ in (σl, σh), r in (rl, rh), q in (ql, qh)
            push!(prices, black_scholes_call(S, K, T, r, q, σ))
        end

        push!(rows, (α, minimum(prices), maximum(prices)))
    end

    return rows
end


# %%
sample = df[1000, :]
fp = propagate_fuzzy_bs(sample.UNDERLYING_LAST,
                        sample.STRIKE,
                        sample.DTE,
                        σ_fuzzy, r_fuzzy, q_fuzzy)

fp


# %%
plot(fp.alpha, fp.low, label="Lower bound", xlabel="α", ylabel="Price",
     title="Fuzzy Price Bands", legend=:bottomright)
plot!(fp.alpha, fp.high, label="Upper bound")
xflip!()  # reverses the α axis

# %%
fp_mid = 0.5 .* (fp.low .+ fp.high)
defuzzified_price = mean(fp_mid)

defuzzified_price


# %%
function fuzzy_row(row)
    fp = propagate_fuzzy_bs(row.UNDERLYING_LAST, row.STRIKE, row.DTE,
                            σ_fuzzy, r_fuzzy, q_fuzzy)
    low = fp.low[1]     # α = 0
    high = fp.high[1]   # α = 0
    mid = mean(0.5 .* (fp.low .+ fp.high))
    return (fuzzy_low=low, fuzzy_high=high, fuzzy_mid=mid)
end

subset = df[1:300, :]  # faster development
fuzzy_results = DataFrame(fuzzy_row.(eachrow(subset)))

first(fuzzy_results, 5)


# %%
