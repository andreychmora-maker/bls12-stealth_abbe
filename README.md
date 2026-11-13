# Stealth ABBE: Attribute-Based Broadcast Encryption (Magma Verification Prototype)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23824328.svg)](https://doi.org/10.5281/zenodo.23824328)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![Magma Compatible](https://img.shields.io/badge/Language-Magma%20V2.29--10-blue.svg)](http://magma.maths.usyd.edu.au/calc/)
[![Code Rate](https://img.shields.io/badge/Code%20Rate-R%3D0.75-green.svg)]()

**Stealth ABBE** is a provably secure Attribute-Based Broadcast Encryption framework combining additively homomorphic (exponential) ElGamal encryption with non-systematic Reed–Solomon error-correcting codes, monolithic KEM encapsulation, policy-scoped ephemeral half-radius blind noise, and a two-tier cryptographic revocation mechanism.

This repository contains the full algebraic verification prototype and benchmarking suite implemented for the **Magma Computational Algebra System**. The core verification script (`stealth-abbe-GT.m`) executes over the cyclotomic target subgroup 𝔾<sub><i>T</i></sub> ⊂ 𝔽*<sub><i>p</i><sup>12</sup></sub> of the **BLS12-381** pairing-friendly elliptic curve, featuring cost-free Frobenius conjugation, carry-free Base-3 homomorphic packing, non-systematic MDS coding, and Tier-1 cover-free quarantine with stream-seeded blind noise. Additionally, `benchmark-GT-LUT-vs-Kangaroo.m` provides an empirical comparison of memory-computation trade-offs for short-interval discrete logarithm extraction.

### Benchmark: Short-Interval DLP Extraction in 𝔾<sub><i>T</i></sub> ⊂ 𝔽*<sub><i>p</i><sup>12</sup></sub>

Evaluated on BLS12-381 for <i>η</i> = 8 (<i>Z</i> ∈ [0, 13120], <i>N</i><sub>blk</sub> = 256 blocks per <i>C</i><sub>RS</sub>[256, 192, 65]<sub>256</sub> broadcast frame, averaged over 10,000 trials):

| Metric | Variant 1: Direct Full LUT | Variant 2: 64-Bit Prefix LUT (L1/L2 Cache) | Variant 3: Kangaroo (Distinguished Points) |
| :--- | :---: | :---: | :---: |
| **Stored Table Entries** | `13,121` | `13,121` (Collision-free) | `242` (<i>D</i><sub>mod</sub> = 57) |
| **Entry Size** | `578 B` (`576B` 𝔽<sub><i>p</i><sup>12</sup></sub> + `2B` Index) | **`10 B`** (`8B` Key + `2B` Index) | `578 B` (`576B` 𝔽<sub><i>p</i><sup>12</sup></sub> + `2B` Index) |
| **Memory Footprint (SI / IEC)** | `7.58 MB` (`7.23 MiB`) | **`131.2 KB` (`128.1 KiB`)** | `139.9 KB` (`136.6 KiB`) |
| **Memory Reduction Factor** | `1.0x` (Baseline) | **`57.8x smaller`** | `54.2x smaller` |
| **Offline Precomputation Time** | `0.540 sec` | `0.580 sec` | `0.580 sec` |
| **Avg. 𝔽<sub><i>p</i><sup>12</sup></sub> Muls / Block** | `0` (<i>O</i>(1) Hash Lookup) | **`0` (<i>O</i>(1) Prefix Hash)** | `112.5 muls` |
| **Online Time per Block** | `0.0010 ms` | **`0.0044 ms`** | `5.039 ms` |
| **Online Time per 256B Frame** | `0.0003 sec` | **`0.0011 sec`** | `1.290 sec` |
| **Exact Frame Recovery** | `true` (`256/256`) | `true` (`256/256`) | `true` (`256/256`) |

---

## 🚀 Key Architectural Features

1. **Non-Systematic Reed–Solomon Puncturing Defense (Rate <i>R</i> = 0.75) & Monolithic KEM:**
   * Employs a non-systematic [255, 192, 64]<sub>256</sub> cyclic Reed–Solomon core embedded in a 256-byte container (<i>C</i><sub>RS</sub>[256, 192, 65]<sub>256</sub>) over GF(256) with a Berlekamp–Massey unique decoding radius of ℵ = 31 symbol errors.
   * Utilizes a dense invertible scrambling matrix <i>S</i> ∈ GL(192, GF(256)) to enforce a 64-byte MDS puncturing margin (<i>δ</i> = 64 bytes), neutralizing direct linear matrix inversion attacks.
   * Encapsulates the 256-bit session key (`κ̂_i`, 32B), SHA-256 integrity digest (`κ̃_i`, 32B), Broadcast Roster (`B`, 64B), session salt (`σ_i`, 16B), and compact Schnorr signature (`Σ_i`, 48B) into a single 192-byte monolithic payload (`κ_i`) with zero external header overhead.

2. **Policy-Scoped Ephemeral Half-Radius Blind Noise (<i>ξ<sub>i</sub></i>) & Support Overlap Bounds:**
   * **Support Intersection & Byte Cancellations:** To neutralize historical state-caching patches and inter-frame linear ciphertext addition (`c'_i + c'_j`), the broadcaster injects stream-seeded ephemeral blind noise (`wt(ξ_i) = wt(ξ_j) = 22`). Under inter-frame addition, the combined error weight is `wt(ξ_i + ξ_j) = 44 - s - c`, where `s` is the support intersection size (`s ~ Hypergeometric(N = 255, K = 22, n = 22)`, expected overlap `E[s] ≈ 1.898`) and `c` is the byte cancellation count over `GF(256)*` (`c ~ Binomial(s, 1/255)`).
   * **Exact Tail Probability:** Falling within the Berlekamp–Massey unique decoding radius (`wt(ξ_i + ξ_j) ≤ 31`) requires `s + c ≥ 13`. The exact single-pair collision probability over the 255-symbol cyclic RS core is:
     * Profile `wt(ξ_i) = 22, w_pol ≤ 9`: `Pr[wt(ξ_i + ξ_j) ≤ 31] = 2.30 × 10^-10 (≈ 2^-32.0)` (`≈ 2.19 × 10^-10 ≈ 2^-32.1` for `N = 256`).
     * Profile `wt(ξ_i) = 20, w_pol ≤ 11`: `Pr[wt(ξ_i + ξ_j) ≤ 31] = 2.38 × 10^-6 (≈ 2^-18.8)`.
   * **Error Budget & Fast-Path Bypass:** Active policy error budget `w_pol ≤ 9` combined with disjoint ephemeral noise `wt(ξ_i) = 22` satisfies `9 + 22 = 31 = ℵ`, guaranteeing single-pass blind decoding for legitimate clients. For clean policies (`ξ_i = 0`), a fast zero-syndrome check (`S = 0`) bypasses Berlekamp–Massey evaluation completely.

3. **Two-Tier Cryptographic Revocation Strategy:**
   * **Tier-1 (Intra-Epoch Zero-Latency Quarantine):** Implements a cover-free family of clean windows <i>W<sub>j</sub></i> within the revocation sub-block. In the stateless regime (<i>M</i> = 48B, <i>w</i><sub>clean</sub> = 16B, Δ<sub>int</sub> ≤ 4B, <i>τ</i><sub>coh</sub> = 27B), perturbing <i>w</i><sub>pert</sub> = 12B pushes the revoked user to `wt = 39 > J(128, 64) = 38 > ℵ = 31` while keeping legitimate cohort members at `wt ≤ 31`. In the active quarantine regime (`wt(ξ_i) = 22`, <i>τ</i><sub>sc</sub> = 8B, Δ<sub>int,sc</sub> = 1B, <i>w</i><sub>pert</sub> = 9B), legitimate users decode blindly at `wt = 31 ≤ 31`, whereas revoked users are blocked beyond the punctured Johnson bound both on direct decoding (`wt = 39 > 38`) and on state-cached differential patching (`wt = 47 > 38`).
   * **Tier-2 (Inter-Epoch Hard Reset):** Global cohort-isolating blocker (**w**) and blinding mask (**m**) rotation permanently evicts revoked credentials, reclaims the full decoding radius ℵ = 31, and resets `ξ_i = 0`.

4. **Cyclotomic ElGamal Engine (BLS12-381):**
   * Block-wise additive ElGamal aggregation over BLS12-381 using carry-free Base-3 scalar embedding with ternary weights 3<sup>0</sup>, 3<sup>1</sup>, ..., 3<sup>7</sup> (<i>η</i> = 8, max scalar <i>Z</i> = 13120).
   * Implements split-key pairing projection cancelled via cost-free cyclotomic inversion using Frobenius conjugation (<i>A</i><sup>−1</sup> = <i>A</i><sup><i>p</i><sup>6</sup></sup>), followed by <i>O</i>(1) lookup-table (LUT) or Kangaroo short-interval discrete logarithm recovery.

5. **Two-Layer Collusion Resistance:**
   * **Base-3 Carry Avalanche & Mask Preservation:** Homomorphic aggregation of odd (<i>T</i> = 3) or even (<i>T</i> = 2) coalitions in 𝔾<sub><i>T</i></sub> either triggers inter-digit ternary carries (3 = 10<sub>3</sub>, 4 = 11<sub>3</sub>) or leaves the global masks (**w**, **m**) uncancelled, causing a catastrophic `253 / 255`-symbol decoding failure.
   * **Combinatorial Error Amplification:** Same-attribute odd coalitions (<i>T</i> = 3) attempting direct algebraic combination in GF(256) encounter an enforced error weight of `43 > J(128, 64) = 38 > ℵ = 31`, strictly exceeding both the unique decoding radius and the punctured Guruswami–Sudan / Johnson list-decoding bound.

---

## 🛠️ Repository Structure

- `stealth-abbe-GT.m` — Standalone end-to-end Magma verification script containing:
  * BLS12-381 𝔾<sub><i>T</i></sub> ⊂ 𝔽*<sub><i>p</i><sup>12</sup></sub> domain setup, Frobenius conjugation, simulated DKG/MPC split-key provisioning, and <i>O</i>(1) Short-Interval DLP lookup table (LUT) generator (13,121 entries).
  * Non-systematic RS [255, 192, 64]<sub>256</sub> (in 256B container) encoder, zero-syndrome fast check (`S = 0`), and guarded Berlekamp–Massey decoder.
  * Monolithic KEM encapsulation and verification functions (`κ̂ || κ̃ || B || σ || Σ`).
  * Stream-seeded PRG generator for policy-scoped ephemeral half-radius blind noise (`ξ_i`).
  * Validated across `50,000` random frame pairs (`Theoretical E[s] = 1.898`, `Empirical Mean Overlap = 1.904`, `Empirical Minimum wt = 35 > 31`, `Collisions = 0`).
  * Cover-free clean window geometry verifier and 9 comprehensive verification scenarios:
    * **Scenarios 1–2:** Baseline authorized broadcast & stateless Tier-1 intra-epoch revocation (`wt = 39 > 31` vs. `wt = 31 ≤ 31`).
    * **Scenarios 3A, 3B & 4:** Algebraic odd coalition (`T = 3` in GF(256), `wt = 43 > 38`), homomorphic odd coalition (`T = 3` in 𝔾<sub><i>T</i></sub>, Base-3 carry avalanche `253 / 255`), and even coalition (`T = 2`, unmasked **w**, **m** `253 / 255`).
    * **Scenarios 5A–5B:** State-caching vulnerability reproduction on static Tier-1 (`ξ_i = 0`, `wt = 12 ≤ 31`) and complete mitigation via stream-seeded blind noise (`wt(ξ_i) = 22`, legitimate `U_1` decoded at `wt = 31 ≤ 31`, revoked `U_2` blocked at `wt = 39 > 38` direct and `wt = 47 > 38` patched).
    * **Scenarios 6–9:** Inter-frame linear addition defense (`c'_102 + c'_103`), full `κ_102` compromise resilience on target Frame 103, exact hypergeometric & 500-pair Monte Carlo overlap verification, and `S = 0` zero-syndrome fast-path bypass.

---

## ⚙️ Getting Started & Verification

To run the reference prototype and verify all security scenarios, open your Magma environment (or the [Magma Online Calculator](http://magma.maths.usyd.edu.au/calc/)) and execute:

```magma
load "stealth-abbe-GT.m";
load "benchmark-GT-LUT-vs-Kangaroo.m";
```

## Empirical Verification & Cryptanalytic Benchmark (`stealth-abbe-GT.m`)

The complete Stealth ABBE verification suite—including cyclotomic $\mathbb{G}_T \subset \mathbb{F}_{p^{12}}^*$ short-interval DLP extraction on BLS12-381, cover-free Tier-1 revocation windows, and $50{,}000$-pair Monte Carlo validation of $\boldsymbol{\xi}_i$—executes directly in the **Magma Online Calculator**.

### Console Output (`Magma V2.29`)

```text
=== STEALTH ABBE PROTOTYPE SETUP IN F_{p^12}^* (BLS12-381) ===
Building O(1) Short-Interval DLP LUT in F_{p^12}^* (Max Z = 13120, Entries = 13121)...
LUT in F_{p^12}^* constructed in 0.540 sec (Uncompressed footprint: 7.58 MB / 7.23 MiB).
Total Domain & Non-Systematic RS Setup completed in 0.730 sec.

--- VERIFYING TIER-1 CLEAN WINDOW GEOMETRY ---
  |W_1 cap W_2| = 4 (<= Delta_int = 4)
  |W_1 cap W_3| = 4 (<= Delta_int = 4)
  |W_1 cap W_4| = 4 (<= Delta_int = 4)
  |W_2 cap W_3| = 4 (<= Delta_int = 4)
  |W_2 cap W_4| = 4 (<= Delta_int = 4)
  |W_3 cap W_4| = 4 (<= Delta_int = 4)

Provisioning 4 Cohort Participants via simulated DKG/MPC...
Provisioning completed in 0.510 sec.

=== SCENARIO 1: BASELINE BROADCAST TO AUTHORIZED COHORT (MONOLITHIC KEM) ===
  [U_1 Authorized] RS Decode: true | wt(e_1) = 27 (<= aleph = 31) | KEM Digest & Schnorr Sig Valid: true | Key Match: true (0.180 sec)
  [U_2 Pre-Revoke] RS Decode: true | wt(e_2) = 27 | U_2 caches its own error vector e_U2 (wt = 27)

=== SCENARIO 2: TIER-1 INTRA-EPOCH REVOCATION (NAIVE U_2 WITHOUT CACHING) ===
  [U_2 REVOKED (Stateless)] RS Decode: false | Error Weight wt(e_2) = 39 (> aleph = 31) -> ACCESS BLOCKED!
  [U_1 LEGITIMATE]          RS Decode: true  | Error Weight wt(e_1) = 31 (<= aleph = 31) | Payload Match: true

=== SCENARIO 3A: ALGEBRAIC ODD COALITION (T = 3) OVER GF(256) ===
  Left 128B Error (w, m canceled): 0
  Semantic Attribute 79B Error:    0 (identical attributes!)
  Tier-1 Revocation 48B Error:     43 (> J(128,64) = 38 & aleph = 31)
  Algebraic Coalition RS Decode:   false -> COLLUSION DEFEATED BY TIER-1!

=== SCENARIO 3B: HOMOMORPHIC ODD COALITION (T = 3) IN G_T (BASE-3 CARRY OVERFLOW) ===
  Total 255B RS Core Error Weight (Base-3 Carry Avalanche in G_T): 255 / 255 | RS Decode: false

=== SCENARIO 4: EVEN COALITION (T = 2) MASK ANNIHILATION FAILURE ===
  Total 255B RS Core Error Weight (Unmasked w, m): 254 / 255 | RS Decode: false

==========================================================================
PART 8: DYNAMIC ENTROPY (xi_i) & MONOLITHIC KEM DEFENSE SUITE
==========================================================================

=== SCENARIO 5A: STATE-CACHING ATTACK ON STATIC TIER-1 (xi_i = 0) ===
  [Static Tier-1 State-Patch] Residual Error Weight wt(delta_rev) = 12 (<= aleph = 31) | RS Decode: true | Key Exposed: true

=== SCENARIO 5B: TIER-1 STATE-CACHING DEFEATED BY STREAM-SEEDED NOISE (wt(xi_i) = 22) ===
  [Frame 101 Pre-Revoke] U_2 Blind RS Decode: true | wt(e_pol + xi_101) = 30 (<= 31) | U_2 caches E_101
  [Frame 102 U_1 Legitimate] Blind RS Decode: true | wt(e_pol + xi_102) = 31 (<= 31) | KEM Valid: true
  [Frame 102 U_2 Direct]     Blind RS Decode: false | wt(e_rev + xi_102) = 39 (> 38 & 31) -> BLOCKED!
  [Frame 102 U_2 Patched]    Blind RS Decode: false | wt(delta_rev + xi_102 - xi_101) = 47 (> 38 & 31) -> CACHE PATCH DEFEATED!

=== SCENARIO 6: INTER-FRAME LINEAR ADDITION ATTACK (c'_102 + c'_103) ===
  Support Overlap |supp(xi_102) cap supp(xi_103)| = 4
  Combined Ephemeral Noise Weight wt(xi_102 + xi_103) = 40 (> aleph = 31)
  RS Decode on Inter-Frame Sum (c'_102 + c'_103): false -> INTER-FRAME ADDITION BLOCKED!

=== SCENARIO 7: RESILIENCE UNDER FULL kappa_102 COMPROMISE (WITH LOGGED sigma_102, Sigma_102) ===
  Residual Error on Target Frame 103: wt(xi_103 - xi_102) = 40 (> aleph = 31)
  Target Frame 103 RS Decode after Full kappa_102 Leak: false -> TARGET FRAME PROTECTED!

=== SCENARIO 8: ANALYTICAL & MONTE CARLO SUPPORT OVERLAP BOUND ===
  [Profile wt(xi)=20, w_pol<=11] Exact Pr[s >= 9]  = 1.635924364E-6 | Total Pr[wt <= 31] = 2.382234622E-6 (~ 2^-18.8)
  [Profile wt(xi)=22, w_pol<=9]  Exact Pr[s >= 13] = 7.912538399E-11 | Total Pr[wt <= 31] = 2.298592658E-10 (~ 2^-32.0)
  Theoretical E[s] = 1.898 | Empirical Mean Overlap (50000 pairs) = 1.904
  Empirical Minimum wt(xi_i + xi_j) across 50000 pairs: 35 (Threshold aleph = 31) | Collisions: 0

=== SCENARIO 9: POLICY-SCOPED SELECTIVE ACTIVATION (S = 0 FAST PATH) & TIER-2 RESET ===
  [Clean Policy / Post-Tier-2 Reset] Synthetic Noise wt(xi_i) = 0 | Zero-Syndrome Fast Check (S = 0): true
  [Clean Policy / Post-Tier-2 Reset] Berlekamp-Massey Bypassed | wt = 0 | Payload Match: true
```

### Verification Summary Table

| Scenario | Operational / Adversarial Test Case | Observed Weight `wt(e)` | Bound (`ℵ = 31`, `J = 38`) | RS Decode | Security Verdict |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Scenario 1** | Baseline Authorized Broadcast (Monolithic KEM) | `27` (U1, U2) | `<= 31` | `true` | ✅ Validated (`0.180 s`) |
| **Scenario 2** | Stateless Tier-1 Intra-Epoch Revocation (`w_pert = 12`) | `39` (U2) / `31` (U1) | `> 38` / `<= 31` | `false` / `true` | 🛡️ U2 Blocked, U1 Decodes |
| **Scenario 3A** | Algebraic Odd Coalition (`T = 3`, Identical Semantic Attrs) | `43` | `> 38` | `false` | 🛡️ Cover-Free Amplification |
| **Scenario 3B** | Homomorphic Odd Coalition (`T = 3`, 4 Operands in `G_T`) | `255 / 255` | `> 38` | `false` | 🛡️ Base-3 Carry Avalanche |
| **Scenario 4** | Homomorphic Even Coalition (`T = 2`, Mask Self-Annihilation) | `254 / 255` | `> 38` | `false` | 🛡️ Masks `(w, m)` Intact |
| **Scenario 5A** | State-Caching Patch on Static Tier-1 (`xi_i = 0` Baseline) | `12` | `<= 31` | `true` | ⚠️ Vulnerable without `xi_i` |
| **Scenario 5B** | Tier-1 Quarantine with Stream-Seeded `xi_i` (`wt(xi_i) = 22`) | `31` (U1) / `39` (Dir) / `47` (Patch) | `<= 31` / `> 38` | `true` / `false` | 🛡️ Cache Patch Defeated |
| **Scenario 6** | Inter-Frame Linear Addition (`c'_102 + c'_103`) | `40` (`overlap = 4`) | `> 31` | `false` | 🛡️ Frame Sum Blocked |
| **Scenario 7** | Target Frame 103 under Full `kappa_102` Compromise | `40` | `> 31` | `false` | 🛡️ Forward/Post Isolation |
| **Scenario 8** | Analytical Bound & `50,000`-Pair Monte Carlo (`wt(xi_i) = 22`) | `min = 35` (`E[s] = 1.904`) | `> 31` | `0 collisions` | ✅ `Pr ≈ 2.30e-10 (~2^-32.0)` |
| **Scenario 9** | Policy-Scoped Fast Path (`S = 0`) & Post-Tier-2 Reset | `0` | `0` | `true` (Bypass) | ⚡ BM Decoder Bypassed |

## Empirical Verification & Cryptanalytic Benchmark (`benchmark-GT-LUT-vs-Kangaroo.m`)

- Memory-computation trade-off benchmarking script (10,000 trials) evaluating:
  * Variant 1: Direct uncompressed <i>O</i>(1) LUT (13,121 entries, 578 B/entry, 7.58 MB / 7.23 MiB).
  * Variant 2: Compressed 64-bit prefix <i>O</i>(1) LUT (13,121 entries, 10 B/entry, 131.2 KB / 128.1 KiB, 57.8× smaller memory footprint, L1/L2 cache-resident).
  * Variant 3: Distinguished Points / Kangaroo search (242 entries, 578 B/entry, 139.9 KB / 136.6 KiB, 54.2× smaller memory footprint).
  * Head-to-head online extraction timing across a full 256-block RS frame.
  
### Console Output (`Magma V2.29`)

```text
=== INITIALIZING BLS12-381 TARGET GROUP G_T subset F_{p^12}^* ===
Group G_T initialized in 0.190 sec (Max scalar Z = 13120).

=== VARIANT 1: DIRECT UNCOMPRESSED O(1) LUT IN F_{p^12}^* ===
  Precomputation Time:   0.540 sec
  Stored Table Entries:  13121 entries (578 B/entry: 576B F_{p^12} + 2B index)
  Memory Footprint:      7.58 MB (7.23 MiB)

=== VARIANT 2: COMPRESSED 64-BIT PREFIX O(1) LUT (L1/L2 CACHE-RESIDENT) ===
  Precomputation Time:   0.580 sec
  Stored Table Entries:  13121 entries (10 B/entry: 8B prefix + 2B index)
  64-Bit Collision-Free: true (Unique prefixes: 13121 / 13121)
  Memory Footprint:      131.2 KB (128.1 KiB)

=== VARIANT 3: DISTINGUISHED POINTS (KANGAROO) IN F_{p^12}^* ===
  Precomputation Time:   0.580 sec
  Stored DP Entries:     242 entries (Theoretical 2*sqrt(13120) ~ 229)
  Memory Footprint:      139.9 KB (136.6 KiB)

=== GENERATING 256 RANDOM TEST TARGETS g_T^(z_t) IN [0, 13120] ===

========================================================================================================
          SUMMARY BENCHMARK: DLP IN F_{p^12}^* (eta = 8, Z in [0, 13120], 256 Blocks = 1 Frame)
========================================================================================================
Metric                           | Direct Full LUT      | 64-Bit Prefix LUT    | Kangaroo (DP Variant)
--------------------------------------------------------------------------------------------------------
Stored Table Entries             | 13121                | 13121                | 242
Entry Size (Bytes)               | 578 B (Full F_p^12)  | 10 B (8B Key+2B Idx) | 578 B (Full F_p^12)
Memory Footprint (Decimal SI)    | 7.58 MB              | 131.2 KB             | 139.9 KB
Memory Footprint (Binary IEC)    | 7.23 MiB             | 128.1 KiB            | 136.6 KiB
Memory Reduction vs. Full LUT    | 1.0x (Baseline)      | 57.8x smaller        | 54.2x smaller
Offline Precomputation Time      | 0.540 sec            | 0.580 sec            | 0.580 sec
Avg F_{p^12} Muls / Block        | 0 (O(1) Hash Lookup) | 0 (O(1) Prefix Hash) | 112.5 muls
Online Time per Block (ms)       | 0.0010 ms            | 0.0044 ms            | 5.039 ms
Online Time per 256B Frame (sec) | 0.0003 sec           | 0.0011 sec           | 1.290 sec
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
