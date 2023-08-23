#include "Xoroshiro128Plus.isph"
#include "BitonicSort8.isph"

#define Sort8Type int

inline void COEX8_(uniform Sort8Type V1[], uniform Sort8Type V2[])
{
    foreach (i = 0 ... 8)
    {
        Sort8Type Temp = V1[i];

        V1[i] = min(Temp, V2[i]);
        V2[i] = max(Temp, V2[i]);
    }
}

inline void RightShift(uniform uint64* V, uniform int32 imm8)
{
    foreach (i = 0 ... 4)
    {
        V[i] = V[i] >> imm8;
    }
}

inline void Copy_Temp_Vector8_(uniform Sort8Type Temp[], uniform Sort8Type V[])
{
    foreach (i = 0 ... 8)
    {
        Temp[i] = V[i];
    }
}

void Shuffle8_One_Vector_To_Vector_(uniform Sort8Type V[], uniform int32 SaveV[], const uniform int32 Mask[])
{ 
#if TARGET_WIDTH == 8
    foreach (i = 0 ... 8) 
    { 
        (SaveV)[i] = shuffle((V)[i], Mask[i]); 
    }
#else
    uniform Sort8Type _STemp[8];
    Copy_Temp_Vector8_(_STemp, V);
    foreach (i = 0 ... 8)
    {
        #pragma ignore warning(perf)
        (SaveV)[i] = _STemp[Mask[i]];
    }
#endif
}

inline void Shuffle8_Two_Vectors_(uniform int32* V1, uniform int32* V2, uniform int32* SaveV, const uniform int32 Mask[])
{
#if TARGET_WIDTH == 8
    foreach (i = 0 ... 8)
    {
        SaveV[i] = shuffle(V1[i], V2[i], Mask[i]);
    }
#else
    uniform int32 Temp[8 + 8];
    foreach (i = 0 ... 8)
    {
        Temp[i] = V1[i];
        Temp[i + 8] = V2[i];
    }

    foreach (i = 0 ... 8)
    {
        #pragma ignore warning(perf)
        SaveV[i] = Temp[Mask[i]];
    }
#endif
}

inline void RandomBound(uniform uint64* RandomVec, uniform uint64* Bound)
{
    uniform uint64 Even[4];

    // _mm256_mul_epu32
    {
        foreach (i = 0 ... 4)
        {
            Even[i] = (uint64)(RandomVec[i] & 0xFFFFFFFF) * (uint64)(Bound[i] & 0xFFFFFFFF);
        }
    }

    RightShift(Even, 32);

    uniform uint64 Odd[4];
    RightShift(RandomVec, 32);

    // _mm256_mul_epu32
    {
        foreach (i = 0 ... 4)
        {
            Odd[i] = (uint64)(RandomVec[i] & 0xFFFFFFFF) * (uint64)(Bound[i] & 0xFFFFFFFF);
        }
    }

    uniform int Mask[8] = {0, 1 + 8, 2, 3 + 8, 4, 5 + 8, 6, 7 + 8};
    uniform int32* Even4 = (uniform int32*)(&Even[0]);
    uniform int32* Odd4 = (uniform int32*)(&Odd[0]);
    uniform int32* RandomVec4 = (uniform int32*)(&RandomVec[0]);
    Shuffle8_Two_Vectors_(Even4, Odd4, RandomVec4, Mask);
}

#ifdef GetVectorIndex8
#undef GetVectorIndex8
#endif

#define GetVectorIndex8(Index) (Index) * 8

void COEX_SHUFFLE_8_(uniform Sort8Type V[], uniform int32 Mask1[], uniform int32 Mask2[])
{
    uniform Sort8Type TempV[8];
    Shuffle8_One_Vector_To_Vector_(V, TempV, Mask1);

    uniform Sort8Type Min[8];
    uniform Sort8Type Max[8];
    foreach (i = 0 ... 8)
    {
        Min[i] = min(TempV[i], (V)[i]);
        Max[i] = max(TempV[i], (V)[i]);
    }

    Shuffle8_Two_Vectors_(Min, Max, V, Mask2);
}

/** 
 * sorting network for 8 int with compare-exchange macros
 * (used for pivot selection in median of the medians) 
 */
inline void Sort_8(uniform Sort8Type Data[])
{
    uniform int Mask[8] = {1, 0, 3, 2, 5, 4, 7, 6};
    uniform int Mask1[8] = {0, 0 + 8, 2, 2 + 8, 4, 4 + 8, 6, 6 + 8};
    COEX_SHUFFLE_8_(Data, Mask, Mask1); 

    uniform int Mask2[8] = {2, 3, 0, 1, 6, 7, 4, 5};
    uniform int Mask3[8] = {0, 1, 0 + 8, 1 + 8, 4, 5, 4 + 8, 5 + 8};
    COEX_SHUFFLE_8_(Data, Mask2, Mask3);

    uniform int Mask4[8] = {0, 2, 1, 3, 4, 6, 5, 7};
    uniform int Mask5[8] = {0, 1, 2 + 8, 3 + 8, 4, 5, 6 + 8, 7 + 8};
    COEX_SHUFFLE_8_(Data, Mask4, Mask5);

    uniform int Mask6[8] = {7, 6, 5, 4, 3, 2, 1, 0};
    uniform int Mask7[8] = {0, 1, 2, 3,  4 + 8, 5 + 8, 6 + 8, 7 + 8};
    COEX_SHUFFLE_8_(Data, Mask6, Mask7);

    COEX_SHUFFLE_8_(Data, Mask2, Mask3);

    COEX_SHUFFLE_8_(Data, Mask, Mask1);
}

