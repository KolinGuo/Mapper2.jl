"""
Overwrite routing link type to allow classification of routing links by class.
"""
struct TypedRoutingLink <: AbstractRoutingLink
    channels::Vector{Int64}
    cost    ::Float64
    capacity::Int64
    class   ::String
end

"""
Provide constructor.
"""
function TypedRoutingLink(cost, capacity, class)
    return TypedRoutingLink(Int[], cost, capacity, class)
end


"""
New RoutingTask type to allow classification of tasks by a class.
"""
struct TypedRoutingChannel <: AbstractRoutingChannel
    start::Vector{Vector{Int64}}
    stop::Vector{Vector{Int64}}
    class::String

    function TypedRoutingChannel(start, stop, edge)
        class = get(edge.metadata, "class", "all")
        return new(start, stop, class)
    end
end

function Mapper2.routing_channel(::Type{A}, start, stop, edge::TaskgraphEdge) where {A <: TestArchitecture} 
    TypedRoutingChannel(start, stop, edge)
end

# Provide custom annotation methods.
function Mapper2.annotate(::Type{A},port::Port) where {A <: TestArchitecture}
    capacity = get(port.metadata, "capacity", 10)
    class    = get(port.metadata, "class", "all")
    cost     = get(port.metadata, "cost", 1.0)
    TypedRoutingLink(cost,capacity,class)
end
function Mapper2.annotate(::Type{A},link::Link) where {A <: TestArchitecture}
    capacity = get(link.metadata, "capacity", 10)
    class    = get(link.metadata, "class", "all")
    cost     = get(link.metadata, "cost", 1.0)
    TypedRoutingLink(cost,capacity,class)
end
function Mapper2.annotate(::Type{A}, component::Component) where {A <: TestArchitecture}
    @assert component.primitive == "mux"
    return TypedRoutingLink(1.0,10,"all")
end

# Validity checks
function check_class(item, edge::TaskgraphEdge)
    item_class = get(item.metadata, "class", "all")
    edge_class = get(edge.metadata, "class", "all")
    return check_class(item_class, edge_class)
end
function check_class(item, edge)
    if edge == "all"
        return true
    elseif item == "all"
        return true
    else
        return edge == item
    end
end

function Mapper2.canuse(::Type{A}, item::Union{Port,Link}, edge::TaskgraphEdge) where
        A <: TestArchitecture
    return check_class(item, edge)
end
function Mapper2.canuse(::Type{A}, item::TypedRoutingLink, edge::TypedRoutingChannel) where
        A <: TestArchitecture
    return check_class(item.class, edge.class)
end
function Mapper2.isvalid_source_port(::Type{A}, 
                                     port::Port, 
                                     edge::TaskgraphEdge) where A <: TestArchitecture
    port.class in Mapper2.PORT_SINKS || return false
    # Check metadata
    return check_class(port, edge)
end
function Mapper2.isvalid_sink_port(::Type{A}, 
                                   port::Port, 
                                   edge::TaskgraphEdge) where A <: TestArchitecture
    port.class in Mapper2.PORT_SOURCES || return false
    # Check metadata
    return check_class(port, edge)
end
