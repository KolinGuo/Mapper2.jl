#=
Authors
    Mark Hildebrand

A collection of methods for interacting with the SAStruct.
=#

"""
    assign(sa::SAStruct, node, component, address)

Assigns the `node` index to the given `address` and `component` index at that
address.
"""
function assign(sa::SAStruct, node, component, address)
    # Update the grid
    sa.grid[component, address] = node
    sa.nodes[node].component = component
    sa.nodes[node].address = address
    return nothing
end

"""
    move(sa::SAStruct, node, component, address)

Move `node` to the given `component` and `address`.
"""
function move(sa::SAStruct, node, component::Integer, address::CartesianIndex)
    # Clear out the present location of the node.
    sa.grid[sa.nodes[node].component, sa.nodes[node].address] = 0
    # Assign it a new location.
    assign(sa, node, component, address)
    return nothing
end

"""
    swap(sa::SAStruct, node1, node2)

Swap two nodes in the placement structure.
"""
function swap(sa::SAStruct, node1, node2)
    # Get references to these objects to make life easier.
    n1 = sa.nodes[node1]
    n2 = sa.nodes[node2]
    # Swap address/component assignments
    n1.address, n2.address = n2.address, n1.address
    n1.component, n2.component = n2.component, n1.component
    # Swap grid.
    sa.grid[n1.component, n1.address] = node1
    sa.grid[n2.component, n2.address] = node2
    return nothing
end

################################################################################
# DEFAULT METRIC FUNCTIONS
################################################################################
#=
Right now, this first function is basically a dispatch method to handle the
case when we have multiple edge types.

Ideas include:

1. Allow type dispatch to do everything.
2. Make this a "generated" function based on all the types of the edges and
    build a "case" statement out of it.
=#
function edge_cost(::Type{A}, sa::SAStruct, i::Int) where {A <: AbstractArchitecture}
    return edge_cost(A, sa, sa.edges[i])
end

function edge_cost(::Type{<:AbstractArchitecture}, sa::SAStruct, edge::TwoChannel)
    a = sa.nodes[edge.source].address
    b = sa.nodes[edge.sink].address
    return Float64(sa.distance[a,b])
end

function edge_cost(::Type{<:AbstractArchitecture}, sa::SAStruct, edge::MultiChannel)
    cost = 0.0
    for src in edge.sources, snk in edge.sinks
        # Get the source and sink addresses
        a = sa.nodes[src].address
        b = sa.nodes[snk].address
        cost += sa.distance[a,b]
    end
    return cost
end

#=
NOTE: for the functions "map_cost" and "node_code", we do the funky schenanigans
with the "first" bool to make sure that "cost" is the correct return type
to make this code fast.

TODO: Think of a better way to make this code generic.
=#

map_cost(sa::SAStruct) = map_cost(architecture(sa), sa)
function map_cost(::Type{A}, sa::SAStruct) where {A <: AbstractArchitecture}
    cost = 0.0
    for i in eachindex(sa.edges)
        cost += edge_cost(A, sa, i)
    end
    for n in sa.nodes
        cost += address_cost(n, sa.address_data)
    end
    return cost
end

function node_cost(::Type{A}, sa::SAStruct, node) where {A <: AbstractArchitecture}
    # Unpack node data type.
    n = sa.nodes[node]
    cost = 0.0
    for edge in n.out_edges
        cost += edge_cost(A, sa, edge)
    end
    for edge in n.in_edges
        cost += edge_cost(A, sa, edge)
    end
    cost += address_cost(n, sa.address_data)
    return cost
end

#=
Node pair cost is slightly more subtle than just each independent node cost if

    1. The communication resources in the array are asymmetric. Then if two 
        nodes are swapped and are connected by a channel, the double cost of 
        that channel is not cancelled out correctly.

    2. For multi-pin nets, if a source and sink are swapped, then the the 
        objective function is calculated incorrectly due to counting the channel
        twice.
=#
function node_pair_cost(::Type{A}, sa::SAStruct, i,j) where {A <: AbstractArchitecture}
    cost = node_cost(A, sa, i)
    # Get the two node types for calculating the cost of the second node.
    a = sa.nodes[i]
    b = sa.nodes[j]

    for edge in b.out_edges
        if !in(edge, a.in_edges)
            cost += edge_cost(A, sa, edge)
        end
    end
    for edge in b.in_edges
        if !in(edge, a.out_edges)
            cost += edge_cost(A, sa, edge)
        end
    end
    cost += address_cost(b, sa.address_data)
    return cost
end

address_cost(node::Node, ::EmptyAddressData) = zero(Float64)
