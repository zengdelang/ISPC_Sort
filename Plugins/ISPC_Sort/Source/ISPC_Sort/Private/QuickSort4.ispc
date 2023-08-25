#include "Xoroshiro128Plus.isph"
#include "BitonicSort4.isph"

#define Sort4Type int

inline void COEX4_(uniform Sort4Type V1[], uniform Sort4Type V2[])
{
    foreach (i = 0 ... 4)
    {
        Sort4Type Temp = V1[i];

        V1[i] = min(Temp, V2[i]);
        V2[i] = max(Temp, V2[i]);
    }
}

inline void RightShift(uniform uint64* V, uniform int32 imm8)
{
    foreach (i = 0 ... 2)
    {
        V[i] = V[i] >> imm8;
    }
}

inline void Copy_Temp_Vector4_(uniform Sort4Type Temp[], uniform Sort4Type V[])
{
    foreach (i = 0 ... 4)
    {
        Temp[i] = V[i];
    }
}

void Shuffle4_One_Vector_To_Vector_(uniform Sort4Type V[], uniform int32 SaveV[], const uniform int32 Mask[])
{ 
#if TARGET_WIDTH == 4
    foreach (i = 0 ... 4) 
    { 
        (SaveV)[i] = shuffle((V)[i], Mask[i]); 
    }
#else
    uniform Sort4Type _STemp[4];
    Copy_Temp_Vector4_(_STemp, V);
    foreach (i = 0 ... 4)
    {
        #pragma ignore warning(perf)
        (SaveV)[i] = _STemp[Mask[i]];
    }
#endif
}

inline void Shuffle4_Two_Vectors_(uniform int32* V1, uniform int32* V2, uniform int32* SaveV, const uniform int32 Mask[])
{
#if TARGET_WIDTH == 4
    foreach (i = 0 ... 4)
    {
        SaveV[i] = shuffle(V1[i], V2[i], Mask[i]);
    }
#else
    uniform int32 Temp[4 + 4];
    foreach (i = 0 ... 4)
    {
        Temp[i] = V1[i];
        Temp[i + 4] = V2[i];
    }

    foreach (i = 0 ... 4)
    {
        #pragma ignore warning(perf)
        SaveV[i] = Temp[Mask[i]];
    }
#endif
}

inline void RandomBound(uniform uint64* RandomVec, uniform uint64* Bound)
{
    uniform uint64 Even[2];

    // _mm256_mul_epu32
    {
        foreach (i = 0 ... 2)
        {
            Even[i] = (uint64)(RandomVec[i] & 0xFFFFFFFF) * (uint64)(Bound[i] & 0xFFFFFFFF);
        }
    }

    RightShift(Even, 32);

    uniform uint64 Odd[2];
    RightShift(RandomVec, 32);

    // _mm256_mul_epu32
    {
        foreach (i = 0 ... 2)
        {
            Odd[i] = (uint64)(RandomVec[i] & 0xFFFFFFFF) * (uint64)(Bound[i] & 0xFFFFFFFF);
        }
    }

    uniform int Mask[4] = {0, 1 + 4, 2, 3 + 4};
    uniform int32* Even4 = (uniform int32*)(&Even[0]);
    uniform int32* Odd4 = (uniform int32*)(&Odd[0]);
    uniform int32* RandomVec4 = (uniform int32*)(&RandomVec[0]);
    Shuffle4_Two_Vectors_(Even4, Odd4, RandomVec4, Mask);
}

#ifdef GetVectorIndex4
#undef GetVectorIndex4
#endif

#define GetVectorIndex4(Index) (Index) * 4

void COEX_SHUFFLE_4_(uniform Sort4Type V[], uniform int32 Mask1[], uniform int32 Mask2[])
{
    uniform Sort4Type TempV[4];
    Shuffle4_One_Vector_To_Vector_(V, TempV, Mask1);

    uniform Sort4Type Min[4];
    uniform Sort4Type Max[4];
    foreach (i = 0 ... 4)
    {
        Min[i] = min(TempV[i], (V)[i]);
        Max[i] = max(TempV[i], (V)[i]);
    }

    Shuffle4_Two_Vectors_(Min, Max, V, Mask2);
}

/** 
 * sorting network for 4 int with compare-exchange macros
 * (used for pivot selection in median of the medians) 
 */
