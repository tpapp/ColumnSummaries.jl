using ColumnSummaries
using Test

using Dates: Date

@testset "string counter" begin
    s = StringCounter()
    @test capture!(s, "foo")
    @test capture!(s, "bar")
    @test capture!(s, "foo")
    @test count(s) == 3
    for _ in 1:3
        @test capture!(s, "bar")
    end
    @test count(s) == 6
    @test collect(s)::Vector{Pair{String,Int64}} == ["bar" => 4, "foo" => 2]
    @test keys(s)::Vector{String} == ["bar", "foo"]
    @test values(s)::Vector{Int64} == [4, 2]
end

@testset "date range" begin
    s = TimeRange(Date, "yyyy-mm-dd")
    @test count(s) == 0
    @test min(s) ≡ nothing
    @test max(s) ≡ nothing
    @test capture!(s, "2000-01-01")
    @test capture!(s, "1980-02-09")
    @test !capture!(s, "a fish")   # not a date
    # @test !capture!(s, "19800101") # other format
    @test count(s) == 2
    @test max(s) == Date(2000, 1, 1)
    @test min(s) == Date(1980, 2, 9)
end

@testset "number range" begin
    s = NumRange(Int)
    @test count(s) == 0
    @test min(s) ≡ nothing
    @test max(s) ≡ nothing
    @test !capture!(s, "2000-01-01")
    @test !capture!(s, "a fish")
    @test !capture!(s, "3.14")
    @test capture!(s, "-9")
    @test capture!(s, "11")
    @test count(s) == 2
    @test max(s) == 11
    @test min(s) == -9
end
