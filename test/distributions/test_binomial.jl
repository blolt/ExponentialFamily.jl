module BinomialTest

using Test
using ExponentialFamily
using Distributions
using Random
import StatsFuns: logit
import ExponentialFamily: KnownExponentialFamilyDistribution, getnaturalparameters, basemeasure

@testset "Binomial" begin
    @testset "probvec" begin
        @test all(probvec(Binomial(2, 0.8)) .≈ (0.2, 0.8)) # check
        @test probvec(Binomial(2, 0.2)) == (0.8, 0.2)
        @test probvec(Binomial(2, 0.1)) == (0.9, 0.1)
        @test probvec(Binomial(2)) == (0.5, 0.5)
    end

    @testset "vague" begin
        @test_throws MethodError vague(Binomial)
        @test_throws MethodError vague(Binomial, 1 / 2)

        vague_dist = vague(Binomial, 5)
        @test typeof(vague_dist) <: Binomial
        @test probvec(vague_dist) == (0.5, 0.5)
    end

    @testset "prod" begin
        left = Binomial(10, 0.5)
        right = Binomial(15, 0.3)
        prod_dist = prod(ClosedProd(), left, right)

        sample_points = collect(1:5)
        for x in sample_points
            @test prod_dist.basemeasure(x) == (binomial(10, x) * binomial(15, x))
            @test prod_dist.sufficientstatistics(x) == x
        end

        sample_points = [-5, -2, 0, 2, 5]
        for η in sample_points
            @test prod_dist.logpartition(η) == log(pFq([-10, -15], [1], exp(η)))
        end

        @test prod_dist.naturalparameters == [logit(0.5) + logit(0.3)]
        @test prod_dist.support == support(left)

        sample_points = collect(1:5)
        for x in sample_points
            hist_sum(x) =
                prod_dist.basemeasure(x) * exp(
                    prod_dist.sufficientstatistics(x) * prod_dist.naturalparameters[1] -
                    prod_dist.logpartition(prod_dist.naturalparameters[1])
                )
            @test sum(hist_sum(x) for x in 0:20) ≈ 1.0 atol = 1e-5
        end
    end

    @testset "naturalparameter related Binomial" begin
        d1 = Binomial(5, 1 / 3)
        d2 = Binomial(5, 1 / 2)
        η1 = KnownExponentialFamilyDistribution(Binomial, [logit(1 / 3)], 5)
        η2 = KnownExponentialFamilyDistribution(Binomial, [logit(1 / 2)], 5)

        @test convert(KnownExponentialFamilyDistribution, d1) == η1
        @test convert(KnownExponentialFamilyDistribution, d2) == η2

        @test convert(Distribution, η1) ≈ d1
        @test convert(Distribution, η2) ≈ d2

        η3 = KnownExponentialFamilyDistribution(Binomial, [log(exp(1) - 1)], 5)
        η4 = KnownExponentialFamilyDistribution(Binomial, [log(exp(1) - 1)], 10)

        @test logpartition(η3) ≈ 5.0
        @test logpartition(η4) ≈ 10.0

        @test basemeasure(d1, 5) == 1
        @test basemeasure(d2, 2) == 10
        @test basemeasure(η1, 5) == basemeasure(d1, 5)
        @test basemeasure(η2, 2) == basemeasure(d2, 2)

        @test logpdf(η1, 2) == logpdf(d1, 2)
        @test logpdf(η2, 3) == logpdf(d2, 3)

        @test pdf(η1, 2) == pdf(d1, 2)
        @test pdf(η2, 4) == pdf(d2, 4)
    end
end
end
