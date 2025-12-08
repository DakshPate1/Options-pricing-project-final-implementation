module FuzzyNumbers

export TriangularFuzzy, TrapezoidalFuzzy, center, support, spread

"""
    TriangularFuzzy(a, m, b)

Represents a **triangular fuzzy number** with:
- left endpoint `a`
- mode `m`
- right endpoint `b`

Assumes `a ≤ m ≤ b`.
"""
struct TriangularFuzzy
    a::Float64
    m::Float64
    b::Float64
    function TriangularFuzzy(a, m, b)
        a <= m <= b || throw(ArgumentError("Require a ≤ m ≤ b"))
        new(a, m, b)
    end
end

"""
    TrapezoidalFuzzy(a, m1, m2, b)

Represents a **trapezoidal fuzzy number**.
"""
struct TrapezoidalFuzzy
    a::Float64
    m1::Float64
    m2::Float64
    b::Float64
    function TrapezoidalFuzzy(a, m1, m2, b)
        a ≤ m1 ≤ m2 ≤ b || throw(ArgumentError("Require a ≤ m1 ≤ m2 ≤ b"))
        new(a, m1, m2, b)
    end
end

# ---------- Core Fuzzy Utilities ---------- #

"Return midpoint/centroid approximation (fast defuzzification)."
center(t::TriangularFuzzy) = (t.a + t.m + t.b) / 3

center(z::TrapezoidalFuzzy) = (z.m1 + z.m2) / 2

"Return support as a closed interval."
support(t::TriangularFuzzy) = (t.a, t.b)
support(z::TrapezoidalFuzzy) = (z.a, z.b)

"Return symmetric spread measure (for calibration)."
spread(t::TriangularFuzzy) = (t.b - t.a) / 2
spread(z::TrapezoidalFuzzy) = (z.b - z.a) / 2

end  # module
