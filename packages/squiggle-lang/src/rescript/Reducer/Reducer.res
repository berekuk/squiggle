module ErrorValue = Reducer_ErrorValue
module Expression = Reducer_Expression

type environment = ReducerInterface_ExpressionValue.environment
type errorValue = Reducer_ErrorValue.errorValue
type expressionValue = ReducerInterface_ExpressionValue.expressionValue
type externalBindings = ReducerInterface_ExpressionValue.externalBindings
let evaluate = Expression.evaluate
let evaluateUsingOptions = Expression.evaluateUsingOptions
let evaluatePartialUsingExternalBindings = Expression.evaluatePartialUsingExternalBindings
let parse = Expression.parse
