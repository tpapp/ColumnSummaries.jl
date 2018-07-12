__precompile__()
module ColumnSummaries

export
    # general interface
    AbstractSummary, capture!, isomnivore,
    # specific summaries
    StringCounter, NumRange, TimeRange

using DataStructures: counter, Accumulator
using Dates: TimeType, default_format, DateFormat
using DocStringExtensions: SIGNATURES, TYPEDEF

import Base: count, min, max, keys, values, collect


# general interface

"""
    $TYPEDEF

Subtypes parse and summarize strings.

They should support the following interface:

- [`capture!`](@ref) for adding elements to a summary

- `count(summary)` for the number of elements captured

- [`isomnivore`](@ref) to query whether `capture!` unconditionally captures
  everything
"""
abstract type AbstractSummary{T} end

"""
    capture!(summary::AbstractSummary, str::AbstractString)

If `summary` can accept `str`, do that and return `true`, otherwise `false`.
"""
function capture! end

"""
    $SIGNATURES

If `capture!` always accepts, return `true`, otherwise `false`.
"""
isomnivore(::AbstractSummary) = false

"""
    $TYPEDEF

Also count accepted elements individually.

Supports `keys`, `values`, and `collect`. Sorted by the counts in descending
order, using `collect` once is the most efficient way to access the contents.
"""
abstract type AbstractCounter{T} <: AbstractSummary{T} end

"""
    $TYPEDEF

Record the range of elements.

Supports `min` and `max`.
"""
abstract type AbstractRange{T} <: AbstractSummary{T} end

count(s::AbstractRange) = s.count

max(s::AbstractRange) = s.count == 0 ? nothing : s.max

min(s::AbstractRange) = s.count == 0 ? nothing : s.min


# string counter

struct StringCounter{S <: AbstractString} <: AbstractCounter{S}
    acc::Accumulator{S, Int64}
end

isomnivore(::StringCounter) = true

StringCounter(::Type{S}) where {S <: AbstractString} = StringCounter(counter(S))

StringCounter() = StringCounter(String)

capture!(s::StringCounter, str::AbstractString) = (push!(s.acc, str); true)

count(s::StringCounter) = sum(s.acc)

collect(s::StringCounter) = sort!(collect(s.acc); rev = true, by = last)

keys(s::StringCounter) = first.(collect(s))

values(s::StringCounter) = last.(collect(s))


# ranges

mutable struct NumRange{T <: Real} <: AbstractRange{T}
    count::Int64
    min::T
    max::T
end

NumRange(::Type{T}) where {T<:Real} = NumRange(0, zero(T), zero(T))

count(s::NumRange) = s.count

function capture!(s::NumRange{T}, str::AbstractString) where T
    x = tryparse(T, str)
    x ≡ nothing && return false
    if s.count == 0
        s.min = x
        s.max = x
    else
        s.min = min(s.min, x)
        s.max = max(s.max, x)
    end
    s.count += 1
    true
end

mutable struct TimeRange{T <: TimeType, D <: DateFormat} <: AbstractRange{T}
    count::Int64
    dateformat::D
    min::T
    max::T
end

TimeRange(::Type{T},
          dateformat::DateFormat = default_format(T)) where {T<:TimeType} =
    TimeRange(0, dateformat, typemax(T), typemin(T))

TimeRange(::Type{T}, format::AbstractString) where {T<:TimeType} =
    TimeRange(T, DateFormat(format))

function capture!(s::TimeRange{T}, str::AbstractString) where T
    x = tryparse(T, str, s.dateformat)
    x ≡ nothing && return false
    s.min = min(s.min, x)
    s.max = max(s.max, x)
    s.count += 1
    true
end

end # module
