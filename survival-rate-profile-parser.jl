const doc = """survival-rate-profile-parser.jl -- Parses a survival-rate profile JSON file
Usage:
    survival-rate-profile-parser.jl [<name>]
    survival-rate-profile-parser.jl -h | --help
    survival-rate-profile-parser.jl --version
"""

using DocOpt
using JSON3
using Plots
using Printf

const args = docopt(doc, version = v"0.1.1")
const GC_N_MAX_POOLS = 51
const GC_MAX_DISPLAYED_AGE = 16

function main()
    name = args["<name>"]
    parse_survival_rate_profile(name)
end

function parse_survival_rate_profile(filename::String)
    global GC_MAX_DISPLAYED_AGE
    dict = JSON3.read(filename)
    dict_mutable = copy(dict)
    d = Dict{}()
    # normalize the survival rate profile
    for (k, v) in dict_mutable
        tmp::Vector{Float64} = v
        if v[1] != 0
            tmp ./= v[1]
        end
        d[k] = tmp
    end
    # remove the previous fig directory
    if isdir("fig")
        rm("fig"; recursive = true)
    end
    # create a /fig directory
    mkdir("fig")
    for i = 0:GC_N_MAX_POOLS-1
        # bar plot on light blue color without displaying
        p1 = bar(
            1:GC_MAX_DISPLAYED_AGE,
            d[Symbol("pool_", i)][1:GC_MAX_DISPLAYED_AGE],
            title = @sprintf("Survival Rate Profile of Normal Pool %03d", i),
            xlabel = "Age",
            ylabel = "Survival Rate",
            label = "Normal Pools",
            legend = true,
            color = :lightblue,
            show = false,
        )
        # now plot the one for i + GC_N_MAX_POOLS, but in light green
        p2 = bar(
            1:GC_MAX_DISPLAYED_AGE,
            d[Symbol("pool_", i + GC_N_MAX_POOLS)][1:GC_MAX_DISPLAYED_AGE],
            title = @sprintf("Survival Rate Profile of Compiler Pool %03d", i),
            xlabel = "Age",
            ylabel = "Survival Rate",
            label = "Compiler Pools",
            legend = true,
            color = :lightgreen,
            show = false,
        )
        # save the plot to a file
        p = plot(p1, p2, layout = (2, 1), size = (800, 600))
        savefig(p, @sprintf("fig/survival_rate_profile_%03d.png", i))
    end
end

main()
