# Stealth ABBE: Attribute-Based Broadcast Encryption (Magma Verification Prototype)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23824328.svg)](https://doi.org/10.5281/zenodo.23824328)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[![Magma Compatible](https://img.shields.io/badge/Language-Magma%20V2.29.10-blue.svg)](http://magma.maths.usyd.edu.au/)
[![Code Rate](https://img.shields.io/badge/Code%20Rate-R%3D0.75-green.svg)]()


**Stealth ABBE** is a provably secure Attribute-Based Broadcast Encryption framework combining homomorphic ElGamal encryption with non-systematic Reed-Solomon error-correcting codes and a two-tier cryptographic revocation mechanism.

This repository contains the simplified algebraic verification prototype implemented for the **Magma Computational Algebra System**. To enable fast execution in the Magma Online Calculator, the prototype abstracts the bilinear pairing layer (BLS12) into a single-group ElGamal engine over **Curve25519**, focusing on the exact verification of the Base-3 homomorphic pipeline, non-systematic MDS coding, and Tier-1 cover-free revocation geometry.

---

## 🚀 Key Architectural Features

1. **Non-Systematic Reed-Solomon Puncturing Defense (Rate *R* = 0.75):**
   * Employs an extended [256, 192, 65]₂₅₆ code over GF(256) with a punctured syndrome decoder radius of ℵ = 31 symbol errors (32 on the full MDS code).
   * Utilizes a non-systematic scrambling matrix *S* ∈ GL(192, GF(256)) to provide a robust MDS puncturing margin (*δ* = 64 bytes), neutralizing direct linear matrix inversion attacks.

2. **Two-Tier Revocation Strategy:**
   * **Tier-1 (Intra-Epoch Zero-Latency Revocation):** Implements a cover-free family of clean windows *W* of size *w* = 16 bytes within a revocation sub-block (*M* = 48 bytes), with bounded pairwise intersection Δ ≤ 4 bytes and baseline cohort error weight *τ* = 27 bytes. Enables instant user blacklisting via targeted broadcast perturbations.
   * **Tier-2 (Inter-Epoch Hard Reset):** Global cohort blocker (**w**) and session mask (**m**) rotation ensuring long-term cryptographic hygiene and history purging.

3. **Simplified Homomorphic ElGamal Engine (Curve25519):**
   * Block-wise additive ElGamal aggregation over Curve25519 (*p* = 2²⁵⁵ − 19) using carry-free Base-3 scalar embedding with ternary weights 3⁰, 3¹, ..., 3⁷.
   * Simulates the split-key DKG invariant (*sk* + *h*) mod *q* = *α* directly in the scalar ring Z/*q*Z, followed by O(1) lookup-table (LUT) short-interval discrete logarithm recovery.

4. **Two-Layer Collusion Resistance:**
   * **Base-3 Carry Avalanche:** Homomorphic aggregation of *T* ≥ 3 ciphertexts in the curve group triggers inter-digit ternary carries (3 = 10₃, 4 = 11₃), causing a catastrophic 256 / 256-byte decoding failure.
   * **Combinatorial Error Amplification:** Same-attribute odd coalitions (*T* = 3) attempting direct algebraic combination in GF(256) encounter an enforced error weight of ~43.8 bytes > *J*(128, 64) = 38, strictly exceeding both the unique decoding radius and the Johnson list-decoding bound.

---

## 🛠️ Repository Structure

* `stealth_abbe.m` — Standalone end-to-end Magma verification script containing:
  * Curve25519 domain setup and O(1) Short-Interval DLP lookup table (LUT) generator.
  * Non-systematic RS [256, 192, 65]₂₅₆ encoder and guarded syndrome decoder.
  * Cover-free clean window geometry verifier (*M* = 48, *w* = 16, Δ = 4).
  * Complete execution scenarios (Authorized decrypt, Tier-1 revocation, Algebraic & Homomorphic Odd Collusion *T* = 3 defeat, Even Collusion *T* = 2 mask annihilation failure).

---

## ⚙️ Getting Started & Verification

To run the reference prototype and verify all security scenarios, open your Magma environment (or the Magma Online Calculator) and run the script:

```magma
load "stealth_abbe.m";
```
### Expected Output Summary:
- **Scenario 1 (Baseline Broadcast):** Authorized participant *U*₁ successfully decrypts with error weight wt(**e**₁) = 27 ≤ ℵ = 31.
- **Scenario 2 (Tier-1 Revocation):** Target user *U*₂ error weight jumps to 39 > 31 (Access Blocked), while legitimate user *U*₁ stays at 31 ≤ 31 (Access Granted).
- **Scenario 3A (Algebraic Odd Coalition):** Direct sum in GF(256) yields 0 errors in the left 128-byte block and 80-byte attributes, but the revocation sub-block error reaches 43 > 38, defeating list decoding.
- **Scenario 3B (Homomorphic Odd Coalition):** Base-3 carry overflow in Curve25519 results in 256 / 256 corrupted bytes.
- **Scenario 4 (Even Coalition):** Unmasked cohort blockers result in 256 / 256 corrupted bytes.

### 📚 Academic Citation

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23677112.svg)](https://doi.org/10.5281/zenodo.23677112)

If you utilize these scripts in your research,
please cite the associated archive:

```bash
@misc{chmora2026stealthabbe,
  author       = {Andrey Chmora},
  title        = {Stealth ABBE: Carry-Free Homomorphic Packing and Blind Reed–Solomon Decoding},
  month        = {Oct},
  year         = {2026},
  publisher    = {Zenodo},
  doi          = 10.5281/zenodo.23536594
  url          = [https://zenodo.org/badge/DOI/10.5281/zenodo.23677112.svg](https://doi.org/10.5281/zenodo.23677112)
```
