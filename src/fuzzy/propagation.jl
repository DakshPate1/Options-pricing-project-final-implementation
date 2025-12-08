module FuzzyPropagation

using ..FuzzyNumbers
using ..AlphaCuts
using Distributions
using Statistics

export fuzzy_black_scholes_call, fuzzy_black_scholes_put

# Import Person 1’s pricing functions
import ..BlackScholes: black_scholes_call, black_scholes_put

"""
    interval_bs_call(SI, KI, TI, rI, qI, σI)

Compute the interval [min BS, max BS] over parameter intervals
coming from an α-cut.
"""
function interval_bs_call((Smin, Smax),
                          (Kmin, Kmax),
                          (Tmin, Tmax),
                          (rmin, rmax),
                          (qmin, qmax),
                          (σmin, σmax))

    # Evaluate all 2^6 = 64 corner combinations
    # This ensures true interval bounds without assuming monotonicity
    params = Iterators.product(
        (Smin, Smax),
        (Kmin, Kmax),
        (Tmin, Tmax),
        (rmin, rmax),
        (qmin, qmax),
        (σmin, σmax)
    )

    vals = Float64[]
    for (S,K,T,r,q,σ) in params
        try
            push!(vals, black_scholes_call(S,K,T,r,q,σ))
        catch
            push!(vals, NaN)
        end
    end

    clean = skipmissing(filter(!isnan, vals))
    return (minimum(clean), maximum(clean))
end


"""
    fuzzy_black_scholes_call(Sfz, Kfz, Tfz, rfz, qfz, σfz; α_grid=0:0.1:1)

Propagate fuzzy numbers through Black-Scholes call pricing
using α-cut interval arithmetic.
"""
function fuzzy_black_scholes_call(Sfz, Kfz, Tfz, rfz, qfz, σfz; α_grid=0:0.1:1)
    α_vals = collect(α_grid)
    intervals = Vector{Tuple{Float64,Float64}}()

    for α in α_vals
        SI = alpha_cut(Sfz, α)
        KI = alpha_cut(Kfz, α)
        TI = alpha_cut(Tfz, α)
        rI = alpha_cut(rfz, α)
        qI = alpha_cut(qfz, α)
        σI = alpha_cut(σfz, α)

        push!(intervals, interval_bs_call(SI, KI, TI, rI, qI, σI))
    end

    return (alphas=α_vals, intervals=intervals)
end


"""
    fuzzy_black_scholes_put(...)

Same as call but using BS put.
"""
function fuzzy_black_scholes_put(Sfz, Kfz, Tfz, rfz, qfz, σfz; α_grid=0:0.1:1)
    α_vals = collect(α_grid)
    intervals = Vector{Tuple{Float64,Float64}}()

    for α in α_vals
        SI = alpha_cut(Sfz, α)
        KI = alpha_cut(Kfz, α)
        TI = alpha_cut(Tfz, α)
        rI = alpha_cut(rfz, α)
        qI = alpha_cut(qfz, α)
        σI = alpha_cut(σfz, α)

        # same logic but call BS put
        params = Iterators.product(
            (SI[1], SI[2]),
            (KI[1], KI[2]),
            (TI[1], TI[2]),
            (rfz.a, rfz.b),
            (qfz.a, qfz.b),
            (σfz.a, σfz.b)
        )

        vals = Float64[]
        for (S,K,T,r,q,σ) in params
            try
                push!(vals, black_scholes_put(S,K,T,r,q,σ))
            catch
                push!(vals, NaN)
            end
        end

        clean = skipmissing(filter(!isnan, vals))
        push!(intervals, (minimum(clean), maximum(clean)))
    end

    return (alphas=α_vals, intervals=intervals)
end

end # module
