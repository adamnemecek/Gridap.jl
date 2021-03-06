module ConformingFESpaces

using Gridap
using Gridap.Helpers
using Gridap.CellValuesGallery
using Gridap.CachedArrays
using Base: @propagate_inbounds
using LinearAlgebra: det
using Base: transpose

using Gridap.BoundaryGrids: _setup_tags

export ConformingFESpace
export H1ConformingFESpace
export DivConformingFESpace
export CurlConformingFESpace
import Gridap: num_free_dofs
import Gridap: num_diri_dofs
import Gridap: diri_tags
import Gridap: apply_constraints
import Gridap: apply_constraints_rows
import Gridap: apply_constraints_cols
import Gridap: celldofids
import Gridap: interpolate_values
import Gridap: interpolate_diri_values
import Gridap: CellField
import Gridap: CellBasis
import Gridap: Triangulation
import Base: size
import Base: getindex

"""
Conforming FE Space, where only one RefFE is possible in the whole mesh
"""
struct ConformingFESpace{D,Z,T} <: FESpace{D,Z,T}
  dim_to_nface_eqclass::Vector{<:IndexCellArray{Int}}
  cell_eqclass::IndexCellArray{Int}
  num_free_dofs::Int
  num_diri_dofs::Int
  diri_tags::Vector{Int}
  reffe::RefFE{Z,T}
  triangulation::Triangulation{D,Z}
  gridgraph::GridGraph
  facelabels::FaceLabels
  cellbasis::CellBasis{Z,T}
end

function ConformingFESpace(
  reffe::RefFE{D,T},
  trian::Triangulation{D,Z},
  graph::GridGraph,
  labels::FaceLabels,
  diri_tags::Vector{Int}) where {D,Z,T}
  args = _setup_conforming_fe_fields(reffe,trian,graph,labels,diri_tags,D)
  ConformingFESpace{D,Z,T}(args...)
end

function ConformingFESpace(
  reffe::RefFE{D,T},
  trian::Triangulation{D,Z},
  graph::GridGraph,
  labels::FaceLabels) where {D,Z,T}
  return ConformingFESpace(reffe, trian, graph, labels, ())
end

num_free_dofs(this::ConformingFESpace) = this.num_free_dofs

num_diri_dofs(this::ConformingFESpace) = this.num_diri_dofs

diri_tags(f::ConformingFESpace) = f.diri_tags

function apply_constraints(
  this::ConformingFESpace, cellvec::CellVector, cellids::CellNumber)
  cellvec
end

function apply_constraints_rows(
  this::ConformingFESpace, cellmat::CellMatrix, cellids::CellNumber)
  cellmat
end

function apply_constraints_cols(
  this::ConformingFESpace, cellmat::CellMatrix, cellids::CellNumber)
  cellmat
end

function celldofids(this::ConformingFESpace)
  this.cell_eqclass
end

function interpolate_values(this::ConformingFESpace,f::Function)
  _interpolate_values(this,f)
end

function interpolate_values(this::ConformingFESpace{D,Z,T},val::T) where {D,Z,T}
  fun(x) = val
  interpolate_values(this,fun)
end

function interpolate_diri_values(this::ConformingFESpace, funs::Vector{<:Function})
  _interpolate_diri_values(this,funs)
end

function interpolate_diri_values(this::ConformingFESpace{D,Z,T}, vals::Vector{T}) where {D,Z,T}
  _interpolate_diri_values(this,vals)
end

function CellField(
  fespace::ConformingFESpace{D,Z,T},
  free_dofs::AbstractVector{E},
  diri_dofs::AbstractVector{E}) where {D,Z,T,E}

  _CellField(fespace, free_dofs, diri_dofs,T,E)
end

CellBasis(this::ConformingFESpace) = this.cellbasis

Triangulation(this::ConformingFESpace) = this.triangulation

function H1ConformingFESpace(
  ::Type{T}, model::DiscreteModel{D}, order::Integer, diri_tags) where {D,T}

  labels = FaceLabels(model)
  H1ConformingFESpace(T,model,labels,order,diri_tags)
end

