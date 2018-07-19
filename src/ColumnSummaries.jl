__precompile__()
module ColumnSummaries

export
    # general interface
    AbstractSummary, capture!, isomnivore,
    # specific summaries
    StringCounter, NumRange, TimeRange, ChainedSummaries

using DataStructures: counter, Accumulator
using Dates: TimeType, default_format, DateFormat
using DocStringExtensions: SIGNATURES, TYPEDEF

import Base:
    # generic
    count, show, isempty, eltype,
    # specific types
    min, max, extrema, keys, values, collect, getindex, length


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

eltype(::AbstractSummary{T}) where T = T

isempty(s::AbstractSummary) = count(s) == 0

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

Supports `min`, `max`, `extrema`.
"""
abstract type AbstractRange{T} <: AbstractSummary{T} end

count(s::AbstractRange) = s.count

max(s::AbstractRange) = s.count == 0 ? nothing : s.max

min(s::AbstractRange) = s.count == 0 ? nothing : s.min

extrema(s::AbstractRange) = s.count == 0 ? nothing : (s.min, s.max)


# utilities

"""
    $SIGNATURES

Summarize ratio as a percentage in exactly 3 characters.
"""
function percentage_string(count::Integer, total::Integer)
    if count == 0
        " ∅ "
    elseif count == total
        "all"
    else
        ratio = count/total
        if ratio < 0.01
            "<1%"
        else
            lpad("$(round(Int, ratio*100))%", 3)
        end
    end
end

"""
    $SIGNATURES

Convert counts to strings, with percentages, padded to the same width.
"""
function padded_count_percentages(counts)
    isempty(counts) && return String[]
    count_strings = string.(counts)
    total = sum(counts)
    max_width = maximum(length.(count_strings))
    @. lpad(count_strings, max_width) * " (" *
        percentage_string(counts, total) * ")"
end

_withindent(io::IO) = IOContext(io, :indent => get(io, :indent, 0) + 1)

_withchain(io::IO) = IOContext(_withindent(io), :chain => true)

_ischain(io::IO) = get(io, :chain, false)

function _limit_length(io::IO, v, n = 10)
    if get(io, :limit, true) && length(v) > n
        v[1:n], true
    else
        v, false
    end
end

function _newline_indent(io::IO)
    println(io)
    print(io, " " ^ (4 * get(io, :indent, 0)))
end

_print_type(io::IO, s::AbstractSummary) = show(io, typeof(s))

function _print_captured(io::IO, s)
    if !_ischain(io)
        print(io, isempty(s) ? " (empty)" : " captured $(count(s))")
    end
end

_print_extrema(io::IO, s::AbstractRange) = print(io, " in ", extrema(s))


_print_bits(io::IO, i::Integer) = print(io, " [≤$(ndigits(i; base = 2)) bits]")

_print_bits(io::IO, d::DatePeriod) = _print_bits(io, d.value)

function _print_bits(io::IO, s::AbstractRange)
    a, b = extrema(s)
    d = b - a
    _print_bits(io::IO, d + oneunit(d))
end


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

function show(io::IO, s::StringCounter)
    ischain = _ischain(io)
    _print_type(io, s)
    _print_captured(io, s)
    n = length(s.acc)
    print(io, ", $(n) distinct")
    _print_bits(io, n)
    kv, istruncated = _limit_length(io, collect(s))
    let io = _withindent(io)
        for (c, s) in zip(padded_count_percentages(last.(kv)), first.(kv))
            _newline_indent(io)
            print(io, c, " \"", s, "\"")
        end
        if istruncated
            _newline_indent(io)
            print(io, "…")
        end
    end
end


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

_print_type(io::IO, s::TimeRange{T}) where T = print(io, "TimeRange{$(T)}")

function show(io::IO, s::AbstractRange{T}) where T
    _print_type(io, s)
    _print_captured(io, s)
    if !isempty(s)
        _print_extrema(io, s)
        T <: Union{Integer,TimeType} && _print_bits(io, s)
    end
end


#

struct ChainedSummaries{T <: Tuple{Vararg{AbstractSummary}},
                        S} <: AbstractSummary{S}
    ChainedSummaries(chain::Tuple{Vararg{AbstractSummary}}) =
        new{typeof(chain), Union{(eltype.(chain))...}}(chain)
    chain::T
end

ChainedSummaries(chain::AbstractSummary...) = ChainedSummaries(chain)

isomnivore(c::ChainedSummaries) = any(isomnivore, c.chain)

function capture!(c::ChainedSummaries, str::AbstractString)
    for s in c.chain        # FIXME unroll?
        capture!(s, str) && return true
    end
    false
end

count(c::ChainedSummaries) = sum(count, c.chain)

getindex(c::ChainedSummaries, index::Int) = c.chain[index]

length(c::ChainedSummaries) = length(c.chain)

function show(io::IO, c::ChainedSummaries)
    print(io, "ChainedSummaries")
    _print_captured(io, c)
    pc = padded_count_percentages(count.(c.chain))
    let io = _withchain(io)
        for (p, s) in zip(pc, c.chain)
            _newline_indent(io)
            print(io, p, " ", s)
        end
    end
end

end # module
