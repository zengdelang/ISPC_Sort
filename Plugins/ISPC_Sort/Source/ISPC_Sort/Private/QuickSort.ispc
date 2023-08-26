#include "PrimitiveTypes/QuickSort4.isph"

export void QuickSort_Int32_ASC(uniform int32 Data[], uniform uint32 Left, uniform uint32 Right, 
    uniform bool Choose_Avg = false, uniform int32 Avg = 0, uniform int16 RemainingLevels = 40)
{
#if TARGET_WIDTH == 4
    QuickSort4_Int32_ASC_Impl(Data, Left, Right, Choose_Avg, Avg, RemainingLevels);
#elif TARGET_WIDTH == 8

#else
    assert(false);
#endif
}

export void QuickSort_Int32_DESC(uniform int32 Data[], uniform uint32 Left, uniform uint32 Right, 
    uniform bool Choose_Avg = false, uniform int32 Avg = 0, uniform int16 RemainingLevels = 40)
{
#if TARGET_WIDTH == 4
    QuickSort4_Int32_DESC_Impl(Data, Left, Right, Choose_Avg, Avg, RemainingLevels);
#elif TARGET_WIDTH == 8

#else
    assert(false);
#endif
}

export void QuickSort_Float_ASC(uniform float Data[], uniform uint32 Left, uniform uint32 Right, 
    uniform bool Choose_Avg = false, uniform float Avg = 0, uniform int16 RemainingLevels = 40)
{
#if TARGET_WIDTH == 4
    QuickSort4_Float_ASC_Impl(Data, Left, Right, Choose_Avg, Avg, RemainingLevels);
#elif TARGET_WIDTH == 8

#else
    assert(false);
#endif
}

export void QuickSort_Float_DESC(uniform float Data[], uniform uint32 Left, uniform uint32 Right, 
    uniform bool Choose_Avg = false, uniform float Avg = 0, uniform int16 RemainingLevels = 40)
{
#if TARGET_WIDTH == 4
    QuickSort4_Float_DESC_Impl(Data, Left, Right, Choose_Avg, Avg, RemainingLevels);
#elif TARGET_WIDTH == 8

#else
    assert(false);
#endif
}