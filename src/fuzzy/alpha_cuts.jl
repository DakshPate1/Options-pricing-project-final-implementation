module AlphaCuts

using ..FuzzyNumbers

export alpha_cut

"""
    alpha_cut(fz, α)

Return the α-cut interval `[Lα, Rα]` of a fuzzy number.

For triangular fuzzy numbers:
    Lα = a + α(m - a)
    Rα = b - α(b - m)

For trapezoidal fuzzy numbers:
    Lα = a + α(m1 - a)
    Rα = b - α(b - m2)
"""
function alpha_cut(t::TriangularFuzzy, α::Float64)
    α < 0 || α > 1 && throw(ArgumentError("α must be in [0,1]"))
    L = t.a + α*(t.m - t.a)
    R = t.b - α*(t.b - t.m)
    return (L, R)
end

function alpha_cut(z::TrapezoidalFuzzy, α::Float64)
    α < 0 || α > 1 && throw(ArgumentError("α must be in [0,1]"))
    L = z.a + α*(z.m1 - z.a)
    R = z.b - α*(z.b - z.m2)
    return (L, R)
end

end # module
