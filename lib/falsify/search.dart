import 'dart:core';

Iterable<BigInt> binarySearch(BigInt x) sync* {
  var current = BigInt.zero;
  var delta = x ~/ BigInt.two;

  while (delta > BigInt.one) {
    current += delta;

    delta = switch ((delta % BigInt.two).toInt()) {
      0 => delta ~/ BigInt.two,
      _ => delta ~/ BigInt.two + BigInt.one
    };

    yield current;
  }

  if (delta == BigInt.one) yield BigInt.one;
}