inline void Sort_4(uniform Sort4Type Data[])
{
    uniform int Mask[4] = {1, 0, 3, 2};
    uniform int Mask1[4] = {0, 0 + 4, 2, 2 + 4};
    COEX_SHUFFLE_4_(Data, Mask, Mask1); 

    uniform int Mask2[4] = {3, 2, 1, 0};
    uniform int Mask3[4] = {0, 1, 2 + 4, 3 + 4};
    COEX_SHUFFLE_4_(Data, Mask2, Mask3);

    COEX_SHUFFLE_4_(Data, Mask, Mask1);
}

inline uniform Sort4Type GetPivot(uniform Sort4Type Data[], uniform int32 Left, uniform int32 Right)
{
    uniform uint32 Bound[4];
    foreach (i = 0 ... 4)
    {
        Bound[i] = Right - Left + 1;
    }

    uniform uint32 LeftVec[4];
    foreach (i = 0 ... 4)
    {
        LeftVec[i] = Left;
    }

    // TODO 使用新的种子生成器来处理
    /* seeds for vectorized random number generator */
    uniform uint64 S0[2] = {8265987198341093849, 3762817312854612374}; // {8265987198341093849, 3762817312854612374, 1324281658759788278, 6214952190349879213};
    uniform uint64 S1[2] = {1324281658759788278, 6214952190349879213}; // {2874178529384792648, 1257248936691237653, 7874578921548791257, 1998265912745817298};

    foreach (i = 0 ... 2)
    {
        S0[i] = S0[i] + Left;
    }

    foreach (i = 0 ... 2)
    {
        S1[i] = S1[i] - Right;
    }

    uniform Sort4Type V[4 * 9];
    for (uniform int32 i = 0; i < 9; ++i) /* fill 9 vectors with random numbers */
    {
        /* vector with 2 random uint64_t */
        uniform uint64 Result[2];
        Xoroshiro128Plus(S0, S1, Result, 2);

        /* random numbers between 0 and bound - 1 */
        uniform uint64* Bound2 = (uniform uint64*)(&Bound[0]);
        RandomBound(Result, Bound2);
       
        /* indices for arr */
        uniform uint32* Result4 = (uniform uint32*)(&Result[0]);
        foreach (j = 0 ... 4)
        {
            Result4[j] = Result4[j] + LeftVec[j];
        }

        uniform int32 StartIndex = i * 4;
        foreach (j = 0 ... 4)
        {
            V[StartIndex + j] = Data[Result4[j]];
        }
    }

    /* median network for 9 elements */
    COEX4_(V + GetVectorIndex4(0), V + GetVectorIndex4(1)); COEX4_(V + GetVectorIndex4(2), V + GetVectorIndex4(3)); /* step 1 */
    COEX4_(V + GetVectorIndex4(4), V + GetVectorIndex4(5)); COEX4_(V + GetVectorIndex4(6), V + GetVectorIndex4(7));
    COEX4_(V + GetVectorIndex4(0), V + GetVectorIndex4(2)); COEX4_(V + GetVectorIndex4(1), V + GetVectorIndex4(3)); /* step 2 */
    COEX4_(V + GetVectorIndex4(4), V + GetVectorIndex4(6)); COEX4_(V + GetVectorIndex4(5), V + GetVectorIndex4(7));
    COEX4_(V + GetVectorIndex4(0), V + GetVectorIndex4(4)); COEX4_(V + GetVectorIndex4(1), V + GetVectorIndex4(2)); /* step 3 */
    COEX4_(V + GetVectorIndex4(5), V + GetVectorIndex4(6)); COEX4_(V + GetVectorIndex4(3), V + GetVectorIndex4(7));
    COEX4_(V + GetVectorIndex4(1), V + GetVectorIndex4(5)); COEX4_(V + GetVectorIndex4(2), V + GetVectorIndex4(6)); /* step 4 */
    COEX4_(V + GetVectorIndex4(3), V + GetVectorIndex4(5)); COEX4_(V + GetVectorIndex4(2), V + GetVectorIndex4(4)); /* step 5 */
    COEX4_(V + GetVectorIndex4(3), V + GetVectorIndex4(4));                   /* step 6 */
    COEX4_(V + GetVectorIndex4(3), V + GetVectorIndex4(8));                   /* step 7 */
    COEX4_(V + GetVectorIndex4(4), V + GetVectorIndex4(8));                   /* step 8 */

    Sort_4(V + GetVectorIndex4(4)); /* sort the eight medians in v[4] */

    return Average(V[4 * 4 + 1], V[4 * 4 + 2]); /* compute next pivot */
}