inline uniform Sort8Type GetPivot(uniform Sort8Type Data[], uniform int32 Left, uniform int32 Right)
{
    uniform uint32 Bound[8];
    foreach (i = 0 ... 8)
    {
        Bound[i] = Right - Left + 1;
    }

    uniform uint32 LeftVec[8];
    foreach (i = 0 ... 8)
    {
        LeftVec[i] = Left;
    }

    // TODO 使用新的种子生成器来处理
    /* seeds for vectorized random number generator */
    uniform uint64 S0[4] = {8265987198341093849, 3762817312854612374, 1324281658759788278, 6214952190349879213};
    uniform uint64 S1[4] = {2874178529384792648, 1257248936691237653, 7874578921548791257, 1998265912745817298};

    foreach (i = 0 ... 4)
    {
        S0[i] = S0[i] + Left;
    }

    foreach (i = 0 ... 4)
    {
        S1[i] = S1[i] - Right;
    }

    uniform Sort8Type V[8 * 9];
    for (uniform int32 i = 0; i < 9; ++i) /* fill 9 vectors with random numbers */
    {
        /* vector with 4 random uint64_t */
        uniform uint64 Result[4];
        Xoroshiro128Plus(S0, S1, Result, 4);

        /* random numbers between 0 and bound - 1 */
        uniform uint64* Bound4 = (uniform uint64*)(&Bound[0]);
        RandomBound(Result, Bound4);
       
        /* indices for arr */
        uniform uint32* Result8 = (uniform uint32*)(&Result[0]);
        foreach (j = 0 ... 8)
        {
            Result8[j] = Result8[j] + LeftVec[j];
        }

        uniform int32 StartIndex = i * 8;
        foreach (j = 0 ... 8)
        {
            V[StartIndex + j] = Data[Result8[j]];
        }
    }

    /* median network for 9 elements */
    COEX8_(V + GetVectorIndex8(0), V + GetVectorIndex8(1)); COEX8_(V + GetVectorIndex8(2), V + GetVectorIndex8(3)); /* step 1 */
    COEX8_(V + GetVectorIndex8(4), V + GetVectorIndex8(5)); COEX8_(V + GetVectorIndex8(6), V + GetVectorIndex8(7));
    COEX8_(V + GetVectorIndex8(0), V + GetVectorIndex8(2)); COEX8_(V + GetVectorIndex8(1), V + GetVectorIndex8(3)); /* step 2 */
    COEX8_(V + GetVectorIndex8(4), V + GetVectorIndex8(6)); COEX8_(V + GetVectorIndex8(5), V + GetVectorIndex8(7));
    COEX8_(V + GetVectorIndex8(0), V + GetVectorIndex8(4)); COEX8_(V + GetVectorIndex8(1), V + GetVectorIndex8(2)); /* step 3 */
    COEX8_(V + GetVectorIndex8(5), V + GetVectorIndex8(6)); COEX8_(V + GetVectorIndex8(3), V + GetVectorIndex8(7));
    COEX8_(V + GetVectorIndex8(1), V + GetVectorIndex8(5)); COEX8_(V + GetVectorIndex8(2), V + GetVectorIndex8(6)); /* step 4 */
    COEX8_(V + GetVectorIndex8(3), V + GetVectorIndex8(5)); COEX8_(V + GetVectorIndex8(2), V + GetVectorIndex8(4)); /* step 5 */
    COEX8_(V + GetVectorIndex8(3), V + GetVectorIndex8(4));                   /* step 6 */
    COEX8_(V + GetVectorIndex8(3), V + GetVectorIndex8(8));                   /* step 7 */
    COEX8_(V + GetVectorIndex8(4), V + GetVectorIndex8(8));                   /* step 8 */

    Sort_8(V + GetVectorIndex8(4)); /* sort the eight medians in v[4] */

    return Average(V[4 * 8 + 3], V[4 * 8 + 4]); /* compute next pivot */
}

