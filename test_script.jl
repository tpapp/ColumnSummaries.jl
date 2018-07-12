using Pkg
# Pkg.add("https://github.com/tpapp/ColumnSummaries.jl")
Pkg.activate(".")
Pkg.build()
Pkg.test(; coverage=true)
