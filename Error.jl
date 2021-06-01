
struct Error
    node
    previousNode
    absolutePosition::Int32
end

struct ExpandedError 
    message::String
    absolutePosition::Int32
    lineStartPosition::Int32
    source::String
    span::Int32
end