/* auto generated permutations masks for quicksort(8 KB..) */
const uniform int32 Permutation_Masks[256][8] = {{0, 1, 2, 3, 4, 5, 6, 7},
                                            {1, 2, 3, 4, 5, 6, 7, 0},
                                            {0, 2, 3, 4, 5, 6, 7, 1},
                                            {2, 3, 4, 5, 6, 7, 0, 1},
                                            {0, 1, 3, 4, 5, 6, 7, 2},
                                            {1, 3, 4, 5, 6, 7, 0, 2},
                                            {0, 3, 4, 5, 6, 7, 1, 2},
                                            {3, 4, 5, 6, 7, 0, 1, 2},
                                            {0, 1, 2, 4, 5, 6, 7, 3},
                                            {1, 2, 4, 5, 6, 7, 0, 3},
                                            {0, 2, 4, 5, 6, 7, 1, 3},
                                            {2, 4, 5, 6, 7, 0, 1, 3},
                                            {0, 1, 4, 5, 6, 7, 2, 3},
                                            {1, 4, 5, 6, 7, 0, 2, 3},
                                            {0, 4, 5, 6, 7, 1, 2, 3},
                                            {4, 5, 6, 7, 0, 1, 2, 3},
                                            {0, 1, 2, 3, 5, 6, 7, 4},
                                            {1, 2, 3, 5, 6, 7, 0, 4},
                                            {0, 2, 3, 5, 6, 7, 1, 4},
                                            {2, 3, 5, 6, 7, 0, 1, 4},
                                            {0, 1, 3, 5, 6, 7, 2, 4},
                                            {1, 3, 5, 6, 7, 0, 2, 4},
                                            {0, 3, 5, 6, 7, 1, 2, 4},
                                            {3, 5, 6, 7, 0, 1, 2, 4},
                                            {0, 1, 2, 5, 6, 7, 3, 4},
                                            {1, 2, 5, 6, 7, 0, 3, 4},
                                            {0, 2, 5, 6, 7, 1, 3, 4},
                                            {2, 5, 6, 7, 0, 1, 3, 4},
                                            {0, 1, 5, 6, 7, 2, 3, 4},
                                            {1, 5, 6, 7, 0, 2, 3, 4},
                                            {0, 5, 6, 7, 1, 2, 3, 4},
                                            {5, 6, 7, 0, 1, 2, 3, 4},
                                            {0, 1, 2, 3, 4, 6, 7, 5},
                                            {1, 2, 3, 4, 6, 7, 0, 5},
                                            {0, 2, 3, 4, 6, 7, 1, 5},
                                            {2, 3, 4, 6, 7, 0, 1, 5},
                                            {0, 1, 3, 4, 6, 7, 2, 5},
                                            {1, 3, 4, 6, 7, 0, 2, 5},
                                            {0, 3, 4, 6, 7, 1, 2, 5},
                                            {3, 4, 6, 7, 0, 1, 2, 5},
                                            {0, 1, 2, 4, 6, 7, 3, 5},
                                            {1, 2, 4, 6, 7, 0, 3, 5},
                                            {0, 2, 4, 6, 7, 1, 3, 5},
                                            {2, 4, 6, 7, 0, 1, 3, 5},
                                            {0, 1, 4, 6, 7, 2, 3, 5},
                                            {1, 4, 6, 7, 0, 2, 3, 5},
                                            {0, 4, 6, 7, 1, 2, 3, 5},
                                            {4, 6, 7, 0, 1, 2, 3, 5},
                                            {0, 1, 2, 3, 6, 7, 4, 5},
                                            {1, 2, 3, 6, 7, 0, 4, 5},
                                            {0, 2, 3, 6, 7, 1, 4, 5},
                                            {2, 3, 6, 7, 0, 1, 4, 5},
                                            {0, 1, 3, 6, 7, 2, 4, 5},
                                            {1, 3, 6, 7, 0, 2, 4, 5},
                                            {0, 3, 6, 7, 1, 2, 4, 5},
                                            {3, 6, 7, 0, 1, 2, 4, 5},
                                            {0, 1, 2, 6, 7, 3, 4, 5},
                                            {1, 2, 6, 7, 0, 3, 4, 5},
                                            {0, 2, 6, 7, 1, 3, 4, 5},
                                            {2, 6, 7, 0, 1, 3, 4, 5},
                                            {0, 1, 6, 7, 2, 3, 4, 5},
                                            {1, 6, 7, 0, 2, 3, 4, 5},
                                            {0, 6, 7, 1, 2, 3, 4, 5},
                                            {6, 7, 0, 1, 2, 3, 4, 5},
                                            {0, 1, 2, 3, 4, 5, 7, 6},
                                            {1, 2, 3, 4, 5, 7, 0, 6},
                                            {0, 2, 3, 4, 5, 7, 1, 6},
                                            {2, 3, 4, 5, 7, 0, 1, 6},
                                            {0, 1, 3, 4, 5, 7, 2, 6},
                                            {1, 3, 4, 5, 7, 0, 2, 6},
                                            {0, 3, 4, 5, 7, 1, 2, 6},
                                            {3, 4, 5, 7, 0, 1, 2, 6},
                                            {0, 1, 2, 4, 5, 7, 3, 6},
                                            {1, 2, 4, 5, 7, 0, 3, 6},
                                            {0, 2, 4, 5, 7, 1, 3, 6},
                                            {2, 4, 5, 7, 0, 1, 3, 6},
                                            {0, 1, 4, 5, 7, 2, 3, 6},
                                            {1, 4, 5, 7, 0, 2, 3, 6},
                                            {0, 4, 5, 7, 1, 2, 3, 6},
                                            {4, 5, 7, 0, 1, 2, 3, 6},
                                            {0, 1, 2, 3, 5, 7, 4, 6},
                                            {1, 2, 3, 5, 7, 0, 4, 6},
                                            {0, 2, 3, 5, 7, 1, 4, 6},
                                            {2, 3, 5, 7, 0, 1, 4, 6},
                                            {0, 1, 3, 5, 7, 2, 4, 6},
                                            {1, 3, 5, 7, 0, 2, 4, 6},
                                            {0, 3, 5, 7, 1, 2, 4, 6},
                                            {3, 5, 7, 0, 1, 2, 4, 6},
                                            {0, 1, 2, 5, 7, 3, 4, 6},
                                            {1, 2, 5, 7, 0, 3, 4, 6},
                                            {0, 2, 5, 7, 1, 3, 4, 6},
                                            {2, 5, 7, 0, 1, 3, 4, 6},
                                            {0, 1, 5, 7, 2, 3, 4, 6},
                                            {1, 5, 7, 0, 2, 3, 4, 6},
                                            {0, 5, 7, 1, 2, 3, 4, 6},
                                            {5, 7, 0, 1, 2, 3, 4, 6},
                                            {0, 1, 2, 3, 4, 7, 5, 6},
                                            {1, 2, 3, 4, 7, 0, 5, 6},
                                            {0, 2, 3, 4, 7, 1, 5, 6},
                                            {2, 3, 4, 7, 0, 1, 5, 6},
                                            {0, 1, 3, 4, 7, 2, 5, 6},
                                            {1, 3, 4, 7, 0, 2, 5, 6},
                                            {0, 3, 4, 7, 1, 2, 5, 6},
                                            {3, 4, 7, 0, 1, 2, 5, 6},
                                            {0, 1, 2, 4, 7, 3, 5, 6},
                                            {1, 2, 4, 7, 0, 3, 5, 6},
                                            {0, 2, 4, 7, 1, 3, 5, 6},
                                            {2, 4, 7, 0, 1, 3, 5, 6},
                                            {0, 1, 4, 7, 2, 3, 5, 6},
                                            {1, 4, 7, 0, 2, 3, 5, 6},
                                            {0, 4, 7, 1, 2, 3, 5, 6},
                                            {4, 7, 0, 1, 2, 3, 5, 6},
                                            {0, 1, 2, 3, 7, 4, 5, 6},
                                            {1, 2, 3, 7, 0, 4, 5, 6},
                                            {0, 2, 3, 7, 1, 4, 5, 6},
                                            {2, 3, 7, 0, 1, 4, 5, 6},
                                            {0, 1, 3, 7, 2, 4, 5, 6},
                                            {1, 3, 7, 0, 2, 4, 5, 6},
                                            {0, 3, 7, 1, 2, 4, 5, 6},
                                            {3, 7, 0, 1, 2, 4, 5, 6},
                                            {0, 1, 2, 7, 3, 4, 5, 6},
                                            {1, 2, 7, 0, 3, 4, 5, 6},
                                            {0, 2, 7, 1, 3, 4, 5, 6},
                                            {2, 7, 0, 1, 3, 4, 5, 6},
                                            {0, 1, 7, 2, 3, 4, 5, 6},
                                            {1, 7, 0, 2, 3, 4, 5, 6},
                                            {0, 7, 1, 2, 3, 4, 5, 6},
                                            {7, 0, 1, 2, 3, 4, 5, 6},
                                            {0, 1, 2, 3, 4, 5, 6, 7},
                                            {1, 2, 3, 4, 5, 6, 0, 7},
                                            {0, 2, 3, 4, 5, 6, 1, 7},
                                            {2, 3, 4, 5, 6, 0, 1, 7},
                                            {0, 1, 3, 4, 5, 6, 2, 7},
                                            {1, 3, 4, 5, 6, 0, 2, 7},
                                            {0, 3, 4, 5, 6, 1, 2, 7},
                                            {3, 4, 5, 6, 0, 1, 2, 7},
                                            {0, 1, 2, 4, 5, 6, 3, 7},
                                            {1, 2, 4, 5, 6, 0, 3, 7},
                                            {0, 2, 4, 5, 6, 1, 3, 7},
                                            {2, 4, 5, 6, 0, 1, 3, 7},
                                            {0, 1, 4, 5, 6, 2, 3, 7},
                                            {1, 4, 5, 6, 0, 2, 3, 7},
                                            {0, 4, 5, 6, 1, 2, 3, 7},
                                            {4, 5, 6, 0, 1, 2, 3, 7},
                                            {0, 1, 2, 3, 5, 6, 4, 7},
                                            {1, 2, 3, 5, 6, 0, 4, 7},
                                            {0, 2, 3, 5, 6, 1, 4, 7},
                                            {2, 3, 5, 6, 0, 1, 4, 7},
                                            {0, 1, 3, 5, 6, 2, 4, 7},
                                            {1, 3, 5, 6, 0, 2, 4, 7},
                                            {0, 3, 5, 6, 1, 2, 4, 7},
                                            {3, 5, 6, 0, 1, 2, 4, 7},
                                            {0, 1, 2, 5, 6, 3, 4, 7},
                                            {1, 2, 5, 6, 0, 3, 4, 7},
                                            {0, 2, 5, 6, 1, 3, 4, 7},
                                            {2, 5, 6, 0, 1, 3, 4, 7},
                                            {0, 1, 5, 6, 2, 3, 4, 7},
                                            {1, 5, 6, 0, 2, 3, 4, 7},
                                            {0, 5, 6, 1, 2, 3, 4, 7},
                                            {5, 6, 0, 1, 2, 3, 4, 7},
                                            {0, 1, 2, 3, 4, 6, 5, 7},
                                            {1, 2, 3, 4, 6, 0, 5, 7},
                                            {0, 2, 3, 4, 6, 1, 5, 7},
                                            {2, 3, 4, 6, 0, 1, 5, 7},
                                            {0, 1, 3, 4, 6, 2, 5, 7},
                                            {1, 3, 4, 6, 0, 2, 5, 7},
                                            {0, 3, 4, 6, 1, 2, 5, 7},
                                            {3, 4, 6, 0, 1, 2, 5, 7},
                                            {0, 1, 2, 4, 6, 3, 5, 7},
                                            {1, 2, 4, 6, 0, 3, 5, 7},
                                            {0, 2, 4, 6, 1, 3, 5, 7},
                                            {2, 4, 6, 0, 1, 3, 5, 7},
                                            {0, 1, 4, 6, 2, 3, 5, 7},
                                            {1, 4, 6, 0, 2, 3, 5, 7},
                                            {0, 4, 6, 1, 2, 3, 5, 7},
                                            {4, 6, 0, 1, 2, 3, 5, 7},
                                            {0, 1, 2, 3, 6, 4, 5, 7},
                                            {1, 2, 3, 6, 0, 4, 5, 7},
                                            {0, 2, 3, 6, 1, 4, 5, 7},
                                            {2, 3, 6, 0, 1, 4, 5, 7},
                                            {0, 1, 3, 6, 2, 4, 5, 7},
                                            {1, 3, 6, 0, 2, 4, 5, 7},
                                            {0, 3, 6, 1, 2, 4, 5, 7},
                                            {3, 6, 0, 1, 2, 4, 5, 7},
                                            {0, 1, 2, 6, 3, 4, 5, 7},
                                            {1, 2, 6, 0, 3, 4, 5, 7},
                                            {0, 2, 6, 1, 3, 4, 5, 7},
                                            {2, 6, 0, 1, 3, 4, 5, 7},
                                            {0, 1, 6, 2, 3, 4, 5, 7},
                                            {1, 6, 0, 2, 3, 4, 5, 7},
                                            {0, 6, 1, 2, 3, 4, 5, 7},
                                            {6, 0, 1, 2, 3, 4, 5, 7},
                                            {0, 1, 2, 3, 4, 5, 6, 7},
                                            {1, 2, 3, 4, 5, 0, 6, 7},
                                            {0, 2, 3, 4, 5, 1, 6, 7},
                                            {2, 3, 4, 5, 0, 1, 6, 7},
                                            {0, 1, 3, 4, 5, 2, 6, 7},
                                            {1, 3, 4, 5, 0, 2, 6, 7},
                                            {0, 3, 4, 5, 1, 2, 6, 7},
                                            {3, 4, 5, 0, 1, 2, 6, 7},
                                            {0, 1, 2, 4, 5, 3, 6, 7},
                                            {1, 2, 4, 5, 0, 3, 6, 7},
                                            {0, 2, 4, 5, 1, 3, 6, 7},
                                            {2, 4, 5, 0, 1, 3, 6, 7},
                                            {0, 1, 4, 5, 2, 3, 6, 7},
                                            {1, 4, 5, 0, 2, 3, 6, 7},
                                            {0, 4, 5, 1, 2, 3, 6, 7},
                                            {4, 5, 0, 1, 2, 3, 6, 7},
                                            {0, 1, 2, 3, 5, 4, 6, 7},
                                            {1, 2, 3, 5, 0, 4, 6, 7},
                                            {0, 2, 3, 5, 1, 4, 6, 7},
                                            {2, 3, 5, 0, 1, 4, 6, 7},
                                            {0, 1, 3, 5, 2, 4, 6, 7},
                                            {1, 3, 5, 0, 2, 4, 6, 7},
                                            {0, 3, 5, 1, 2, 4, 6, 7},
                                            {3, 5, 0, 1, 2, 4, 6, 7},
                                            {0, 1, 2, 5, 3, 4, 6, 7},
                                            {1, 2, 5, 0, 3, 4, 6, 7},
                                            {0, 2, 5, 1, 3, 4, 6, 7},
                                            {2, 5, 0, 1, 3, 4, 6, 7},
                                            {0, 1, 5, 2, 3, 4, 6, 7},
                                            {1, 5, 0, 2, 3, 4, 6, 7},
                                            {0, 5, 1, 2, 3, 4, 6, 7},
                                            {5, 0, 1, 2, 3, 4, 6, 7},
                                            {0, 1, 2, 3, 4, 5, 6, 7},
                                            {1, 2, 3, 4, 0, 5, 6, 7},
                                            {0, 2, 3, 4, 1, 5, 6, 7},
                                            {2, 3, 4, 0, 1, 5, 6, 7},
                                            {0, 1, 3, 4, 2, 5, 6, 7},
                                            {1, 3, 4, 0, 2, 5, 6, 7},
                                            {0, 3, 4, 1, 2, 5, 6, 7},
                                            {3, 4, 0, 1, 2, 5, 6, 7},
                                            {0, 1, 2, 4, 3, 5, 6, 7},
                                            {1, 2, 4, 0, 3, 5, 6, 7},
                                            {0, 2, 4, 1, 3, 5, 6, 7},
                                            {2, 4, 0, 1, 3, 5, 6, 7},
                                            {0, 1, 4, 2, 3, 5, 6, 7},
                                            {1, 4, 0, 2, 3, 5, 6, 7},
                                            {0, 4, 1, 2, 3, 5, 6, 7},
                                            {4, 0, 1, 2, 3, 5, 6, 7},
                                            {0, 1, 2, 3, 4, 5, 6, 7},
                                            {1, 2, 3, 0, 4, 5, 6, 7},
                                            {0, 2, 3, 1, 4, 5, 6, 7},
                                            {2, 3, 0, 1, 4, 5, 6, 7},
                                            {0, 1, 3, 2, 4, 5, 6, 7},
                                            {1, 3, 0, 2, 4, 5, 6, 7},
                                            {0, 3, 1, 2, 4, 5, 6, 7},
                                            {3, 0, 1, 2, 4, 5, 6, 7},
                                            {0, 1, 2, 3, 4, 5, 6, 7},
                                            {1, 2, 0, 3, 4, 5, 6, 7},
                                            {0, 2, 1, 3, 4, 5, 6, 7},
                                            {2, 0, 1, 3, 4, 5, 6, 7},
                                            {0, 1, 2, 3, 4, 5, 6, 7},
                                            {1, 0, 2, 3, 4, 5, 6, 7},
                                            {0, 1, 2, 3, 4, 5, 6, 7},
                                            {0, 1, 2, 3, 4, 5, 6, 7}};

