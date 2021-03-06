module CellIntegration

using Gridap
using Gridap.Kernels: IntegrateKernel

export integrate

function integrate(
  cellfun::CellMap{Point{D},1,T,N},
  phi::CellGeomap{D,Z},
  quad::CellQuadrature{D}) where {D,Z,T,N}
  z = coordinates(quad)
  w = weights(quad)
  f = evaluate(cellfun,z)
  j = evaluate(gradient(phi),z)
  m = meas(j)
  k = _prepare_kernel(f,m,w)
  apply(k,f,m,w)
end

function _prepare_kernel(f::CellArray{T,N},m::CellArray{J},w::CellArray{W}) where {T,N,J,W}
  S = Base._return_type(*,(T,J,W))
  IntegrateKernel(Val(N),S)
end

function integrate(
  cellfun::CellMap{Point{D},1},trian::Triangulation{D,Z},quad::CellQuadrature{D}) where {D,Z}
  phi = CellGeomap(trian)
  integrate(cellfun,phi,quad)
end

function integrate(
  fun::Function,trian::Triangulation{D,Z},quad::CellQuadrature{D}) where {D,Z}
  phi = CellGeomap(trian)
  cellfun = compose(fun,phi)
  integrate(cellfun,phi,quad)
end

end # module CellIntegration
