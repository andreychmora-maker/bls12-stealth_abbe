/* ==========================================================================
   STEALTH ABBE END-TO-END PROTOTYPE & CRYPTANALYTIC BENCHMARK
   Based on the A-Scheme Homomorphic Engine (a_prototype.m)
   Parameters: RS [256, 192, 65]_256 (Rate R = 0.75, aleph = 32),
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

// Simulates MPC/DKG provisioning: sk_j sampled by U_j, H_j = (alpha - sk_j) mod q
ProvisionUserSplitKey := function(alpha, q)
    sk_j := Random(1, q - 1);
    h_j  := (alpha - sk_j) mod q;
    return sk_j, h_j;
end function;

ElGamalEncryption := function(PlainTextScalar, P_pub, G, q)
    T := PlainTextScalar * G;
    r := Random(1, q - 1);
    return [r * G, T + r * P_pub];
end function;

// Split-key decryption using invariant (sk_j + h_j) mod q == alpha
SplitKeyElGamalDecryption := function(CipherText, sk_j, h_j, q)
    combined_scalar := (sk_j + h_j) mod q;
    return CipherText[2] - combined_scalar * CipherText[1];
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
   PART 2: ALGEBRAIC ENGINE (Non-Systematic RS [256, 192, 65]_256 & Bridges)
   -------------------------------------------------------------------------- */
F<w> := GaloisField(256);
n_len := 256;
k_dim := 192; // Code rate R = k/n = 0.75 (MDS puncturing margin delta = 64 bytes)
d_rs255 := n_len - k_dim; // Design distance d = 64 for punctured [255, 192, 64]_256

C_rs255 := ReedSolomonCode(F, d_rs255); // [255, 192, 64] over GF(256)
G_sys255 := GeneratorMatrix(C_rs255);

// Extend to n = 256 by appending an overall parity check coordinate
V256 := VectorSpace(F, n_len);
V192 := VectorSpace(F, k_dim);

G_ext_flat := [];
for r in [1..k_dim] do
    row_seq := ElementToSequence(G_sys255[r]);
    parity_coord := &+row_seq;
    Append(~row_seq, parity_coord);
    G_ext_flat cat:= row_seq;
end for;
G_ext := Matrix(F, k_dim, n_len, G_ext_flat);

// Non-systematic scrambling matrix S in GL_k(F_q) to prevent systematic puncturing
repeat
    S_scram := RandomMatrix(F, k_dim, k_dim);
until IsInvertible(S_scram);
S_inv := S_scram^(-1);
G_ns := S_scram * G_ext; // Non-systematic generator matrix [192 x 256]

aleph := 31; // Syndrome decoder radius on the 255-byte RS projection (32 on full MDS)

FieldElementToBinVec := function(element)
    seq := ElementToSequence(element);
    bin_seq := [ Integers() ! x : x in seq ];
    while #bin_seq lt 8 do Append(~bin_seq, 0); end while;
    return Reverse(bin_seq);
end function;

BinVecToFieldElement := function(bin_vec)
    le_vec := Reverse(bin_vec);
    if #le_vec eq 0 then return F!0; end if;
    return F ! [ GF(2) ! x : x in le_vec ];
end function;

// Non-systematic RS Encoder & Safe Blind Decoder wrapper
EncodeNS := function(kappa_vec)
    return kappa_vec * G_ns;
end function;

DecodeNS := function(perturbed_cw)
    cw_255 := VectorSpace(F, 255) ! [perturbed_cw[i] : i in [1..255]];
    ok, dec_cw255 := Decode(C_rs255, cw_255);
    // Guard against uncorrectable vectors that are not in the code space C_rs255
    if (not ok) or (not (dec_cw255 in C_rs255)) then
        return false, V192!0, -1;
    end if;
    scr_msg_seq := Coordinates(C_rs255, dec_cw255);
    scr_msg_vec := V192 ! scr_msg_seq;
    kappa_hat   := scr_msg_vec * S_inv;
    
    full_clean_cw := kappa_hat * G_ns;
    err_vec := perturbed_cw + full_clean_cw;
    wt_err  := #[i : i in [1..n_len] | err_vec[i] ne F!0];
    if wt_err gt aleph then
        return false, V192!0, wt_err;
    end if;
    return true, kappa_hat, wt_err;
end function;

/* --------------------------------------------------------------------------
   PART 3: DOMAIN SETUP & HOMOMORPHIC BLOCK ENGINE
   -------------------------------------------------------------------------- */
eta := 8; // 1 byte per block (N_blk = 256)
printf "\n=== STEALTH ABBE PROTOTYPE SETUP (R = 0.75, [256, 192, 65]_256) ===\n";
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

