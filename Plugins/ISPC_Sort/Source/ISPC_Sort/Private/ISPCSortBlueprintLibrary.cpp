#include "ISPCSortBlueprintLibrary.h"

#if INTEL_ISPC
#include "QuickSort.ispc.generated.h"
#endif

/////////////////////////////////////////////////////
// UISPCSortBlueprintLibrary

inline void UISPCSortBlueprintLibrary::Sort_Int32_ASC(TArray<int32>& Array)
{
#if INTEL_ISPC
	ispc::QuickSort_Int32_ASC(Array.GetData(), 0, Array.Num() - 1, false, 0, 40);
#endif
}

inline void UISPCSortBlueprintLibrary::Sort_Int32_DESC(TArray<int32>& Array)
{
#if INTEL_ISPC
	ispc::QuickSort_Int32_DESC(Array.GetData(), 0, Array.Num() - 1, false, 0, 40);
#endif
}

/////////////////////////////////////////////////////