/* auto generated permutations masks for quicksort */
const uniform int32 Permutation_4_Masks[16][4] = {{0, 1, 2, 3},
                                            {1, 2, 3, 0},
                                            {0, 2, 3, 1},
                                            {2, 3, 0, 1},
                                            {0, 1, 3, 2},
                                            {1, 3, 0, 2},
                                            {0, 3, 1, 2},
                                            {3, 0, 1, 2},
                                            {0, 1, 2, 3},
                                            {1, 2, 0, 3},
                                            {0, 2, 1, 3},
                                            {2, 0, 1, 3},
                                            {0, 1, 2, 3},
                                            {1, 0, 2, 3},
                                            {0, 1, 2, 3},
                                            {0, 1, 2, 3}};

inline uniform int Partition_Vec(uniform Sort4Type CurVec[], uniform Sort4Type PivotVec[], uniform Sort4Type SmallestVec[], uniform Sort4Type BiggestVec[])
{
    /* which elements are larger than the pivot */
    /* extract the most significant bit from each integer of the vector */
    uniform int32 MoveMask = packmask(CurVec[programIndex] > PivotVec[programIndex]);
    assert(MoveMask < 16);
    
    prefetch_l1(&Permutation_4_Masks[0]);

    /* update the smallest and largest values of the array */
    foreach (i = 0 ... 4)
    {
        SmallestVec[i] = min(SmallestVec[i], CurVec[i]);
    }

    foreach (i = 0 ... 4)
    {
        BiggestVec[i] = max(BiggestVec[i], CurVec[i]);
    }

    /* how many ones, each 1 stands for an element greater than pivot */
    uniform int32 Amount_GT_Pivot = popcnt(MoveMask);

    Shuffle4_One_Vector_To_Vector_(CurVec, CurVec, Permutation_4_Masks[MoveMask]);

    return Amount_GT_Pivot;
}

inline uniform Sort4Type Calc_Min(uniform Sort4Type V[])
{
    uniform int Mask[4] = {3, 2, 1, 0};
    uniform Sort4Type Temp[4];
    Shuffle4_One_Vector_To_Vector_(V, Temp, Mask);

    foreach (i = 0 ... 4)
    {
        V[i] = min(V[i], Temp[i]);
    }

    uniform int Mask1[4] = {1, 0, 3, 2};
    Shuffle4_One_Vector_To_Vector_(V, Temp, Mask1);

    foreach (i = 0 ... 4)
    {
        V[i] = min(V[i], Temp[i]);
    }

    return V[0];
}

inline uniform Sort4Type Calc_Max(uniform Sort4Type V[])
{
    uniform int Mask[4] = {3, 2, 1, 0};
    uniform Sort4Type Temp[4];
    Shuffle4_One_Vector_To_Vector_(V, Temp, Mask);

    foreach (i = 0 ... 4)
    {
        V[i] = max(V[i], Temp[i]);
    }

    uniform int Mask1[4] = {1, 0, 3, 2};
    Shuffle4_One_Vector_To_Vector_(V, Temp, Mask1);

    foreach (i = 0 ... 4)
    {
        V[i] = max(V[i], Temp[i]);
    }

    return V[0];
}

inline void Load_Vector_4(uniform Sort4Type Src[], uniform Sort4Type Dest[])
{
    foreach(i = 0 ... 4)
    {
        Dest[i] = Src[i];
    }
}

inline void Store_Vector_4(uniform Sort4Type Src[], uniform Sort4Type Dest[])
{
    foreach(i = 0 ... 4)
    {
        Dest[i] = Src[i];
    }
}

