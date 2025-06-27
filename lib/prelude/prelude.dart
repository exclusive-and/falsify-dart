import 'dart:core';

/// [Maybe] algebraic data type.

sealed class Maybe<A> {
  static Maybe<A> pure<A>(A x) => Just(x);
}

class Nothing<A> implements Maybe<A> {}

class Just<A> implements Maybe<A> {
  Just(this.value);
  final A value;
}

extension FunctorMaybe<A> on Maybe<A> {
  Maybe<B> map<B>(B Function(A) f) => switch (this) {
        Nothing() => Nothing(),
        Just(value: final a) => Just(f(a)),
      };
}

extension ApplicativeMaybe<A> on Maybe<A> {
  Maybe<B> ap<B>(Maybe<B Function(A)> mf) =>
      this.bind((a) => mf.bind((f) => Just(f(a))));
}

extension MonadMaybe<A> on Maybe<A> {
  Maybe<B> bind<B>(Maybe<B> Function(A) k) => switch (this) {
        Nothing() => Nothing(),
        Just(value: final a) => k(a),
      };
}

/// [Either] algebraic data type.

sealed class Either<A, B> {}

class Left<A, B> implements Either<A, B> {
  Left(this.left);
  final A left;
}

class Right<A, B> implements Either<A, B> {
  Right(this.right);
  final B right;
}

extension FunctorEither<A, B> on Either<A, B> {
  Either<A, C> map<C>(C Function(B) f) => switch (this) {
        Left(left: final a) => Left(a),
        Right(right: final b) => Right(f(b)),
      };
}

extension ApplicativeEither<A, B> on Either<A, B> {
  Either<A, C> ap<C>(Either<A, C Function(B)> mf) =>
      this.bind((a) => mf.bind((f) => Right(f(a))));
}

extension MonadEither<A, B> on Either<A, B> {
  Either<A, C> bind<C>(Either<A, C> Function(B) k) => switch (this) {
        Left(left: final a) => Left(a),
        Right(right: final b) => k(b),
      };
}

/// Concatenate lists together.

Iterable<A> concat<A>(Iterable<Iterable<A>> xss) => xss.bind((x) => x);

extension MonadList<A> on Iterable<A> {
  Iterable<B> bind<B>(Iterable<B> Function(A) k) => this.expand(k);
}

///

Iterable<A> catMaybes<A>(Iterable<Maybe<A>> xs) sync* {
  final it = xs.iterator;
  while (it.moveNext()) {
    switch (it.current) {
      case Nothing():
        continue;
      case Just(value: final x):
        yield x;
    }
  }
}

/// Zip a pair of lists elementwise into a list of pairs.

Iterable<(A, B)> zip<A, B>(Iterable<A> xs, Iterable<B> ys) sync* {
  final iterators = [xs.iterator, ys.iterator];
  while (iterators.every((iterator) => iterator.moveNext())) {
    yield (xs.first, ys.first);
  }
}

extension ScatterGather<A> on List<A> {
  /// Gather the elements at each of the provided indices.

  Iterable<A> gather(Iterable<int> indices) =>
      indices.map((index) => this[index]);

  /// Create a copy of this list, with the elements at each index substituted
  /// for an element from the other list.
  ///
  /// Indices must be in ascending order.

  Iterable<A> scatter(Iterable<A> other, Iterable<int> indices) {
    var ys = List<A>.from(this);
    zip(indices, other).forEach((x) => ys[x.$1] = x.$2);
    return ys;
  }
}

/// Haskell-ish prototypical definitions for [Functor], [Applicative], and
/// [Monad].
///
/// Without HKTs and typeclasses, we can't properly implement instances of
/// these concretely. Instead, we implement extension methods that mirror the
/// spiritual type laws described here. See [Maybe] and [Either].
///
/// There's also the Selective typeclass, but it requires HKTs to even be
/// expressed in a single definition.
///
/// These definitions are here solely to serve as rough outlines or templates.

mixin Functor<A> {
  Functor<B> map<B>(B Function(A) f);
}

mixin Applicative<A> implements Functor<A> {
  Applicative<B> pure<B>(B x);
  Applicative<B> ap<B>(covariant Applicative<B Function(A)> mf);
}

mixin Monad<A> implements Applicative<A> {
  Monad<B> bind<B>(covariant Monad<B> Function(A));

  Monad<B> map<B>(B Function(A) f) => this.bind((a) => pure(f(a)) as Monad<B>);

  Monad<B> ap<B>(covariant Monad<B Function(A)> mf) =>
      this.bind((a) => mf.bind((f) => pure(f(a)) as Monad<B>));
}
