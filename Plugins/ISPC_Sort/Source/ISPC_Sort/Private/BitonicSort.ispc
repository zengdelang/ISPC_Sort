#include "BitonicSort4.isph"
#include "BitonicSort8.isph"
#include "BitonicSort16.isph"
#include "BitonicSort32.isph"
#include "BitonicSort64.isph"

export void Sort4_Sorting_Network(uniform int Data[], uniform int DataSize, uniform int MaxValue)
{
//#if TARGET_WIDTH == 4
//    uniform int Buffer[260];
//    Sort4_Sorting_Network_Impl(int, Data, DataSize, Buffer, MaxValue, COEX_4_DESC, COEX_SHUFFLE_4_DESC);
//#endif
}

export void Sort16_Sorting_Network(uniform int Data[], uniform int DataSize, uniform int MaxValue)
{
//#if TARGET_WIDTH == 16
//    uniform int Buffer[1040];
//    Sort16_Sorting_Network_Impl(int, Data, DataSize, Buffer, MaxValue, COEX_16_ASC, COEX_SHUFFLE_16_ASC);
//#endif
}

export void Sort32_Sorting_Network(uniform int Data[], uniform int DataSize, uniform int MaxValue)
{
//#if TARGET_WIDTH == 32
//    uniform int Buffer[2080];
//    Sort32_Sorting_Network_Impl(int, Data, DataSize, Buffer, MaxValue, COEX_32_ASC, COEX_SHUFFLE_32_ASC);
//#endif
}

export void Sort64_Sorting_Network(uniform int Data[], uniform int DataSize, uniform int MaxValue)
{
//#if TARGET_WIDTH == 32
//    uniform int Buffer[4160];
//    Sort64_Sorting_Network_Impl(int, Data, DataSize, Buffer, MaxValue, COEX_64_ASC, COEX_SHUFFLE_64_ASC);
//#endif
}