inline uniform Sort4Type Partition_Vectorized_4(uniform Sort4Type Data[], uniform int32 Left, uniform int32 Right, uniform int32 Pivot, uniform int32& Smallest, uniform int32& Biggest)
{
    /* make array length divisible by four, shortening the array */
    for (uniform int32 i = (Right - Left) % 4; i > 0; --i)
    {
        Smallest = min(Smallest, Data[Left]);
        Biggest = max(Biggest, Data[Left]);
        
        if (Data[Left] > Pivot)
        {
            --Right;
            uniform Sort4Type TempValue = Data[Left];
            Data[Left] = Data[Right];
            Data[Right] = TempValue;
        }
        else
        {
            ++Left;
        }
    }

    /* less than 4 elements in the array */
    if (Left == Right)
        return Left;

    /* fill vector with pivot */
    uniform Sort4Type PivotVec[4];
    foreach (i = 0 ... 4)
    {
        PivotVec[i] = Pivot;
    }

    /* vector for smallest elements */
    uniform Sort4Type SmallestVec[4];
    foreach (i = 0 ... 4)
    {
        SmallestVec[i] = Smallest;
    }

    /* vector for biggest elements */
    uniform Sort4Type BiggestVec[4];
    foreach (i = 0 ... 4)
    {
        BiggestVec[i] = Biggest;
    }

    if (Right - Left == 4)
    {
        /* if 4 elements Left after shortening */
        uniform Sort4Type Vec_Left[4];
        Load_Vector_4(Data + Left, Vec_Left);
        uniform int32 Amount_GT_Pivot = Partition_Vec(Vec_Left, PivotVec, SmallestVec, BiggestVec);
        Store_Vector_4(Vec_Left, Data + Left);

        Smallest = Calc_Min(SmallestVec);
        Biggest = Calc_Max(BiggestVec);
        return Left + (4 - Amount_GT_Pivot);
    }

    /* first and last 4 values are partitioned at the end */
    uniform Sort4Type Vec_Left[4];
    Load_Vector_4(Data + Left, Vec_Left);          /* first 4 values */

    uniform Sort4Type Vec_Right[4];
    Load_Vector_4(Data + (Right - 4), Vec_Right);  /* last 4 values  */

    /* store points of the vectors */
    uniform int32 R_Store = Right - 4; /* Right store point */
    uniform int32 L_Store = Left;      /* Left store point */

    /* indices for loading the elements */
    Left += 4;   /* increase, because first 4 elements are cached */
    Right -= 4;  /* decrease, because last 4 elements are cached */

    while (Right - Left != 0)
    {
        /* partition 4 elements per iteration */
        uniform Sort4Type Curr_Vec[4]; /* vector to be partitioned */

        /* if fewer elements are stored on the Right side of the array,
         * then next elements are loaded from the Right side,
         * otherwise from the Left side */
        if ((R_Store + 4) - Right < Left - L_Store)
        {
            Right -= 4;
            Load_Vector_4(Data + Right, Curr_Vec);
        }
        else
        {
            Load_Vector_4(Data + Left, Curr_Vec);
            Left += 4;
        }
        
        /* partition the current vector and save it on both sides of the array */
        uniform int32 Amount_GT_Pivot = Partition_Vec(Curr_Vec, PivotVec, SmallestVec, BiggestVec);
        Store_Vector_4(Curr_Vec, Data + L_Store);
        Store_Vector_4(Curr_Vec, Data + R_Store);

        /* update store points */
        R_Store -= Amount_GT_Pivot;
        L_Store += (4 - Amount_GT_Pivot);
    }

    /* partition and save Vec_Left */
    uniform int32 Amount_GT_Pivot = Partition_Vec(Vec_Left, PivotVec, SmallestVec, BiggestVec);
    Store_Vector_4(Vec_Left, Data + L_Store);
    Store_Vector_4(Vec_Left, Data + R_Store);
    L_Store += (4 - Amount_GT_Pivot);
    
    /* partition and save Vec_Right */
    Amount_GT_Pivot = Partition_Vec(Vec_Right, PivotVec, SmallestVec, BiggestVec);
    Store_Vector_4(Vec_Right, Data + L_Store);
    L_Store += (4 - Amount_GT_Pivot);

    Smallest = Calc_Min(SmallestVec); /* determine smallest value in vector */
    Biggest = Calc_Max(BiggestVec);   /* determine largest value in vector */
    return L_Store;
}

