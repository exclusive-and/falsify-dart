import 'dart:core';
import 'package:falsify/prelude.dart';
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
    return shortcut(concat([
      if (this.left() is Minimal)
        []
      else
        ls.map((l) => SampleTree1(this.next, () => l, this.right)),
      if (this.right() is Minimal)
        []
      else
        rs.map((r) => SampleTree1(this.next, this.left, () => r))
    ]));
  }

  static Iterable<SampleTree> shortcut(Iterable<SampleTree> st) {
    if (st.isEmpty) {
      return [];
    } else {
      return concat([
        [Minimal()],
        st
      ]);
    }
  }
}

SampleTree fromPRNG(SplitMix prng) {
  final (l, r) = prng.split();
  final lazyLeft = () => fromPRNG(l);
  final lazyRight = () => fromPRNG(r);
  final sample = NotShrunk(prng.nextWord64());
  return SampleTree1(sample, lazyLeft, lazyRight);
}

void main() {
  final rng = SplitMix.fromSeed(BigInt.from(0));

  final st0 = fromPRNG(rng);
  final st1 = st0.left();
  final st2 = st0.right();

  print(st0.next.value);
  print(st1.next.value);
  print(st2.next.value);

  final st3 = st1.right();

  print(st3.next.value);
}
