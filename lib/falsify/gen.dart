import 'dart:core';
import 'package:falsify/prelude.dart';

import 'sample.dart';
import 'search.dart';
import 'shrink.dart' as falsify;

abstract interface class Gen<T> implements falsify.RunGen<T> {
  static Gen<T> pure<T>(T x) => PureGen(x);

  static Gen<Sample> primWith(Iterable<BigInt> Function(Sample) f) =>
      PrimGen(f);

  static Gen<BigInt> prim() =>
      primWith((s) => binarySearch(s.value)).map((s) => s.value);
}

class FunctionalGen<A> implements Gen<A> {
  FunctionalGen(this._runGen);

  final (A, Iterable<SampleTree>) Function(SampleTree) _runGen;

  (A, Iterable<SampleTree>) runGen(SampleTree st) => _runGen(st);
}

class MapGen<A, B> implements Gen<B> {
  MapGen(this.mx, this.f);

  final Gen<A> mx;
  final B Function(A) f;

  (B, Iterable<SampleTree>) runGen(SampleTree st) {
    final (a, st1) = mx.runGen(st);
    return (f(a), st1);
  }
}

extension FunctorGen<A> on Gen<A> {
  Gen<B> map<B>(B Function(A) f) => MapGen(this, f);
}

class PureGen<A> implements Gen<A> {
  PureGen(this.x);

  final A x;

  (A, Iterable<SampleTree>) runGen(SampleTree st) => (x, []);
}

class ApGen<A, B> implements Gen<B> {
  ApGen(this.mx, this.mf);

  final Gen<A> mx;
  final Gen<B Function(A)> mf;

  (B, Iterable<SampleTree>) runGen(SampleTree st) {
    final (x, ls) = mx.runGen(st);
    final (f, rs) = mf.runGen(st);
    return (f(x), st.combineShrunk(ls, rs));
  }
}

class BindGen<A, B> implements Gen<B> {
  BindGen(this.mx, this.k);

  final Gen<A> mx;
  final Gen<B> Function(A) k;

  (B, Iterable<SampleTree>) runGen(SampleTree st) {
    final (a, ls) = mx.runGen(st.left());
    final (b, rs) = k(a).runGen(st.right());
    return (b, st.combineShrunk(ls, rs));
  }
}

extension MonadGen<A> on Gen<A> {
  Gen<B> bind<B>(Gen<B> Function(A) k) => BindGen(this, k);
}

class TraversalGen<A, B> implements Gen<Iterable<B>> {
  TraversalGen(this.tx, this.f);

  final Iterable<A> tx;
  final Gen<B> Function(A) f;

  (Iterable<B>, Iterable<SampleTree>) runGen(SampleTree st) {
    var st1 = st;
    var acc = List<(B, SampleTree, Iterable<SampleTree>)>.empty(growable: true);

    for (final x in tx) {
      final (y, ls) = f(x).runGen(st1.left());
      acc.add((y, st1, ls));
      st1 = st1.right();
    }
    ;

    var rs = Iterable<SampleTree>.empty();
    var ys = List<B>.empty(growable: true);

    for (final (y, st2, ls) in acc.reversed) {
      ys.add(y);
      rs = st2.combineShrunk(ls, rs);
    }

    return (ys, rs);
  }
}

extension TraverseGen<A> on Iterable<A> {
  Gen<Iterable<B>> traverse<B>(Gen<B> Function(A) f) => TraversalGen(this, f);
}

extension SequenceGen<A> on Iterable<Gen<A>> {
  Gen<Iterable<A>> sequence() => this.traverse((x) => x);
}

class SelectGen<A, B> implements Gen<B> {
  SelectGen(this.mx, this.mf);

  final Gen<Either<A, B>> mx;
  final Gen<B Function(A)> mf;

  (B, Iterable<SampleTree>) runGen(SampleTree st) {
    final (either, ls) = mx.runGen(st.left());
    switch (either) {
      case Left(left: final a):
        final (f, rs) = mf.runGen(st.right());
        return (f(a), st.combineShrunk(ls, rs));
      case Right(right: final b):
        return (b, st.combineShrunk(ls, []));
    }
  }
}

extension SelectiveGen<A, B> on Gen<Either<A, B>> {
  Gen<B> select(Gen<B Function(A)> mf) => SelectGen(this, mf);

  Gen<C> branch<C>(Gen<C Function(A)> l, Gen<C Function(B)> r) => this
      .map<Either<A, Either<B, C>>>((ab) => ab.map((b) => Left(b)))
      .select(l.map((f) => (a) => Right(f(a))))
      .select(r);
}

