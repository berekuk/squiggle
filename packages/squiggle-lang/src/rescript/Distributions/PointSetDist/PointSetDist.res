open Distributions

type t = PointSetTypes.pointSetDist

let mapToAll = ((fn1, fn2, fn3), t: t) =>
  switch t {
  | Mixed(m) => fn1(m)
  | Discrete(m) => fn2(m)
  | Continuous(m) => fn3(m)
  }

let fmap = ((fn1, fn2, fn3), t: t): t =>
  switch t {
  | Mixed(m) => Mixed(fn1(m))
  | Discrete(m) => Discrete(fn2(m))
  | Continuous(m) => Continuous(fn3(m))
  }

let fmapResult = ((fn1, fn2, fn3), t: t): result<t, 'e> =>
  switch t {
  | Mixed(m) => fn1(m)->E.R2.fmap(x => PointSetTypes.Mixed(x))
  | Discrete(m) => fn2(m)->E.R2.fmap(x => PointSetTypes.Discrete(x))
  | Continuous(m) => fn3(m)->E.R2.fmap(x => PointSetTypes.Continuous(x))
  }

let toMixed = mapToAll((
  m => m,
  d =>
    Mixed.make(
      ~integralSumCache=d.integralSumCache,
      ~integralCache=d.integralCache,
      ~discrete=d,
      ~continuous=Continuous.empty,
    ),
  c =>
    Mixed.make(
      ~integralSumCache=c.integralSumCache,
      ~integralCache=c.integralCache,
      ~discrete=Discrete.empty,
      ~continuous=c,
    ),
))

//TODO WARNING: The combineAlgebraicallyWithDiscrete will break for subtraction and division, like, discrete - continous
let combineAlgebraically = (op: Operation.convolutionOperation, t1: t, t2: t): t =>
  switch (t1, t2) {
  | (Continuous(m1), Continuous(m2)) =>
    Continuous.combineAlgebraically(op, m1, m2) |> Continuous.T.toPointSetDist
  | (Discrete(m1), Continuous(m2)) =>
    Continuous.combineAlgebraicallyWithDiscrete(
      op,
      m2,
      m1,
      ~discretePosition=First,
    ) |> Continuous.T.toPointSetDist
  | (Continuous(m1), Discrete(m2)) =>
    Continuous.combineAlgebraicallyWithDiscrete(
      op,
      m1,
      m2,
      ~discretePosition=Second,
    ) |> Continuous.T.toPointSetDist
  | (Discrete(m1), Discrete(m2)) =>
    Discrete.combineAlgebraically(op, m1, m2) |> Discrete.T.toPointSetDist
  | (m1, m2) => Mixed.combineAlgebraically(op, toMixed(m1), toMixed(m2)) |> Mixed.T.toPointSetDist
  }

let combinePointwise = (
  ~integralSumCachesFn: (float, float) => option<float>=(_, _) => None,
  ~integralCachesFn: (
    PointSetTypes.continuousShape,
    PointSetTypes.continuousShape,
  ) => option<PointSetTypes.continuousShape>=(_, _) => None,
  fn: (float, float) => result<float, Operation.Error.t>,
  t1: t,
  t2: t,
): result<PointSetTypes.pointSetDist, Operation.Error.t> =>
  switch (t1, t2) {
  | (Continuous(m1), Continuous(m2)) =>
    Continuous.combinePointwise(
      ~integralSumCachesFn,
      fn,
      m1,
      m2,
    )->E.R2.fmap(x => PointSetTypes.Continuous(x))
  | (Discrete(m1), Discrete(m2)) =>
    Discrete.combinePointwise(
      ~integralSumCachesFn,
      ~fn,
      m1,
      m2,
    )->E.R2.fmap(x => PointSetTypes.Discrete(x))
  | (m1, m2) =>
    Mixed.combinePointwise(
      ~integralSumCachesFn,
      ~integralCachesFn,
      fn,
      toMixed(m1),
      toMixed(m2),
    )->E.R2.fmap(x => PointSetTypes.Mixed(x))
  }

