import 'dart:core';
import 'package:falsify/splitmix.dart';

sealed class Sample {
  Sample(this.value);
  final BigInt value;
}

class Shrunk implements Sample {
  Shrunk(this.value);
  final BigInt value;
}

class NotShrunk implements Sample {
  NotShrunk(this.value);
  final BigInt value;
}

sealed class SampleTree {
  SampleTree(this.next, this.left, this.right);

  final Sample next;

  final SampleTree Function() left;
  final SampleTree Function() right;
}

class SampleTree1 implements SampleTree {
  SampleTree1(this.next, this.left, this.right);

  final Sample next;

  final SampleTree Function() left;
  final SampleTree Function() right;
}

class Minimal implements SampleTree {
  Minimal();

  final Sample next = Shrunk(BigInt.zero);

  final left = () => Minimal();
  final right = () => Minimal();
}

extension CombineShrunk on SampleTree {
  Iterable<SampleTree> combineShrunk(
      Iterable<SampleTree> ls, Iterable<SampleTree> rs) {
    final ls1 = switch (left()) {
      Minimal() => Iterable<SampleTree>.empty(),
      _ => ls.map(
          (l) => SampleTree1(this.next, () => l, this.right) as SampleTree),
    };

    final rs1 = switch (right()) {
      Minimal() => Iterable<SampleTree>.empty(),
      _ =>
        rs.map((r) => SampleTree1(this.next, this.left, () => r) as SampleTree),
    };

    return shortcut(ls1.followedBy(rs1));
  }
}

Iterable<SampleTree> shortcut(Iterable<SampleTree> st) {
  if (st.isEmpty) {
    return [];
  } else {
    return [Minimal() as SampleTree].followedBy(st);
  }
}

SampleTree fromPRNG(SplitMix prng) {
  final (l, r) = prng.split();
  final lazyLeft = () => fromPRNG(l);
  final lazyRight = () => fromPRNG(r);
  final sample = NotShrunk(prng.nextWord64().$1);
  return SampleTree1(sample, lazyLeft, lazyRight);
}
