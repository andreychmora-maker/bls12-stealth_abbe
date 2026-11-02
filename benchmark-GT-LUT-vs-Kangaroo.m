/* ==========================================================================
   BENCHMARK: DIRECT O(1) LUT vs. DISTINGUISHED POINTS (KANGAROO) IN F_{p^12}^*
   Environment: Magma Online Calculator (http://magma.maths.usyd.edu.au/calc/)
   Target Group: BLS12-381 Cyclotomic Subgroup G_T subset F_{p^12}^*
   Scalar Range: Z in [0, 13120] (eta = 8, N_blk = 256 blocks per frame)
   ========================================================================== */
clear;

/* --------------------------------------------------------------------------
   PART 1: BLS12-381 G_T SETUP IN F_{p^12}^*
   -------------------------------------------------------------------------- */
SetupBLS12_381_GT := function()
    p := 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
    q := 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;

    Fp := GF(p);
    R<x> := PolynomialRing(Fp);
    Fp12<u> := ExtensionField<Fp, x | x^12 - 2*x^6 + 2>;

    cofactor_Phi12 := (p^4 - p^2 + 1) div q;
    repeat
        raw := Random(Fp12);
        if raw ne Fp12!0 then
            cyc := raw^(p^6 - 1);
            cyc := cyc^(p^2 + 1);
            g_T := cyc^cofactor_Phi12;
        else
            g_T := Fp12!1;
        end if;
    until g_T ne Fp12!1;

    return Fp12, g_T, p, q;
end function;

printf "=== INITIALIZING BLS12-381 TARGET GROUP G_T subset F_{p^12}^* ===\n";
t0 := Cputime();
Fp12, g_T, p, q := SetupBLS12_381_GT();
Z_Int := Integers();
eta := 8;
MaxVal := 2 * (3^eta - 1); // 13120
N_blocks := 256;           // 1 full RS [256, 192, 65]_256 frame at eta = 8
BytesPerEntry := 580;      // 12 * 48B (F_{p^12}) + 4B scalar index
printf "Group G_T initialized in %.3o sec (Max scalar Z = %o).\n\n", Cputime(t0), MaxVal;

/* --------------------------------------------------------------------------
   PART 2: VARIANT 1 - DIRECT O(1) LOOK-UP TABLE (13,121 ENTRIES)
   -------------------------------------------------------------------------- */
BuildDirectLUT := function(g_T, MaxVal)
    Table := AssociativeArray();
    curr  := Parent(g_T) ! 1;
    Table[curr] := 0;
    for z in [1..MaxVal] do
        curr *:= g_T;
        Table[curr] := z;
    end for;
    return Table;
end function;

printf "=== VARIANT 1: DIRECT O(1) LUT IN F_{p^12}^* ===\n";
t_lut_build := Cputime();
DirectLUT := BuildDirectLUT(g_T, MaxVal);
time_direct_precomp := Cputime(t_lut_build);
num_direct_entries  := #Keys(DirectLUT);
mem_direct_MB       := num_direct_entries * BytesPerEntry / 1000000.0;
mem_direct_MiB      := num_direct_entries * BytesPerEntry / 1048576.0;

printf "  Precomputation Time:   %.3o sec\n", time_direct_precomp;
printf "  Stored Table Entries:  %o entries\n", num_direct_entries;
printf "  Memory Footprint:      %.2o MB (%.2o MiB)\n", mem_direct_MB, mem_direct_MiB;

/* --------------------------------------------------------------------------
   PART 3: VARIANT 2 - DISTINGUISHED POINTS (KANGAROO) TABLE (~229 ENTRIES)
   -------------------------------------------------------------------------- */
// Pseudorandom jump function & distinguished-point predicate on F_{p^12}^*
// Using trap modulus D_mod = 57 yields expected ~13121 / 57 = 230 distinguished points
D_mod    := 57; // ~ (1/2) * sqrt(13120) so that stored traps ~ 2 * sqrt(13120) = 229
NumJumps := 16;
// Precompute jump sizes s_1..s_16 with mean ~ D_mod / 2 ~ 29
JumpSizes := [ Z_Int ! Round(Exp((j - 1) * Log(2.0 * D_mod) / (NumJumps - 1))) : j in [1..NumJumps] ];
JumpSteps := [ g_T^s : s in JumpSizes ];

// Fast mixing of F_{p^12} coefficients to extract jump index and DP property
MixElement := function(Elem, Z_Int)
    seq := Eltseq(Elem);
    c1  := Z_Int ! seq[1];
    c2  := Z_Int ! seq[2];
    c7  := Z_Int ! seq[7];
    return c1 + 257 * c2 + 65537 * c7;
end function;

// Construct Distinguished Points (DP) table by harvesting all DPs in [0, MaxVal + 12*D_mod]
// and launching Tame Kangaroo paths to guarantee 100% trap coverage
BuildKangarooDPTable := function(g_T, MaxVal, D_mod, Z_Int)
    DPTable := AssociativeArray();
    curr := Parent(g_T) ! 1;
    DPTable[curr] := 0; // Always include 0 as anchor trap
    horizon := MaxVal + 12 * D_mod;
    for z in [1..horizon] do
        curr *:= g_T;
        h_val := MixElement(curr, Z_Int);
        if (h_val mod D_mod) eq 0 then
            DPTable[curr] := z;
        end if;
    end for;
    return DPTable;
end function;

