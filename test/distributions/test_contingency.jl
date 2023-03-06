module ContingencyTest

using Test
using ExponentialFamily
using Distributions
using Random

@testset "Contingency" begin
    @testset "common" begin
        @test Contingency <: Distribution
        @test Contingency <: DiscreteDistribution
        @test Contingency <: MultivariateDistribution

        @test value_support(Contingency) === Discrete
        @test variate_form(Contingency) === Multivariate
    end

    @testset "contingency_matrix" begin
        @test ExponentialFamily.contingency_matrix(Contingency(ones(3, 3))) == ones(3, 3) ./ 9
        @test ExponentialFamily.contingency_matrix(Contingency(ones(3, 3), Val(true))) == ones(3, 3) ./ 9
        @test ExponentialFamily.contingency_matrix(Contingency(ones(3, 3), Val(false))) == ones(3, 3) # Matrix is wrong, but just to test that `false` is working
        @test ExponentialFamily.contingency_matrix(Contingency(ones(4, 4))) == ones(4, 4) ./ 16
        @test ExponentialFamily.contingency_matrix(Contingency(ones(4, 4), Val(true))) == ones(4, 4) ./ 16
        @test ExponentialFamily.contingency_matrix(Contingency(ones(4, 4), Val(false))) == ones(4, 4)
    end

    @testset "vague" begin
        @test_throws MethodError vague(Contingency)

        d1 = vague(Contingency, 3)

        @test typeof(d1) <: Contingency
        @test ExponentialFamily.contingency_matrix(d1) ≈ ones(3, 3) ./ 9

        d2 = vague(Contingency, 4)

        @test typeof(d2) <: Contingency
        @test ExponentialFamily.contingency_matrix(d2) ≈ ones(4, 4) ./ 16
    end

    @testset "pdf" begin
        d1 = vague(Contingency, 3)
        d2 = Contingency(ones(3, 3), Val(true))
        d3 = vague(Contingency, 2)
        @test_throws MethodError pdf(d1, 1)
        @test_throws AssertionError pdf(d1, [1,2,3,4])
        @test_throws AssertionError pdf(d1, [1.1 ])
        @test pdf(d1, [1, 2] ) == ExponentialFamily.contingency_matrix(d1)[1,2]
        @test pdf(d1, [true false false ; false true false] ) == pdf(d1, [1,2])
        @test logpdf(d1, [1, 2] )  == log(ExponentialFamily.contingency_matrix(d1)[1,2])
        @test logpdf(d1, [true false false ; false true false]) == logpdf(d1, [1,2])
        @test logpdf(d2, [2 ,3] )  == log(ExponentialFamily.contingency_matrix(d2)[2,3])
        @test mean(d3)             == [3/2, 3/2]

        @test cov(d3)              == [0.25 0; 0 0.25]
        @test var(d3)              == [0.25, 0.25]
    end

    @testset "NaturalParameters" begin
        d1           = vague(Contingency,2)
        d2           = vague(Contingency,2)
        ηcontingency = ContingencyNaturalParameters(log.([0.1 0.7; 0.05 0.15]))
        @test ηcontingency.logcontingency == log.([0.1 0.7; 0.05 0.15])
        @test convert(ContingencyNaturalParameters, log.([0.1 0.7; 0.05 0.15])) == ContingencyNaturalParameters(log.([0.1 0.7; 0.05 0.15]))
        @test d1 == d2
        @test naturalparams(d1)     == ContingencyNaturalParameters(log.([1/4 1/4; 1/4 1/4]))
        @test convert(Contingency, ηcontingency) ≈ Contingency([0.1 0.7; 0.05 0.15])
        @test ηcontingency + ηcontingency == ContingencyNaturalParameters(2log.([0.1 0.7; 0.05 0.15]))
    end

    @testset "entropy" begin
        @test entropy(Contingency([0.7 0.1; 0.1 0.1])) ≈ 0.9404479886553263
        @test entropy(Contingency(10.0 * [0.7 0.1; 0.1 0.1])) ≈ 0.9404479886553263
        @test entropy(Contingency([0.07 0.41; 0.31 0.21])) ≈ 1.242506182893139
        @test entropy(Contingency(10.0 * [0.07 0.41; 0.31 0.21])) ≈ 1.242506182893139
        @test entropy(Contingency([0.09 0.00; 0.00 0.91])) ≈ 0.30253782309749805
        @test entropy(Contingency(10.0 * [0.09 0.00; 0.00 0.91])) ≈ 0.30253782309749805
        @test !isnan(entropy(Contingency([0.0 1.0; 1.0 0.0])))
        @test !isinf(entropy(Contingency([0.0 1.0; 1.0 0.0])))
    end
end

end