function H1ConformingFESpace(
  ::Type{T},
  model::DiscreteModel{D},
  labels::FaceLabels,
  order::Integer,
  diri_tags) where {D,T}

  grid = Grid(model,D)
  trian = Triangulation(grid)
  graph = GridGraph(model)
  orders = fill(order,D)
  polytope = _polytope(celltypes(grid))
  fe = LagrangianRefFE(T,polytope, orders)
  _diri_tags = _setup_tags(labels,diri_tags)
  ConformingFESpace(fe,trian,graph,labels,_diri_tags)
end

# @santiagobadia : Create a HDiv conforming constructor

# Helpers

function _CellField(
  fespace, free_dofs, diri_dofs, ::Type{T}, ::Type{E}) where {T,E}

  @assert E == eltype(T)
  @assert num_free_dofs(fespace) == length(free_dofs)
  @assert num_diri_dofs(fespace) == length(diri_dofs)
  reffe = fespace.reffe
  celldofs = celldofids(fespace)
  shb = CellBasis(fespace)
  cdofs = CellVectorFromLocalToGlobalPosAndNeg(
  celldofs, free_dofs, diri_dofs)
  lincomb(shb,cdofs)
  # @santiagobadia: For RT methods, we must add here a local_to_global_dofs
  # or global_to_local_dofs

end

function _setup_conforming_fe_fields(reffe,trian,graph,labels,diri_tags,D)
  dim_to_nface_eqclass, nfree, ndiri  = _generate_dim_to_nface_to_dofs(
  reffe, graph, labels, diri_tags)
  cellvefs_dim = [connections(graph,D,i) for i in 0:D]
  offset = length.(dim_to_nface_eqclass)
  for i in 2:length(offset)
    offset[i] += offset[i-1]
  end
  offset = tuple(offset[1:(end-1)]...)
  cellvefs = local_append(offset, cellvefs_dim...)
  dofs_all = append(dim_to_nface_eqclass...)
  cell_eqclass = CellEqClass(cellvefs, dofs_all, reffe)
  shb = ConstantCellValue(shfbasis(reffe), ncells(trian))
  phi = CellGeomap(trian)
  basis = attachgeomap(shb,phi)
  return dim_to_nface_eqclass, cell_eqclass, nfree, ndiri, diri_tags,
  reffe, trian, graph, labels, basis
end

function _generate_dim_to_nface_to_dofs(
  reffe::RefFE{D},
  graph::GridGraph,
  labels::FaceLabels,
  diri_tags::Vector{Int}) where D

  i_free_dof = 1
  i_diri_dof = -1

  dim_to_nface_to_dofs = IndexCellVector{Int}[]
  tag_to_labels = labels.tag_to_labels

  for d in 0:D

    nface_to_label = labels_on_dim(labels,d)
    cell_to_nfaces = connections(graph,D,d)
    nface_to_cells = connections(graph,d,D)
    icell = 1
    nface_to_cellowner = get_local_item(nface_to_cells,icell)
    nface_to_lnface = find_local_index(nface_to_cellowner, cell_to_nfaces)

    lnface_to_ldofs = nfacedofs(reffe,d)
    lnface_to_nldofs = length.(lnface_to_ldofs)

    num_nfaces = length(nface_to_cells)

    nface_to_dofs_ptrs = zeros(Int, num_nfaces+1)
    nface_to_dofs_data = Int[]

    if any(lnface_to_nldofs != 0)

      i_free_dof, i_diri_dof = _generate_nface_to_dofs!(
      nface_to_dofs_data,
      nface_to_dofs_ptrs,
      nface_to_lnface,
      lnface_to_nldofs,
      nface_to_label,
      diri_tags,
      tag_to_labels,
      i_free_dof,
      i_diri_dof)

    end

    length_to_ptrs!(nface_to_dofs_ptrs)

    nface_to_dofs = CellVectorFromDataAndPtrs(
    nface_to_dofs_data, nface_to_dofs_ptrs)

    push!(dim_to_nface_to_dofs, nface_to_dofs)

  end

  return (dim_to_nface_to_dofs, i_free_dof-1, -i_diri_dof-1)

