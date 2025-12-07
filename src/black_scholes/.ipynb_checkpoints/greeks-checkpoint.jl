# Black-Scholes Greeks
# Person 1: Sensitivity measures

using Distributions

"""
    delta(S, K, T, r, q, σ; option_type="call")

Calculate option delta (∂V/∂S).

Delta measures the rate of change of option price with respect to 
changes in the underlying asset price.

# Arguments
- `option_type::String`: "call" or "put"

# Returns
- `Float64`: Delta value
  - Call delta: 0 to 1
  - Put delta: -1 to 0
"""
function delta(S::Float64, K::Float64, T::Float64, r::Float64, 
               q::Float64, σ::Float64; option_type::String="call")
    if T <= 0.0
        if option_type == "call"
            return S >= K ? 1.0 : 0.0
        else
            return S <= K ? -1.0 : 0.0
        end
    end
    
    d1 = (log(S/K) + (r - q + 0.5*σ^2)*T) / (σ*sqrt(T))
    
    if option_type == "call"
        return exp(-q*T) * cdf(Normal(), d1)
    else
        return -exp(-q*T) * cdf(Normal(), -d1)
    end
end


"""
    gamma(S, K, T, r, q, σ)

Calculate option gamma (∂²V/∂S²).

Gamma measures the rate of change of delta with respect to changes 
in the underlying asset price. Same for calls and puts.

# Returns
- `Float64`: Gamma value (always positive)
"""
function gamma(S::Float64, K::Float64, T::Float64, r::Float64, 
               q::Float64, σ::Float64)
    if T <= 0.0
        return 0.0
    end
    
    d1 = (log(S/K) + (r - q + 0.5*σ^2)*T) / (σ*sqrt(T))
    
    return exp(-q*T) * pdf(Normal(), d1) / (S * σ * sqrt(T))
end


"""
    vega(S, K, T, r, q, σ)

Calculate option vega (∂V/∂σ).

Vega measures sensitivity to volatility. Same for calls and puts.
Note: Vega is per 1.0 change in volatility (not per 1% or per 0.01).

# Returns
- `Float64`: Vega value (always positive)
"""
function vega(S::Float64, K::Float64, T::Float64, r::Float64, 
              q::Float64, σ::Float64)
    if T <= 0.0
        return 0.0
    end
    
    d1 = (log(S/K) + (r - q + 0.5*σ^2)*T) / (σ*sqrt(T))
    
    return S * exp(-q*T) * pdf(Normal(), d1) * sqrt(T)
end


"""
    theta(S, K, T, r, q, σ; option_type="call")

Calculate option theta (-∂V/∂T).

Theta measures time decay - the rate of change in option value 
with respect to passage of time. Typically negative (options 
lose value as expiration approaches).

# Returns
- `Float64`: Theta value (per year)
"""
function theta(S::Float64, K::Float64, T::Float64, r::Float64, 
               q::Float64, σ::Float64; option_type::String="call")
    if T <= 0.0
        return 0.0
    end
    
    d1 = (log(S/K) + (r - q + 0.5*σ^2)*T) / (σ*sqrt(T))
    d2 = d1 - σ*sqrt(T)
    
    term1 = -(S * exp(-q*T) * pdf(Normal(), d1) * σ) / (2 * sqrt(T))
    
    if option_type == "call"
        term2 = q * S * exp(-q*T) * cdf(Normal(), d1)
        term3 = -r * K * exp(-r*T) * cdf(Normal(), d2)
        return term1 - term2 + term3
    else
        term2 = q * S * exp(-q*T) * cdf(Normal(), -d1)
        term3 = r * K * exp(-r*T) * cdf(Normal(), -d2)
        return term1 + term2 - term3
    end
end


"""
    rho(S, K, T, r, q, σ; option_type="call")

Calculate option rho (∂V/∂r).

Rho measures sensitivity to interest rate changes.

# Returns
- `Float64`: Rho value
  - Call rho: positive (higher rates increase call value)
  - Put rho: negative (higher rates decrease put value)
"""
function rho(S::Float64, K::Float64, T::Float64, r::Float64, 
             q::Float64, σ::Float64; option_type::String="call")
    if T <= 0.0
        return 0.0
    end
    
    d1 = (log(S/K) + (r - q + 0.5*σ^2)*T) / (σ*sqrt(T))
    d2 = d1 - σ*sqrt(T)
    
    if option_type == "call"
        return K * T * exp(-r*T) * cdf(Normal(), d2)
    else
        return -K * T * exp(-r*T) * cdf(Normal(), -d2)
    end
end


"""
    all_greeks(S, K, T, r, q, σ; option_type="call")

Calculate all Greeks at once for efficiency.

# Returns
- `NamedTuple`: (delta, gamma, vega, theta, rho)
"""
function all_greeks(S::Float64, K::Float64, T::Float64, r::Float64,
                    q::Float64, σ::Float64; option_type::String="call")
    return (
        delta = delta(S, K, T, r, q, σ, option_type=option_type),
        gamma = gamma(S, K, T, r, q, σ),
        vega = vega(S, K, T, r, q, σ),
        theta = theta(S, K, T, r, q, σ, option_type=option_type),
        rho = rho(S, K, T, r, q, σ, option_type=option_type)
    )
end