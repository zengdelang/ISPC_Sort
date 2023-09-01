#pragma once

#include "CoreMinimal.h"

struct FSortTypeInfo
{
	FString VariableType;
	FString VariableName;
};

class FISPCSortCodeGenerator
{
public:
	void GenerateCode(const FString& ID, const TArray<FSortTypeInfo>& SortTypeInfos);

protected:
	void Generate_Bitonic_Sort_16(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code);
	void Generate_Sort8_Sorting_Network_Impl(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code);
	void Generate_Sort_16_Column_Wise(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code);
	void Generate_Merge_8_Columns_With_16_Elements(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code);
	void Generate_Bitonic_Merge(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code);
};
