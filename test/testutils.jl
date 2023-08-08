using ExponentialFamily, Distributions
using Test, ForwardDiff, Random, StatsFuns, StableRNGs

import ExponentialFamily:
    ExponentialFamilyDistribution, getnaturalparameters, getconditioner, compute_logscale, logpartition, basemeasure, insupport,
    sufficientstatistics, fisherinformation, pack_parameters, unpack_parameters, isbasemeasureconstant,
    ConstantBaseMeasure, MeanToNatural, NaturalToMean, NaturalParametersSpace, default_prod_rule

function test_exponentialfamily_interface(distribution;
    test_parameters_conversion = true,
    test_similar_creation = true,
    test_distribution_conversion = true,
    test_packing_unpacking = true,
    test_isproper = true,
    test_basic_functions = true,
    test_fisherinformation_against_hessian = true,
    test_fisherinformation_against_jacobian = true
)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    @test ef isa ExponentialFamilyDistribution{T}

    test_parameters_conversion && run_test_parameters_conversion(distribution)
    test_similar_creation && run_test_similar_creation(distribution)
    test_distribution_conversion && run_test_distribution_conversion(distribution)
    test_packing_unpacking && run_test_packing_unpacking(distribution)
    test_isproper && run_test_isproper(distribution)
    test_basic_functions && run_test_basic_functions(distribution)
    test_fisherinformation_against_hessian && run_test_fisherinformation_against_hessian(distribution)
    test_fisherinformation_against_jacobian && run_test_fisherinformation_against_jacobian(distribution)

    return ef
end

function run_test_parameters_conversion(distribution)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    tuple_of_θ, conditioner = ExponentialFamily.separate_conditioner(T, params(distribution))

    @test all(ExponentialFamily.join_conditioner(T, tuple_of_θ, conditioner) .== params(distribution))

    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    @test conditioner === getconditioner(ef)

    # Check the `conditioned` conversions, should work for un-conditioned members as well
    tuple_of_η = MeanToNatural(T)(tuple_of_θ, conditioner)
    @test all(NaturalToMean(T)(tuple_of_η, conditioner) .≈ tuple_of_θ)
    @test all(MeanToNatural(T)(tuple_of_θ, conditioner) .≈ tuple_of_η)
    @test all(NaturalToMean(T)(pack_parameters(T, tuple_of_η), conditioner) .≈ pack_parameters(T, tuple_of_θ))
    @test all(MeanToNatural(T)(pack_parameters(T, tuple_of_θ), conditioner) .≈ pack_parameters(T, tuple_of_η))

    # Double check the `conditioner` free conversions
    if isnothing(conditioner)
        local _tuple_of_η = MeanToNatural(T)(tuple_of_θ)

        @test all(_tuple_of_η .== tuple_of_η)
        @test all(NaturalToMean(T)(_tuple_of_η) .≈ tuple_of_θ)
        @test all(NaturalToMean(T)(_tuple_of_η) .≈ tuple_of_θ)
        @test all(MeanToNatural(T)(tuple_of_θ) .≈ _tuple_of_η)
        @test all(NaturalToMean(T)(pack_parameters(T, _tuple_of_η)) .≈ pack_parameters(T, tuple_of_θ))
        @test all(MeanToNatural(T)(pack_parameters(T, tuple_of_θ)) .≈ pack_parameters(T, _tuple_of_η))
    end

    @test all(unpack_parameters(T, pack_parameters(T, tuple_of_η)) .== tuple_of_η)
    @test all(unpack_parameters(T, pack_parameters(T, tuple_of_θ)) .== tuple_of_θ)
end

function run_test_similar_creation(distribution)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    @test similar(ef) isa ExponentialFamilyDistribution{T}
end

function run_test_distribution_conversion(distribution)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    @test @inferred(convert(Distribution, ef)) ≈ distribution
    @test @allocated(convert(Distribution, ef)) === 0
end

function run_test_packing_unpacking(distribution)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    tuple_of_θ, conditioner = ExponentialFamily.separate_conditioner(T, params(distribution))
    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    tuple_of_η = MeanToNatural(T)(tuple_of_θ, conditioner)

    @test all(unpack_parameters(ef) .≈ tuple_of_η)
    @test @allocated(unpack_parameters(ef)) === 0
end

function run_test_isproper(distribution)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    exponential_family_form = @inferred(convert(ExponentialFamilyDistribution, distribution))

    @test @inferred(isproper(exponential_family_form))
    @test @allocated(isproper(exponential_family_form)) === 0
end