end

function _generate_nface_to_dofs!(
  nface_to_dofs_data,
  nface_to_dofs_ptrs,
  nface_to_lnface,
  lnface_to_nldofs,
  nface_to_label,
  diri_tags,
  tag_to_labels,
  i_free_dof,
  i_diri_dof)

  for (nface, lnface) in enumerate(nface_to_lnface)

    nldofs = lnface_to_nldofs[lnface]
    label = nface_to_label[nface]
    isdiri = _is_diri(label,diri_tags,tag_to_labels)

    if isdiri
      for i in 1:nldofs
        push!(nface_to_dofs_data,i_diri_dof)
        i_diri_dof += -1
      end
    else
      for i in 1:nldofs
        push!(nface_to_dofs_data,i_free_dof)
        i_free_dof += 1
      end
    end

    nface_to_dofs_ptrs[nface+1] = nldofs
  end

  (i_free_dof, i_diri_dof)
end

_polytope(celltypes) = @notimplemented

function _polytope(celltypes::ConstantCellValue)
  code = celltypes.value
  Polytope(code)
end

function _interpolate_values(fesp::ConformingFESpace{D,Z,T},fun::Function) where {D,Z,T}
  reffe = fesp.reffe
  dofb = dofbasis(reffe)
  trian = fesp.triangulation
  phi = CellGeomap(trian)
  uphys = fun ∘ phi
  celldofs = fesp.cell_eqclass
  nfdofs = fesp.dim_to_nface_eqclass
  E = dof_type(T)
  free_dofs = zeros(E, num_free_dofs(fesp))
  diri_dofs = zeros(E, num_diri_dofs(fesp))
  aux = zeros(E, length(dofb))
  _interpolate_values_kernel!(
  free_dofs,diri_dofs,uphys,celldofs,dofb,aux)
  return free_dofs, diri_dofs
end

function _interpolate_values_kernel!(
  free_dofs,diri_dofs,uphys,celldofs,dofb,aux)

  for (imap,l2g) in zip(uphys,celldofs)
    evaluate!(dofb,imap,aux)
    # @santiagobadia : Here we should add a method for RT that multiplies by -1
    # if the face has this cell as the second one in the grid graph
    # local_to_global_dofs, global_to_local_dofs CellArray
    for (i,gdof) in enumerate(l2g)
      if (gdof > 0)
        free_dofs[gdof] = aux[i]
      else
        diri_dofs[-gdof] = aux[i]
      end
    end
  end
end

function _interpolate_diri_values(fesp::ConformingFESpace{D,Z,T},funs) where {D,Z,T}

  labels = fesp.facelabels
  dim_to_nface_to_label = labels.dim_to_nface_to_label
  dim_to_nface_to_dofs = fesp.dim_to_nface_eqclass
  diri_tags = fesp.diri_tags
  @assert length(diri_tags) == length(funs)
  E = eltype(T)
  diri_dof_to_val = zeros(E, num_diri_dofs(fesp))
  tag_to_labels = labels.tag_to_labels

  for (ifunc,f) in enumerate(funs)

    tag_f = diri_tags[ifunc]
    _ , diri_dof_to_fval = interpolate_values(fesp,f)

    if length(funs) == 1
      return diri_dof_to_fval
    end

    for idim in 0:D
      nface_to_label = dim_to_nface_to_label[idim+1]
      nface_to_dofs  = dim_to_nface_to_dofs[idim+1]
      _interpolate_diri_values_kernel!(
      diri_dof_to_val,
      diri_dof_to_fval,
      nface_to_label,
      nface_to_dofs,
      tag_f,
      tag_to_labels)
    end
  end

  return diri_dof_to_val

end

function _interpolate_diri_values_kernel!(
  diri_dof_to_val,
  diri_dof_to_fval,
  nface_to_label,
  nface_to_dofs,
  tag_f,
  tag_to_labels)

  for (nface, label) in enumerate(nface_to_label)
    dofs = nface_to_dofs[nface]
    if _is_diri(label,tag_f,tag_to_labels)
      for dof in dofs
        i = -dof
        diri_dof_to_val[i] = diri_dof_to_fval[i]
      end
    end
  end
