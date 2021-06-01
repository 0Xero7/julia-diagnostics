# include("src/CSTParser.jl")
using CSTParser

function dfs(node)
    if isempty(node) return end

    println(node.head)

    if !isnothing(node.args)        
        for i in eachindex(node.args)
            dfs(node.args[i])
        end
    end

end

# function find_error(src, cst, offset, tabs)
#     if cst.head == :errortoken # cst.typ == CSTParser.ErrorToken
#         # get the starting of this line
#         i = min(offset, length(src))
#         j = 0
#         while i > 0 && src[i] != '\n'
#             i -= 1
#             j += 1
#         end
        
#         # get the end of this line
#         endLine = min(offset, length(src))
#         while endLine < length(src) && src[endLine] != '\n'
#             endLine += 1
#         end
# # offset + cst.fullspan - 1
#         # endLine -= 1

#         line = SubString(src, i + 1, endLine)
#         if last(line, 1) == '\n'
#             line = SubString(line, 0, len(line) - 1)
#         end

#         printstyled("Error: ")
#         # printstyled(cst.meta, color=:red)
#         if (string(cst.meta) == "MissingConditional")
#             printstyled(cst.meta, ": Expected a boolean expression", color=:red)
#         elseif (string(cst.meta) == "StringInterpolationWithTrailingWhitespace")
#             printstyled(cst.meta, ": Expected an expression after \$, found whitespace", color=:red)
#         else
#             printstyled("Unexpected Token", color=:red)
#         end
#         println()
#         printstyled(line, "\n", color=:red)
#         printstyled(" " ^ (7 + j - 1), "^" ^ (cst.span + 1), "\n", color=:red)

#         # ps = CSTParser.ParseState(string(SubString(src, i + 1, offset + cst.span - 1)))
#         # x = CSTParser.parse_expression(ps)

#         # println(x)

#         return 0, true
#     end

    
#     _span = cst.fullspan 
#     if cst.head == :file _span = 0 end
    
#     # t = "   " ^ tabs
#     # println(offset, ":", offset + _span - 1, t, cst.head, " ")

#     _offset = offset

#     if !isnothing(cst.args)        
#         for i in eachindex(cst.args)
#             _offset, found_error = find_error(src, cst.args[i], _offset, tabs + 1)
#             if found_error return 0, true end
#         end
#     end

#     return offset + _span, false
# end


function main()
    # file = open("test1.jl", "r")
    file = open("test1.jl", "r")
    # file = open("test3.jl", "r")
    # file = open("test4.jl", "r")

    source = read(file, String)
    close(file)

    for i in range(1, length(source), step = 1)
        println(string(i) , "  " , source[i])
    end

    ps = CSTParser.ParseState(source);
    top, ps = CSTParser.parse(ps, true);

    print(top)

    # dfs(top)





    # println(top)
    # # println(ps.errored)

    # if ps.errored
    #     _ = find_error(source, top, 1, 0)
    # end

    0
end

main()