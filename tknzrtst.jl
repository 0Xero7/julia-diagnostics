using Tokenize

s = "a && && b"
s = collect(Tokenize.tokenize(s))

for i in s
    println(i.exactkind)
end