inline uniform Sort4Type Partition_Vectorized_32(uniform Sort4Type Data[], uniform int32 Left, uniform int32 Right, uniform int32 Pivot, uniform int32& Smallest, uniform int32& Biggest)
{ 
    if (Right - Left < 65) 
    {   
        /* do not optimize if less than 65 elements */
        return Partition_Vectorized_4(Data, Left, Right, Pivot, Smallest, Biggest);
    }

    /* make array length divisible by four, shortening the array */
    for (uniform int32 i = (Right - Left) % 4; i > 0; --i)
    {
        Smallest = min(Smallest, Data[Left]);
        Biggest = max(Biggest, Data[Left]);
        
        if (Data[Left] > Pivot)
        {
            --Right;
            uniform Sort4Type TempValue = Data[Left];
            Data[Left] = Data[Right];
            Data[Right] = TempValue;
        }
        else
        {
            ++Left;
        }
    }

    /* fill vector with pivot */
    uniform Sort4Type PivotVec[4];
    foreach (i = 0 ... 4)
    {
        PivotVec[i] = Pivot;
    }

    /* vector for smallest elements */
    uniform Sort4Type SmallestVec[4];
    foreach (i = 0 ... 4)
    {
        SmallestVec[i] = Smallest;
    }

    /* vector for biggest elements */
    uniform Sort4Type BiggestVec[4];
    foreach (i = 0 ... 4)
    {
        BiggestVec[i] = Biggest;
    }

    /* make array length divisible by 32, shortening the array */
    for (uniform int32 i = ((Right - Left) % 32) / 4; i > 0; --i) 
    {
        uniform Sort4Type CurVec[4];
        Load_Vector_4(Data + Left, CurVec);

        /* which elements are larger than the pivot */
        /* extract the most significant bit from each integer of the vector */
        uniform int32 MoveMask = packmask(CurVec[programIndex] > PivotVec[programIndex]);
    assert(MoveMask < 16);
        prefetch_l1(&Permutation_4_Masks[0]);

        /* update the smallest and largest values of the array */
        foreach (j = 0 ... 4)
        {
            SmallestVec[j] = min(SmallestVec[j], CurVec[j]);
        }

        foreach (j = 0 ... 4)
        {
            BiggestVec[j] = max(BiggestVec[j], CurVec[j]);
        }

        /* how many ones, each 1 stands for an element greater than pivot */
        uniform int32 Amount_GT_Pivot = popcnt(MoveMask);

        Shuffle4_One_Vector_To_Vector_(CurVec, CurVec, Permutation_4_Masks[MoveMask]);

        /* this is a slower way to partition an array with vector instructions */
        uniform uint32 Compared[4];
        foreach (j = 0 ... 4)
        {
            Compared[j] = sign_extend(CurVec[j] > PivotVec[j]);
        }

        uniform Sort4Type Vec_Right[4];
        Load_Vector_4(Data + Right - 4, Vec_Right);

        uniform Sort4Type Vec_L_New[4];
        foreach (j = 0 ... 4)
        {
            Vec_L_New[j] = select((bool)Compared[j], Vec_Right[j], CurVec[j]);
        }

        uniform Sort4Type Vec_R_New[4];
        foreach (j = 0 ... 4)
        {
            Vec_R_New[j] = select((bool)Compared[j], CurVec[j], Vec_Right[j]);
        }
        
        Store_Vector_4(Vec_L_New, Data + Left); 
        Store_Vector_4(Vec_R_New, Data + Right - 4);

        Left += (4 - Amount_GT_Pivot); 
        Right -= Amount_GT_Pivot;
    }

    /* buffer 4 vectors from both sides of the array */
    uniform Sort4Type Vec_Left[4];
    uniform Sort4Type Vec_Left2[4];
    uniform Sort4Type Vec_Left3[4];
    uniform Sort4Type Vec_Left4[4];
    uniform Sort4Type Vec_Left5[4];
    uniform Sort4Type Vec_Left6[4];
    uniform Sort4Type Vec_Left7[4];
    uniform Sort4Type Vec_Left8[4];
    Load_Vector_4(Data + Left, Vec_Left);
    Load_Vector_4(Data + Left + 4, Vec_Left2);
    Load_Vector_4(Data + Left + 8, Vec_Left3);
    Load_Vector_4(Data + Left + 12, Vec_Left4);
    Load_Vector_4(Data + Left + 16, Vec_Left5);
    Load_Vector_4(Data + Left + 20, Vec_Left6);
    Load_Vector_4(Data + Left + 24, Vec_Left7);
    Load_Vector_4(Data + Left + 28, Vec_Left8);

    uniform Sort4Type Vec_Right[4];
    uniform Sort4Type Vec_Right2[4];
    uniform Sort4Type Vec_Right3[4];
    uniform Sort4Type Vec_Right4[4];
    uniform Sort4Type Vec_Right5[4];
    uniform Sort4Type Vec_Right6[4];
    uniform Sort4Type Vec_Right7[4];
    uniform Sort4Type Vec_Right8[4];
    Load_Vector_4(Data + (Right - 32), Vec_Right);
    Load_Vector_4(Data + (Right - 28), Vec_Right2);
    Load_Vector_4(Data + (Right - 24), Vec_Right3);
    Load_Vector_4(Data + (Right - 20), Vec_Right4);
    Load_Vector_4(Data + (Right - 16), Vec_Right5);
    Load_Vector_4(Data + (Right - 12), Vec_Right6);
    Load_Vector_4(Data + (Right - 8), Vec_Right7);
    Load_Vector_4(Data + (Right - 4), Vec_Right8);

    /* store points of the vectors */
    uniform int32 R_Store = Right - 32; /* Right store point */
    uniform int32 L_Store = Left; /* Left store point */
    /* indices for loading the elements */
    Left += 32; /* increase because first 32 elements are cached */
    Right -= 32; /* decrease because last 32 elements are cached */

    while (Right - Left != 0) 
    { 
        /* partition 32 elements per iteration */
        uniform Sort4Type Curr_Vec[4];
        uniform Sort4Type Curr_Vec2[4];
        uniform Sort4Type Curr_Vec3[4];
        uniform Sort4Type Curr_Vec4[4];
        uniform Sort4Type Curr_Vec5[4];
        uniform Sort4Type Curr_Vec6[4];
        uniform Sort4Type Curr_Vec7[4];
        uniform Sort4Type Curr_Vec8[4];

        /* if less elements are stored on the Right side of the array,
         * then next 4 vectors load from the Right side, otherwise load from the Left side */
        if ((R_Store + 32) - Right < Left - L_Store) 
        {
            Right -= 32;
            Load_Vector_4(Data + Right, Curr_Vec); Load_Vector_4(Data + Right + 4, Curr_Vec2);
            Load_Vector_4(Data + Right + 8, Curr_Vec3); Load_Vector_4(Data + Right + 12, Curr_Vec4);
            Load_Vector_4(Data + Right + 16, Curr_Vec5); Load_Vector_4(Data + Right + 20, Curr_Vec6);
            Load_Vector_4(Data + Right + 24, Curr_Vec7); Load_Vector_4(Data + Right + 28, Curr_Vec8); 
        }
        else 
        {
            Load_Vector_4(Data + Left, Curr_Vec); Load_Vector_4(Data + Left + 4, Curr_Vec2);
            Load_Vector_4(Data + Left + 8, Curr_Vec3); Load_Vector_4(Data + Left + 12, Curr_Vec4);
            Load_Vector_4(Data + Left + 16, Curr_Vec5); Load_Vector_4(Data + Left + 20, Curr_Vec6);
            Load_Vector_4(Data + Left + 24, Curr_Vec7); Load_Vector_4(Data + Left + 28, Curr_Vec8);
            Left += 32; 
        }

        /* partition 4 vectors and store them on both sides of the array */
        uniform int32 Amount_GT_Pivot = Partition_Vec(Curr_Vec, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot2 = Partition_Vec(Curr_Vec2, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot3 = Partition_Vec(Curr_Vec3, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot4 = Partition_Vec(Curr_Vec4, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot5 = Partition_Vec(Curr_Vec5, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot6 = Partition_Vec(Curr_Vec6, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot7 = Partition_Vec(Curr_Vec7, PivotVec, SmallestVec, BiggestVec);
        uniform int32 Amount_GT_Pivot8 = Partition_Vec(Curr_Vec8, PivotVec, SmallestVec, BiggestVec);

        Store_Vector_4(Curr_Vec, Data + L_Store); L_Store += (4 - Amount_GT_Pivot);
        Store_Vector_4(Curr_Vec2, Data + L_Store); L_Store += (4 - Amount_GT_Pivot2);
        Store_Vector_4(Curr_Vec3, Data + L_Store); L_Store += (4 - Amount_GT_Pivot3);
        Store_Vector_4(Curr_Vec4, Data + L_Store); L_Store += (4 - Amount_GT_Pivot4);
        Store_Vector_4(Curr_Vec5, Data + L_Store); L_Store += (4 - Amount_GT_Pivot5);
        Store_Vector_4(Curr_Vec6, Data + L_Store); L_Store += (4 - Amount_GT_Pivot6);
        Store_Vector_4(Curr_Vec7, Data + L_Store); L_Store += (4 - Amount_GT_Pivot7);
        Store_Vector_4(Curr_Vec8, Data + L_Store); L_Store += (4 - Amount_GT_Pivot8);

        Store_Vector_4(Curr_Vec, Data + R_Store + 28); R_Store -= Amount_GT_Pivot;
        Store_Vector_4(Curr_Vec2, Data + R_Store + 28); R_Store -= Amount_GT_Pivot2;
        Store_Vector_4(Curr_Vec3, Data + R_Store + 28); R_Store -= Amount_GT_Pivot3;
        Store_Vector_4(Curr_Vec4, Data + R_Store + 28); R_Store -= Amount_GT_Pivot4;
        Store_Vector_4(Curr_Vec5, Data + R_Store + 28); R_Store -= Amount_GT_Pivot5;
        Store_Vector_4(Curr_Vec6, Data + R_Store + 28); R_Store -= Amount_GT_Pivot6;
        Store_Vector_4(Curr_Vec7, Data + R_Store + 28); R_Store -= Amount_GT_Pivot7;
        Store_Vector_4(Curr_Vec8, Data + R_Store + 28); R_Store -= Amount_GT_Pivot8;
    }

    /* partition and store 4 vectors coming from the Left side of the array */
    uniform int32 Amount_GT_Pivot = Partition_Vec(Vec_Left, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot2 = Partition_Vec(Vec_Left2, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot3 = Partition_Vec(Vec_Left3, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot4 = Partition_Vec(Vec_Left4, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot5 = Partition_Vec(Vec_Left5, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot6 = Partition_Vec(Vec_Left6, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot7 = Partition_Vec(Vec_Left7, PivotVec, SmallestVec, BiggestVec);
    uniform int32 Amount_GT_Pivot8 = Partition_Vec(Vec_Left8, PivotVec, SmallestVec, BiggestVec);

    Store_Vector_4(Vec_Left, Data + L_Store); L_Store += (4 - Amount_GT_Pivot);
    Store_Vector_4(Vec_Left2, Data + L_Store); L_Store += (4 - Amount_GT_Pivot2);
    Store_Vector_4(Vec_Left3, Data + L_Store); L_Store += (4 - Amount_GT_Pivot3);
    Store_Vector_4(Vec_Left4, Data + L_Store); L_Store += (4 - Amount_GT_Pivot4);
    Store_Vector_4(Vec_Left5, Data + L_Store); L_Store += (4 - Amount_GT_Pivot5);
    Store_Vector_4(Vec_Left6, Data + L_Store); L_Store += (4 - Amount_GT_Pivot6);
    Store_Vector_4(Vec_Left7, Data + L_Store); L_Store += (4 - Amount_GT_Pivot7);
    Store_Vector_4(Vec_Left8, Data + L_Store); L_Store += (4 - Amount_GT_Pivot8);

    Store_Vector_4(Vec_Left, Data + R_Store + 28); R_Store -= Amount_GT_Pivot;
    Store_Vector_4(Vec_Left2, Data + R_Store + 28); R_Store -= Amount_GT_Pivot2;
    Store_Vector_4(Vec_Left3, Data + R_Store + 28); R_Store -= Amount_GT_Pivot3;
    Store_Vector_4(Vec_Left4, Data + R_Store + 28); R_Store -= Amount_GT_Pivot4;
    Store_Vector_4(Vec_Left5, Data + R_Store + 28); R_Store -= Amount_GT_Pivot5;
    Store_Vector_4(Vec_Left6, Data + R_Store + 28); R_Store -= Amount_GT_Pivot6;
    Store_Vector_4(Vec_Left7, Data + R_Store + 28); R_Store -= Amount_GT_Pivot7;
    Store_Vector_4(Vec_Left8, Data + R_Store + 28); R_Store -= Amount_GT_Pivot8;

    /* partition and store 4 vectors coming from the Right side of the array */
    Amount_GT_Pivot = Partition_Vec(Vec_Right, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot2 = Partition_Vec(Vec_Right2, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot3 = Partition_Vec(Vec_Right3, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot4 = Partition_Vec(Vec_Right4, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot5 = Partition_Vec(Vec_Right5, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot6 = Partition_Vec(Vec_Right6, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot7 = Partition_Vec(Vec_Right7, PivotVec, SmallestVec, BiggestVec);
    Amount_GT_Pivot8 = Partition_Vec(Vec_Right8, PivotVec, SmallestVec, BiggestVec);

    Store_Vector_4(Vec_Right, Data + L_Store); L_Store += (4 - Amount_GT_Pivot);
    Store_Vector_4(Vec_Right2, Data + L_Store); L_Store += (4 - Amount_GT_Pivot2);
    Store_Vector_4(Vec_Right3, Data + L_Store); L_Store += (4 - Amount_GT_Pivot3);
    Store_Vector_4(Vec_Right4, Data + L_Store); L_Store += (4 - Amount_GT_Pivot4);
    Store_Vector_4(Vec_Right5, Data + L_Store); L_Store += (4 - Amount_GT_Pivot5);
    Store_Vector_4(Vec_Right6, Data + L_Store); L_Store += (4 - Amount_GT_Pivot6);
    Store_Vector_4(Vec_Right7, Data + L_Store); L_Store += (4 - Amount_GT_Pivot7);
    Store_Vector_4(Vec_Right8, Data + L_Store); L_Store += (4 - Amount_GT_Pivot8);

    Store_Vector_4(Vec_Right, Data + R_Store + 28); R_Store -= Amount_GT_Pivot;
    Store_Vector_4(Vec_Right2, Data + R_Store + 28); R_Store -= Amount_GT_Pivot2;
    Store_Vector_4(Vec_Right3, Data + R_Store + 28); R_Store -= Amount_GT_Pivot3;
    Store_Vector_4(Vec_Right4, Data + R_Store + 28); R_Store -= Amount_GT_Pivot4;
    Store_Vector_4(Vec_Right5, Data + R_Store + 28); R_Store -= Amount_GT_Pivot5;
    Store_Vector_4(Vec_Right6, Data + R_Store + 28); R_Store -= Amount_GT_Pivot6;
    Store_Vector_4(Vec_Right7, Data + R_Store + 28); R_Store -= Amount_GT_Pivot7;
    Store_Vector_4(Vec_Right8, Data + R_Store + 28);

    Smallest = Calc_Min(SmallestVec); /* determine smallest value in vector */
    Biggest = Calc_Max(BiggestVec);   /* determine largest value in vector */
    return L_Store;
}

export void QuickSort4(uniform Sort4Type Data[], uniform int32 Left, uniform int32 Right, uniform bool Choose_Avg = false, uniform int32 Avg = 0)
{
    if (Right - Left < 257)
    {
        /* use sorting networks for small arrays */
        uniform int Buffer[260]; /* buffer for sorting networks */
        uniform Sort4Type* DataLeft = Data + Left;
        uniform int DataSize = Right - Left + 1;
        Sort4_Sorting_Network_Impl(Sort4Type, DataLeft, DataSize, Buffer, 2147483647, COEX_4_ASC, COEX_SHUFFLE_4_ASC);
        return;
    }

    /* avg is average of largest and smallest values in array */
    uniform Sort4Type Pivot = Choose_Avg ? Avg : GetPivot(Data, Left, Right);

    uniform int32 Smallest = 2147483647;         /* INT32_MAX; smallest value after partitioning */
    uniform int32 Biggest = (-2147483647 - 1);   /* INT32_MIN; largest value after partitioning */

    uniform int32 Bound = Partition_Vectorized_32(Data, Left, Right + 1, Pivot, Smallest, Biggest);

    /* the ratio of the length of the smaller partition to the array length */
    uniform double Ratio = (min(Right - (Bound - 1), Bound - Left) / (uniform double)(Right - Left + 1));
    
    /* if unbalanced sub-arrays, change pivot selection strategy */
    if (Ratio < 0.2)
    {
        Choose_Avg = !Choose_Avg;
    }

    if (Pivot != Smallest) /* if values in the Left sub-array are not identical */
    {   
        QuickSort4(Data, Left, Bound - 1, Choose_Avg, Average(Smallest, Pivot));
    }
      
    if (Pivot + 1 != Biggest) /* if values in the Right sub-array are not identical */
    {   
        QuickSort4(Data, Bound, Right, Choose_Avg, Average(Biggest, Pivot));
    }
}
