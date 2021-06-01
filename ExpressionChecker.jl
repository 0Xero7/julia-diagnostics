using DataStructures
using Tokenize
include("Error.jl")

function checkExprValidity(expr::String)
    s = Stack{Char}()
    closingSymbols = Dict('(' => ')', '[' => ']')
    openingSymbols = Dict(')' => '(', ']' => '[')

    for c in expr
        if c in keys(closingSymbols)
            push!(s, c)
        end
        
        if c in keys(openingSymbols)
            if first(s) != openingSymbols[c]
                return "Expected a \"$(closingSymbols[first(s)])\" but found \"$c\"."
            end
        end
    end

    if !isempty(s)
        return "Premature ending of line. Expected \"$(closingSymbols[first(s)])\"."
    end
end


function isExpressionX(node)::Bool
    if isnothing(node) return false end

    return node.typ == CSTParser.IDENTIFIER ||
        node.typ == CSTParser.LITERAL ||
        node.typ == CSTParser.Call ||
        node.typ == CSTParser.EXPR ||
        node.typ == CSTParser.BinaryOpCall ||
        isTerminal(node)
end


function isTerminal(node)::Bool
    if isnothing(node) return false end

    return node.kind == Tokens.IDENTIFIER || node.kind == Tokens.LITERAL ||
        node.kind == Tokens.INTEGER || node.kind == Tokens.STRING ||
        node.kind == Tokens.FLOAT || node.kind == Tokens.BIN_INT || node.kind == Tokens.RPAREN || 
        node.kind == Tokens.TRUE || node.kind == Tokens.FALSE
end

function extract_line(source::String, pos)
    left = pos
    while left > 1
        left -= 1
        if source[left] == '\n'
            left += 1
            break
        end
    end

    right = min(pos, length(source))
    while right <= length(source)
        if source[right] == '\n'
            right -= 1
            break
        end
        right += 1
    end
    
    if right > length(source)
        right = length(source)
    end

    if source[right] == '\n'
        right -= 1
    end

    return source[left: right] #source, left, right)
end


# Check the current block, essentially an array of statements
function checkBlock(node, ast_pos, errors, source, isElseBlock = false) 
    offset = 0
    for i in node.args
        if isElseBlock && i.typ == CSTParser.ErrorToken && !isempty(i.args) && (i.args[1].kind == Tokens.ELSE || i.args[1].kind == Tokens.ELSEIF)
            _type = (i.args[1].kind == Tokens.ELSE ? "else" : "elseif")
            push!(errors, ExpandedError("'$(_type)' is not allowed after 'else'. Try moving it before 'else'.", ast_pos + offset, 1, 
            rstrip(extract_line(source, ast_pos + offset)), i.args[1].span))
        end

        if i.typ == CSTParser.If
            checkIfBlock(i, ast_pos + offset, errors, source)
        elseif i.typ == CSTParser.While
            checkWhile(i, ast_pos + offset, errors, source)
        elseif i.typ == CSTParser.For
            checkFor(i, ast_pos + offset, errors, source)
        elseif i.typ == CSTParser.FunctionDef
            checkFunctionDecl(i, ast_pos + offset, errors, source)
        elseif i.typ == CSTParser.Return
            checkReturn(i, ast_pos + offset, errors, source)
        else
            checkExpr(extract_line(source, ast_pos + offset), ast_pos + offset, errors)
        end

        offset += i.fullspan
    end
end

# Check if a function definition is syntactically okay
function checkFunctionDecl(node, ast_pos, errors, source)
    offset = 0

    if (node.args[1].typ != CSTParser.KEYWORD) return end
    offset += node.args[1].fullspan

    # Define the parameters and function name, essentially a call
    offset += node.args[2].fullspan

    if !isempty(node.args[3].args)
        checkBlock(node.args[3], ast_pos + offset, errors, source)
    end
    offset += node.args[3].fullspan

    # fourth arg is an "end"
    if node.args[4].typ == CSTParser.ErrorToken
        push!(errors, ExpandedError("Expected an 'end' token, but found nothing.",
            ast_pos + offset, 1, " ", 1))
    end
