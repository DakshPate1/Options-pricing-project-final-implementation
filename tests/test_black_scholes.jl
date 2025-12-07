# Unit Tests for Black-Scholes Implementation
# Person 1: Test suite

using Test
include("../src/black_scholes/pricing.jl")
include("../src/black_scholes/greeks.jl")

@testset "Black-Scholes Pricing Tests" begin
    
    @testset "ATM Option Pricing" begin
        S, K, T, r, q, σ = 100.0, 100.0, 1.0, 0.05, 0.02, 0.20
        
        call = black_scholes_call(S, K, T, r, q, σ)
        put = black_scholes_put(S, K, T, r, q, σ)
        
        # Call should be worth more than put for positive r-q
        @test call > put
        
        # Both should be positive
        @test call > 0
        @test put > 0
        
        # Rough sanity check on magnitude
        @test 8.0 < call < 15.0
        @test 5.0 < put < 12.0
        
        println("✓ ATM option pricing: Call=$call, Put=$put")
    end
    
    @testset "Put-Call Parity" begin
        test_cases = [
            (100.0, 100.0, 1.0, 0.05, 0.02, 0.20),  # ATM
            (100.0, 90.0, 0.5, 0.03, 0.01, 0.25),   # ITM call
            (100.0, 110.0, 0.25, 0.04, 0.015, 0.30), # OTM call
        ]
        
        for (S, K, T, r, q, σ) in test_cases
            @test validate_put_call_parity(S, K, T, r, q, σ)
        end
        
        println("✓ Put-call parity holds for all test cases")
    end
    
    @testset "Edge Cases" begin
        S, K, r, q, σ = 100.0, 100.0, 0.05, 0.02, 0.20
        
        # Zero time to expiry
        call_zero = black_scholes_call(105.0, 100.0, 0.0, r, q, σ)
        @test call_zero ≈ 5.0
        
        put_zero = black_scholes_put(95.0, 100.0, 0.0, r, q, σ)
        @test put_zero ≈ 5.0
        
        println("✓ Zero DTE returns intrinsic value")
        
        # Deep ITM call should be worth at least intrinsic
        call_itm = black_scholes_call(150.0, 100.0, 1.0, r, q, σ)
        intrinsic = 150.0 - 100.0
        @test call_itm > intrinsic
        
        println("✓ Deep ITM option > intrinsic value")
        
        # Deep OTM should be near zero
        call_otm = black_scholes_call(100.0, 200.0, 1.0, r, q, σ)
        @test call_otm < 1.0
        
        println("✓ Deep OTM option near zero")
    end
    
    @testset "Error Handling" begin
        # Negative volatility should throw
        @test_throws ArgumentError black_scholes_call(100.0, 100.0, 1.0, 0.05, 0.02, -0.20)
        
        # Negative price should throw
        @test_throws ArgumentError black_scholes_call(-100.0, 100.0, 1.0, 0.05, 0.02, 0.20)
        
        println("✓ Error handling works correctly")
    end
end

@testset "Greeks Tests" begin
    S, K, T, r, q, σ = 100.0, 100.0, 1.0, 0.05, 0.02, 0.20
    
    @testset "Delta" begin
        call_delta = delta(S, K, T, r, q, σ, option_type="call")
        put_delta = delta(S, K, T, r, q, σ, option_type="put")
        
        # ATM call delta should be around 0.5
        @test 0.4 < call_delta < 0.6
        
        # Put delta = Call delta - e^(-qT)
        @test abs(put_delta - (call_delta - exp(-q*T))) < 1e-10
        
        # Call delta should be positive, put negative
        @test call_delta > 0
        @test put_delta < 0
        
        println("✓ Delta: Call=$(round(call_delta, digits=3)), Put=$(round(put_delta, digits=3))")
    end
    
    @testset "Gamma" begin
        γ = gamma(S, K, T, r, q, σ)
        
        # Gamma always positive
        @test γ > 0
        
        # ATM gamma is maximum
        γ_itm = gamma(110.0, 100.0, T, r, q, σ)
        γ_otm = gamma(90.0, 100.0, T, r, q, σ)
        @test γ > γ_itm
        @test γ > γ_otm
        
        println("✓ Gamma: $(round(γ, digits=4))")
    end
    
    @testset "Vega" begin
        v = vega(S, K, T, r, q, σ)
        
        # Vega always positive
        @test v > 0
        
        # Vega should be reasonable magnitude
        @test 10.0 < v < 100.0
        
        println("✓ Vega: $(round(v, digits=2))")
    end
    
    @testset "Theta" begin
        call_theta = theta(S, K, T, r, q, σ, option_type="call")
        put_theta = theta(S, K, T, r, q, σ, option_type="put")
        
        # Theta typically negative (time decay)
        # Can be positive for deep ITM European puts with high rates
        # So we just check reasonable magnitude
        @test abs(call_theta) < 50.0
        @test abs(put_theta) < 50.0
        
        println("✓ Theta: Call=$(round(call_theta, digits=2)), Put=$(round(put_theta, digits=2))")
    end
    
    @testset "Rho" begin
        call_rho = rho(S, K, T, r, q, σ, option_type="call")
        put_rho = rho(S, K, T, r, q, σ, option_type="put")
        
        # Call rho positive, put rho negative
        @test call_rho > 0
        @test put_rho < 0
        
        println("✓ Rho: Call=$(round(call_rho, digits=2)), Put=$(round(put_rho, digits=2))")
    end
    
    @testset "All Greeks" begin
        greeks = all_greeks(S, K, T, r, q, σ, option_type="call")
        
        # Check we get all five
        @test haskey(greeks, :delta)
        @test haskey(greeks, :gamma)
        @test haskey(greeks, :vega)
        @test haskey(greeks, :theta)
        @test haskey(greeks, :rho)
        
        println("✓ All Greeks function returns complete set")
    end
end

println("\n" * "="^60)
println("✅ ALL BLACK-SCHOLES TESTS PASSED!")
println("="^60)