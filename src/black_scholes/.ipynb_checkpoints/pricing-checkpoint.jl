# Black-Scholes Pricing Functions
# Person 1: Core pricing engine

using Distributions

"""
    black_scholes_call(S, K, T, r, q, σ)

Calculate European call option price using Black-Scholes formula.

# Arguments
- `S::Float64`: Current stock price
- `K::Float64`: Strike price
- `T::Float64`: Time to maturity (years)
- `r::Float64`: Risk-free interest rate (decimal)
- `q::Float64`: Dividend yield (decimal)
- `σ::Float64`: Volatility (decimal)

# Returns
- `Float64`: Call option price

# Notes
While SPY options are American-style, we use European formula because:
1. Small dividend yield (1.8%) makes early exercise suboptimal
2. Market IV already reflects any American premium
3. Near-ATM options (our focus) have minimal American premium

# Example
```julia
S, K, T, r, q, σ = 400.0, 400.0, 60/365, 0.05, 0.018, 0.20
call_price = black_scholes_call(S, K, T, r, q, σ)
```
"""
function black_scholes_call(S::Float64, K::Float64, T::Float64, 
                            r::Float64, q::Float64, σ::Float64)
    # Handle edge cases
    if T <= 0.0
        return max(S - K, 0.0)  # Intrinsic value at expiration
    end
    
    if σ <= 0.0
        throw(ArgumentError("Volatility must be positive, got σ=$σ"))
    end
    
    if S <= 0.0 || K <= 0.0
        throw(ArgumentError("Prices must be positive, got S=$S, K=$K"))
    end
    
    # Calculate d1 and d2
    d1 = (log(S/K) + (r - q + 0.5*σ^2)*T) / (σ*sqrt(T))
    d2 = d1 - σ*sqrt(T)
    
    # Calculate call price using Black-Scholes formula
    call_price = S * exp(-q*T) * cdf(Normal(), d1) - 
                 K * exp(-r*T) * cdf(Normal(), d2)
    
    return call_price
end


"""
    black_scholes_put(S, K, T, r, q, σ)

Calculate European put option price using Black-Scholes formula.

# Arguments
Same as black_scholes_call

# Returns
- `Float64`: Put option price
"""
function black_scholes_put(S::Float64, K::Float64, T::Float64, 
                           r::Float64, q::Float64, σ::Float64)
    # Handle edge cases
    if T <= 0.0
        return max(K - S, 0.0)  # Intrinsic value at expiration
    end
    
    if σ <= 0.0
        throw(ArgumentError("Volatility must be positive, got σ=$σ"))
    end
    
    if S <= 0.0 || K <= 0.0
        throw(ArgumentError("Prices must be positive, got S=$S, K=$K"))
    end
    
    # Calculate d1 and d2
    d1 = (log(S/K) + (r - q + 0.5*σ^2)*T) / (σ*sqrt(T))
    d2 = d1 - σ*sqrt(T)
    
    # Calculate put price using Black-Scholes formula
    put_price = K * exp(-r*T) * cdf(Normal(), -d2) - 
                S * exp(-q*T) * cdf(Normal(), -d1)
    
    return put_price
end


"""
    validate_put_call_parity(S, K, T, r, q, σ; tol=1e-10)

Validate Black-Scholes implementation using put-call parity.

Put-Call Parity: C - P = S*e^(-qT) - K*e^(-rT)

# Returns
- `Bool`: true if parity holds within tolerance
"""
function validate_put_call_parity(S::Float64, K::Float64, T::Float64,
                                  r::Float64, q::Float64, σ::Float64;
                                  tol::Float64=1e-10)
    call = black_scholes_call(S, K, T, r, q, σ)
    put = black_scholes_put(S, K, T, r, q, σ)
    
    # Put-Call Parity: C - P = S*e^(-qT) - K*e^(-rT)
    lhs = call - put
    rhs = S * exp(-q*T) - K * exp(-r*T)
    
    error = abs(lhs - rhs)
    
    return error < tol
end