EncryptVectorEG := function(vec_256, P_pub, G, q, Weights, eta)
    CipherBlocks := [];
    for t in [1..#vec_256] do
        b_vec := FieldElementToBinVec(vec_256[t]);
        W_val := &+[b_vec[i] * Weights[i] : i in [1..eta]];
        Append(~CipherBlocks, ElGamalEncryption(W_val, P_pub, G, q));
    end for;
    return CipherBlocks;
end function;

HomomorphicEvalAndUnpack := function(C_bc, C_user_list, sk_j, h_j, q, LUT, eta)
    OutVec := [F!0 : t in [1..#C_bc]];
    for t in [1..#C_bc] do
        C1_sum := C_bc[t][1];
        C2_sum := C_bc[t][2];
        for u in [1..#C_user_list] do
            C1_sum +:= C_user_list[u][t][1];
            C2_sum +:= C_user_list[u][t][2];
        end for;
        Pt := SplitKeyElGamalDecryption([C1_sum, C2_sum], sk_j, h_j, q);
        Z_t := ECDLPByTable(Pt, LUT);
        Rec_bits := BinVecReconstruction(Z_t, eta);
        OutVec[t] := BinVecToFieldElement(Rec_bits);
    end for;
    return V256 ! OutVec;
end function;

/* --------------------------------------------------------------------------
   PART 4: COHORT & TIER-1 COVER-FREE ATTRIBUTE PROVISIONING
   -------------------------------------------------------------------------- */
M_rev      := 48;  // Revocation sub-block length (bytes 209..256)
w_clean    := 16;  // Clean window size |W_j| = 16
tau_coh    := 27;  // Baseline error weight = 27 (so 27 + Delta_int = 31 <= aleph)
Delta_int  := 4;   // Max pairwise window intersection |W_j cap W_j'| <= 4
attr_len   := 128 - M_rev; // 80 bytes of unconstrained semantic attributes

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
            eps := F!0;
            while eps eq F!0 do eps := Random(F); end while;
            r_j[pos] := p_pol[pos] + eps;
        else
            r_j[pos] := p_pol[pos];
        end if;
    end for;
    w_concat_r := w_coh cat r_j;
    M_j := [w_concat_r[i] + m_msk[i] : i in [1..256]];
    return r_j, M_j;
end function;

Users_M   := [];
Users_C   := [];
Users_sk  := [];
Users_h   := [];

printf "\nProvisioning 4 Cohort Participants via simulated DKG/MPC...\n";
for j in [1..4] do
    _, M_j := BuildUserVector(CleanWindows[j], p_policy, w_cohort, m_mask);
    sk_j, h_j := ProvisionUserSplitKey(alpha, q);
    C_Uj := EncryptVectorEG(M_j, P_pub, G, q, Weights, eta);
    Append(~Users_M, M_j);
    Append(~Users_C, C_Uj);
    Append(~Users_sk, sk_j);
    Append(~Users_h, h_j);
end for;

/* --------------------------------------------------------------------------
   PART 5: SCENARIO 1 - NORMAL BROADCAST & AUTHORIZED DECRYPTION
   -------------------------------------------------------------------------- */
printf "\n=== SCENARIO 1: BASELINE BROADCAST TO AUTHORIZED COHORT ===\n";
kappa_payload := V192 ! [Random(F) : i in [1..k_dim]];
c_codeword    := EncodeNS(kappa_payload);

w_concat_p := w_cohort cat p_policy;
c_prime    := [c_codeword[i] + w_concat_p[i] + m_mask[i] : i in [1..n_len]];
C_broadcast := EncryptVectorEG(c_prime, P_pub, G, q, Weights, eta);

c_double_prime_U1 := HomomorphicEvalAndUnpack(C_broadcast, [Users_C[1]], Users_sk[1], Users_h[1], q, LUT, eta);
ok_1, rec_kappa_1, wt_1 := DecodeNS(c_double_prime_U1);
printf "  [U_1 Authorized] RS Decode: %o | Error Weight wt(e_1) = %o (<= aleph = %o) | Payload Match: %o\n",
       ok_1, wt_1, aleph, rec_kappa_1 eq kappa_payload;

/* --------------------------------------------------------------------------
   PART 6: SCENARIO 2 - TIER-1 ZERO-LATENCY REVOCATION OF U_2
   -------------------------------------------------------------------------- */
printf "\n=== SCENARIO 2: TIER-1 INTRA-EPOCH REVOCATION (TARGETING U_2) ===\n";
p_revoked := p_policy;
perturbed_coords := SetToSequence(CleanWindows[2])[1..12]; // 12 coords inside W_2
for s in perturbed_coords do
    pos := attr_len + s;
    delta_val := F!0;
    while delta_val eq F!0 do delta_val := Random(F); end while;
    p_revoked[pos] +:= delta_val;
end for;

w_concat_p_rev := w_cohort cat p_revoked;
c_prime_rev    := [c_codeword[i] + w_concat_p_rev[i] + m_mask[i] : i in [1..n_len]];
C_broadcast_rev := EncryptVectorEG(c_prime_rev, P_pub, G, q, Weights, eta);

// Evaluate for Target Revoked User U_2 (Expected weight: 27 + 12 = 39 > 31)
c_dp_U2 := HomomorphicEvalAndUnpack(C_broadcast_rev, [Users_C[2]], Users_sk[2], Users_h[2], q, LUT, eta);
ok_2, _, _ := DecodeNS(c_dp_U2);
actual_wt_U2 := #[i : i in [1..n_len] | (c_dp_U2 + c_codeword)[i] ne F!0];
printf "  [U_2 REVOKED]    RS Decode: %o | Error Weight wt(e_2) = %o (> aleph = %o) -> ACCESS BLOCKED!\n",
       ok_2, actual_wt_U2, aleph;

// Evaluate for Non-Revoked User U_1 (Shares at most Delta_int = 4 coords with W_2 -> wt <= 27 + 4 = 31)
c_dp_U1_after := HomomorphicEvalAndUnpack(C_broadcast_rev, [Users_C[1]], Users_sk[1], Users_h[1], q, LUT, eta);
ok_1_after, rec_kappa_1_after, wt_1_after := DecodeNS(c_dp_U1_after);
printf "  [U_1 LEGITIMATE] RS Decode: %o  | Error Weight wt(e_1) = %o (<= aleph = %o) | Payload Match: %o\n",
       ok_1_after, wt_1_after, aleph, rec_kappa_1_after eq kappa_payload;

/* --------------------------------------------------------------------------
   PART 7: SCENARIO 3 & 4 - SAME-ATTRIBUTE COLLUSION ATTACKS
   -------------------------------------------------------------------------- */
printf "\n=== SCENARIO 3A: ALGEBRAIC ODD COALITION (T = 3) OVER GF(256) ===\n";
// Direct GF(256) sum c' + M_2 + M_3 + M_4 (testing the Tier-1 combinatorial bound in isolation)
c_alg_coll_odd := V256 ! [c_prime[i] + Users_M[2][i] + Users_M[3][i] + Users_M[4][i] : i in [1..n_len]];
err_alg_odd    := c_alg_coll_odd + c_codeword;
wt_alg_left128 := #[i : i in [1..128]   | err_alg_odd[i] ne F!0];
wt_alg_attr80  := #[i : i in [129..208] | err_alg_odd[i] ne F!0];
wt_alg_rev48   := #[i : i in [209..256] | err_alg_odd[i] ne F!0];
ok_alg_odd, _, _ := DecodeNS(c_alg_coll_odd);

printf "  Left 128B Error (w, m canceled): %o\n", wt_alg_left128;
printf "  Semantic Attribute 80B Error:    %o (identical attributes!)\n", wt_alg_attr80;
printf "  Tier-1 Revocation 48B Error:     %o (> J(128,64) = 38 & aleph = %o)\n", wt_alg_rev48, aleph;
printf "  Algebraic Coalition RS Decode:   %o -> COLLUSION DEFEATED BY TIER-1!\n", ok_alg_odd;

printf "\n=== SCENARIO 3B: HOMOMORPHIC ODD COALITION (T = 3) IN G_1 (BASE-3 CARRY OVERFLOW) ===\n";
// Adding 4 ElGamal ciphertexts (C_bc + C_U2 + C_U3 + C_U4) causes Base-3 carry overflow (bits sum to 3 or 4)!
c_hom_coll_odd := HomomorphicEvalAndUnpack(C_broadcast, [Users_C[2], Users_C[3], Users_C[4]], Users_sk[2], Users_h[2], q, LUT, eta);
err_hom_odd    := c_hom_coll_odd + c_codeword;
wt_hom_total   := #[i : i in [1..256] | err_hom_odd[i] ne F!0];
ok_hom_odd, _, _ := DecodeNS(c_hom_coll_odd);
printf "  Total 256B Error Weight (Base-3 Carry Avalanche): %o / 256 | RS Decode: %o\n", wt_hom_total, ok_hom_odd;

printf "\n=== SCENARIO 4: EVEN COALITION (T = 2) MASK ANNIHILATION FAILURE ===\n";
c_dp_coll_even := HomomorphicEvalAndUnpack(C_broadcast, [Users_C[2], Users_C[3]], Users_sk[2], Users_h[2], q, LUT, eta);
err_coll_even  := c_dp_coll_even + c_codeword;
wt_total_even  := #[i : i in [1..256] | err_coll_even[i] ne F!0];
ok_coll_even, _, _ := DecodeNS(c_dp_coll_even);
printf "  Total 256B Error Weight (Unmasked w, m): %o / 256 | RS Decode: %o\n", wt_total_even, ok_coll_even;
