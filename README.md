# Stealth ABBE: Attribute-Based Broadcast Encryption (Magma Verification Prototype)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23824328.svg)](https://doi.org/10.5281/zenodo.23824328)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![Magma Compatible](https://img.shields.io/badge/Language-Magma%20V2.29--10-blue.svg)](http://magma.maths.usyd.edu.au/)
[![Code Rate](https://img.shields.io/badge/Code%20Rate-R%3D0.75-green.svg)]()

**Stealth ABBE** is a provably secure Attribute-Based Broadcast Encryption framework combining homomorphic ElGamal encryption with non-systematic Reed-Solomon error-correcting codes and a two-tier cryptographic revocation mechanism.

This repository contains the full algebraic verification prototype and benchmarking suite implemented for the **Magma Computational Algebra System**. The core verification script (`stealth-abbe-GT.m`) executes over the cyclotomic target subgroup 𝔾<sub><i>T</i></sub> ⊂ 𝔽*<sub><i>p</i><sup>12</sup></sub><sup></sup> of the **BLS12-381** pairing-friendly elliptic curve, featuring cost-free Frobenius conjugation, carry-free Base-3 homomorphic packing, non-systematic MDS coding, and Tier-1 cover-free revocation. Additionally, `benchmark-GT-LUT-vs-Kangaroo.m` provides an empirical comparison of memory-computation trade-offs for short-interval discrete logarithm extraction.

### Benchmark: Short-Interval DLP Extraction in 𝔾<sub><i>T</i></sub> ⊂ 𝔽*<sub><i>p</i><sup>12</sup></sub><sup></sup>

Evaluated on BLS12-381 for <i>η</i> = 8 (<i>Z</i> ∈ [0, 13120], <i>N</i><sub>blk</sub> = 256 blocks per <i>C</i><sub>RS</sub>[256, 192, 65]<sub>256</sub> broadcast frame):

| Metric | Variant 1: Direct Full LUT | Variant 2: 64-Bit Prefix LUT (L1/L2 Cache) | Variant 3: Kangaroo (Distinguished Points) |
| :--- | :---: | :---: | :---: |
| **Stored Table Entries** | `13,121` | `13,121` (Collision-free) | `244` (<i>D</i><sub>mod</sub> = 57) |
| **Entry Size** | `580 B` (Full 𝔽<sub><i>p</i><sup>12</sup></sub>) | **`10 B`** (`8B` Key + `2B` Index) | `580 B` (Full 𝔽<sub><i>p</i><sup>12</sup></sub>) |
| **Memory Footprint (SI / IEC)** | `7.61 MB` (`7.26 MiB`) | **`131.2 KB` (`128.1 KiB`)** | `141.5 KB` (`138.2 KiB`) |
| **Memory Reduction Factor** | `1.0x` (Baseline) | **`58.0x smaller`** | `53.8x smaller` |
| **Offline Precomputation Time** | `0.540 sec` | `0.590 sec` | `0.580 sec` |
| **Avg. 𝔽<sub><i>p</i><sup>12</sup></sub> Muls / Block** | `0` (<i>O</i>(1) Lookup) | **`0` (<i>O</i>(1) Prefix Lookup)** | `93.0 muls` |
| **Online Time per Block** | `0.0020 ms` | **`0.0039 ms`** | `4.258 ms` |
| **Online Time per 256B Frame** | `0.0005 sec` | **`0.0010 sec`** | `1.090 sec` |
| **Exact Frame Recovery** | `true` (`256/256`) | `true` (`256/256`) | `true` (`256/256`) |

---

## 🚀 Key Architectural Features

1. **Non-Systematic Reed-Solomon Puncturing Defense (Rate *R* = 0.75):**
   * Employs an extended [256, 192, 65]<sub>256</sub> code over GF(256) with a punctured syndrome decoder radius of ℵ = 31 symbol errors (32 on the full MDS code).
   * Utilizes a non-systematic scrambling matrix *S* ∈ GL(192, GF(256)) to provide a robust MDS puncturing margin (*δ* = 64 bytes), neutralizing direct linear matrix inversion attacks.

2. **Two-Tier Revocation Strategy:**
   * **Tier-1 (Intra-Epoch Zero-Latency Revocation):** Implements a cover-free family of clean windows *W* of size *w* = 16 bytes within a revocation sub-block (*M* = 48 bytes), with bounded pairwise intersection Δ ≤ 4 bytes and baseline cohort error weight *τ* = 27 bytes. Enables instant user blacklisting via targeted broadcast perturbations.
   * **Tier-2 (Inter-Epoch Hard Reset):** Global cohort blocker (**w**) and session mask (**m**) rotation ensuring long-term cryptographic hygiene and history purging.

3. **Cyclotomic ElGamal Engine (BLS12-381):**
   * Block-wise additive ElGamal aggregation over BLS12-381 using carry-free Base-3 scalar embedding with ternary weights 3<sup>0</sup>, 3<sup>1</sup>, ..., 3<sup>7</sup> (<i>η</i> = 8, max scalar <i>Z</i> = 13120).
   * Implements split-key pairing projection cancelled via fast cyclotomic inversion using Frobenius conjugation (<i>A</i><sup>−1</sup> = <i>A</i><sup><i>p</i><sup>6</sup></sup>), followed by <i>O</i>(1) lookup-table (LUT) or Kangaroo short-interval discrete logarithm recovery.

4. **Two-Layer Collusion Resistance:**
   * **Base-3 Carry Avalanche:** Homomorphic aggregation of *T* ≥ 3 ciphertexts in 𝔾<sub><i>T</i></sub> triggers inter-digit ternary carries (3 = 10<sub>3</sub>, 4 = 11<sub>3</sub>), causing a catastrophic 256 / 256-byte decoding failure.
   * **Combinatorial Error Amplification:** Same-attribute odd coalitions (*T* = 3) attempting direct algebraic combination in GF(256) encounter an enforced error weight of ~43.8 bytes > *J*(128, 64) = 38, strictly exceeding both the unique decoding radius and the Johnson list-decoding bound.

---

## 🛠️ Repository Structure

- `stealth-abbe-GT.m` — Standalone end-to-end Magma verification script containing:
  * BLS12-381 𝔾<sub><i>T</i></sub> ⊂ 𝔽<sub><i>p</i><sup>12</sup></sub><sup>*</sup> domain setup, Frobenius conjugation, and <i>O</i>(1) Short-Interval DLP lookup table (LUT) generator (13,121 entries).
  * Non-systematic RS [256, 192, 65]<sub>256</sub> encoder and guarded syndrome decoder.
  * Cover-free clean window geometry verifier (*M* = 48, *w* = 16, Δ = 4).
  * Complete execution scenarios (Authorized decrypt, Tier-1 revocation, Algebraic & Homomorphic Odd Collusion *T* = 3 defeat, Even Collusion *T* = 2 mask annihilation failure).

- `benchmark-GT-LUT-vs-Kangaroo.m` — Memory-computation trade-off benchmarking script evaluating:
  * Variant 1: Direct uncompressed <i>O</i>(1) LUT (13,121 entries, 7.61 MB / 7.26 MiB).
  * Variant 2: Compressed 64-bit prefix <i>O</i>(1) LUT (13,121 entries, 131.2 KB / 128.1 KiB, 58.0× smaller memory footprint, L1/L2 cache-resident).
  * Variant 3: Distinguished Points / Kangaroo search (244 entries, 141.5 KB / 138.2 KiB, 53.8× smaller memory footprint).
  * Head-to-head online extraction timing across a full 256-block RS frame.

---

## ⚙️ Getting Started & Verification

To run the reference prototype and verify all security scenarios, open your Magma environment (or the Magma Online Calculator) and execute:

```magma
load "stealth-abbe-GT.m";
load "benchmark-GT-LUT-vs-Kangaroo.m";
```

### Expected Output Summary:

`stealth-abbe-GT.m`:

```text
=== STEALTH ABBE PROTOTYPE SETUP (Magma Online Calculator) ===
Building O(1) Short-Interval DLP LUT (Max Z = 13120)...
Domain & Non-Systematic RS Setup completed in 0.180 sec.

--- VERIFYING TIER-1 CLEAN WINDOW GEOMETRY ---
  |W_1 cap W_2| = 4 (<= Delta_int = 4)
  |W_1 cap W_3| = 4 (<= Delta_int = 4)
  |W_1 cap W_4| = 4 (<= Delta_int = 4)
  |W_2 cap W_3| = 4 (<= Delta_int = 4)
  |W_2 cap W_4| = 4 (<= Delta_int = 4)
  |W_3 cap W_4| = 4 (<= Delta_int = 4)

Provisioning 4 Cohort Participants via simulated DKG/MPC...
Provisioning completed in 0.110 sec.

=== SCENARIO 1: BASELINE BROADCAST TO AUTHORIZED COHORT ===
  [U_1 Authorized] RS Decode: true | Error Weight wt(e_1) = 27 (<= aleph = 31) | Payload Match: true (0.050 sec)

=== SCENARIO 2: TIER-1 INTRA-EPOCH REVOCATION (TARGETING U_2) ===
  [U_2 REVOKED]    RS Decode: false | Error Weight wt(e_2) = 39 (> aleph = 31) -> ACCESS BLOCKED!
  [U_1 LEGITIMATE] RS Decode: true  | Error Weight wt(e_1) = 31 (<= aleph = 31) | Payload Match: true

=== SCENARIO 3A: ALGEBRAIC ODD COALITION (T = 3) OVER GF(256) ===
  Left 128B Error (w, m canceled): 0
  Semantic Attribute 80B Error:    0 (identical attributes!)
  Tier-1 Revocation 48B Error:     43 (> J(128,64) = 38 & aleph = 31)
  Algebraic Coalition RS Decode:   false -> COLLUSION DEFEATED BY TIER-1!

=== SCENARIO 3B: HOMOMORPHIC ODD COALITION (T = 3) IN G_1 (BASE-3 CARRY OVERFLOW) ===
  Total 256B Error Weight (Base-3 Carry Avalanche): 256 / 256 | RS Decode: false

=== SCENARIO 4: EVEN COALITION (T = 2) MASK ANNIHILATION FAILURE ===
  Total 256B Error Weight (Unmasked w, m): 255 / 256 | RS Decode: false
```
`benchmark-GT-LUT-vs-Kangaroo.m`:

```text
=== INITIALIZING BLS12-381 TARGET GROUP G_T subset F_{p^12}^* ===
Group G_T initialized in 0.190 sec (Max scalar Z = 13120).

=== VARIANT 1: DIRECT UNCOMPRESSED O(1) LUT IN F_{p^12}^* ===
  Precomputation Time:   0.540 sec
  Stored Table Entries:  13121 entries (580 B/entry)
  Memory Footprint:      7.61 MB (7.26 MiB)

=== VARIANT 2: COMPRESSED 64-BIT PREFIX O(1) LUT (L1/L2 CACHE-RESIDENT) ===
  Precomputation Time:   0.590 sec
  Stored Table Entries:  13121 entries (10 B/entry: 8B prefix + 2B index)
  64-Bit Collision-Free: true (Unique prefixes: 13121 / 13121)
  Memory Footprint:      131.2 KB (128.1 KiB)

=== VARIANT 3: DISTINGUISHED POINTS (KANGAROO) IN F_{p^12}^* ===
  Precomputation Time:   0.580 sec
  Stored DP Entries:     244 entries (Theoretical 2*sqrt(13120) ~ 229)
  Memory Footprint:      141.5 KB (138.2 KiB)

=== GENERATING 256 RANDOM TEST TARGETS g_T^(z_t) IN [0, 13120] ===

========================================================================================================
          SUMMARY BENCHMARK: DLP IN F_{p^12}^* (eta = 8, Z in [0, 13120], 256 Blocks = 1 Frame)
========================================================================================================
Metric                           | Direct Full LUT      | 64-Bit Prefix LUT    | Kangaroo (DP Variant)
--------------------------------------------------------------------------------------------------------
Stored Table Entries             | 13121                | 13121                | 244
Entry Size (Bytes)               | 580 B (Full F_p^12)  | 10 B (8B Key+2B Idx) | 580 B (Full F_p^12)
Memory Footprint (Decimal SI)    | 7.61 MB              | 131.2 KB             | 141.5 KB
Memory Footprint (Binary IEC)    | 7.26 MiB             | 128.1 KiB            | 138.2 KiB
Memory Reduction vs. Full LUT    | 1.0x (Baseline)      | 58.0x smaller        | 53.8x smaller
Offline Precomputation Time      | 0.540 sec            | 0.590 sec            | 0.580 sec
Avg F_{p^12} Muls / Block        | 0 (O(1) Hash Lookup) | 0 (O(1) Prefix Hash) | 93.0 muls
Online Time per Block (ms)       | 0.0020 ms            | 0.0039 ms            | 4.258 ms
Online Time per 256B Frame (sec) | 0.0005 sec           | 0.0010 sec           | 1.090 sec
Exact Recovery (256/256 blocks)  | true                 | true                 | true
========================================================================================================
```

### 📚 Academic Citation

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23677112.svg)](https://doi.org/10.5281/zenodo.23677112)

If you utilize these scripts in your research, please cite the associated archive and preprint:

```bibtex
@misc{chmora2026stealthabbe,
  author       = {Andrey L. Chmora},
  title        = {Stealth ABBE: Carry-Free Homomorphic Packing and Blind Reed–Solomon Decoding},
  month        = {Oct},
  year         = {2026},
  publisher    = {Zenodo},
  doi          = {10.5281/zenodo.23677112},
  url          = {https://doi.org/10.5281/zenodo.23677112}
}
```
