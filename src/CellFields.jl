export CellField
export evaluate, compose

"""
Abstract type that represents a cell-wise field, where
`T` stands for the type that represents the field at a point
(e.g., scalar, vector, tensor) and `D` stands for the space
dimension
"""
const CellField{D,T} = EvaluableCellArray{D,T,1} where {D,T}

evaluate(::CellField{D,T} where {D,T},::CellPoints{D} where D)::CellFieldValues{T} = @abstractmethod

# @santiagobadia : Again, T, TG, etc, should be <: FieldType (TBD)

"""
Returns another CellField object that represents the gradient.
`TG` has a rank one order greater than the one of `T`
"""
gradient(::CellField{D,T} where {D,T})::CellField{D,TG} = @abstractmethod

(∇)(self::CellField) = gradient(self)

"""
Composes a lambda function `f` with a `CellField`
`g` to provide `f ∘ g`. It has to be overloaded with 2 methods,
one that returns the type of the result, and another one that
returns the result
"""
function compose(f,g::CellField{D,S}) where {D,S}
  T = f(S)
  CellFieldFromComposeWithLambda{D,S,T}(f,g)
end

# @santiagobadia : The idea about two methods is very good, but
# I was wondering whether there is an automatic way to extract it
# from Julia if we provide info in the function interface about what
# it receives and what it provides. Simplifying, is the type method
# already in Julia if we feed it right?

Base.:∘(f,g::CellField) = compose(f,g)

# Can we put ∘ and ∇ as compose(,) and gradient() in the base module using duck-typing
# only once for all cases?