end

@inline function _is_diri(label,diritags,tag_to_labels)
  for tag in diritags
    for dirilabel in tag_to_labels[tag]
      if (label == dirilabel)
        return true
      end
    end
  end
  return false
end

"""
Type encoding the cellwise local to global dof map.
For the moment, for the case of a single RefFE and for oriented nfaces.
"""
struct CellEqClass{T,A,B} <: IndexCellValue{CachedVector{T,Vector{T}},1}
  cell_to_nfaces::A
  nface_to_dofs::B
  lnface_to_ldofs::Vector{Vector{Int}}
  nldofs::Int
  cv::CachedVector{T,Vector{T}}
end

function CellEqClass(
  cell_to_nfaces::IndexCellVector{<:Integer},
  nface_to_dofs::IndexCellVector{T},
  reffe::RefFE) where T<:Integer

  lnface_to_ldofs = nfacedofs(reffe)
  A = typeof(cell_to_nfaces)
  B = typeof(nface_to_dofs)
  nldofs = length(dofbasis(reffe))
  v = zeros(T,nldofs)
  cv = CachedVector(v)
  CellEqClass{T,A,B}(cell_to_nfaces,nface_to_dofs,lnface_to_ldofs,nldofs,cv)
end

size(self::CellEqClass) = (length(self.cell_to_nfaces),)

@propagate_inbounds function getindex(self::CellEqClass,cell::Int)
  nfaces = self.cell_to_nfaces[cell]
  for (lnface,nface) in enumerate(nfaces)
    dofs = self.nface_to_dofs[nface]
    ldofs = self.lnface_to_ldofs[lnface]
    for i in 1:length(dofs)
      dof = dofs[i]
      ldof = ldofs[i]
      self.cv[ldof] = dof
    end
  end
  self.cv
end

function DivConformingFESpace(
  reffe::RefFE{D,T},
  trian::Triangulation{D,Z},
  graph::GridGraph,
  labels::FaceLabels,
  diri_tags::Vector{Int}) where {D,Z,T}

  dim_to_nface_eqclass,
  cell_eqclass,
  nfree,
  ndiri, diri_tags,
  reffe,
  trian,
  graph,
  labels,
  basis = _setup_conforming_fe_fields(reffe,trian,graph,labels,diri_tags,D)

  phi = CellGeomap(trian)
  jac = gradient(phi)
  detjac = det(jac)

  piola_map = (1.0/detjac)*jac

  # physbasis = _attachpiola(basis,piola_map)
  physbasis = basis

  ConformingFESpace{D,Z,T}( dim_to_nface_eqclass,
  cell_eqclass,
  nfree,
  ndiri, diri_tags,
  reffe,
  trian,
  graph,
  labels,
  physbasis )
end

function CurlConformingFESpace(
  reffe::RefFE{D,T},
  trian::Triangulation{D,Z},
  graph::GridGraph,
  labels::FaceLabels,
  diri_tags::Vector{Int}) where {D,Z,T}

  dim_to_nface_eqclass,
  cell_eqclass,
  nfree,
  ndiri, diri_tags,
  reffe,
  trian,
  graph,
  labels,
  basis = _setup_conforming_fe_fields(reffe,trian,graph,labels,diri_tags,D)

  phi = CellGeomap(trian)
  jac = gradient(phi)
  jact = transpose(jac)

  piola_map = inv(jact)

  # physbasis = _attachpiola(basis,piola_map)
  physbasis = piola_map

  ConformingFESpace{D,Z,T}( dim_to_nface_eqclass,
  cell_eqclass,
  nfree,
  ndiri, diri_tags,
  reffe,
  trian,
  graph,
  labels,
  physbasis )
end

# @santiagobadia : It is not ready because I think that the product of a
# integration point values times a
function _attachpiola(a::CellBasis{D},piola::CellFieldLike) where D
  Gridap.CellFieldsOperations._merge_val_and_grad(piola*a.val,piola*a.grad)
  # Gridap.CellFieldsOperations._merge_val_and_grad(a,gradient(a))
end

end # module
