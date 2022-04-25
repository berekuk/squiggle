/*
  Macros are like functions but instead of taking values as parameters,
  they take expressions as parameters and return a new expression.
  Macros are used to define language building blocks. They are like Lisp macros.
*/
module ExpressionT = Reducer_Expression_T
module ExpressionValue = ReducerInterface.ExpressionValue
module Result = Belt.Result

open Reducer_ErrorValue

type expression = ExpressionT.expression

type reducerFn = (
  expression,
  ExpressionT.bindings,
) => result<ExpressionValue.expressionValue, errorValue>

let rec replaceSymbols = (expression: expression, bindings: ExpressionT.bindings): result<
  expression,
  errorValue,
> => {
  let getParameters = (bindings: ExpressionT.bindings): array<string> => {
    let eParameters = Belt.Map.String.getWithDefault(bindings, "$parameters", EParameters([]))
    switch eParameters {
    | EParameters(parameters) => parameters
    | _ => []
    }
  }

  let putParameters = (
    bindings: ExpressionT.bindings,
    parameters: array<string>,
  ): ExpressionT.bindings =>
    Belt.Map.String.set(bindings, "$parameters", ExpressionT.EParameters(parameters))

  switch expression {
  | ExpressionT.EValue(EvSymbol(aSymbol)) => {
      let parameters = getParameters(bindings)
      switch Js.Array2.some(parameters, a => a == aSymbol) {
      | true => expression->Ok // We cannot bind the parameters with global values
      | false =>
        switch bindings->Belt.Map.String.get(aSymbol) {
        | Some(boundExpression) => boundExpression->Ok
        | None => RESymbolNotFound(aSymbol)->Error
        }
      }
    }
  | ExpressionT.EValue(_) => expression->Ok
  | ExpressionT.EBindings(_) => expression->Ok
  | ExpressionT.EParameters(_) => expression->Ok
  | ExpressionT.EList(list{
      ExpressionT.EValue(EvCall("$lambda")),
      ExpressionT.EParameters(parameters),
      expr,
    }) => {
      let oldParameters = getParameters(bindings)
      let newParameters = oldParameters->Js.Array2.concat(parameters)
      let newBindings = putParameters(bindings, newParameters)
      let rNewExpr = replaceSymbols(expr, newBindings)
      rNewExpr->Result.flatMap(newExpr =>
        ExpressionT.EList(list{
          ExpressionT.EValue(EvCall("$lambda")),
          ExpressionT.EParameters(parameters),
          newExpr,
        })->Ok
      )
    }
  | ExpressionT.EList(list) => {
      let racc = list->Belt.List.reduceReverse(Ok(list{}), (racc, each: expression) =>
        racc->Result.flatMap(acc => {
          each
          ->replaceSymbols(bindings)
          ->Result.flatMap(newNode => {
            acc->Belt.List.add(newNode)->Ok
          })
        })
      )
      racc->Result.map(acc => acc->ExpressionT.EList)
    }
  }
}

let dispatchMacroCall = (
  list: list<expression>,
  bindings: ExpressionT.bindings,
  reduceExpression: reducerFn,
): result<expression, 'e> => {
  let doBindStatement = (statement: expression, bindings: ExpressionT.bindings) => {
    switch statement {
    | ExpressionT.EList(list{
        ExpressionT.EValue(EvCall("$let")),
        ExpressionT.EValue(EvSymbol(aSymbol)),
        expressionToReduce,
      }) => {
        let rNewExpressionToReduce = replaceSymbols(expressionToReduce, bindings)

        let rNewValue =
          rNewExpressionToReduce->Result.flatMap(newExpressionToReduce =>
            reduceExpression(newExpressionToReduce, bindings)
          )

        let rNewExpression = rNewValue->Result.map(newValue => ExpressionT.EValue(newValue))
        rNewExpression->Result.map(newExpression =>
          Belt.Map.String.set(bindings, aSymbol, newExpression)->ExpressionT.EBindings
        )
      }
    | _ => REAssignmentExpected->Error
    }
  }

  let doExportVariableExpression = (bindings: ExpressionT.bindings) => {
    let emptyDictionary: Js.Dict.t<ExpressionValue.expressionValue> = Js.Dict.empty()
    let reducedBindings = bindings->Belt.Map.String.keep((_key, value) =>
      switch value {
      | ExpressionT.EValue(_) => true
      | _ => false
      }
    )
    let externalBindings = reducedBindings->Belt.Map.String.reduce(emptyDictionary, (
      acc,
      key,
      expressionValue,
    ) => {
      let value = switch expressionValue {
      | EValue(aValue) => aValue
      | _ => EvSymbol("internal")
      }
      Js.Dict.set(acc, key, value)
      acc
    })
    externalBindings->EvRecord->ExpressionT.EValue->Ok
  }

  let doBindExpression = (expression: expression, bindings: ExpressionT.bindings) =>
    switch expression {
    | ExpressionT.EList(list{ExpressionT.EValue(EvCall("$let")), ..._}) =>
      REExpressionExpected->Error
    | ExpressionT.EList(list{ExpressionT.EValue(EvCall("$exportVariablesExpression"))}) =>
      doExportVariableExpression(bindings)
    | _ => replaceSymbols(expression, bindings)
    }

  switch list {
  | list{ExpressionT.EValue(EvCall("$$bindings"))} => bindings->ExpressionT.EBindings->Ok

  | list{
      ExpressionT.EValue(EvCall("$$bindStatement")),
      ExpressionT.EBindings(bindings),
      statement,
    } =>
    doBindStatement(statement, bindings)
  | list{
      ExpressionT.EValue(EvCall("$$bindExpression")),
      ExpressionT.EBindings(bindings),
      expression,
    } =>
    doBindExpression(expression, bindings)
  | _ => list->ExpressionT.EList->Ok
  }
}
