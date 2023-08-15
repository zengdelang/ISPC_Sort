[简体中文](./README_ZH.md) | English

# ISPC-Sort

ISPC-Sort is a plugin for UE5. Use [Intel® ISPC](https://github.com/ispc/ispc) to implement a SIMD-based quick sort algorithm
The ideas and code are based on these two research papers [1] and [2].

#### QuickSort

ISPC code
```
export void QuickSort8(uniform Sort8Type Data[], uniform int32 Left, uniform int32 Right, uniform bool Choose_Avg = false, uniform int32 Avg = 0)
```
C++ Code
```cpp
#if INTEL_ISPC
  ispc::QuickSort8(Array.GetData(), 0, Array.Num() - 1, false, 0);
#endif
```

#### BitonicSort

ISPC code
```
export void Sort8_Sorting_Network(uniform int Data[], uniform int DataSize, uniform int MaxValue)
{
    uniform int Buffer[520];
    Sort8_Sorting_Network_Impl(int, Data, DataSize, Buffer, MaxValue, COEX_8_ASC, COEX_SHUFFLE_8_ASC);
}
```
C++ code
```cpp
#if INTEL_ISPC
  ispc::Sort8_Sorting_Network(Array.GetData(), Array.Num(), MAX_int32);
#endif
```

#### TODO

QuickSort4 (Neon, SSE)

QuickSort16 (AVX512)

## Performance

### Environment

OS: Windows 11
Build: UE5 Shipping
CPU: 2th Gen Intel(R) Core(TM) i9-12900K   3.20 GHz

### BitonicSort

#### Test condition

Perform 1000,000 loops, each time generating 512 random numbers for sorting.

#### Test code

```cpp
#if INTEL_ISPC
#include "BitonicSort.ispc.generated.h"
#endif

void TestBitonicSort()
{
	uint64 Time1 = 0;
	uint64 Time2 = 0;
	uint64 Time3 = 0;
	
	for (int Index = 0; Index < 1000000; ++Index)
	{
		TArray<int32> Array;
		TArray<int32> Array1;
		TArray<int32> Array2;
		
		for (int i = 0; i < 512 ; ++i)
		{
			auto Value = FMath::Rand();
			Array.Add(Value);
			Array1.Add(Value);
			Array2.Add(Value);
		}

		const uint64 BeginTime1 = FPlatformTime::Cycles64();
		Array1.Sort();
		const uint64 EndTime1 = FPlatformTime::Cycles64();
		Time1 += EndTime1 - BeginTime1;

		const uint64 BeginTime2 = FPlatformTime::Cycles64();
		sort_int_sorting_network(Array1.GetData(), Buffer, Array1.Num());
		const uint64 EndTime2 = FPlatformTime::Cycles64();
		Time2 += EndTime2 - BeginTime2;
		
#if INTEL_ISPC
		const uint64 BeginTime3 = FPlatformTime::Cycles64();
		ispc::Sort8_Sorting_Network(Array2.GetData(), Array2.Num(), MAX_int32);
		const uint64 EndTime3 = FPlatformTime::Cycles64();
		Time3 += EndTime3 - BeginTime3;
#endif
	}
	
	FFileHelper::SaveStringToFile(FString::Format(TEXT("UE5 TArray::Sort: {0}"), {FPlatformTime::ToSeconds64(Time1)}), TEXT("J:\\TArray.txt"));
	FFileHelper::SaveStringToFile(FString::Format(TEXT("fast-and-robust AVX::Sort: {0}"), {FPlatformTime::ToSeconds64(Time2)}), TEXT("J:\\AVX.txt"));
	FFileHelper::SaveStringToFile(FString::Format(TEXT("ISPC::Sort: {0}"), {FPlatformTime::ToSeconds64(Time3)}), TEXT("J:\\ISPC.txt"));
}

```

#### Time cost

UE5 TArray::Sort:             12.294841 s

fast-and-robust AVX::Sort:    0.665838 s

ISPC::Sort:                   0.634222 s


### QuickSort

#### Test condition

Perform 10,000 loops, each time generating 100,000 random numbers for sorting.

#### Test code

```cpp
#if INTEL_ISPC
#include "BitonicSort.ispc.generated.h"
#endif 

void TestQuickSort()
{
	uint64 Time1 = 0;
	uint64 Time2 = 0;
	uint64 Time3 = 0;
	
	for (int32 Index = 0; Index < 10000; ++Index)
	{
		TArray<int32> Array;
		TArray<int32> Array1;
		TArray<int32> Array2;
		
		for (int32 J = 0; J < 100000 ; ++J)
		{
			auto Value = FMath::Rand();
			Array.Add(Value);
			Array1.Add(Value);
			Array2.Add(Value);
		}

		const uint64 BeginTime1 = FPlatformTime::Cycles64();
		Array1.Sort();
		const uint64 EndTime1 = FPlatformTime::Cycles64();
		Time1 += EndTime1 - BeginTime1;

		const uint64 BeginTime2 = FPlatformTime::Cycles64();
		avx2::_internal::qs_core(Array1.GetData(), 0, Array1.Num() - 1);
		const uint64 EndTime2 = FPlatformTime::Cycles64();
		Time2 += EndTime2 - BeginTime2;
		
#if INTEL_ISPC
		const uint64 BeginTime3 = FPlatformTime::Cycles64();
		ispc::QuickSort8(Array2.GetData(), 0, Array2.Num() - 1, false, 0);
		const uint64 EndTime3 = FPlatformTime::Cycles64();
		Time3 += EndTime3 - BeginTime3;
#endif
	}
	
	FFileHelper::SaveStringToFile(FString::Format(TEXT("UE5 TArray::Sort: {0}"), {FPlatformTime::ToSeconds64(Time1)}), TEXT("J:\\TArray.txt"));
	FFileHelper::SaveStringToFile(FString::Format(TEXT("fast-and-robust AVX::Sort: {0}"), {FPlatformTime::ToSeconds64(Time2)}), TEXT("J:\\AVX.txt"));
	FFileHelper::SaveStringToFile(FString::Format(TEXT("ISPC::Sort: {0}"), {FPlatformTime::ToSeconds64(Time3)}), TEXT("J:\\ISPC.txt"));
}

```

#### Time cost

UE5 TArray::Sort:             43.558048 s

fast-and-robust AVX::Sort:    3.214110 s

ISPC::Sort:                   3.307544 s

## References

* [1] Fast and Robust Vectorized In-Place Sorting of Primitive Types
  https://drops.dagstuhl.de/opus/volltexte/2021/13775/

* [2] A Novel Hybrid Quicksort Algorithm Vectorized using AVX-512 on Intel
  Skylake https://arxiv.org/pdf/1704.08579.pdf

* [3] https://github.com/simd-sorting/fast-and-robust: SPDX-License-Identifier: MIT

* [4] http://mitp-content-server.mit.edu:18180/books/content/sectbyfn?collid=books_pres_0&fn=Chapter%2027.pdf&id=8030

