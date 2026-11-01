/* Optimized Gaudry-Schost for Target Group G_T in F_{p^12}^* */
/* Fixed While Loop Syntax Version */

clear;
 
ElGamalKeysGT := function(g_T, order_q)
    s := Random(order_q);
    return <g_T^s, s>;
end function;

ElGamalEncryptionGT := function(PlainTextScalar, PublicKeyGT, g_T, order_q)
    T := g_T^PlainTextScalar;
    r := Random(order_q);
    return <g_T^r, T * (PublicKeyGT^r)>;
end function;

ElGamalDecryptionGT := function(CipherText, SecretKey, order_q)
    return CipherText[2] / (CipherText[1]^SecretKey);
end function;

CanonicalRepresentativeGT := function(Element)
    InvElement := Element^(-1);
    if Eltseq(Element) le Eltseq(InvElement) then
        return Element, 0;
    else
        return InvElement, 1;
    end if;
end function;

GaudrySchostResolveCollisionGT := function(TargetTag, TameTable, WildTable, order_q)
    Result := <[], false>;
    if not IsDefined(TameTable, TargetTag) or not IsDefined(WildTable, TargetTag) then
        return Result;
    end if;
    
    TameCands := TameTable[TargetTag];
    WildCands := WildTable[TargetTag];
    
    candidates_diff := [];
    for tc in TameCands do
        for wc in WildCands do
            if tc[1] eq wc[1] then // Strict coordinate comparison of Rep
                Tame_RandNum := tc[2];
                Wild_RandNum := wc[2];
                Tame_Orient  := tc[3]; 
                Wild_Orient  := tc[3]; 
                
                exp_t := (Tame_Orient eq 0) select Tame_RandNum else -Tame_RandNum;
                exp_w := (Wild_Orient eq 0) select Wild_RandNum else -Wild_RandNum;
                
                Append(~candidates_diff, (exp_t - exp_w) mod order_q);
                Append(~candidates_diff, (-exp_t - exp_w) mod order_q);
            end if;
        end for;
    end for;
    
    if #candidates_diff gt 0 then
        return <candidates_diff, true>;
    end if;
    return Result;
end function;

GaudrySchostGT := function(Q, g_T, TameRange, order_q)
    TameTable := AssociativeArray();
    WildTable := AssociativeArray();
    
    CompressionRatio := 0.1;
    WildRange := Floor((TameRange * CompressionRatio) / 2);
    i := 0;
    
    while true do
        // Tame step
        i +:= 1;
        RandomNumber := Random(TameRange);
        Elem := g_T^RandomNumber;
        
        Rep, Orientation := CanonicalRepresentativeGT(Elem);
        RandNum := (Orientation eq 0) select RandomNumber else -RandomNumber;
        Tag := Sprint(Rep);
        
        if not IsDefined(TameTable, Tag) then
            TameTable[Tag] := [];
        end if;
        Append(~TameTable[Tag], <Rep, RandNum, Orientation>);
        
        if IsDefined(WildTable, Tag) then 
            Res := GaudrySchostResolveCollisionGT(Tag, TameTable, WildTable, order_q);
            if Res[2] then 
                for cand in Res[1] do
                    if g_T^cand eq Q then
                        return <cand, i>;
                    end if;
                end for;
            end if;
        end if;
        
        // Wild step
        i +:= 1;
        RandomNumber := Random(-WildRange, WildRange);
        Elem := Q * (g_T^RandomNumber);
        
        Rep, Orientation := CanonicalRepresentativeGT(Elem);
        RandNum := (Orientation eq 0) select RandomNumber else -RandomNumber;
        Tag := Sprint(Rep);
        
        if not IsDefined(WildTable, Tag) then
            WildTable[Tag] := [];
        end if;
        Append(~WildTable[Tag], <Rep, RandNum, Orientation>);
        
        if IsDefined(TameTable, Tag) then 
            Res := GaudrySchostResolveCollisionGT(Tag, TameTable, WildTable, order_q);
            if Res[2] then 
                for cand in Res[1] do
                    if g_T^cand eq Q then
                        return <cand, i>;
                    end if;
                end for;
            end if;
        end if;
    end while;
end function;

k := 10;

"-- DOMAIN PARAMETERS SETUP (BLS12-381 Target Group G_T in F_{p^12}) --";
t := Cputime();

p := 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab;
q := 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;

Fp := GF(p);
P2<x2> := PolynomialRing(Fp);
Fp2 := ext<Fp | x2^2 + 1>; 
Fp12 := ext<Fp2 | 6>; 

// Instant deterministic generator assignment for g_T without search loops
// (taking an extension basis element and projecting it into the subgroup of order q)
g_T := (Fp12.1 + 1)^((p^12 - 1) div q);

DomainParSetUpTime := Cputime(t);

"\n-- Optimal weights for Base-3 packing --";
Weights := [3^i : i in [0..k-1 by 1]];
printf "All possible sums of weights take values from range: [0,%o].\n", (&+Weights)*2;

"\n-- TEST FOR ELGAMAL IN G_T & GAUDRY-SCHOST --";
PlainTextScalar := Random(1, 3^k - 1);
printf "Original plaintext scalar Z: %o\n", PlainTextScalar;

MyKeys := ElGamalKeysGT(g_T, q);
MyPublicKey := MyKeys[1];
MySecretKey := MyKeys[2];

CipherText := ElGamalEncryptionGT(PlainTextScalar, MyPublicKey, g_T, q);
printf "ElGamal ciphertext in G_T generated successfully.\n";

ResultElement := ElGamalDecryptionGT(CipherText, MySecretKey, q);
printf "Decryption result in G_T matches g_T^Z: %o\n", ResultElement eq g_T^PlainTextScalar;

"\n-- MAPPING TO TARGET GROUP DLP SOLUTION (Gaudry-Schost) --";
t := ClockCycles();
Solution := GaudrySchostGT(ResultElement, g_T, (&+Weights)*2, q);
GetGaudrySchostCycles := ClockCycles() - t;

printf "DLP solution found by Gaudry-Schost algorithm: %o.\n", Solution[1];
printf "Amount of trials in Gaudry-Schost algorithm: %o.\n", Solution[2];
printf "Verification (Solution == PlainTextScalar): %o.\n", Solution[1] eq PlainTextScalar;

printf "\nTime and performance metrics:\n";
printf "1) Domain setup time: %.3o sec.\n", DomainParSetUpTime;
printf "2) Gaudry-Schost cycles spent: %o.\n", GetGaudrySchostCycles;

quit;
