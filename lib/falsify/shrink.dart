import 'dart:core';

import 'sample.dart';

abstract interface class RunGen<T> {
  (T, Iterable<SampleTree>) runGen(SampleTree st);
}

Explanation<P, N> shrink<A, P, N>(RunGen<A> gen, int limit,
    (P, Iterable<SampleTree>) start, IsValidShrink<P, N> Function(A) prop) {
  var history = List<P>.empty(growable: true);

  final greedy = (Iterable<SampleTree> xs) {
    final candidates = xs.map((st) => gen.runGen(st));

    var counterexamples = List<N>.empty(growable: true);

    for (final (a, shrunk) in candidates) {
      switch (prop(a)) {
        case InvalidShrink(counterexample: final n):
          counterexamples.add(n);
        case ValidShrink(shrunk: final p):
          history.add(p);
          return ShrunkTo<P, N>(p, shrunk);
      }
    }

    return DoneShrinking<P, N>(counterexamples);
  };

  final go = (Iterable<SampleTree> shrunk) {
    while (!shrunk.isEmpty && limit > 0) {
      limit--;
      switch (greedy(shrunk)) {
        case DoneShrinking(counterexamples: final ns):
          return ns;
        case ShrunkTo(value: _, shrunk: final shrunk1):
          shrunk = shrunk1;
      }
    }
    return List<N>.empty();
  };

  final (initial, shrunk) = start;
  final counterexamples = go(shrunk);

  return Explanation(initial, history, counterexamples);
}

class Explanation<P, N> {
  Explanation(this.initial, this.history, this.counterexamples);

  final P initial;
  final List<P> history;
  final List<N> counterexamples;
}

sealed class IsValidShrink<P, N> {}

class ValidShrink<P, N> implements IsValidShrink<P, N> {
  ValidShrink(this.shrunk);
  final P shrunk;
}

class InvalidShrink<P, N> implements IsValidShrink<P, N> {
  InvalidShrink(this.counterexample);
  final N counterexample;
}

sealed class ShrinkStep<P, N> {}

class DoneShrinking<P, N> implements ShrinkStep<P, N> {
  DoneShrinking(this.counterexamples);
  final List<N> counterexamples;
}

class ShrunkTo<P, N> implements ShrinkStep<P, N> {
  ShrunkTo(this.value, this.shrunk);

  final P value;
  final Iterable<SampleTree> shrunk;
}

/*
Gen<A> shrinkToOneOf<A>(A x, List<A> xs) {
  Iterable<BigInt> shrinker(Sample x) => switch (x) {
        Shrunk(value: _) => [],
        NotShrunk(value: _) => [
            for (int i = 0; i < xs.length; i++) BigInt.from(i)
          ]
      };

  A aux(Sample i) => switch (i) {
        Shrunk(value: final i) => xs[i.toInt()],
        NotShrunk(value: _) => x
      };

  return primWith(shrinker).map(aux);
}

Gen<A> firstThen<A>(A x, A y) => shrinkToOneOf(x, [y]);

typedef Marked<A> = (bool, Gen<A>);

Gen<Marked<A>> mark<A>(Gen<A> gen) =>
    firstThen(true, false).map((marked) => (marked, gen));
*/