class ChoiceGen<A> implements Gen<A> {
  ChoiceGen(this.mb, this.mx, this.my);

  final Gen<bool> mb;
  final Gen<A> mx;
  final Gen<A> my;

  (A, Iterable<SampleTree>) runGen(SampleTree st) {
    final (b, ls) = mb.runGen(st.left());
    final right = st.right();
    if (b) {
      final (x, rs) = mx.runGen(right.left());
      return (x, st.combineShrunk(ls, right.combineShrunk(rs, [])));
    } else {
      final (y, rs) = my.runGen(right.right());
      return (y, st.combineShrunk(ls, right.combineShrunk(rs, [])));
    }
  }
}

extension SelectiveIfGen on Gen<bool> {
  Gen<A> ifS<A>(Gen<A> t, Gen<A> f) => ChoiceGen(this, t, f);
}

class ShrinkToOneOfGen<A> implements Gen<A> {
  ShrinkToOneOfGen(this.x, this.xs);

  final A x;
  final List<A> xs;

  (A, Iterable<SampleTree>) runGen(SampleTree st) => switch (st.next) {
        Shrunk(value: final i) => (xs[i.toInt()], []),
        NotShrunk(value: _) => (
            x,
            [
              for (int i = 0; i < xs.length; i++)
                SampleTree1(Shrunk(BigInt.from(i)), st.left, st.right)
            ]
          ),
      };
}

Gen<A> shrinkToOneOf<A>(A x, Iterable<A> xs) =>
    ShrinkToOneOfGen(x, xs.toList());

Gen<A> firstThen<A>(A x, A y) => shrinkToOneOf(x, [y]);

class BoolGen implements Gen<bool> {
  BoolGen(this.target);

  final bool target;

  (bool, Iterable<SampleTree>) runGen(SampleTree st) {
    final s = st.next;
    final b = s.value.toSigned(64).toInt() < 0 ? !target : target;
    switch (s) {
      case Shrunk(value: final x) when x == BigInt.zero:
        return (target, []);
      case _:
        return (b, [SampleTree1(Shrunk(BigInt.zero), st.left, st.right)]);
    }
  }
}

Gen<bool> genBool(bool target) => BoolGen(target);

Gen<A> choose<A>(Gen<A> mx, Gen<A> my) => genBool(true).ifS(mx, my);

class PrimGen implements Gen<Sample> {
  PrimGen(this.shrink);

  final Iterable<BigInt> Function(Sample) shrink;

  (Sample, Iterable<SampleTree>) runGen(SampleTree st) {
    final s = st.next;
    return (
      s,
      this.shrink(s).map((t) => SampleTree1(Shrunk(t), st.left, st.right))
    );
  }
}

class RangeGen implements Gen<BigInt> {
  RangeGen(this.min, this.max);

  final BigInt min;
  final BigInt max;

  (BigInt, Iterable<SampleTree>) runGen(SampleTree st) {
    final step = max - min;
    final precision = step.bitLength;

    final factor = BigInt.two.pow(precision);
    final s = st.next.value & (factor - BigInt.one);

    final shrinks =
        binarySearch(s).map((t) => SampleTree1(Shrunk(t), st.left, st.right));

    return (min + ((s * step) ~/ factor), shrinks);
  }
}

Gen<BigInt> inBigRange(BigInt a, BigInt b) => RangeGen(a, b);

Gen<int> inRange(int a, int b) =>
    inBigRange(BigInt.from(a), BigInt.from(b)).map((x) => x.toInt());

typedef Marked<A> = ({bool getMark, Gen<A> unmark});

Gen<Marked<A>> mark<A>(Gen<A> gen) =>
    firstThen(true, false).map((b) => (getMark: b, unmark: gen));

Gen<Maybe<A>> keepIfMarked<A>(Marked<A> marked) => Gen.pure(marked.getMark)
    .ifS(marked.unmark.map(Just.new), Gen.pure(Nothing()));

class ListGen<A> implements Gen<Iterable<A>> {
  ListGen(this.length, this.gen);

  final int length;
  final Gen<A> gen;

  (Iterable<A>, Iterable<SampleTree>) runGen(SampleTree st) {
    final (len, ls) = inRange(0, length).runGen(st.left());

    final gen1 = List.filled(len, mark(gen)).sequence();
    final gen2 = gen1.bind((g) => g.traverse(keepIfMarked)).map(catMaybes);
    final (xs, rs) = gen2.runGen(st.right());

    return (xs, st.combineShrunk(ls, rs));
  }
}

extension ReplicateGen<A> on Gen<A> {
  Gen<Iterable<A>> replicate(int len) => ListGen(len, this);
}
