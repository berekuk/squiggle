module BBindings = Reducer_Expression_Bindings
module BErrorValue = Reducer_ErrorValue
module BExpressionT = Reducer_Expression_T
module BExpressionValue = ReducerInterface.ExpressionValue

type errorValue = BErrorValue.errorValue
type expression = BExpressionT.expression
type internalCode = ReducerInterface_ExpressionValue.internalCode

external castExpressionToInternalCode: expression => internalCode = "%identity"

let eArray = anArray => anArray->BExpressionValue.EvArray->BExpressionT.EValue

let eArrayString = anArray => anArray->BExpressionValue.EvArrayString->BExpressionT.EValue

let eBindings = (anArray: array<(string, BExpressionValue.expressionValue)>) =>
  anArray->Js.Dict.fromArray->BExpressionValue.EvRecord->BExpressionT.EValue

let eBool = aBool => aBool->BExpressionValue.EvBool->BExpressionT.EValue

let eCall = (name: string): expression => name->BExpressionValue.EvCall->BExpressionT.EValue

let eFunction = (fName: string, lispArgs: list<expression>): expression => {
  let fn = fName->eCall
  list{fn, ...lispArgs}->BExpressionT.EList
}

let eLambda = (
  parameters: array<string>,
  context: BExpressionValue.externalBindings,
  expr: expression,
) => {
  // Js.log(`eLambda context ${BBindings.externalBindingsToString(context)}`)
  BExpressionValue.EvLambda({
    parameters: parameters,
    context: context,
    body: expr->castExpressionToInternalCode,
  })->BExpressionT.EValue
}

let eNumber = aNumber => aNumber->BExpressionValue.EvNumber->BExpressionT.EValue

let eRecord = aRecord => aRecord->BExpressionValue.EvRecord->BExpressionT.EValue

let eString = aString => aString->BExpressionValue.EvString->BExpressionT.EValue

let eSymbol = (name: string): expression => name->BExpressionValue.EvSymbol->BExpressionT.EValue

let eList = (list: list<expression>): expression => list->BExpressionT.EList

let eBlock = (exprs: list<expression>): expression => eFunction("$$_block_$$", exprs)

let eLetStatement = (symbol: string, valueExpression: expression): expression =>
  eFunction("$_let_$", list{eSymbol(symbol), valueExpression})

let eBindStatement = (bindingExpr: expression, letStatement: expression): expression =>
  eFunction("$$_bindStatement_$$", list{bindingExpr, letStatement})

let eBindStatementDefault = (letStatement: expression): expression =>
  eFunction("$$_bindStatement_$$", list{letStatement})

let eBindExpression = (bindingExpr: expression, expression: expression): expression =>
  eFunction("$$_bindExpression_$$", list{bindingExpr, expression})

let eBindExpressionDefault = (expression: expression): expression =>
  eFunction("$$_bindExpression_$$", list{expression})

let eTypeIdentifier = (name: string): expression =>
  name->BExpressionValue.EvTypeIdentifier->BExpressionT.EValue