module T = Dist({
  type t = PointSetTypes.pointSetDist
  type integral = PointSetTypes.continuousShape

  let xToY = (f: float) => mapToAll((Mixed.T.xToY(f), Discrete.T.xToY(f), Continuous.T.xToY(f)))

  let toPointSetDist = (t: t) => t

  let downsample = (i, t) =>
    fmap((Mixed.T.downsample(i), Discrete.T.downsample(i), Continuous.T.downsample(i)), t)

  let truncate = (leftCutoff, rightCutoff, t): t =>
    fmap(
      (
        Mixed.T.truncate(leftCutoff, rightCutoff),
        Discrete.T.truncate(leftCutoff, rightCutoff),
        Continuous.T.truncate(leftCutoff, rightCutoff),
      ),
      t,
    )

  let normalize = fmap((Mixed.T.normalize, Discrete.T.normalize, Continuous.T.normalize))

  let updateIntegralCache = (integralCache, t: t): t =>
    fmap(
      (
        Mixed.T.updateIntegralCache(integralCache),
        Discrete.T.updateIntegralCache(integralCache),
        Continuous.T.updateIntegralCache(integralCache),
      ),
      t,
    )

  let toContinuous = mapToAll((
    Mixed.T.toContinuous,
    Discrete.T.toContinuous,
    Continuous.T.toContinuous,
  ))
  let toDiscrete = mapToAll((Mixed.T.toDiscrete, Discrete.T.toDiscrete, Continuous.T.toDiscrete))

  let toDiscreteProbabilityMassFraction = mapToAll((
    Mixed.T.toDiscreteProbabilityMassFraction,
    Discrete.T.toDiscreteProbabilityMassFraction,
    Continuous.T.toDiscreteProbabilityMassFraction,
  ))

  let minX = mapToAll((Mixed.T.minX, Discrete.T.minX, Continuous.T.minX))
  let integral = mapToAll((
    Mixed.T.Integral.get,
    Discrete.T.Integral.get,
    Continuous.T.Integral.get,
  ))
  let integralEndY = mapToAll((
    Mixed.T.Integral.sum,
    Discrete.T.Integral.sum,
    Continuous.T.Integral.sum,
  ))
  let integralXtoY = f =>
    mapToAll((Mixed.T.Integral.xToY(f), Discrete.T.Integral.xToY(f), Continuous.T.Integral.xToY(f)))
  let integralYtoX = f =>
    mapToAll((Mixed.T.Integral.yToX(f), Discrete.T.Integral.yToX(f), Continuous.T.Integral.yToX(f)))
  let maxX = mapToAll((Mixed.T.maxX, Discrete.T.maxX, Continuous.T.maxX))
  let mapY = (~integralSumCacheFn=_ => None, ~integralCacheFn=_ => None, ~fn: float => float): (
    t => t
  ) =>
    fmap((
      Mixed.T.mapY(~integralSumCacheFn, ~integralCacheFn, ~fn),
      Discrete.T.mapY(~integralSumCacheFn, ~integralCacheFn, ~fn),
      Continuous.T.mapY(~integralSumCacheFn, ~integralCacheFn, ~fn),
    ))

  let mapYResult = (
    ~integralSumCacheFn=_ => None,
    ~integralCacheFn=_ => None,
    ~fn: float => result<float, 'e>,
  ): (t => result<t, 'e>) =>
    fmapResult((
      Mixed.T.mapYResult(~integralSumCacheFn, ~integralCacheFn, ~fn),
      Discrete.T.mapYResult(~integralSumCacheFn, ~integralCacheFn, ~fn),
      Continuous.T.mapYResult(~integralSumCacheFn, ~integralCacheFn, ~fn),
    ))

  let mean = (t: t): float =>
    switch t {
    | Mixed(m) => Mixed.T.mean(m)
    | Discrete(m) => Discrete.T.mean(m)
    | Continuous(m) => Continuous.T.mean(m)
    }

  let variance = (t: t): float =>
    switch t {
    | Mixed(m) => Mixed.T.variance(m)
    | Discrete(m) => Discrete.T.variance(m)
    | Continuous(m) => Continuous.T.variance(m)
    }

  let klDivergence = (prediction: t, answer: t) =>
    switch (prediction, answer) {
    | (Continuous(t1), Continuous(t2)) => Continuous.T.klDivergence(t1, t2)
    | (Discrete(t1), Discrete(t2)) => Discrete.T.klDivergence(t1, t2)
    | (m1, m2) => Mixed.T.klDivergence(m1->toMixed, m2->toMixed)
    }

  let logScoreWithPointResolution = (~prediction: t, ~answer: float, ~prior: option<t>) => {
    switch (prior, prediction) {
    | (Some(Continuous(t1)), Continuous(t2)) =>
      Continuous.T.logScoreWithPointResolution(~prediction=t2, ~answer, ~prior=t1->Some)
    | (None, Continuous(t2)) =>
      Continuous.T.logScoreWithPointResolution(~prediction=t2, ~answer, ~prior=None)
    | _ => Error(Operation.NotYetImplemented)
    }
  }
})

let pdf = (f: float, t: t) => {
  let mixedPoint: PointSetTypes.mixedPoint = T.xToY(f, t)
  mixedPoint.continuous +. mixedPoint.discrete
}

let inv = T.Integral.yToX
let cdf = T.Integral.xToY

let doN = (n, fn) => {
  let items = Belt.Array.make(n, 0.0)
  for x in 0 to n - 1 {
    let _ = Belt.Array.set(items, x, fn())
  }
  items
}

let sample = (t: t): float => {
  let randomItem = Random.float(1.0)
  t |> T.Integral.yToX(randomItem)
}

let isFloat = (t: t) =>
  switch t {
  | Discrete({xyShape: {xs: [_], ys: [1.0]}}) => true
  | _ => false
  }

let sampleNRendered = (n, dist) => {
  let integralCache = T.Integral.get(dist)
  let distWithUpdatedIntegralCache = T.updateIntegralCache(Some(integralCache), dist)
  doN(n, () => sample(distWithUpdatedIntegralCache))
}

let operate = (distToFloatOp: Operation.distToFloatOperation, s): float =>
  switch distToFloatOp {
  | #Pdf(f) => pdf(f, s)
  | #Cdf(f) => cdf(f, s)
  | #Inv(f) => inv(f, s)
  | #Sample => sample(s)
  | #Mean => T.mean(s)
  }

let toSparkline = (t: t, bucketCount): result<string, PointSetTypes.sparklineError> =>
  T.toContinuous(t)
  ->E.O2.fmap(Continuous.downsampleEquallyOverX(bucketCount))
  ->E.O2.toResult(PointSetTypes.CannotSparklineDiscrete)
  ->E.R2.fmap(r => Continuous.getShape(r).ys->Sparklines.create())
