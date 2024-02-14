const doc = """
Usage:
    brute_force.jl <repo_dir>
"""

using DocOpt
using Base.Threads

const args = docopt(doc, version = v"0.1.1")
const PARALLEL_MARKING_FIRST_COMMIT_HASH = "abeecee"
const NRUNS = 2_048

function all_commits_after_parallel_marking(repo_dir::String)
    # Get all commits after the parallel marking first commit
    cmd = pipeline(`git -C $repo_dir log --pretty=format:%H`, stdout="/tmp/commits")
    run(cmd)
    commits = readlines("/tmp/commits")
    first_commit_index = findfirst(x -> startswith(x, PARALLEL_MARKING_FIRST_COMMIT_HASH), commits)
    return commits[1:first_commit_index]
end

function main()
    repo_dir = args["<repo_dir>"]
    commits = all_commits_after_parallel_marking(repo_dir)
    reverse!(commits)
    Threads.@threads for commit in commits
        # clone the repo `https://github.com/JuliaLang/julia.git`
        if isdir("/tmp/julia-$commit")
            rm("/tmp/julia-$commit"; recursive = true)
        end
        run(`git clone https://github.com/JuliaLang/julia.git /tmp/julia-$commit`)
        # checkout the commit
        run(`git -C /tmp/julia-$commit checkout $commit`)
        # build the julia
        cd("/tmp/julia-$commit")
        run(`make -j`)
        cd("/tmp")
        # create a file `$commit_output.txt` to store the output
        if isfile("/tmp/$commit.txt")
            rm("/tmp/$commit.txt")
        end
        open("/tmp/$commit.txt", "w")
        # run `test/gc/binarytree.jl`
        cd("/tmp/julia-$commit")
        failed = false
        for i in 1:NRUNS
            cmd = pipeline(`./julia --gcthreads=16 test/gc/binarytree.jl`, stdout="/tmp/$commit.txt")
            r = run(cmd)
            if !success(r)
                println("Failed to run binarytree.jl")
                write("/tmp/$commit.txt", "Failed to run binarytree.jl")
                failed = true
                break
            end
        end
        if !failed
            println("Succeeded to run binarytree.jl")
            write("/tmp/$commit.txt", "Succeeded to run binarytree.jl")
        end
        rm("/tmp/julia-$commit"; recursive = true)
    end
    for commit in commits
        # if the output file `$commit_output.txt` contains "Failed to run binarytree.jl"
        # then print the commit hash and exit
        if occursin("Failed to run binarytree.jl", read("/tmp/$commit.txt", String))
            println("Failed to run binarytree.jl at commit $commit")
            break
        end
    end
end

main()