inline uniform int Partition_Vec(uniform Sort8Type CurVec[], uniform Sort8Type PivotVec[], uniform Sort8Type SmallestVec[], uniform Sort8Type BiggestVec[])
{
    /* which elements are larger than the pivot */
    // __m256i compared = _mm256_cmpgt_epi32(Curr_Vec, pivot_vec);
    /* extract the most significant bit from each integer of the vector */
    // int mm = _mm256_movemask_ps(_mm256_castsi256_ps(compared));
    uniform int32 MoveMask = packmask(CurVec[programIndex] > PivotVec[programIndex]);

    prefetch_l1(&Permutation_Masks[0]);

    /* update the smallest and largest values of the array */
    foreach (i = 0 ... 8)
    {
        SmallestVec[i] = min(SmallestVec[i], CurVec[i]);
    }

    foreach (i = 0 ... 8)
    {
        BiggestVec[i] = max(BiggestVec[i], CurVec[i]);
    }

    /* how many ones, each 1 stands for an element greater than pivot */
    // int Amount_GT_Pivot = _mm_popcnt_u32((mm));
    uniform int32 Amount_GT_Pivot = popcnt(MoveMask);

    Shuffle8_One_Vector_To_Vector_(CurVec, CurVec, Permutation_Masks[MoveMask]);

    return Amount_GT_Pivot;
}

