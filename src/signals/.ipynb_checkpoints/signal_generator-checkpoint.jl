module SignalGenerator

using ..DecisionRules
export crisp_signal

"""
Convert fuzzy rule activations into a single crisp decision.
"""
function crisp_signal(fs::FuzzySignal)

    rules = evaluate_rules(fs)

    # Weighted score
    w = Dict(
        :StrongBuy  =>  +2,
        :Buy        =>  +1,
        :Hold       =>   0,
        :Sell       =>  -1,
        :StrongSell =>  -2
    )

    score = sum(rules[r] * w[r] for r in keys(rules))

    # Map score to discrete signal
    if score ≥ 1.2
        return :StrongBuy
    elseif score ≥ 0.3
        return :Buy
    elseif score ≥ -0.3
        return :Hold
    elseif score ≥ -1.2
        return :Sell
    else
        return :StrongSell
    end
end

end # module