// Online Wild Kangaroo search: walks from TargetElem = g_T^z until hitting a Distinguished Point
SolveDLP_Kangaroo := function(TargetElem, g_T, DPTable, JumpSizes, JumpSteps, D_mod, MaxVal, Z_Int)
    curr := TargetElem;
    dist := 0;
    steps := 0;
    max_walk := 40 * D_mod;

    while steps lt max_walk do
        if IsDefined(DPTable, curr) then
            z_rec := DPTable[curr] - dist;
            if (z_rec ge 0) and (z_rec le MaxVal) then
                return true, z_rec, steps;
            end if;
        end if;
        h_val := MixElement(curr, Z_Int);
        j_idx := (h_val mod #JumpSizes) + 1;
        curr *:= JumpSteps[j_idx];
        dist +:= JumpSizes[j_idx];
        steps +:= 1;
    end while;

    // Fallback deterministic linear step if wild path stepped over sparse gap
    curr := TargetElem;
    for d in [1..D_mod*4] do
        curr *:= g_T;
        steps +:= 1;
        if IsDefined(DPTable, curr) then
            return true, DPTable[curr] - d, steps;
        end if;
    end for;
    return false, -1, steps;
end function;

printf "\n=== VARIANT 2: DISTINGUISHED POINTS (KANGAROO) IN F_{p^12}^* ===\n";
t_dp_build := Cputime();
DPTable := BuildKangarooDPTable(g_T, MaxVal, D_mod, Z_Int);
time_dp_precomp := Cputime(t_dp_build);
num_dp_entries  := #Keys(DPTable);
mem_dp_KB       := num_dp_entries * BytesPerEntry / 1000.0;
mem_dp_KiB      := num_dp_entries * BytesPerEntry / 1024.0;

printf "  Precomputation Time:   %.3o sec\n", time_dp_precomp;
printf "  Stored DP Entries:     %o entries (Theoretical 2*sqrt(13120) ~ 229)\n", num_dp_entries;
printf "  Memory Footprint:      %.1o KB (%.1o KiB)\n", mem_dp_KB, mem_dp_KiB;

/* --------------------------------------------------------------------------
   PART 4: HEAD-TO-HEAD ONLINE EXTRACTION BENCHMARK (256 BLOCKS = 1 FRAME)
   -------------------------------------------------------------------------- */
printf "\n=== GENERATING %o RANDOM TEST TARGETS g_T^(z_t) IN [0, %o] ===\n", N_blocks, MaxVal;
TestScalars := [ Random(0, MaxVal) : t in [1..N_blocks] ];
// Fast lookup of test group elements from DirectLUT to avoid tainting benchmark timer
InvSample := AssociativeArray();
curr := Fp12 ! 1;
InvSample[0] := curr;
for z in [1..MaxVal] do
    curr *:= g_T;
    InvSample[z] := curr;
end for;
TestElements := [ InvSample[TestScalars[t]] : t in [1..N_blocks] ];

// 1. Benchmark Direct O(1) LUT over 256 blocks (averaged over 20 frames for timer precision)
N_iters_direct := 20;
t_dir_eval := Cputime();
rec_direct := [ 0 : t in [1..N_blocks] ];
for iter in [1..N_iters_direct] do
    for t in [1..N_blocks] do
        rec_direct[t] := DirectLUT[TestElements[t]];
    end for;
end for;
time_direct_frame := Cputime(t_dir_eval) / N_iters_direct;
ok_direct := (rec_direct eq TestScalars);

// 2. Benchmark Kangaroo Distinguished Points search over 256 blocks
t_kang_eval := Cputime();
rec_kang := [ 0 : t in [1..N_blocks] ];
total_kang_muls := 0;
all_kang_ok := true;
for t in [1..N_blocks] do
    ok_k, z_k, steps_k := SolveDLP_Kangaroo(TestElements[t], g_T, DPTable, JumpSizes, JumpSteps, D_mod, MaxVal, Z_Int);
    rec_kang[t] := z_k;
    total_kang_muls +:= steps_k;
    if not ok_k then all_kang_ok := false; end if;
end for;
time_kang_frame := Cputime(t_kang_eval);
ok_kang := all_kang_ok and (rec_kang eq TestScalars);
avg_muls_per_block := total_kang_muls * 1.0 / N_blocks;

/* --------------------------------------------------------------------------
   PART 5: COMPARATIVE SUMMARY TABLE
   -------------------------------------------------------------------------- */
printf "\n================================================================================\n";
printf "   SUMMARY BENCHMARK: DLP IN F_{p^12}^* (eta = 8, Z in [0, 13120], 256 Blocks)\n";
printf "================================================================================\n";
printf "Metric                           | Direct O(1) LUT      | Kangaroo (DP Variant)\n";
printf "--------------------------------------------------------------------------------\n";
printf "Stored Table Entries             | %-20o | %-20o\n", num_direct_entries, num_dp_entries;
printf "Memory Footprint (Decimal SI)    | %.2o MB              | %.1o KB\n", mem_direct_MB, mem_dp_KB;
printf "Memory Footprint (Binary IEC)    | %.2o MiB             | %.1o KiB\n", mem_direct_MiB, mem_dp_KiB;
printf "Memory Reduction Factor          | 1.0x (Baseline)      | %.1ox smaller\n",
       (num_direct_entries * 1.0) / num_dp_entries;
printf "Offline Precomputation Time      | %.3o sec            | %.3o sec\n", time_direct_precomp, time_dp_precomp;
printf "Avg F_{p^12} Muls / Block        | 0 (O(1) Hash Lookup) | %.1o muls\n", avg_muls_per_block;
printf "Online Time per Block (ms)       | %.4o ms            | %.3o ms\n",
       (time_direct_frame * 1000.0) / N_blocks, (time_kang_frame * 1000.0) / N_blocks;
printf "Online Time per 256B Frame (sec) | %.4o sec           | %.3o sec\n",
       time_direct_frame, time_kang_frame;
printf "Exact Recovery (256/256 blocks)  | %-20o | %-20o\n", ok_direct, ok_kang;
printf "================================================================================\n";
