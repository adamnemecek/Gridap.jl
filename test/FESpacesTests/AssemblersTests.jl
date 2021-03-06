module AssemblersTests

using Test
using Gridap
using SparseArrays
using SparseMatricesCSR

for T in [  SparseMatrixCSC,
            SparseMatrixCSR,
            SparseMatrixCSR{0},
            SparseMatrixCSR{1},
            SparseMatrixCSR{0,Float64, Int},
            SparseMatrixCSR{1,Float64, Int},
            SymSparseMatrixCSR,
            SymSparseMatrixCSR{0},
            SymSparseMatrixCSR{1},
            SymSparseMatrixCSR{0, Float64, Int},
            SymSparseMatrixCSR{1, Float64, Int}]

    model = CartesianDiscreteModel(domain=(0.0,1.0,0.0,1.0), partition=(2,2))

    tags = [1,2,3,4,6,5]

    order = 1
    fespace = H1ConformingFESpace(Float64,model,order,tags)

    assem = SparseMatrixAssembler(T,fespace,fespace)

    trian = Triangulation(model)

    quad = CellQuadrature(trian,degree=2)

    basis = CellBasis(fespace)

    a(v,u) = varinner(∇(v), ∇(u))

    bfun(x) = x[2]

    b(v) = varinner(v,CellField(trian,bfun))

    mmat = integrate(a(basis,basis),trian,quad)

    bvec = integrate(b(basis),trian,quad)

    vec = assemble(assem, bvec)

    mat = assemble(assem, mmat)

    x = mat \ vec

    assemble!(vec,assem, bvec)

    assemble!(mat,assem, mmat)

    x2 = mat \ vec

    @test x ≈ x2

    @test vec ≈ [0.0625, 0.125, 0.0625]

    @test mat[1, 1]  ≈  1.333333333333333
    @test mat[2, 1]  ≈ -0.33333333333333
    @test mat[1, 2]  ≈ -0.33333333333333
    @test mat[2, 2]  ≈ 2.666666666666666
    @test mat[3, 2]  ≈ -0.33333333333333
    @test mat[2, 3]  ≈ -0.33333333333333
    @test mat[3, 3]  ≈ 1.333333333333333

    cellids = IdentityCellNumber(Int,length(bvec))

    vec2 = assemble(assem, (bvec,cellids))

    @test vec2 == vec

    vec3 = assemble(assem, (bvec,cellids), (bvec,cellids))
    @test vec3 ≈ 2*vec

    assemble!(vec3, assem, (bvec,cellids), (bvec,cellids))
    @test vec3 ≈ 2*vec

    mat2 = assemble(assem, (mmat,cellids,cellids) )

    @test mat2 == mat

    mat3 = assemble(assem, (mmat,cellids,cellids), (mmat,cellids,cellids))
    @test mat3 ≈ 2*mat

    assemble!(mat3, assem, (mmat,cellids,cellids), (mmat,cellids,cellids))
    @test mat3 ≈ 2*mat
end

end # module AssemblersTests