end

# Check if a while block is okay (CSTParser cannot parse while correctly)
function checkWhile(node, ast_pos, errors, source)
    offset = 0

    # first arg is while (100%)
    if (node.args[1].typ != CSTParser.KEYWORD) return end
    offset += node.args[1].fullspan

    # second arg is an expression
    if node.args[2].typ == CSTParser.ErrorToken
        push!(errors, ExpandedError("Expected a boolean expression, found nothing.",
            ast_pos, 1, extract_line(source, ast_pos), node.args[1].span))
    elseif !isExpressionX(node.args[2])
        whatIsIt = strip(extract_line(source, ast_pos + offset))
        whatIsIt = whatIsIt[7 : length(whatIsIt)]

        push!(errors, ExpandedError("Expected a boolean expression, found '$whatIsIt'.", 
            ast_pos + offset, offset + 1, extract_line(source, ast_pos + offset), length(whatIsIt)))
    end
    offset += node.args[2].fullspan

    # third arg is a block
    if !isempty(node.args[3].args)
        checkBlock(node.args[3], ast_pos + offset, errors, source)
    end
    offset += node.args[3].fullspan

    # fourth arg is an "end"
    if node.args[4].typ == CSTParser.ErrorToken
        push!(errors, ExpandedError("Expected an 'end' token, but found nothing.",
            ast_pos + offset, 1, " ", 1))
    end
end


# Check if a for loop is syntactically correct
function checkFor(node, ast_pos, errors, source)
    offset = 0

    # first arg is definitely for
    if node.args[1].typ != CSTParser.KEYWORD return end
    offset += node.args[1].fullspan

    # TODO: check if parsed expression is valid
    # check if second arg is a valid iterator
    if node.args[2].typ == CSTParser.ErrorToken
        if node.args[2].meta == CSTParser.InvalidIterator
            _line = extract_line(source, ast_pos + offset)
            _error = strip(_line[offset + 1: length(_line)])

            push!(errors, ExpandedError("Expected an iterator after 'for', but found '$(_error)', which is not a valid iterator.",
            ast_pos + offset, offset + 1, _line, length(_error)))
        end
    end
    offset += node.args[2].fullspan
    
    # third arg is a block
    if !isempty(node.args[3].args)
        println(node.args[3])
        checkBlock(node.args[3], ast_pos + offset, errors, source)
    end
    offset += node.args[3].fullspan

    # fourth arg is an "end"
    if node.args[4].typ == CSTParser.ErrorToken
        push!(errors, ExpandedError("Expected an 'end' token, but found nothing.",
            ast_pos + offset, 1, " ", 1))
    end
end


# Check if an elseif block is syntactically okay
function checkElseIfBlock(node, ast_pos, errors, source)
    offset = 0
    # expect an expression
    if node.args[1].typ == CSTParser.ErrorToken
        if node.args[1].meta == CSTParser.MissingConditional
            push!(errors, ExpandedError("Expected a boolean expression after 'elseif', found nothing.",
                ast_pos, 1, extract_line(source, ast_pos), 2))
        end
    elseif !isExpressionX(node.args[1])
        _line = extract_line(source, ast_pos + offset)
        _error = strip(_line[offset + 1: length(_line)])
        
        push!(errors, ExpandedError("Expected a boolean expression after 'elseif', found $_error.",
        ast_pos + offset, offset + 1, _line, length(_error)))
    end
    offset += node.args[1].fullspan

    # third arg is a block
    if !isempty(node.args[2].args)
        checkBlock(node.args[2], ast_pos + offset, errors, source)
    end
    offset += node.args[2].fullspan

    if length(node.args) == 4
        # check if its elseif
        if node.args[3].kind == Tokens.ELSEIF
            checkElseIfBlock(node.args[4].args[1], ast_pos + offset + node.args[3].fullspan, errors, source)
        elseif node.args[3].kind == Tokens.ELSE
            checkBlock(node.args[4], ast_pos + offset + node.args[3].fullspan, errors, source, true)
        end
    end
