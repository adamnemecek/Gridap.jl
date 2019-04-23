module Cartesian

# Dependencies of this module

using StaticArrays: SVector, MVector, @SVector
using Numa.Helpers
using Numa.FieldValues
using Numa.Polytopes
using Numa.Meshes
using Numa.Geometry
using Numa.CellValues

# Functionality provided 

export CartesianGrid
import Base: size, getindex, IndexStyle
import Numa.CellValues: cellsize
import Numa.Geometry: points, cells, celltypes, cellorders, gridgraph

struct CartesianGrid{D} <: Grid{D,D}
  dim_to_limits::NTuple{D,NTuple{2,Float64}}
  dim_to_ncells::NTuple{D,Int}
  extrusion::NTuple{D,Int}
  order:: Int
end

function CartesianGrid(;partition::NTuple{D,Int},domain=nothing,order::Int=1) where D
  _cartesiangrid(partition,domain,order)
end

function points(self::CartesianGrid)
  dim_to_npoint = tuple([ i+1 for i in self.dim_to_ncells ]...)
  CartesianGridPoints(self.dim_to_limits,dim_to_npoint)
end

cells(self::CartesianGrid) = CartesianGridCells(self.dim_to_ncells)

celltypes(self::CartesianGrid) = ConstantCellValue(self.extrusion,prod(self.dim_to_ncells))

cellorders(self::CartesianGrid) = ConstantCellValue(self.order,prod(self.dim_to_ncells))

function gridgraph(self::CartesianGrid)
  #fverdugo this is a temporary implementation
  nparts = [i for i in self.dim_to_ncells]
  mesh = StructHexMesh(nparts)
  GridGraphFromData(mesh.cellvefs,mesh.vefcells)
end

# Helpers

function _cartesiangrid(partition::NTuple{D,Int},domain,order) where D
  if domain === nothing
    _domain = [ i*(-1)^j for i in ones(D) for j in 1:2 ]
  else
    _domain = domain
  end
  dim_to_limits = tuple([(_domain[2*i-1],_domain[2*i]) for i in 1:D ]...)
  extrusion = tuple(fill(HEX_AXIS,D)...)
  dim_to_ncells = partition
  @notimplementedif order != 1
  CartesianGrid{D}(dim_to_limits,dim_to_ncells,extrusion,order)
end

struct CartesianGridPoints{D} <: IndexCellValue{Point{D},D}
  dim_to_limits::NTuple{D,NTuple{2,Float64}}
  dim_to_npoint::NTuple{D,Int}
end

size(self::CartesianGridPoints) = self.dim_to_npoint

IndexStyle(::Type{CartesianGridPoints{D}} where D) = IndexCartesian()

function getindex(self::CartesianGridPoints{D}, I::Vararg{Int, D}) where D
  p = zero(MPoint{D})
  @inbounds for d in 1:D
    xa = self.dim_to_limits[d][1]
    xb = self.dim_to_limits[d][2]
    p[d] =  xa + (I[d]-1)*(xb-xa)/(self.dim_to_npoint[d]-1)
  end
  Point{D}(p)
end

struct CartesianGridCells{D,L} <: IndexCellArray{Int,1,SVector{L,Int},D}
  dim_to_ncell::SVector{D,Int}
end

function CartesianGridCells(dim_to_ncell::NTuple{D,Int}) where D
  CartesianGridCells{D,2^D}(dim_to_ncell)
end

cellsize(self::CartesianGridCells{D,L}) where {D,L} = (L,)

size(self::CartesianGridCells) = self.dim_to_ncell.data

IndexStyle(::Type{CartesianGridCells{D,L}} where {D,L}) = IndexCartesian()

function getindex(self::CartesianGridCells{D,L}, I::Vararg{Int, D}) where {D,L}
  dim_to_ngpoint = 1 .+ self.dim_to_ncell
  dim_to_nlpoint = @SVector fill(2,D)
  offset = @SVector fill(1,D)
  pointgids = LinearIndices(dim_to_ngpoint.data)
  cellpointlids = CartesianIndices(dim_to_nlpoint.data)
  cellgid = CartesianIndex(I...) - CartesianIndex(offset.data)
  cellpointgids = cellpointlids .+ cellgid
  ids = zero(MVector{L,Int})
  @inbounds for (l,pgid) in enumerate(cellpointgids)
    ids[l] = pointgids[pgid]
  end
  SVector{L,Int}(ids)
end

end # module Cartesian