export vague
export mean, median, mode, shape, scale, rate, var, std, cov, invcov, entropy, pdf, cdf, logpdf, logdetcov
export mean_cov, mean_var, mean_std, mean_invcov, mean_precision, weightedmean_cov, weightedmean_var, weightedmean_std,
    weightedmean_invcov, weightedmean_precision
export weightedmean, probvec, isproper
export variate_form, value_support, promote_variate_type, convert_eltype

using Distributions, Random

import Distributions: mean, median, mode, shape, scale, rate, var, std, cov, invcov, entropy, pdf, logpdf, logdetcov
import Distributions: VariateForm, ValueSupport, Distribution, Univariate, Multivariate, Matrixvariate

import Base: convert

"""
    vague(distribution_type, [ dims... ])

`vague` function returns uninformative probability distribution of a given type and can be used to set an uninformative priors in a model.
"""
function vague end

mean_cov(something)       = (mean(something), cov(something))
mean_var(something)       = (mean(something), var(something))
mean_std(something)       = (mean(something), std(something))
mean_invcov(something)    = (mean(something), invcov(something))
mean_precision(something) = mean_invcov(something)

weightedmean_cov(something)       = (weightedmean(something), cov(something))
weightedmean_var(something)       = (weightedmean(something), var(something))
weightedmean_std(something)       = (weightedmean(something), std(something))
weightedmean_invcov(something)    = (weightedmean(something), invcov(something))
weightedmean_precision(something) = weightedmean_invcov(something)

isproper(something)     = error("`isproper` is not defined for $(something)")
probvec(something)      = error("Probability vector function probvec() is not defined for $(something)")
weightedmean(something) = error("Weighted mean is not defined for $(something)")

"""
    variate_form(distribution_or_type)

Returns the `VariateForm` sub-type (defined in `Distributions.jl`):

- `Univariate`, a scalar number
- `Multivariate`, a numeric vector
- `Matrixvariate`, a numeric matrix

Note: supports real-valued containers, for which it defines:

- `variate_form(real) = Univariate`
- `variate_form(vector_of_reals) = Multivariate`
- `variate_form(matrix_of_reals) = Matrixvariate`

See also: [`ExponentialFamily.value_support`](@ref)
"""
variate_form(::Distribution{F, S}) where {F <: VariateForm, S <: ValueSupport} = F
variate_form(::Type{<:Distribution{F, S}}) where {F <: VariateForm, S <: ValueSupport} = F

variate_form(::Type{T}) where {T <: Real} = Univariate
variate_form(::T) where {T <: Real}       = Univariate

variate_form(::Type{V}) where {T <: Real, V <: AbstractVector{T}} = Multivariate
variate_form(::V) where {T <: Real, V <: AbstractVector{T}}       = Multivariate

variate_form(::Type{M}) where {T <: Real, M <: AbstractMatrix{T}} = Matrixvariate
variate_form(::M) where {T <: Real, M <: AbstractMatrix{T}}       = Matrixvariate

# Note that the recent version of `Distributions.jl` has the exact same methods (`variate_form`) with the exact same names, however, old versions do not.
# We keep that for backward-compatibility with old `Distributions.jl` versions,
# but probably we should revise this at some point and remove our implementations (except for the `real` constrained versions)

"""
    value_support(distribution_or_type)

Returns the `ValueSupport` sub-type (defined in `Distributions.jl`):

- `Discrete`, samples take discrete values
- `Continuous`, samples take continuous real values

See also: [`ExponentialFamily.variate_form`](@ref)
"""
value_support(::Distribution{F, S}) where {F <: VariateForm, S <: ValueSupport} = S
value_support(::Type{<:Distribution{F, S}}) where {F <: VariateForm, S <: ValueSupport} = S

# Note that the recent version of `Distributions.jl` has the exact same methods (`value_support`) with the exact same names, however, old versions do not
# We keep that for backward-compatibility with old `Distributions.jl` versions, but probably we should revise this at some point and remove our implementations