end


# Check if an if statement is syntactically okay
function checkIfBlock(node, ast_pos, errors, source)
    offset = 0

    # first arg is a IF node (guaranteed)
    if node.args[1].typ != CSTParser.KEYWORD return end
    offset += node.args[1].fullspan

    # expect an expression
    if node.args[2].typ == CSTParser.ErrorToken
        if node.args[2].meta == CSTParser.MissingConditional
            push!(errors, ExpandedError("Expected a boolean expression after 'if', found nothing.",
                ast_pos, 1, "if   ", 2))
        end
    elseif !isExpressionX(node.args[2])
        _line = extract_line(source, ast_pos + offset)
        _error = strip(_line[offset + 1: length(_line)])
        
        push!(errors, ExpandedError("Expected a boolean expression after 'if', found $_error.",
        ast_pos + offset, offset + 1, _line, length(_error)))
    end
    offset += node.args[2].fullspan

    # third arg is a block
    if !isempty(node.args[3].args)
        checkBlock(node.args[3], ast_pos + offset, errors, source)
    end
    offset += node.args[3].fullspan

    # it's either end, else or elseif (a keyword)
    #    end
    if length(node.args) == 4 # its END
        if node.args[4].kind == Tokens.END
            return
        end

        if node.args[4].typ == CSTParser.ErrorToken
            push!(errors, ExpandedError("Expected an 'end' token, but found nothing.",
                ast_pos + offset, 1, " ", 1))
        end
    elseif length(node.args) == 6 # its either elseif or else
        offset += node.args[4].fullspan
        if node.args[4].kind == Tokens.ELSEIF
            checkElseIfBlock(node.args[5].args[1], ast_pos + offset, errors, source)
        elseif node.args[4].kind == Tokens.ELSE
            checkBlock(node.args[5], ast_pos + offset, errors, source, true)
        end
        
        offset += node.args[5].fullspan
        
        # make sure at the end its END
        if node.args[6].kind == Tokens.END
            return
        end

        if node.args[6].typ == CSTParser.ErrorToken
            push!(errors, ExpandedError("Expected an 'end' token, but found nothing.",
                ast_pos + offset, 1, " ", 1))
        end
    end
end

# Parse a return statement
function checkReturn(node, ast_pos, errors, source)
    offset = 0

    if node.args[1].kind != Tokens.RETURN return end
    offset += node.args[1].fullspan

    if !isempty(node.args[2])
        if !isExpressionX(node.args[2])
            _line = strip(extract_line(source, ast_pos))
            _err = _line[1 + offset : length(_line)]
            push!(errors, ExpandedError("Expected an expression after 'return', but found '$_err'.",
                ast_pos + offset, offset + 1, _line, length(_err)))
        else
            checkExpr(node.args[2], ast_pos + offset, errors, source)
        end
    end
end

