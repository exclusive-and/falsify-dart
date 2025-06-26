import 'dart:core';

/// A splittable pseudorandom number generator (PRNG) that is quite fast.

class SplitMix {
  SplitMix(this.seed, this.gamma);

  BigInt seed;
  final BigInt gamma;

  /// Generate a psuedorandom 64-bit integer.

  BigInt nextWord64() {
    this.seed = maskU64 & (this.seed + gamma);
    return mix64(seed);
  }

  /// Split the PRNG into two uncorrelated PRNGs.

  (SplitMix, SplitMix) split() {
    final seed1 = maskU64 & (seed + gamma);
    final seed2 = maskU64 & (seed1 + gamma);
    return (SplitMix(seed2, gamma), SplitMix(mix64(seed1), mixGamma(seed2)));
  }

  /// Create a PRNG using an exact seed and gamma. Ensures that gamma is always odd.

  SplitMix.exactly(BigInt seed, BigInt gamma)
      : this.seed = seed,
        this.gamma = gamma | BigInt.from(1);

  static final goldenGamma = BigInt.from(0x9e3779b97f4a7c15).toUnsigned(64);

  /// Create a PRNG from just a seed.

  SplitMix.fromSeed(BigInt seed)
      : this.seed = mix64(seed),
        this.gamma = mixGamma(maskU64 & (seed + goldenGamma));

  /// Create a PRNG seeded by the host clock's current POSIX time.

  static SplitMix posix() =>
      SplitMix.fromSeed(BigInt.from(DateTime.now().microsecondsSinceEpoch));
}

BigInt mix64(BigInt z0) {
  final z1 = shiftXorMultiply(33, BigInt.from(0xff51afd7ed558ccd), z0);
  final z2 = shiftXorMultiply(33, BigInt.from(0xc4ceb9fe1a85ec53), z1);
  final z3 = shiftXor(33, z2);
  return z3;
}

BigInt mix64variant13(BigInt z0) {
  final m1 = BigInt.from(0xbf58476d1ce4e5b9).toUnsigned(64);
  final m2 = BigInt.from(0x94d049bb133111eb).toUnsigned(64);

  final z1 = shiftXorMultiply(30, m1, z0);
  final z2 = shiftXorMultiply(27, m2, z1);
  final z3 = shiftXor(31, z2);
  return z3;
}

BigInt mixGamma(BigInt z0) {
  final m1 = BigInt.from(0xaaaaaaaaaaaaaaaa).toUnsigned(64);

  final z1 = mix64variant13(z0) | BigInt.from(0x1);
  final n = popCount64(z1 ^ (z1 >> 1));
  return n >= BigInt.from(24) ? z1 : z1 ^ m1;
}

BigInt shiftXor(int n, BigInt w) => w ^ (w >> n);

BigInt shiftXorMultiply(int n, BigInt k, BigInt w) =>
    maskU64 & (shiftXor(n, w) * k);

/// Compute the number of ones in the 64-bit binary encoding of an integer. This is also known
/// as the population count or the Hamming weight of a number.

BigInt popCount64(BigInt x) {
  final m1 = BigInt.from(0x5555555555555555).toUnsigned(64);
  final m2 = BigInt.from(0x3333333333333333).toUnsigned(64);
  final m4 = BigInt.from(0x0f0f0f0f0f0f0f0f).toUnsigned(64);

  x = maskU64 & (x - ((x >> 1) & m1));
  x = maskU64 & ((x & m2) + ((x >> 2) & m2));
  x = maskU64 & ((x + (x >> 4)) & m4);
  x = maskU64 & (x + (x >> 8));
  x = maskU64 & (x + (x >> 16));
  x = maskU64 & (x + (x >> 32));
  return x & BigInt.from(0x7f);
}

final maskU64 = BigInt.from(0xffffffffffffffff).toUnsigned(64);
