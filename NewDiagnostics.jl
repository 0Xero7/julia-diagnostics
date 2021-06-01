using CSTParser
include("ExpressionChecker.jl")
include("Error.jl")

global ast_pos = 1

struct Position
    lineNumber::Int32
    characterNumber::Int32
    absolutePosition::Int32
end


function get_positions(source::String)
    pos = Array{Position}(undef, length(source))
    
    line = 1
    ch = 1

    for i in 1:length(source)
        pos[i] = Position(line, ch, i)

        ch = ch + 1
        if source[i] == '\n'
            line += 1
            ch = 1
        end
    end

    return pos
end

function show_diagnostic(node, pos)
    print()
end

function find_errors(source, node, errors, previous)
    global ast_pos

    if isnothing(node) return end
    
    if node.typ == CSTParser.If
        checkIfBlock(node, ast_pos, errors, source)
        ast_pos += node.fullspan
    elseif node.typ == CSTParser.BinaryOpCall || node.typ == CSTParser.TupleH || node.typ == CSTParser.Call
        # println(doWholeParse(source[ast_pos:min(length(source), ast_pos + node.span)]))
        println(extract_line(source, ast_pos))
        parse(extract_line(source, ast_pos), ast_pos, errors)
    end

    if node.typ == CSTParser.ErrorToken
        # push!(errors, Error(node, previous, ast_pos))
    end

    node.val = SubString(source, ast_pos, min(length(source), ast_pos + node.span))

    if node.typ == CSTParser.IDENTIFIER ||
        node.typ == CSTParser.OPERATOR ||
        node.typ == CSTParser.KEYWORD ||
        node.typ == CSTParser.LITERAL ||
        node.typ == CSTParser.PUNCTUATION

        ast_pos += node.fullspan
    end

    if node.typ == CSTParser.FileH
        if !isnothing(node.args)
            prev = nothing
            for i in eachindex(node.args)
                println(node.args[i].typ)
                find_errors(source, node.args[i], errors, prev)
                prev = node.args[i]
            end
        end
    end
end

# function extract_line(source::String, pos)
#     left = pos
#     while left > 1
#         left -= 1
#         if source[left] == '\n'
#             left += 1
#             break
#         end
#     end

#     right = min(pos, length(source))
#     while right <= length(source)
#         if source[right] == '\n'
#             right -= 1
#             break
#         end
#         right += 1
#     end
    
#     if right > length(source)
#         right = length(source)
#     end

#     if source[right] == '\n'
#         right -= 1
#     end

#     return source[left: right] #source, left, right)
# end

function dfs(node) 
    if isnothing(node)
        return
    end
    
    field = fieldnames(typeof(node));
    for j in field
        println(j, " -> ", getfield(node, j))
        dfs(j)
    end
end

function isExpression(node)::Bool
    if isnothing(node) return false end

    return node.typ == CSTParser.IDENTIFIER ||
        node.typ == CSTParser.LITERAL ||
        node.typ == CSTParser.Call ||
        node.typ == CSTParser.EXPR
end

function get_message(node, prev, lineText::String)
    println("ERROR: ", node.meta)

    msg = ""
    if node.meta == CSTParser.StringInterpolationWithTrailingWhitespace
        msg = "Expected an expression after '\$', found a whitespace. Usually solved by removing the whitespace."
    elseif node.meta == CSTParser.UnexpectedToken
        msg = checkExprValidity(lineText)
    elseif isnothing(node.meta)
        if !isnothing(node.args)
            if node.args[1].typ == CSTParser.OPERATOR
                if !isnothing(prev) 
                    if prev.typ == CSTParser.OPERATOR
                        msg = "Expected an identifier or literal after operator \'$(strip(prev.val))\', but found another operator \'$(strip(node.args[1].val))\'."
                    end
                else
                    msg = "Bitch you've put an operator at the beginning of the line"
                end
            end

            # we have two expressions without any operator inbetween
            # example : z = 3 4
            if length(node.args) >= 2 && isExpression(node.args[1]) && isExpression(node.args[2])
                return "what the fuck man"
            end
        end 
    end

    msg
end

function main(filePath)
    file = open(filePath, "r")
    source = read(file, String)

    positions = get_positions(source)
    
    state = CSTParser.ParseState(source)
    ast, errored = CSTParser.parse(state, true)

    # print(ast)

    errors = Vector{ExpandedError}()
    # find_errors(source, ast, errors, nothing)
    checkBlock(ast, 1, errors, source)
    

    # print(errors)

    if !isempty(errors)
        println("Found ", length(errors), " errors.\n")
        index = 1

        for i in errors
            pos::Int32 = min(i.absolutePosition, length(source))
            lineText = i.source #extract_line(source, pos)

            print("[#$index] ")
            printstyled(i.message, color = :red) 
            # printstyled(get_message(i.node, i.previousNode, lineText), color = :red) 
            println("\n")
            
            locationText = "  [$(positions[pos].lineNumber)] "

            # test = CSTParser.parse_expression(ParseState(lineText));
            # field = fieldnames(typeof(test));
            # for j in field
            #     println(j, " -> ", getfield(test, j))
            # end


            print("  [");
            printstyled("$(positions[pos].lineNumber)", color=:yellow)
            print("] ");
            # print(lineText[1:i.lineStartPosition - 1])
            print(lineText[1:i.lineStartPosition - 1])



            printstyled(lineText[min(length(lineText), i.lineStartPosition):min(length(lineText), i.lineStartPosition+i.span-1)], color = :red)
            
            if (positions[pos].characterNumber+i.span) <= length(lineText)
                print(lineText[(i.lineStartPosition+i.span):length(lineText)])
            end

            println()
            printstyled(" " ^ (i.lineStartPosition - 1 + length(locationText)), "^", "~" ^ (i.span - 1), "\n", color = :red)

            print("at ")
            printstyled("$filePath:$(positions[pos].lineNumber):$(positions[pos].characterNumber)", bold=true)

            index += 1

            println("\n\n")
        end
    end

    #  println(ast)

end

main("$(pwd())\\test1.jl")