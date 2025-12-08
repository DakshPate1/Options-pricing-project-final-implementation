using Test
using FuzzyNumbers
using AlphaCuts
using FuzzyPropagation
using BlackScholes

@testset "Fuzzy Number Tests" begin
    fz = TriangularFuzzy(90.0, 100.0, 110.0)

    @test center(fz) ≈ 100.0
    @test support(fz) == (90.0, 110.0)

    L50, R50 = alpha_cut(fz, 0.5)
    @test L50 == 95.0
    @test R50 == 105.0
end

@testset "Fuzzy BS Propagation" begin
    S = TriangularFuzzy(398.0, 400.0, 402.0)
    K = TriangularFuzzy(395.0, 400.0, 405.0)
    T = TriangularFuzzy(55/365, 60/365, 65/365)
    r = TriangularFuzzy(0.03, 0.04, 0.05)
    q = TriangularFuzzy(0.017, 0.018, 0.019)
    σ = TriangularFuzzy(0.18, 0.20, 0.22)

    out = fuzzy_black_scholes_call(S,K,T,r,q,σ)

    @test length(out.alphas) > 1
    @test length(out.intervals) == length(out.alphas)

    # α = 1 gives the crisp BS price
    α1_index = findfirst(==(1.0), out.alphas)
    L1, R1 = out.intervals[α1_index]
    crisp = black_scholes_call(center(S), center(K), center(T), center(r), center(q), center(σ))

    @test abs(L1 - crisp) < 1e-6
    @test abs(R1 - crisp) < 1e-6
end