export void Pack(uniform int Data[], uniform int Mask[])
{
    foreach (i = 0 ... 8) 
    {
        if (Mask[i] < 0)   // 有点类似AVX512的压缩存储指令
            packed_store_active(&Data[0], i);
    }
}

inline uniform Sort8Type Calc_Min(uniform Sort8Type V[])
{
    uniform int Mask[8] = {7, 6, 5, 4, 3, 2, 1, 0};
    uniform Sort8Type Temp[8];
    Shuffle8_One_Vector_To_Vector_(V, Temp, Mask);

    foreach (i = 0 ... 8)
    {
        V[i] = min(V[i], Temp[i]);
    }

    uniform int Mask1[8] = {1, 0, 3, 2, 5, 4, 7, 6};
    Shuffle8_One_Vector_To_Vector_(V, Temp, Mask1);

    foreach (i = 0 ... 8)
    {
        V[i] = min(V[i], Temp[i]);
    }

    uniform int Mask2[8] = {2, 3, 0, 1, 6, 7, 4, 5};
    Shuffle8_One_Vector_To_Vector_(V, Temp, Mask2);

    foreach (i = 0 ... 8)
    {
        V[i] = min(V[i], Temp[i]);
    }

    return V[0];
}

inline uniform Sort8Type Calc_Max(uniform Sort8Type V[])
{
    uniform int Mask[8] = {7, 6, 5, 4, 3, 2, 1, 0};
    uniform Sort8Type Temp[8];
    Shuffle8_One_Vector_To_Vector_(V, Temp, Mask);

    foreach (i = 0 ... 8)
    {
        V[i] = max(V[i], Temp[i]);
    }

    uniform int Mask1[8] = {1, 0, 3, 2, 5, 4, 7, 6};
    Shuffle8_One_Vector_To_Vector_(V, Temp, Mask1);

    foreach (i = 0 ... 8)
    {
        V[i] = max(V[i], Temp[i]);
    }

    uniform int Mask2[8] = {2, 3, 0, 1, 6, 7, 4, 5};
    Shuffle8_One_Vector_To_Vector_(V, Temp, Mask2);

    foreach (i = 0 ... 8)
    {
        V[i] = max(V[i], Temp[i]);
    }

    return V[0];
}

inline void Load_Vector_8(uniform Sort8Type Src[], uniform Sort8Type Dest[])
{
    foreach(i = 0 ... 8)
    {
        Dest[i] = Src[i];
    }
}

inline void Store_Vector_8(uniform Sort8Type Src[], uniform Sort8Type Dest[])
{
    foreach(i = 0 ... 8)
    {
        Dest[i] = Src[i];
    }
}

inline uniform Sort8Type Partition_Vectorized_8(uniform Sort8Type Data[], uniform int32 Left, uniform int32 Right, uniform int32 Pivot, uniform int32& Smallest, uniform int32& Biggest)
{
    /* make array length divisible by eight, shortening the array */
    for (uniform int32 i = (Right - Left) % 8; i > 0; --i)
    {
        Smallest = min(Smallest, Data[Left]);
        Biggest = max(Biggest, Data[Left]);
        
        if (Data[Left] > Pivot)
        {
            --Right;
            uniform Sort8Type TempValue = Data[Left];
            Data[Left] = Data[Right];
            Data[Right] = TempValue;
        }
        else
        {
            ++Left;
        }
    }

    /* less than 8 elements in the array */
    if (Left == Right)
        return Left;

    /* fill vector with pivot */
    uniform Sort8Type PivotVec[8];
    foreach (i = 0 ... 8)
    {
        PivotVec[i] = Pivot;
    }

    /* vector for smallest elements */
    uniform Sort8Type SmallestVec[8];
    foreach (i = 0 ... 8)
    {
        SmallestVec[i] = Smallest;
    }

    /* vector for biggest elements */
    uniform Sort8Type BiggestVec[8];
    foreach (i = 0 ... 8)
    {
        BiggestVec[i] = Biggest;
    }

    if (Right - Left == 8)
    {
        /* if 8 elements Left after shortening */
        uniform Sort8Type Vec_Left[8];
        Load_Vector_8(Data + Left, Vec_Left);
        uniform int32 Amount_GT_Pivot = Partition_Vec(Vec_Left, PivotVec, SmallestVec, BiggestVec);
        Store_Vector_8(Vec_Left, Data + Left);

        Smallest = Calc_Min(SmallestVec);
        Biggest = Calc_Max(BiggestVec);
        return Left + (8 - Amount_GT_Pivot);
    }

    /* first and last 8 values are partitioned at the end */
    uniform Sort8Type Vec_Left[8];
    Load_Vector_8(Data + Left, Vec_Left);          /* first 8 values */

    uniform Sort8Type Vec_Right[8];
    Load_Vector_8(Data + (Right - 8), Vec_Right);  /* last 8 values  */

    /* store points of the vectors */
    uniform int32 R_Store = Right - 8; /* Right store point */
    uniform int32 L_Store = Left;      /* Left store point */

    /* indices for loading the elements */
    Left += 8;   /* increase, because first 8 elements are cached */
    Right -= 8;  /* decrease, because last 8 elements are cached */

    while (Right - Left != 0)
    {
        /* partition 8 elements per iteration */
        uniform Sort8Type Curr_Vec[8]; /* vector to be partitioned */

        /* if fewer elements are stored on the Right side of the array,
         * then next elements are loaded from the Right side,
         * otherwise from the Left side */
        if ((R_Store + 8) - Right < Left - L_Store)
        {
            Right -= 8;
            Load_Vector_8(Data + Right, Curr_Vec);
        }
        else
        {
            Load_Vector_8(Data + Left, Curr_Vec);
            Left += 8;
        }
        
        /* partition the current vector and save it on both sides of the array */
        uniform int32 Amount_GT_Pivot = Partition_Vec(Curr_Vec, PivotVec, SmallestVec, BiggestVec);
        Store_Vector_8(Curr_Vec, Data + L_Store);
        Store_Vector_8(Curr_Vec, Data + R_Store);

        /* update store points */
        R_Store -= Amount_GT_Pivot;
        L_Store += (8 - Amount_GT_Pivot);
    }

    /* partition and save Vec_Left */
    uniform int32 Amount_GT_Pivot = Partition_Vec(Vec_Left, PivotVec, SmallestVec, BiggestVec);
    Store_Vector_8(Vec_Left, Data + L_Store);
    Store_Vector_8(Vec_Left, Data + R_Store);
    L_Store += (8 - Amount_GT_Pivot);
    
    /* partition and save Vec_Right */
    Amount_GT_Pivot = Partition_Vec(Vec_Right, PivotVec, SmallestVec, BiggestVec);
    Store_Vector_8(Vec_Right, Data + L_Store);
    L_Store += (8 - Amount_GT_Pivot);

    Smallest = Calc_Min(SmallestVec); /* determine smallest value in vector */
    Biggest = Calc_Max(BiggestVec);   /* determine largest value in vector */
    return L_Store;
}