"""
    promote_variate_type(::Type{ <: VariateForm }, distribution_type)

Promotes (if possible) a `distribution_type` to be of the specified variate form.
"""
function promote_variate_type end

promote_variate_type(::D, T) where {D <: Distribution}       = promote_variate_type(variate_form(D), T)
promote_variate_type(::Type{D}, T) where {D <: Distribution} = promote_variate_type(variate_form(D), T)

"""
    convert_eltype(::Type{D}, ::Type{E}, distribution)

Converts (if possible) the `distribution` to be of type `D{E}`.
"""
convert_eltype(::Type{D}, ::Type{E}, distribution::Distribution) where {D <: Distribution, E} =
    convert(D{E}, distribution)

"""
    convert_eltype(::Type{E}, container)

Converts (if possible) the elements of the `container` to be of type `E`.
"""
convert_eltype(::Type{E}, container::AbstractArray) where {E} = convert(AbstractArray{E}, container)
convert_eltype(::Type{E}, number::Number) where {E} = convert(E, number)

"""
    sampletype(distribution)

Returns a type of the distribution. By default fallbacks to the `eltype`.

"""
sampletype(distribution) = eltype(distribution)

sampletype(distribution::Distribution) = sampletype(variate_form(distribution), distribution)
sampletype(::Type{Univariate}, distribution) = eltype(distribution)
sampletype(::Type{Multivariate}, distribution) = Vector{eltype(distribution)}
sampletype(::Type{Matrixvariate}, distribution) = Matrix{eltype(distribution)}

"""
    samplefloattype(distribution)

Returns a type of the distribution or the underlying float type in case if sample is `Multivariate` or `Matrixvariate`. 
By default fallbacks to the `deep_eltype(sampletype(distribution))`.

"""
samplefloattype(distribution) = deep_eltype(sampletype(distribution))

"""
    promote_sampletype(distributions...)

Promotes `sampletype` of the `distributions` to a single type. See also `promote_type`.

"""
promote_sampletype(distributions...) = promote_type(sampletype.(distributions)...)

"""
    promote_samplefloattype(distributions...)

Promotes `samplefloattype` of the `distributions` to a single type. See also `promote_type`.

"""
promote_samplefloattype(distributions...) = promote_type(samplefloattype.(distributions)...)

"""
    logpdf_sample_friendly(distribution) 
    
`logpdf_sample_friendly` function takes as an input a `distribution` and returns corresponding optimized two versions 
for taking `logpdf()` and sampling with `rand!` respectively. By default returns the same distribution, but some distributions 
may override default behaviour for better efficiency.

# Example

```jldoctest
julia> d = vague(MvNormalMeanPrecision, 2)
MvNormalMeanPrecision(
μ: [0.0, 0.0]
Λ: [1.0e-12 0.0; 0.0 1.0e-12]
)


julia> ExponentialFamily.logpdf_sample_friendly(d)
(FullNormal(
dim: 2
μ: [0.0, 0.0]
Σ: [1.0e12 -0.0; -0.0 1.0e12]
)
, FullNormal(
dim: 2
μ: [0.0, 0.0]
Σ: [1.0e12 -0.0; -0.0 1.0e12]
)
)
```
"""
logpdf_sample_friendly(something) = (something, something)

"""
    FactorizedJoint

`FactorizedJoint` represents a joint distribution of independent random variables. Use `getindex()` function or square-brackets indexing to access
the marginal distribution for individual variables.
"""
struct FactorizedJoint{T}
    multipliers::T
end

getmultipliers(joint::FactorizedJoint) = joint.multipliers

Base.getindex(joint::FactorizedJoint, i::Int) = getindex(getmultipliers(joint), i)

Base.length(joint::FactorizedJoint) = length(joint.multipliers)

function Base.isapprox(x::FactorizedJoint, y::FactorizedJoint; kwargs...)
    length(x) === length(y) &&
        all(pair -> isapprox(pair[1], pair[2]; kwargs...), zip(getmultipliers(x), getmultipliers(y)))
end

Distributions.entropy(joint::FactorizedJoint) = mapreduce(entropy, +, getmultipliers(joint))
