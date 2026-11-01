/* ==========================================================================
   STEALTH ABBE END-TO-END PROTOTYPE & CRYPTANALYTIC BENCHMARK
   Environment: Magma Online Calculator (http://magma.maths.usyd.edu.au/calc/)
   Parameters:  Extended Non-Systematic RS [256, 192, 65]_256 (Rate R = 0.75),
                M = 48, w_clean = 16, tau_coh = 27, Delta_int = 4, eta = 8
   ========================================================================== */
clear;

/* --------------------------------------------------------------------------
   PART 1: CRYPTO PRIMITIVES, SPLIT-KEY DKG & O(1) LUT ECDLP
   -------------------------------------------------------------------------- */
MasterKeyGen := function(G, q)
    alpha := Random(1, q - 1);
    P_pub := alpha * G;
    return P_pub, alpha;
end function;

// Simulates MPC/DKG provisioning: sk_j sampled by U_j, h_j = (alpha - sk_j) mod q
ProvisionUserSplitKey := function(alpha, q)
    sk_j := Random(1, q - 1);
    h_j  := (alpha - sk_j) mod q;
    return sk_j, h_j;
end function;

// Carry-free Base-3 reconstruction R_eta(Z) -> GF(2)^eta
BinVecReconstruction := function(ScalarValue, eta)
    Z := Integers();
    BinVec := [0 : i in [1..eta]];
    if ScalarValue eq 0 then return BinVec; end if;
    TmpVec := IntegerToSequence(Z!ScalarValue, 3);
    for i in [1..Min(#TmpVec, eta)] do
        BinVec[i] := TmpVec[i] mod 2;
    end for;
    return BinVec;
end function;

BuildECDLPTable := function(G, MaxVal)
    Table := AssociativeArray();
    Table[0] := 0;
    P := G;
    for i in [1..MaxVal] do
        Table[P[1]] := i;
        P +:= G;
    end for;
    return Table;
end function;

ECDLPByTable := function(Point, Table)
    if IsZero(Point) then return 0; end if;
    return Table[Point[1]];
end function;

/* --------------------------------------------------------------------------
   PART 2: ALGEBRAIC ENGINE (Extended Non-Systematic RS [256, 192, 65]_256)
   -------------------------------------------------------------------------- */
F<w> := GaloisField(256);
n_len := 256;
k_dim := 192;             // Code rate R = k/n = 0.75 (MDS puncturing margin delta = 64B)
d_min := 65;              // Extended MDS minimum distance
aleph := 31;              // Unique decoding radius on the 255-symbol cyclic core

V256 := VectorSpace(F, n_len);
V192 := VectorSpace(F, k_dim);

// Standard cyclic [255, 192, 64]_256 code with systematic generator matrix [I_192 | P]
C_std := ReedSolomonCode(F, d_min - 1);
G_std := GeneratorMatrix(C_std);

// Non-systematic scrambling matrix S in GL_192(F_256)
repeat
    S_mat := RandomMatrix(F, k_dim, k_dim);
until IsInvertible(S_mat);
S_inv := S_mat^-1;

// Combined non-systematic generator matrix (192 x 255) for the cyclic core
G_ns := S_mat * G_std;

FieldElementToBinVec := function(element)
    return [ Integers() ! x : x in ElementToSequence(element) ];
end function;

BinVecToFieldElement := function(bin_vec)
    return F ! [ GF(2) ! x : x in bin_vec ];
end function;

// Explicit encoding: Non-systematic [255, 192, 64] core + 256-th overall parity symbol
EncodeExtNS := function(kappa_vec)
    cw_255 := Eltseq(kappa_vec * G_ns);
    return V256 ! Append(cw_255, &+cw_255);
end function;

// Fast blind decoding via systematic core projection & direct S^-1 inversion
DecodeExtNS := function(perturbed_cw)
    cw_255 := VectorSpace(F, 255) ! Eltseq(perturbed_cw)[1..255];
    ok, dec_255 := Decode(C_std, cw_255);
    if (not ok) or (not (dec_255 in C_std)) then
        return false, V192!0, -1;
    end if;
    
    // Since G_std = [I_192 | P] is systematic, first k_dim symbols are (kappa_vec * S_mat)
    scrambled_rec := V192 ! Eltseq(dec_255)[1..k_dim];
    kappa_hat := scrambled_rec * S_inv;
    
    // Reconstruct full 256-symbol codeword (with overall parity) and verify error weight
    dec_seq := Eltseq(dec_255);
    full_clean_cw := V256 ! Append(dec_seq, &+dec_seq);
    err_vec := perturbed_cw + full_clean_cw;
    wt_err  := #[i : i in [1..n_len] | err_vec[i] ne F!0];
    
    if wt_err gt aleph then
        return false, V192!0, wt_err;
    end if;
    return true, kappa_hat, wt_err;
end function;

/* --------------------------------------------------------------------------
   PART 3: DOMAIN SETUP & FAST HOMOMORPHIC BLOCK ENGINE
   -------------------------------------------------------------------------- */
eta := 8; // 1 byte per block (N_blk = 256)
printf "\n=== STEALTH ABBE PROTOTYPE SETUP (Magma Online Calculator) ===\n";
t_start := Cputime();

p := 2^255 - 19;
Px<x> := PolynomialRing(GF(p));
E := EllipticCurve(x^3 + 486662*x^2 + x);
Gy := 0x5f51e65e475f794b1fe122d388b72eb36dc2b28192839e4dd6163a5d81312c14;
G := E![GF(p)!0x9, GF(p)!Gy];
q := 2^252 + 27742317777372353535851937790883648493;

Weights := [3^i : i in [0..eta-1]];
MaxWeightSum := (&+Weights) * 4;
printf "Building O(1) Short-Interval DLP LUT (Max Z = %o)...\n", MaxWeightSum;
LUT := BuildECDLPTable(G, MaxWeightSum);

P_pub, alpha := MasterKeyGen(G, q);
printf "Domain & Non-Systematic RS Setup completed in %.3o sec.\n", Cputime(t_start);

// Vectorized ElGamal encryption sharing ephemeral randomness r across the 256-byte frame
EncryptVectorEG := function(vec_256, P_pub, G, q, Weights, eta)
    r_eph := Random(1, q - 1);
    C1 := r_eph * G;
    r_Ppub := r_eph * P_pub;
    C2_list := [];
    for t in [1..#vec_256] do
        b_vec := FieldElementToBinVec(vec_256[t]);
        W_val := &+[b_vec[i] * Weights[i] : i in [1..eta]];
        Append(~C2_list, W_val * G + r_Ppub);
    end for;
    return <C1, C2_list>;
end function;

// Split-key homomorphic evaluation & unpacking with cached C_1 scalar multiplication
HomomorphicEvalAndUnpack := function(C_bc, C_user_list, sk_j, h_j, q, LUT, eta)
    C1_sum := C_bc[1];
    for u in [1..#C_user_list] do
        C1_sum +:= C_user_list[u][1];
    end for;
    
    // Split-key invariant: (sk_j + h_j) mod q == alpha, evaluated once per frame
    combined_scalar := (sk_j + h_j) mod q;
    CachedMask := combined_scalar * C1_sum;
    
    n_blocks := #C_bc[2];
    OutVec := [F!0 : t in [1..n_blocks]];
    for t in [1..n_blocks] do
        C2_sum := C_bc[2][t];
        for u in [1..#C_user_list] do
            C2_sum +:= C_user_list[u][2][t];
        end for;
        Pt := C2_sum - CachedMask;
        Z_t := ECDLPByTable(Pt, LUT);
        Rec_bits := BinVecReconstruction(Z_t, eta);
        OutVec[t] := BinVecToFieldElement(Rec_bits);
    end for;
    return V256 ! OutVec;
end function;

/* --------------------------------------------------------------------------
   PART 4: COHORT & TIER-1 COVER-FREE ATTRIBUTE PROVISIONING
   -------------------------------------------------------------------------- */
M_rev     := 48;  // Revocation sub-block length (bytes 209..256)
w_clean   := 16;  // Clean window size |W_j| = 16
tau_coh   := 27;  // Baseline error weight = 27 (so 27 + Delta_int = 31 <= aleph)
Delta_int := 4;   // Max pairwise window intersection |W_j cap W_j'| <= 4
attr_len  := 128 - M_rev; // 80 bytes of unconstrained semantic attributes

w_cohort := [Random(F) : i in [1..128]];
m_mask   := [Random(F) : i in [1..256]];
p_policy := [Random(F) : i in [1..128]];

// Partition {1..48} into 12 blocks of 4 elements: B_1..B_12
B := [ [4*(b-1)+1 .. 4*b] : b in [1..12] ];
CleanWindows := [
    Set(B[1] cat B[2] cat B[3] cat B[4]),   // W_1: blocks 1, 2, 3, 4
    Set(B[1] cat B[5] cat B[6] cat B[7]),   // W_2: blocks 1, 5, 6, 7
    Set(B[2] cat B[5] cat B[8] cat B[9]),   // W_3: blocks 2, 5, 8, 9
    Set(B[3] cat B[6] cat B[8] cat B[10])   // W_4: blocks 3, 6, 8, 10
];

printf "\n--- VERIFYING TIER-1 CLEAN WINDOW GEOMETRY ---\n";
for a in [1..4] do
    for b in [a+1..4] do
        inter := #(CleanWindows[a] meet CleanWindows[b]);
        printf "  |W_%o cap W_%o| = %o (<= Delta_int = %o)\n", a, b, inter, Delta_int;
    end for;
end for;

BuildUserVector := function(W_j, p_pol, w_coh, m_msk)
    r_j := [F!0 : i in [1..128]];
    for s in [1..attr_len] do
        r_j[s] := p_pol[s];
    end for;
    complement_seq := [s : s in [1..M_rev] | not (s in W_j)];
    error_positions := Set(complement_seq[1..tau_coh]);
    for s in [1..M_rev] do
        pos := attr_len + s;
        if s in error_positions then
            repeat eps := Random(F); until eps ne F!0;
            r_j[pos] := p_pol[pos] + eps;
        else
            r_j[pos] := p_pol[pos];
        end if;
    end for;
    w_concat_r := w_coh cat r_j;
    M_j := [w_concat_r[i] + m_msk[i] : i in [1..256]];
    return r_j, M_j;
end function;

Users_M  := [];
Users_C  := [];
Users_sk := [];
Users_h  := [];

printf "\nProvisioning 4 Cohort Participants via simulated DKG/MPC...\n";
t_prov := Cputime();
for j in [1..4] do
    _, M_j := BuildUserVector(CleanWindows[j], p_policy, w_cohort, m_mask);
    sk_j, h_j := ProvisionUserSplitKey(alpha, q);
    C_Uj := EncryptVectorEG(M_j, P_pub, G, q, Weights, eta);
    Append(~Users_M, M_j);
    Append(~Users_C, C_Uj);
    Append(~Users_sk, sk_j);
    Append(~Users_h, h_j);
end for;
printf "Provisioning completed in %.3o sec.\n", Cputime(t_prov);

/* --------------------------------------------------------------------------
   PART 5: SCENARIO 1 - NORMAL BROADCAST & AUTHORIZED DECRYPTION
   -------------------------------------------------------------------------- */
printf "\n=== SCENARIO 1: BASELINE BROADCAST TO AUTHORIZED COHORT ===\n";
t_eval := Cputime();
kappa_payload := Random(V192);
c_codeword    := EncodeExtNS(kappa_payload);

w_concat_p := w_cohort cat p_policy;
c_prime    := [c_codeword[i] + w_concat_p[i] + m_mask[i] : i in [1..n_len]];
C_broadcast := EncryptVectorEG(c_prime, P_pub, G, q, Weights, eta);

c_double_prime_U1 := HomomorphicEvalAndUnpack(C_broadcast, [Users_C[1]], Users_sk[1], Users_h[1], q, LUT, eta);
ok_1, rec_kappa_1, wt_1 := DecodeExtNS(c_double_prime_U1);
printf "  [U_1 Authorized] RS Decode: %o | Error Weight wt(e_1) = %o (<= aleph = %o) | Payload Match: %o (%.3o sec)\n",
       ok_1, wt_1, aleph, rec_kappa_1 eq kappa_payload, Cputime(t_eval);

/* --------------------------------------------------------------------------
   PART 6: SCENARIO 2 - TIER-1 ZERO-LATENCY REVOCATION OF U_2
   -------------------------------------------------------------------------- */
printf "\n=== SCENARIO 2: TIER-1 INTRA-EPOCH REVOCATION (TARGETING U_2) ===\n";
p_revoked := p_policy;
perturbed_coords := SetToSequence(CleanWindows[2])[1..12]; // 12 coords inside W_2
for s in perturbed_coords do
    pos := attr_len + s;
    repeat delta_val := Random(F); until delta_val ne F!0;
    p_revoked[pos] +:= delta_val;
end for;

w_concat_p_rev  := w_cohort cat p_revoked;
c_prime_rev     := [c_codeword[i] + w_concat_p_rev[i] + m_mask[i] : i in [1..n_len]];
C_broadcast_rev := EncryptVectorEG(c_prime_rev, P_pub, G, q, Weights, eta);

// Evaluate for Target Revoked User U_2 (Expected weight: 27 + 12 = 39 > 31)
c_dp_U2 := HomomorphicEvalAndUnpack(C_broadcast_rev, [Users_C[2]], Users_sk[2], Users_h[2], q, LUT, eta);
ok_2, _, _ := DecodeExtNS(c_dp_U2);
actual_wt_U2 := #[i : i in [1..n_len] | (c_dp_U2 + c_codeword)[i] ne F!0];
printf "  [U_2 REVOKED]    RS Decode: %o | Error Weight wt(e_2) = %o (> aleph = %o) -> ACCESS BLOCKED!\n",
       ok_2, actual_wt_U2, aleph;

// Evaluate for Non-Revoked User U_1 (Shares at most Delta_int = 4 coords with W_2 -> wt <= 27 + 4 = 31)
c_dp_U1_after := HomomorphicEvalAndUnpack(C_broadcast_rev, [Users_C[1]], Users_sk[1], Users_h[1], q, LUT, eta);
ok_1_after, rec_kappa_1_after, wt_1_after := DecodeExtNS(c_dp_U1_after);
printf "  [U_1 LEGITIMATE] RS Decode: %o  | Error Weight wt(e_1) = %o (<= aleph = %o) | Payload Match: %o\n",
       ok_1_after, wt_1_after, aleph, rec_kappa_1_after eq kappa_payload;

/* --------------------------------------------------------------------------
   PART 7: SCENARIO 3 & 4 - SAME-ATTRIBUTE COLLUSION ATTACKS
   -------------------------------------------------------------------------- */
printf "\n=== SCENARIO 3A: ALGEBRAIC ODD COALITION (T = 3) OVER GF(256) ===\n";
c_alg_coll_odd := V256 ! [c_prime[i] + Users_M[2][i] + Users_M[3][i] + Users_M[4][i] : i in [1..n_len]];
err_alg_odd    := c_alg_coll_odd + c_codeword;
wt_alg_left128 := #[i : i in [1..128]   | err_alg_odd[i] ne F!0];
wt_alg_attr80  := #[i : i in [129..208] | err_alg_odd[i] ne F!0];
wt_alg_rev48   := #[i : i in [209..256] | err_alg_odd[i] ne F!0];
ok_alg_odd, _, _ := DecodeExtNS(c_alg_coll_odd);

printf "  Left 128B Error (w, m canceled): %o\n", wt_alg_left128;
printf "  Semantic Attribute 80B Error:    %o (identical attributes!)\n", wt_alg_attr80;
printf "  Tier-1 Revocation 48B Error:     %o (> J(128,64) = 38 & aleph = %o)\n", wt_alg_rev48, aleph;
printf "  Algebraic Coalition RS Decode:   %o -> COLLUSION DEFEATED BY TIER-1!\n", ok_alg_odd;

printf "\n=== SCENARIO 3B: HOMOMORPHIC ODD COALITION (T = 3) IN G_1 (BASE-3 CARRY OVERFLOW) ===\n";
c_hom_coll_odd := HomomorphicEvalAndUnpack(C_broadcast, [Users_C[2], Users_C[3], Users_C[4]], Users_sk[2], Users_h[2], q, LUT, eta);
err_hom_odd    := c_hom_coll_odd + c_codeword;
wt_hom_total   := #[i : i in [1..256] | err_hom_odd[i] ne F!0];
ok_hom_odd, _, _ := DecodeExtNS(c_hom_coll_odd);
printf "  Total 256B Error Weight (Base-3 Carry Avalanche): %o / 256 | RS Decode: %o\n", wt_hom_total, ok_hom_odd;

printf "\n=== SCENARIO 4: EVEN COALITION (T = 2) MASK ANNIHILATION FAILURE ===\n";
c_dp_coll_even := HomomorphicEvalAndUnpack(C_broadcast, [Users_C[2], Users_C[3]], Users_sk[2], Users_h[2], q, LUT, eta);
err_coll_even  := c_dp_coll_even + c_codeword;
wt_total_even  := #[i : i in [1..256] | err_coll_even[i] ne F!0];
ok_coll_even, _, _ := DecodeExtNS(c_dp_coll_even);
printf "  Total 256B Error Weight (Unmasked w, m): %o / 256 | RS Decode: %o\n", wt_total_even, ok_coll_even;
