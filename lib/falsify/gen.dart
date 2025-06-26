import 'dart:core';
import 'package:falsify/prelude.dart';
import 'sample.dart';
import 'search.dart';

class Gen<A> {
  Gen(this.runGen);

  final (A, Iterable<SampleTree>) Function(SampleTree) runGen;

  static Gen<A> pure<A>(A x) => Gen((_) => (x, []));
}

extension FunctorGen<A> on Gen<A> {
  Gen<B> map<B>(B Function(A) f) => Gen((st0) {
        final (a, st1) = this.runGen(st0);
        return (f(a), st1);
      });
}

extension ApplicativeGen<A> on Gen<A> {
  Gen<B> ap<B>(Gen<B Function(A)> mf) => this.then((x) => mf.map((f) => f(x)));

  Gen<Iterable<A>> replicateM(int n) {
    var gen = Gen.pure<Iterable<A>>([]);
    for (int i = 0; i < n; i++) {
      gen = liftA2(this, gen, (x, xs) => [x].followedBy(xs));
    }
    return gen;
  }
}

Gen<C> liftA2<A, B, C>(Gen<A> ma, Gen<B> mb, C Function(A, B) f) =>
    ma.then((a) => mb.then((b) => Gen.pure(f(a, b))));

extension MonadGen<A> on Gen<A> {
  Gen<B> then<B>(Gen<B> Function(A) k) => Gen((st) {
        final (a, ls) = this.runGen(st.left());
        final (b, rs) = k(a).runGen(st.right());
        return (b, st.combineShrunk(ls, rs));
      });
}

extension SelectiveGen<A, B> on Gen<Either<A, B>> {
  Gen<B> select(Gen<B Function(A)> mf) => Gen((st) {
        final (either, ls) = this.runGen(st.left());
        switch (either) {
          case Left(left: final a):
            final (f, rs) = mf.runGen(st.right());
            return (f(a), st.combineShrunk(ls, rs));
          case Right(right: final b):
            return (b, st.combineShrunk(ls, []));
        }
      });

  Gen<C> branch<C>(Gen<C Function(A)> l, Gen<C Function(B)> r) => this
      .map<Either<A, Either<B, C>>>((ab) => ab.map((b) => Left(b)))
      .select(l.map((f) => (a) => Right(f(a))))
      .select(r);
}

extension SelectiveIfGen on Gen<bool> {
  Gen<A> ifS<A>(Gen<A> t, Gen<A> f) => this
      .map<Either<(), ()>>((x) => x ? Left(()) : Right(()))
      .branch(t.map((x) => (y) => x), f.map((x) => (y) => x));
}

Gen<Sample> primWith(Iterable<BigInt> Function(Sample) f) => Gen((st) {
      final s = st.next;
      return (s, f(s).map((s1) => SampleTree1(Shrunk(s1), st.left, st.right)));
    });

final prim = primWith((s) => binarySearch(s.value)).map((s) => s.value);

typedef Precision = int;

typedef WordN = ({Precision precision, BigInt word});

WordN truncateAt(Precision p, BigInt x) =>
    (precision: p, word: x & (BigInt.two.pow(p) - BigInt.one));

Gen<WordN> wordN(Precision p) =>
    primWith((s) => binarySearch(truncateAt(p, s.value).word))
        .map((s) => truncateAt(p, s.value));

Gen<BigInt> inBigRange(BigInt a, BigInt b) {
  final p = (b - a).bitLength;
  return wordN(p).map((s) => a + ((s.word * (b - a)) ~/ BigInt.two.pow(p)));
}

Gen<int> inRange(int a, int b) =>
    inBigRange(BigInt.from(a), BigInt.from(b)).map((n) => n.toInt());