# Parse an expression and find if there are any syntactic errors
function checkExpr(source, ast_pos, errors, tokens = nothing)
    # if isnothing(tokens) && !isempty(source)
        temp = collect(tokenize(source))
        if isnothing(temp) return end

        tokens = Vector()
        for i in temp
            # if i.kind != Tokens.WHITESPACE
                push!(tokens, i)
            # end
        end
        if isempty(tokens) return end
        # println(tokens)
        # println(source)
        # println()
    # end

    expr = Stack{Any}()
    ops  = Stack{Any}()

    lastNonWPToken = nothing
    lastToken = nothing

    i::Int32 = 1
    while i <= length(tokens)
        # We've found a '('!  Time to find the matching ')'.
        if tokens[i].kind == Tokens.LPAREN
            j = i + 1
            depth::Int32 = 1

            while j <= length(tokens) && depth > 0
                if tokens[j].kind == Tokens.WHITESPACE
                    j += 1
                    continue
                end

                if tokens[j].kind == Tokens.RPAREN
                    depth -= 1
                end

                if tokens[j].kind == Tokens.LPAREN 
                    depth += 1
                end

                if depth == 0 break end
                j += 1
            end

            if depth > 0
                push!(errors, ExpandedError("Unexpected end of line. Expected a ')'.", ast_pos + (tokens[i].startpos[2] - 1), tokens[i].startpos[2], source, 1))
                return
            end

            # recursively parse the inner statement between ( and )
            xxx = tokens[i + 1: j - 1]
            for xx in xxx
                println(xx)
            end
            println(source[tokens[i+1].startpos[2] : tokens[j - 1].endpos[2]])
            println()

            checkExpr(source[tokens[i+1].startpos[2] : tokens[j - 1].endpos[2]], ast_pos, errors, tokens[i+1:j-1])
            lastNonWPToken = tokens[i]
            lastToken = tokens[i]
            i = j
        end
        
        if !isnothing(lastNonWPToken) && tokens[i].kind != Tokens.WHITESPACE && !isTerminal(tokens[i]) && !isTerminal(lastNonWPToken)
            lineText = extract_line(source, tokens[i].startpos[2])
            firstOp = lineText[ tokens[i].startpos[2] : tokens[i].endpos[2] ]
            secondOp = lineText[ lastNonWPToken.startpos[2] : lastNonWPToken.endpos[2] ]

            println(firstOp, " and ", secondOp, " : ", lineText)

            push!(errors, ExpandedError("Cannot have two operators '$firstOp' and '$secondOp' without an expression between them.", 
                ast_pos + (lastNonWPToken.startpos[2] - 1), lastNonWPToken.startpos[2], lineText, tokens[i].startpos[2] - lastNonWPToken.startpos[2] - 1))
        end
        
        # We've found a ',', check if the previous token is a expr
        if tokens[i].kind == Tokens.COMMA
            if i == 1 || !isTerminal(tokens[i - 1])
                push!(errors, ExpandedError("Missing an identifier, literal or expression before ','.", ast_pos + (tokens[i].startpos[2] - 1), tokens[i].startpos[2], source, 1))
                return
            end
            
            lastNonWPToken = tokens[i]
            lastToken = tokens[i]
        end


        if isTerminal(tokens[i]) && !isnothing(lastNonWPToken) && isTerminal(lastNonWPToken)
            lineText = extract_line(source, tokens[i].startpos[2])
            # println("from checker: ", lineText)
            push!(errors, ExpandedError("Expected an operator between two expressions '$(lastNonWPToken.val)' and '$(tokens[i].val)', but none was found.", ast_pos + (lastNonWPToken.startpos[2] - 1), lastNonWPToken.startpos[2], lineText, tokens[i].startpos[2] - lastNonWPToken.startpos[2] + 1))
        end

        if tokens[i].kind != Tokens.WHITESPACE
            lastNonWPToken = tokens[i]
        end
        lastToken = tokens[i]
        i += 1
    end


end




function doWholeParse(source)
    tokens = collect(tokenize(source))

    println("\n\n$source")
    for t in tokens
        println(t)
    end

    prev = nothing
    for token in tokens
        if token.kind == Tokenize.Tokens.IDENTIFIER || token.kind == Tokenize.Tokens.LITERAL || token.kind == Tokens.INTEGER
            if !isnothing(prev) && (prev.kind == Tokenize.Tokens.IDENTIFIER || prev.kind == Tokenize.Tokens.LITERAL || token.kind == Tokens.INTEGER)
                return "Missing operator btween 2 terminals."
            end            
        end

        if token.kind == Tokenize.Tokens.LPAREN && !isnothing(prev) && prev.kind == Tokenize.Tokens.STRING
            return "Invalid function call. Strings are not callable. You are probably missing an operator, or want to use '[' instead of '('."
        end

        if token.kind == Tokens.COMMA && !(isTerminal(prev) || prev.kind == Tokens.RPAREN)
            return "Expected an identifier, literal or expression before ','."
        end

        if token.kind != Tokenize.Tokens.WHITESPACE
            prev = token
        end
    end

    return ""
end

# parse("test(,)", 1, nothing)