inline uniform Sort8Type Partition_Vectorized_64(uniform Sort8Type Data[], uniform int32 Left, uniform int32 Right, uniform int32 Pivot, uniform int32& Smallest, uniform int32& Biggest)
{ 
    if (Right - Left < 129) 
    {   
        /* do not optimize if less than 129 elements */
        return Partition_Vectorized_8(Data, Left, Right, Pivot, Smallest, Biggest);
    }

    /* make array length divisible by eight, shortening the array */
    for (uniform int32 i = (Right - Left) % 8; i > 0; --i)
    {
        Smallest = min(Smallest, Data[Left]);
        Biggest = max(Biggest, Data[Left]);
        
        if (Data[Left] > Pivot)
        {
            --Right;
            uniform Sort8Type TempValue = Data[Left];
            Data[Left] = Data[Right];
            Data[Right] = TempValue;
        }
        else
        {
            ++Left;
        }
    }

    /* fill vector with pivot */
    uniform Sort8Type PivotVec[8];
    foreach (i = 0 ... 8)
    {
        PivotVec[i] = Pivot;
    }

    /* vector for smallest elements */
    uniform Sort8Type SmallestVec[8];
    foreach (i = 0 ... 8)
    {
        SmallestVec[i] = Smallest;
    }

    /* vector for biggest elements */
    uniform Sort8Type BiggestVec[8];
    foreach (i = 0 ... 8)
    {
        BiggestVec[i] = Biggest;
    }

    /* make array length divisible by 64, shortening the array */
    for (uniform int32 i = ((Right - Left) % 64) / 8; i > 0; --i) 
    {
        uniform Sort8Type CurVec[8];
        Load_Vector_8(Data + Left, CurVec);

        /* which elements are larger than the pivot */
        // __m256i compared = _mm256_cmpgt_epi32(Curr_Vec, pivot_vec);
        /* extract the most significant bit from each integer of the vector */
        // int mm = _mm256_movemask_ps(_mm256_castsi256_ps(compared));
        uniform int32 MoveMask = packmask(CurVec[programIndex] > PivotVec[programIndex]);

        prefetch_l1(&Permutation_Masks[0]);

        /* update the smallest and largest values of the array */
        foreach (j = 0 ... 8)
        {
            SmallestVec[j] = min(SmallestVec[j], CurVec[j]);
        }

        foreach (j = 0 ... 8)
        {
            BiggestVec[j] = max(BiggestVec[j], CurVec[j]);
        }

        /* how many ones, each 1 stands for an element greater than pivot */
        // int Amount_GT_Pivot = _mm_popcnt_u32((mm));
        uniform int32 Amount_GT_Pivot = popcnt(MoveMask);

        // __m256i permuted = _mm256_permutevar8x32_epi32(vec_L, permutation_masks[mm])
        Shuffle8_One_Vector_To_Vector_(CurVec, CurVec, Permutation_Masks[MoveMask]);

        /* this is a slower way to partition an array with vector instructions */
        //__m256i blend_mask = _mm256_cmpgt_epi32(permuted, pivot_vec);
        uniform uint32 Compared[8];
        foreach (j = 0 ... 8)
        {
            Compared[j] = sign_extend(CurVec[j] > PivotVec[j]);
        }

        uniform Sort8Type Vec_Right[8];
        Load_Vector_8(Data + Right - 8, Vec_Right);

        //__m256i vec_L_new = _mm256_blendv_epi8(permuted, vec_R, blend_mask);
        uniform Sort8Type Vec_L_New[8];
        foreach (j = 0 ... 8)
        {
            Vec_L_New[j] = select((bool)Compared[j], Vec_Right[j], CurVec[j]);
        }

        //__m256i vec_R_new = _mm256_blendv_epi8(vec_R, permuted, blend_mask);
        uniform Sort8Type Vec_R_New[8];
        foreach (j = 0 ... 8)
        {
            Vec_R_New[j] = select((bool)Compared[j], CurVec[j], Vec_Right[j]);
        }
        
        Store_Vector_8(Vec_L_New, Data + Left); 
        Store_Vector_8(Vec_R_New, Data + Right - 8);

        Left += (8 - Amount_GT_Pivot); 
        Right -= Amount_GT_Pivot;
    }

    /* buffer 8 vectors from both sides of the array */
    uniform Sort8Type Vec_Left[8];
    uniform Sort8Type Vec_Left2[8];
    uniform Sort8Type Vec_Left3[8];
    uniform Sort8Type Vec_Left4[8];
    uniform Sort8Type Vec_Left5[8];
    uniform Sort8Type Vec_Left6[8];
    uniform Sort8Type Vec_Left7[8];
    uniform Sort8Type Vec_Left8[8];
    Load_Vector_8(Data + Left, Vec_Left);
    Load_Vector_8(Data + Left + 8, Vec_Left2);
    Load_Vector_8(Data + Left + 16, Vec_Left3);
    Load_Vector_8(Data + Left + 24, Vec_Left4);
    Load_Vector_8(Data + Left + 32, Vec_Left5);
    Load_Vector_8(Data + Left + 40, Vec_Left6);
    Load_Vector_8(Data + Left + 48, Vec_Left7);
    Load_Vector_8(Data + Left + 56, Vec_Left8);

    uniform Sort8Type Vec_Right[8];
    uniform Sort8Type Vec_Right2[8];
    uniform Sort8Type Vec_Right3[8];
    uniform Sort8Type Vec_Right4[8];
    uniform Sort8Type Vec_Right5[8];
    uniform Sort8Type Vec_Right6[8];
    uniform Sort8Type Vec_Right7[8];
    uniform Sort8Type Vec_Right8[8];
    Load_Vector_8(Data + (Right - 64), Vec_Right);
    Load_Vector_8(Data + (Right - 56), Vec_Right2);
    Load_Vector_8(Data + (Right - 48), Vec_Right3);
    Load_Vector_8(Data + (Right - 40), Vec_Right4);

    Load_Vector_8(Data + (Right - 32), Vec_Right5);
    Load_Vector_8(Data + (Right - 24), Vec_Right6);
    Load_Vector_8(Data + (Right - 16), Vec_Right7);
    Load_Vector_8(Data + (Right - 8), Vec_Right8);

    /* store points of the vectors */
    uniform int32 R_Store = Right - 64; /* Right store point */
    uniform int32 L_Store = Left; /* Left store point */
    /* indices for loading the elements */
    Left += 64; /* increase because first 64 elements are cached */
    Right -= 64; /* decrease because last 64 elements are cached */

    while (Right - Left != 0) 
    { 
        /* partition 64 elements per iteration */
        uniform Sort8Type Curr_Vec[8];
        uniform Sort8Type Curr_Vec2[8];
        uniform Sort8Type Curr_Vec3[8];
        uniform Sort8Type Curr_Vec4[8];
        uniform Sort8Type Curr_Vec5[8];
        uniform Sort8Type Curr_Vec6[8];
        uniform Sort8Type Curr_Vec7[8];
        uniform Sort8Type Curr_Vec8[8];

        /* if less elements are stored on the Right side of the array,
         * then next 8 vectors load from the Right side, otherwise load from the Left side */
        if ((R_Store + 64) - Right < Left - L_Store) 
        {
            Right -= 64;
            Load_Vector_8(Data + Right, Curr_Vec); Load_Vector_8(Data + Right + 8, Curr_Vec2);
            Load_Vector_8(Data + Right + 16, Curr_Vec3); Load_Vector_8(Data + Right + 24, Curr_Vec4);
            Load_Vector_8(Data + Right + 32, Curr_Vec5); Load_Vector_8(Data + Right + 40, Curr_Vec6);
            Load_Vector_8(Data + Right + 48, Curr_Vec7); Load_Vector_8(Data + Right + 56, Curr_Vec8); 
        }
        else 
        {
            Load_Vector_8(Data + Left, Curr_Vec); Load_Vector_8(Data + Left + 8, Curr_Vec2);
            Load_Vector_8(Data + Left + 16, Curr_Vec3); Load_Vector_8(Data + Left + 24, Curr_Vec4);
            Load_Vector_8(Data + Left + 32, Curr_Vec5); Load_Vector_8(Data + Left + 40, Curr_Vec6);
            Load_Vector_8(Data + Left + 48, Curr_Vec7); Load_Vector_8(Data + Left + 56, Curr_Vec8);
            Left += 64; 
        }

        /* partition 8 vectors and store them on both sides of the array */
        uniform int32 Amount_GT_Pivot = Partition_Vec(Curr_Vec, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot2 = Partition_Vec(Curr_Vec2, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot3 = Partition_Vec(Curr_Vec3, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot4 = Partition_Vec(Curr_Vec4, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot5 = Partition_Vec(Curr_Vec5, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot6 = Partition_Vec(Curr_Vec6, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot7 = Partition_Vec(Curr_Vec7, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot8 = Partition_Vec(Curr_Vec8, PivotVec, SmallestVec, BiggestVec);

        Store_Vector_8(Curr_Vec, Data + L_Store); L_Store += (8 - Amount_GT_Pivot);
        Store_Vector_8(Curr_Vec2, Data + L_Store); L_Store += (8 - Amount_GT_Pivot2);
        Store_Vector_8(Curr_Vec3, Data + L_Store); L_Store += (8 - Amount_GT_Pivot3);
        Store_Vector_8(Curr_Vec4, Data + L_Store); L_Store += (8 - Amount_GT_Pivot4);
        Store_Vector_8(Curr_Vec5, Data + L_Store); L_Store += (8 - Amount_GT_Pivot5);
        Store_Vector_8(Curr_Vec6, Data + L_Store); L_Store += (8 - Amount_GT_Pivot6);
        Store_Vector_8(Curr_Vec7, Data + L_Store); L_Store += (8 - Amount_GT_Pivot7);
        Store_Vector_8(Curr_Vec8, Data + L_Store); L_Store += (8 - Amount_GT_Pivot8);

        Store_Vector_8(Curr_Vec, Data + R_Store + 56); R_Store -= Amount_GT_Pivot;
        Store_Vector_8(Curr_Vec2, Data + R_Store + 56); R_Store -= Amount_GT_Pivot2;
        Store_Vector_8(Curr_Vec3, Data + R_Store + 56); R_Store -= Amount_GT_Pivot3;
        Store_Vector_8(Curr_Vec4, Data + R_Store + 56); R_Store -= Amount_GT_Pivot4;
        Store_Vector_8(Curr_Vec5, Data + R_Store + 56); R_Store -= Amount_GT_Pivot5;
        Store_Vector_8(Curr_Vec6, Data + R_Store + 56); R_Store -= Amount_GT_Pivot6;
        Store_Vector_8(Curr_Vec7, Data + R_Store + 56); R_Store -= Amount_GT_Pivot7;
        Store_Vector_8(Curr_Vec8, Data + R_Store + 56); R_Store -= Amount_GT_Pivot8;
    }

    /* partition and store 8 vectors coming from the Left side of the array */
    uniform int32 Amount_GT_Pivot = Partition_Vec(Vec_Left, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot2 = Partition_Vec(Vec_Left2, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot3 = Partition_Vec(Vec_Left3, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot4 = Partition_Vec(Vec_Left4, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot5 = Partition_Vec(Vec_Left5, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot6 = Partition_Vec(Vec_Left6, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot7 = Partition_Vec(Vec_Left7, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot8 = Partition_Vec(Vec_Left8, PivotVec, SmallestVec, BiggestVec);

    Store_Vector_8(Vec_Left, Data + L_Store); L_Store += (8 - Amount_GT_Pivot);
    Store_Vector_8(Vec_Left2, Data + L_Store); L_Store += (8 - Amount_GT_Pivot2);
    Store_Vector_8(Vec_Left3, Data + L_Store); L_Store += (8 - Amount_GT_Pivot3);
    Store_Vector_8(Vec_Left4, Data + L_Store); L_Store += (8 - Amount_GT_Pivot4);
    Store_Vector_8(Vec_Left5, Data + L_Store); L_Store += (8 - Amount_GT_Pivot5);
    Store_Vector_8(Vec_Left6, Data + L_Store); L_Store += (8 - Amount_GT_Pivot6);
    Store_Vector_8(Vec_Left7, Data + L_Store); L_Store += (8 - Amount_GT_Pivot7);
    Store_Vector_8(Vec_Left8, Data + L_Store); L_Store += (8 - Amount_GT_Pivot8);

    Store_Vector_8(Vec_Left, Data + R_Store + 56); R_Store -= Amount_GT_Pivot;
    Store_Vector_8(Vec_Left2, Data + R_Store + 56); R_Store -= Amount_GT_Pivot2;
    Store_Vector_8(Vec_Left3, Data + R_Store + 56); R_Store -= Amount_GT_Pivot3;
    Store_Vector_8(Vec_Left4, Data + R_Store + 56); R_Store -= Amount_GT_Pivot4;
    Store_Vector_8(Vec_Left5, Data + R_Store + 56); R_Store -= Amount_GT_Pivot5;
    Store_Vector_8(Vec_Left6, Data + R_Store + 56); R_Store -= Amount_GT_Pivot6;
    Store_Vector_8(Vec_Left7, Data + R_Store + 56); R_Store -= Amount_GT_Pivot7;
    Store_Vector_8(Vec_Left8, Data + R_Store + 56); R_Store -= Amount_GT_Pivot8;

    /* partition and store 8 vectors coming from the Right side of the array */
    Amount_GT_Pivot = Partition_Vec(Vec_Right, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot2 = Partition_Vec(Vec_Right2, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot3 = Partition_Vec(Vec_Right3, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot4 = Partition_Vec(Vec_Right4, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot5 = Partition_Vec(Vec_Right5, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot6 = Partition_Vec(Vec_Right6, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot7 = Partition_Vec(Vec_Right7, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot8 = Partition_Vec(Vec_Right8, PivotVec, SmallestVec, BiggestVec);

    Store_Vector_8(Vec_Right, Data + L_Store); L_Store += (8 - Amount_GT_Pivot);
    Store_Vector_8(Vec_Right2, Data + L_Store); L_Store += (8 - Amount_GT_Pivot2);
    Store_Vector_8(Vec_Right3, Data + L_Store); L_Store += (8 - Amount_GT_Pivot3);
    Store_Vector_8(Vec_Right4, Data + L_Store); L_Store += (8 - Amount_GT_Pivot4);
    Store_Vector_8(Vec_Right5, Data + L_Store); L_Store += (8 - Amount_GT_Pivot5);
    Store_Vector_8(Vec_Right6, Data + L_Store); L_Store += (8 - Amount_GT_Pivot6);
    Store_Vector_8(Vec_Right7, Data + L_Store); L_Store += (8 - Amount_GT_Pivot7);
    Store_Vector_8(Vec_Right8, Data + L_Store); L_Store += (8 - Amount_GT_Pivot8);

    Store_Vector_8(Vec_Right, Data + R_Store + 56); R_Store -= Amount_GT_Pivot;
    Store_Vector_8(Vec_Right2, Data + R_Store + 56); R_Store -= Amount_GT_Pivot2;
    Store_Vector_8(Vec_Right3, Data + R_Store + 56); R_Store -= Amount_GT_Pivot3;
    Store_Vector_8(Vec_Right4, Data + R_Store + 56); R_Store -= Amount_GT_Pivot4;
    Store_Vector_8(Vec_Right5, Data + R_Store + 56); R_Store -= Amount_GT_Pivot5;
    Store_Vector_8(Vec_Right6, Data + R_Store + 56); R_Store -= Amount_GT_Pivot6;
    Store_Vector_8(Vec_Right7, Data + R_Store + 56); R_Store -= Amount_GT_Pivot7;
    Store_Vector_8(Vec_Right8, Data + R_Store + 56);

    Smallest = Calc_Min(SmallestVec); /* determine smallest value in vector */
    Biggest = Calc_Max(BiggestVec);   /* determine largest value in vector */
    return L_Store;
}

export void QuickSort8(uniform Sort8Type Data[], uniform int32 Left, uniform int32 Right, uniform bool Choose_Avg = false, uniform int32 Avg = 0)
{
    if (Right - Left < 513)
    {
        /* use sorting networks for small arrays */
        uniform int Buffer[520]; /* buffer for sorting networks */
        uniform Sort8Type* DataLeft = Data + Left;
        uniform int DataSize = Right - Left + 1;
        Sort8_Sorting_Network_Impl(Sort8Type, DataLeft, DataSize, Buffer, 2147483647, COEX_8_ASC, COEX_SHUFFLE_8_ASC);
        return;
    }

    /* avg is average of largest and smallest values in array */
    uniform Sort8Type Pivot = Choose_Avg ? Avg : GetPivot(Data, Left, Right);

    uniform int32 Smallest = 2147483647;         /* INT32_MAX; smallest value after partitioning */
    uniform int32 Biggest = (-2147483647 - 1);   /* INT32_MIN; largest value after partitioning */

    uniform int32 Bound = Partition_Vectorized_64(Data, Left, Right + 1, Pivot, Smallest, Biggest);

    /* the ratio of the length of the smaller partition to the array length */
    uniform double Ratio = (min(Right - (Bound - 1), Bound - Left) / (uniform double)(Right - Left + 1));
    
    /* if unbalanced sub-arrays, change pivot selection strategy */
    if (Ratio < 0.2)
    {
        Choose_Avg = !Choose_Avg;
    }

    if (Pivot != Smallest) /* if values in the Left sub-array are not identical */
    {   
        QuickSort8(Data, Left, Bound - 1, Choose_Avg, Average(Smallest, Pivot));
    }
      
    if (Pivot + 1 != Biggest) /* if values in the Right sub-array are not identical */
    {   
        QuickSort8(Data, Bound, Right, Choose_Avg, Average(Biggest, Pivot));
    }
}
