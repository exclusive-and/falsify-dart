import 'dart:core';
import 'package:falsify/prelude.dart';

import '../gen.dart';
import '../sample.dart';
import '../shrink.dart';

Gen<Iterable<A>> list<A>(int len, Gen<A> gen) =>
    inRange(0, len).then((n) => keepMarked(mark(gen).replicateM(n)));

extension<A> on Marked<A> {
  Gen<Maybe<A>> selectKept() {
    return Gen.pure(this.$1)
        .ifS(this.$2.map((x) => Just(x)), Gen.pure(Nothing()));
  }
}

Gen<Iterable<A>> keepMarked<A>(Gen<Iterable<Marked<A>>> gen) => Gen((st) {
      final (marked, ls) = gen.runGen(st.left());
      final kept = marked.map((x) => x.selectKept());

      var gen1 = Gen.pure(Iterable<A>.empty());

      for (final mx in kept) {
        gen1 = mx.then((x) => gen1.then((xs) => switch (x) {
              Nothing() => Gen.pure(xs),
              Just(value: final x) => Gen.pure([x].followedBy(xs)),
            }));
      }

      final (ys, rs) = gen1.runGen(st.right());

      return (ys, st.combineShrunk(ls, rs));
    });
