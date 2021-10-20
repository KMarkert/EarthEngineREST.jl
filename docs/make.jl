push!(LOAD_PATH,"../src/")

using Documenter, EarthEngineREST

pages = [
    "Home" => "index.md",
    "API" => "api.md",
]

makedocs(;
    modules = [EarthEngineREST],
    authors = "Kel Markert",
    repo = "https://github.com/KMarkert/EarthEngineREST.jl/blob/{commit}{path}#L{line}",
    sitename = "EarthEngineREST.jl",
    pages = pages,
)

deploydocs(;
    repo = "github.com/KMarkert/EarthEngineREST.jl.git",
    devbranch = "main"
)