function run_test_basic_functions(distribution; nsamples = 10, assume_no_allocations = true)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    (η, conditioner) = (getnaturalparameters(ef), getconditioner(ef))

    # ! do not use `rand(distribution, nsamples)`
    # ! do not use fixed RNG
    samples = [rand(distribution) for _ in 1:nsamples]

    for x in samples
        # We believe in the implementation in the `Distributions.jl`
        @test @inferred(logpdf(ef, x)) ≈ logpdf(distribution, x)
        @test @inferred(pdf(ef, x)) ≈ pdf(distribution, x)
        @test @inferred(mean(ef)) ≈ mean(distribution)
        @test @inferred(var(ef)) ≈ var(distribution)
        @test @inferred(std(ef)) ≈ std(distribution)
        @test rand(StableRNG(42), ef) ≈ rand(StableRNG(42), distribution)
        @test all(rand(StableRNG(42), ef, 10) .≈ rand(StableRNG(42), distribution, 10))
        @test all(rand!(StableRNG(42), ef, zeros(10)) .≈ rand!(StableRNG(42), distribution, zeros(10)))

        @test @inferred(isbasemeasureconstant(ef)) === isbasemeasureconstant(T)
        @test @inferred(basemeasure(ef, x)) == getbasemeasure(T, conditioner)(x)
        @test all(@inferred(sufficientstatistics(ef, x)) .== map(f -> f(x), getsufficientstatistics(T, conditioner)))
        @test @inferred(logpartition(ef)) == getlogpartition(T, conditioner)(η)
        @test @inferred(fisherinformation(ef)) == getfisherinformation(T, conditioner)(η)

        # Double check the `conditioner` free methods
        if isnothing(conditioner)
            @test @inferred(basemeasure(ef, x)) == getbasemeasure(T)(x)
            @test all(@inferred(sufficientstatistics(ef, x)) .== map(f -> f(x), getsufficientstatistics(T)))
            @test @inferred(logpartition(ef)) == getlogpartition(T)(η)
            @test @inferred(fisherinformation(ef)) == getfisherinformation(T)(η)
        end

        # Test that the selected methods do not allocate
        if assume_no_allocations
            @test @allocated(logpdf(ef, x)) === 0
            @test @allocated(pdf(ef, x)) === 0
            @test @allocated(mean(ef)) === 0
            @test @allocated(var(ef)) === 0
            @test @allocated(basemeasure(ef, x)) === 0
            @test @allocated(sufficientstatistics(ef, x)) === 0
        end
    end
end

function run_test_fisherinformation_against_hessian(distribution; assume_ours_faster = true, assume_no_allocations = true)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    (η, conditioner) = (getnaturalparameters(ef), getconditioner(ef))

    @test fisherinformation(ef) ≈ ForwardDiff.hessian(η -> getlogpartition(NaturalParametersSpace(), T, conditioner)(η), η)

    # Double check the `conditioner` free methods
    if isnothing(conditioner)
        @test fisherinformation(ef) ≈ ForwardDiff.hessian(η -> getlogpartition(NaturalParametersSpace(), T)(η), η)
    end

    if assume_ours_faster
        @test @elapsed(fisherinformation(ef)) < (@elapsed(ForwardDiff.hessian(η -> getlogpartition(NaturalParametersSpace(), T, conditioner)(η), η)))
    end

    if assume_no_allocations
        @test @allocated(fisherinformation(ef)) === 0
    end
end

function run_test_fisherinformation_against_jacobian(distribution; assume_no_allocations = true)
    T = ExponentialFamily.distribution_typewrapper(distribution)

    ef = @inferred(convert(ExponentialFamilyDistribution, distribution))

    (η, conditioner) = (getnaturalparameters(ef), getconditioner(ef))

    m = NaturalToMean(T)(η, conditioner)
    J = ForwardDiff.jacobian(Base.Fix2(NaturalToMean(T), conditioner), η)
    Fₘ = getfisherinformation(MeanParametersSpace(), T, conditioner)(m)

    @test fisherinformation(ef) ≈ (J * Fₘ * J')

    # Double check the `conditioner` free methods
    if isnothing(conditioner)
        m = NaturalToMean(T)(η)
        J = ForwardDiff.jacobian(NaturalToMean(T), η)
        Fₘ = getfisherinformation(MeanParametersSpace(), T)(m)

        @test fisherinformation(ef) ≈ (J * Fₘ * J')
    end

    if assume_no_allocations
        @test @allocated(getfisherinformation(MeanParametersSpace(), T, conditioner)(m)) === 0
    end
end

# This generic testing works only for the same distributions `D`
function test_generic_simple_exponentialfamily_product(
    left::D,
    right::D;
    strategies = (GenericProd(),),
    test_inplace_version = true,
    test_inplace_assume_zero_allocations = true,
    test_preserve_type_prod_of_distribution = true
) where {D}
    Tl = ExponentialFamily.distribution_typewrapper(left)
    Tr = ExponentialFamily.distribution_typewrapper(right)

    @test Tl === Tr

    T = Tl

    efleft = @inferred(convert(ExponentialFamilyDistribution, left))
    efright = @inferred(convert(ExponentialFamilyDistribution, right))
    ηleft = @inferred(getnaturalparameters(efleft))
    ηright = @inferred(getnaturalparameters(efright))

    if (!isnothing(getconditioner(efleft)) || !isnothing(getconditioner(efright)))
        @test isapprox(getconditioner(efleft), getconditioner(efright))
    end

    for strategy in strategies
        @test @inferred(prod(strategy, efleft, efright)) == ExponentialFamilyDistribution(T, ηleft + ηright, getconditioner(efleft))

        # Double check the `conditioner` free methods
        if isnothing(getconditioner(efleft)) && isnothing(getconditioner(efright))
            @test @inferred(prod(strategy, efleft, efright)) == ExponentialFamilyDistribution(T, ηleft + ηright)
        end
    end

    if test_inplace_version
        @test @inferred(prod!(similar(efleft), efleft, efright)) ==
              ExponentialFamilyDistribution(T, ηleft + ηright, getconditioner(efleft))

        if test_inplace_assume_zero_allocations
            let _similar = similar(efleft)
                @test @allocated(prod!(_similar, efleft, efright)) === 0
            end
        end
    end

    if test_preserve_type_prod_of_distribution
        @test @inferred(prod(PreserveTypeProd(T), efleft, efright)) ≈
              prod(PreserveTypeProd(T), left, right)
    end

    return true
end