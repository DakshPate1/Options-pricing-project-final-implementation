using Test
using DecisionRules
using SignalGenerator

@testset "Fuzzy Rule Evaluation" begin

    fs = FuzzySignal(90, 100, 110)

    rules = evaluate_rules(fs)

    @test rules[:StrongBuy] ≥ 0
    @test rules[:Hold] ≥ 0
    @test rules[:StrongSell] ≥ 0
    @test sum(values(rules)) ≤ 3.0    
end


@testset "Crisp Signal Generation" begin

    # undervalued
    fs_buy = FuzzySignal(80, 100, 105)
    @test crisp_signal(fs_buy) in [:Buy, :StrongBuy]

    # overvalued
    fs_sell = FuzzySignal(95, 100, 130)
    @test crisp_signal(fs_sell) in [:Sell, :StrongSell]

    # neutral
    fs_hold = FuzzySignal(98, 100, 102)
    @test crisp_signal(fs_hold) == :Hold

end
