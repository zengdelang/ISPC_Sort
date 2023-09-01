#include "ISPCSortCodeGenerator.h"
#include "Interfaces/IPluginManager.h"
#include "Misc/FileHelper.h"

/////////////////////////////////////////////////////
// FISPCSortCodeGenerator

void FISPCSortCodeGenerator::GenerateCode(const FString& ID, const TArray<FSortTypeInfo>& SortTypeInfos)
{
	const FString TemplateDir = FPaths::Combine(IPluginManager::Get().FindPlugin(TEXT("ISPC_Sort"))->GetBaseDir(), TEXT("Templates"));
	const FString CodeDir = FPaths::Combine(IPluginManager::Get().FindPlugin(TEXT("ISPC_Sort"))->GetBaseDir(), TEXT("GeneratedCodes"));

	FString Bitonic_Sort_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Sort_Params.Append(FString::Format(TEXT("uniform {0} {1}[]"), {SortType.VariableType, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Bitonic_Sort_Params.Append(", ");
		}
	}

	// BitonicSort8
	{
		const FString BitonicSort8FilePath = FPaths::Combine(TemplateDir, TEXT("BitonicSort8.ispc.template"));
		FString BitonicSort8Code;
		FFileHelper::LoadFileToString(BitonicSort8Code, *BitonicSort8FilePath);

		BitonicSort8Code.ReplaceInline(TEXT("##ID##"), *ID);
		BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Sort_Params##"), *Bitonic_Sort_Params);
		
		Generate_Bitonic_Sort_16(SortTypeInfos, BitonicSort8Code);
		Generate_Sort8_Sorting_Network_Impl(SortTypeInfos, BitonicSort8Code);
		Generate_Sort_16_Column_Wise(SortTypeInfos, BitonicSort8Code);
		Generate_Merge_8_Columns_With_16_Elements(SortTypeInfos, BitonicSort8Code);
		Generate_Bitonic_Merge(SortTypeInfos, BitonicSort8Code);
		
		const FString BitonicSort8OutputFilePath = FPaths::Combine(CodeDir, FString::Format(TEXT("BitonicSort8_{0}.ispc"), {ID}));
		FFileHelper::SaveStringToFile(BitonicSort8Code, *BitonicSort8OutputFilePath);
	}
}

void FISPCSortCodeGenerator::Generate_Bitonic_Sort_16(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code)
{
	FString LoadDataCode;
	{
		for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
		{
			const auto& SortType = SortTypeInfos[Index];
			LoadDataCode.Append(FString::Format(TEXT("	uniform {0} {1}_V1[8];\n"), {SortType.VariableType, SortType.VariableName}));
			LoadDataCode.Append(FString::Format(TEXT("	uniform {0} {1}_V2[8];\n"), {SortType.VariableType, SortType.VariableName}));
			LoadDataCode.Append(FString::Format(TEXT("	uniform {0} {1}_Temp[8];\n"), {SortType.VariableType, SortType.VariableName}));
		}

		LoadDataCode.Append(TEXT("	foreach (i = 0 ... 8)\n"));
		LoadDataCode.Append(TEXT("	{\n"));

		for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
		{
			const auto& SortType = SortTypeInfos[Index];
			LoadDataCode.Append(FString::Format(TEXT("		{0}_V1[i] = {1}[i];\n"), {SortType.VariableName, SortType.VariableName}));
			LoadDataCode.Append(FString::Format(TEXT("		{0}_V2[i] = {1}[i + 8];\n"), {SortType.VariableName, SortType.VariableName}));
		}
			
		LoadDataCode.Append(TEXT("	}"));
	}

	FString COEX_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_Params.Append(FString::Format(TEXT("{0}_V1, {1}_V2"), {SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			COEX_Params.Append(", ");
		}
	}
	
	FString COEX_Func_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_Func_Params.Append(FString::Format(TEXT("uniform {0} {1}_V1[], uniform {2} {3}_V2[], uniform {4} {5}_Min[], uniform {6} {7}_Max[]"),
			{SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName}));
		if (Index < Count - 1)
		{
			COEX_Func_Params.Append(", ");
		}
	}

	FString COEX1_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX1_Params.Append(FString::Format(TEXT("{0}_V1, {1}_V2, {2}_V1, {3}_V2"), {SortType.VariableName, SortType.VariableName, SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			COEX1_Params.Append(", ");
		}
	}

	FString COEX1_Func_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX1_Func_Params.Append(FString::Format(TEXT("uniform {0} {1}_V1[], uniform {2} {3}_V2[]"),
			{SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName}));
		if (Index < Count - 1)
		{
			COEX1_Func_Params.Append(", ");
		}
	}

	FString COEX_Sequence_Func_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_Sequence_Func_Params.Append(FString::Format(TEXT("uniform {0} {1}_V1[], "),
			{SortType.VariableType, SortType.VariableName}));
	}

	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_Sequence_Func_Params.Append(FString::Format(TEXT("uniform {0} {1}_V2[]"),
			{SortType.VariableType, SortType.VariableName}));
		if (Index < Count - 1)
		{
			COEX_Sequence_Func_Params.Append(", ");
		}
	}

	FString Copy_Temp_Vector_V1;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Copy_Temp_Vector_V1.Append(FString::Format(TEXT("		Copy_Temp_Vector8({0}_Temp, {1}_V1);"), {SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Copy_Temp_Vector_V1.Append("\n");
		}
	}

	FString Shuffle_One_Vector;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Shuffle_One_Vector.Append(FString::Format(TEXT("		Shuffle8_One_Vector({0}, {1}_V2, Mask);"), {SortType.VariableType, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Shuffle_One_Vector.Append("\n");
		}
	}

	FString Shuffle_Two_Vectors1;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Shuffle_Two_Vectors1.Append(FString::Format(TEXT("		Shuffle8_Two_Vectors({0}, {1}_V1, {2}_V2, {3}_V1, Mask1);"), {SortType.VariableType, SortType.VariableName, SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Shuffle_Two_Vectors1.Append("\n");
		}
	}

	FString Shuffle_Two_Vectors2;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Shuffle_Two_Vectors2.Append(FString::Format(TEXT("		Shuffle8_Two_Vectors({0}, {1}_Temp, {2}_V2, {3}_V2, Mask2);"), {SortType.VariableType, SortType.VariableName, SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Shuffle_Two_Vectors2.Append("\n");
		}
	}

	FString Shuffle_Two_Vectors3;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Shuffle_Two_Vectors3.Append(FString::Format(TEXT("		Shuffle8_Two_Vectors({0}, {1}_Temp, {2}_V2, {3}_V1, Mask1);"), {SortType.VariableType, SortType.VariableName, SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Shuffle_Two_Vectors3.Append("\n");
		}
	}

	FString Shuffle_Two_Vectors4;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Shuffle_Two_Vectors4.Append(FString::Format(TEXT("		Shuffle8_Two_Vectors({0}, {1}_V1, {2}_V2, {3}, Mask1);"), {SortType.VariableType, SortType.VariableName, SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Shuffle_Two_Vectors4.Append("\n");
		}
	}

	FString Shuffle_Two_Vectors5;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Shuffle_Two_Vectors5.Append(FString::Format(TEXT("		Shuffle8_Two_Vectors({0}, {1}_V1, {2}_V2, {3} + 8, Mask2);"), {SortType.VariableType, SortType.VariableName, SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Shuffle_Two_Vectors5.Append("\n");
		}
	}

	FString COEX_SHUFFLE_Func_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_SHUFFLE_Func_Params.Append(FString::Format(TEXT("uniform {0} V{1}[]"), {SortType.VariableType, 1 + Index}));
		if (Index < Count - 1)
		{
			COEX_SHUFFLE_Func_Params.Append(", ");
		}
	}

	FString COEX_SHUFFLE_Step1;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_SHUFFLE_Step1.Append(FString::Format(TEXT("	uniform {0} Temp_V{1}[8];\n"), {SortType.VariableType, 1 + Index}));
		COEX_SHUFFLE_Step1.Append(FString::Format(TEXT("	uniform {0} Min_V{1}[8];\n"), {SortType.VariableType, 1 + Index}));
		COEX_SHUFFLE_Step1.Append(FString::Format(TEXT("	uniform {0} Max_V{1}[8];\n"), {SortType.VariableType, 1 + Index}));
	}

	FString COEX_SHUFFLE_Step2;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_SHUFFLE_Step2.Append(FString::Format(TEXT("	Shuffle8_One_Vector_To_Vector({0}, V{1}, Temp_V{2}, Mask1);"), {SortType.VariableType, 1 + Index, 1 + Index}));
		if (Index < Count - 1)
		{
			COEX_SHUFFLE_Step2.Append("\n");
		}
	}

	FString COEX_SHUFFLE_Step3;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_SHUFFLE_Step3.Append(FString::Format(TEXT("Temp_V{0}, V{1}, Min_V{2}, Max_V{3}"), {1 + Index, 1 + Index, 1 + Index, 1 + Index}));
		if (Index < Count - 1)
		{
			COEX_SHUFFLE_Step3.Append(", ");
		}
	}
	
	FString COEX_SHUFFLE_Step4;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_SHUFFLE_Step4.Append(FString::Format(TEXT("	Shuffle8_Two_Vectors({0}, Min_V{1}, Max_V{2}, V{3}, Mask2);"), {SortType.VariableType, 1 + Index, 1 + Index, 1 + Index}));
		if (Index < Count - 1)
		{
			COEX_SHUFFLE_Step4.Append("\n");
		}
	}
	
	FString COEX_PERMUTE_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_PERMUTE_Params.Append(FString::Format(TEXT("uniform {0} Data{1}_V1[], "), {SortType.VariableType, Index + 1}));
	}

	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_PERMUTE_Params.Append(FString::Format(TEXT("uniform {0} Data{1}_V2[]"), {SortType.VariableType, Index + 1}));
		if (Index < Count - 1)
		{
			COEX_PERMUTE_Params.Append(", ");
		}
	}

	FString COEX_PERMUTE_Step1;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_PERMUTE_Step1.Append(FString::Format(TEXT("	Shuffle8_One_Vector({0}, Data{1}_V2, Mask);"), {SortType.VariableType, Index + 1}));
		if (Index < Count - 1)
		{
			COEX_PERMUTE_Step1.Append("\n");
		}
	}

	FString COEX_PERMUTE_Step2;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		COEX_PERMUTE_Step2.Append(FString::Format(TEXT("Data{1}_V1, Data{2}_V2"), {SortType.VariableType, Index + 1, Index + 1}));
		if (Index < Count - 1)
		{
			COEX_PERMUTE_Step2.Append(", ");
		}
	}

	BitonicSort8Code.ReplaceInline(TEXT("##COEX_PERMUTE_Step2##"), *COEX_PERMUTE_Step2);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_PERMUTE_Step1##"), *COEX_PERMUTE_Step1);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_PERMUTE_Params##"), *COEX_PERMUTE_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX1_Params##"), *COEX1_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_Sequence_Func_Params##"), *COEX_Sequence_Func_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX1_Func_Params##"), *COEX1_Func_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_SHUFFLE_Step4##"), *COEX_SHUFFLE_Step4);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_SHUFFLE_Step3##"), *COEX_SHUFFLE_Step3);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_SHUFFLE_Step2##"), *COEX_SHUFFLE_Step2);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_SHUFFLE_Step1##"), *COEX_SHUFFLE_Step1);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_SHUFFLE_Func_Params##"), *COEX_SHUFFLE_Func_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##Shuffle_Two_Vectors5##"), *Shuffle_Two_Vectors5);
	BitonicSort8Code.ReplaceInline(TEXT("##Shuffle_Two_Vectors4##"), *Shuffle_Two_Vectors4);
	BitonicSort8Code.ReplaceInline(TEXT("##Shuffle_Two_Vectors3##"), *Shuffle_Two_Vectors3);
	BitonicSort8Code.ReplaceInline(TEXT("##Shuffle_Two_Vectors2##"), *Shuffle_Two_Vectors2);
	BitonicSort8Code.ReplaceInline(TEXT("##Shuffle_Two_Vectors1##"), *Shuffle_Two_Vectors1);
	BitonicSort8Code.ReplaceInline(TEXT("##Shuffle_One_Vector##"), *Shuffle_One_Vector);
	BitonicSort8Code.ReplaceInline(TEXT("##Copy_Temp_Vector_V1##"), *Copy_Temp_Vector_V1);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_Func_Params##"), *COEX_Func_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##COEX_Params##"), *COEX_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##LoadDataCode##"), *LoadDataCode);
}

void FISPCSortCodeGenerator::Generate_Sort8_Sorting_Network_Impl(const TArray<FSortTypeInfo>& SortTypeInfos,
	FString& BitonicSort8Code)
{
	FString Func_Params;
	
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Func_Params.Append(FString::Format(TEXT("uniform {0} {1}[], uniform {2} {3}_Buffer[], uniform {4} {5}_MaxValue"), {SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName, SortType.VariableType, SortType.VariableName}));
		if (Index < Count - 1)
		{
			Func_Params.Append(", ");
		}
	}

	FString Bitonic_Sort_16_Invoke_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Sort_16_Invoke_Params.Append(FString::Format(TEXT("{0}"), {SortType.VariableName}));
		if (Index < Count - 1)
		{
			Bitonic_Sort_16_Invoke_Params.Append(", ");
		}
	}

	FString SaveBuffer;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		SaveBuffer.Append(FString::Format(TEXT("		{0}_Buffer[i] = {1}[i];"), {SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			SaveBuffer.Append("\n");
		}
	}
	
	FString SaveBufferMaxValue;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		SaveBufferMaxValue.Append(FString::Format(TEXT("		{0}_Buffer[i] = {1}_MaxValue;"), {SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			SaveBufferMaxValue.Append("\n");
		}
	}

	FString SaveData;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		SaveData.Append(FString::Format(TEXT("		{0}[i] = {1}_Buffer[i];"), {SortType.VariableName, SortType.VariableName}));
		if (Index < Count - 1)
		{
			SaveData.Append("\n");
		}
	}

	FString Bitonic_Sort_16_Rest_Invoke_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Sort_16_Rest_Invoke_Params.Append(FString::Format(TEXT("{0}_Buffer + GetVectorIndex8(I)"), {SortType.VariableName}));
		if (Index < Count - 1)
		{
			Bitonic_Sort_16_Rest_Invoke_Params.Append(", ");
		}
	}

	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Sort_16_Rest_Invoke_Params##"), *Bitonic_Sort_16_Rest_Invoke_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##SaveData##"), *SaveData);
	BitonicSort8Code.ReplaceInline(TEXT("##SaveBuffer##"), *SaveBuffer);
	BitonicSort8Code.ReplaceInline(TEXT("##SaveBufferMaxValue##"), *SaveBufferMaxValue);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Sort_16_Invoke_Params##"), *Bitonic_Sort_16_Invoke_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##Sort8_Sorting_Network_Impl_Params##"), *Func_Params);
}

void FISPCSortCodeGenerator::Generate_Sort_16_Column_Wise(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code)
{
	TArray<TArray<int32>> StepIndexList;

	TArray<int32> Step1 = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15};
	StepIndexList.Emplace(Step1);
	
	TArray<int32> Step2 = {0, 2, 1, 3, 4, 6, 5, 7, 8, 10, 9, 11, 12, 14, 13, 15};
	StepIndexList.Emplace(Step2);
	
	TArray<int32> Step3 = {0, 4, 1, 5, 2, 6, 3, 7, 8, 12, 9, 13, 10, 14, 11, 15};
	StepIndexList.Emplace(Step3);
	
	TArray<int32> Step4 = {0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15};
	StepIndexList.Emplace(Step4);
	
	TArray<int32> Step5 = {5, 10, 6, 9, 3, 12, 7, 11, 13, 14, 4, 8, 1, 2};
	StepIndexList.Emplace(Step5);
	
	TArray<int32> Step6 = {1, 4, 7, 13, 2, 8, 11, 14};
	StepIndexList.Emplace(Step6);
	
	TArray<int32> Step7 = {2, 4, 5, 6, 9, 10, 11, 13, 3, 8, 7, 12};
	StepIndexList.Emplace(Step7);
	
	TArray<int32> Step8 = {3, 5, 6, 8, 7, 9, 10, 12};
	StepIndexList.Emplace(Step8);
	
	TArray<int32> Step9 = {3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
	StepIndexList.Emplace(Step9);
	
	TArray<int32> Step10 = {6, 7, 8, 9};
	StepIndexList.Emplace(Step10);
	
	for (int32 Index = 0; Index < 16; ++Index)
	{
		for (int32 StepIndex = 0; StepIndex < 10; ++StepIndex)
		{
			FString StepParams;
			for (int32 TypeIndex = 0, Count = SortTypeInfos.Num(); TypeIndex < Count; ++TypeIndex)
			{
				if (!StepIndexList.IsValidIndex(StepIndex) || !StepIndexList[StepIndex].IsValidIndex(Index))
					continue;

				StepParams.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8({1})"), {TypeIndex, StepIndexList[StepIndex][Index]}));
				if (TypeIndex < Count - 1)
				{
					StepParams.Append(", ");
				}
			}
			BitonicSort8Code.ReplaceInline(*FString::Format(TEXT("##Sort_16_Column_Wise_Step{0}_{1}##"), {StepIndex + 1, Index}), *StepParams);
		}
	}

	FString Sort_16_Column_Wise_Invoke_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Sort_16_Column_Wise_Invoke_Params.Append(FString::Format(TEXT("{0}_Buffer + GetVectorIndex8(J)"), {SortType.VariableName}));
		if (Index < Count - 1)
		{
			Sort_16_Column_Wise_Invoke_Params.Append(", ");
		}
	}
	
	FString Sort_16_Column_Wise_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Sort_16_Column_Wise_Params.Append(FString::Format(TEXT("uniform {0} Data_{1}[]"), {SortType.VariableType, Index}));
		if (Index < Count - 1)
		{
			Sort_16_Column_Wise_Params.Append(", ");
		}
	}
	
	BitonicSort8Code.ReplaceInline(TEXT("##Sort_16_Column_Wise_Params##"), *Sort_16_Column_Wise_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##Sort_16_Column_Wise_Invoke_Params##"), *Sort_16_Column_Wise_Invoke_Params);
}

void FISPCSortCodeGenerator::Generate_Merge_8_Columns_With_16_Elements(const TArray<FSortTypeInfo>& SortTypeInfos, FString& BitonicSort8Code)
{
	TArray<TArray<int32>> StepIndexList;
	TArray<int32> Step1 = {7, 8,   6, 9,   5, 10,   4, 11,   3, 12,   2, 13,    1, 14,   0, 15,   3, 4,    2, 5,    1, 6,      0, 7,     11, 12,   10, 13,   9, 14,   8, 15,
		                   1, 2,   0, 3,   5, 6,    4, 7,    9, 10,   8, 11,    13, 14,  12, 15,  0, 1,    2, 3,    4, 5,      6, 7,     8, 9,    10, 11,   12, 13,  14, 15};
	StepIndexList.Emplace(Step1);

	TArray<int32> Step2 = {0, 1, 2, 3,    4, 5, 6, 7,   8, 9, 10, 11,  12, 13, 14, 15};
	StepIndexList.Emplace(Step2);

	TArray<int32> Step3 = {7, 8,   6, 9,   5, 10,   4, 11,   3, 12,   2, 13,    1, 14,   0, 15,   3, 4,    2, 5,    1, 6,      0, 7,     11, 12,   10, 13,   9, 14,   8, 15,
				   1, 2,   0, 3,   5, 6,    4, 7,    9, 10,   8, 11,    13, 14,  12, 15,  0, 1,    2, 3,    4, 5,      6, 7,     8, 9,    10, 11,   12, 13,  14, 15};
	StepIndexList.Emplace(Step3);
	
	TArray<int32> Step4 = {0, 1, 2, 3,    4, 5, 6, 7,   8, 9, 10, 11,  12, 13, 14, 15};
	StepIndexList.Emplace(Step4);
	
	TArray<int32> Step5 = {7, 8,   6, 9,   5, 10,   4, 11,   3, 12,   2, 13,    1, 14,   0, 15,   3, 4,    2, 5,    1, 6,      0, 7,     11, 12,   10, 13,   9, 14,   8, 15,
			   1, 2,   0, 3,   5, 6,    4, 7,    9, 10,   8, 11,    13, 14,  12, 15,  0, 1,    2, 3,    4, 5,      6, 7,     8, 9,    10, 11,   12, 13,  14, 15};
	StepIndexList.Emplace(Step5);

	TArray<int32> Step6 = {0, 1, 2, 3,    4, 5, 6, 7,   8, 9, 10, 11,  12, 13, 14, 15};
	StepIndexList.Emplace(Step6);

	for (int32 Index = 0; Index < 96; ++Index)
	{
		for (int32 StepIndex = 0; StepIndex < 10; ++StepIndex)
		{
			FString StepParams;
			for (int32 TypeIndex = 0, Count = SortTypeInfos.Num(); TypeIndex < Count; ++TypeIndex)
			{
				if (!StepIndexList.IsValidIndex(StepIndex) || !StepIndexList[StepIndex].IsValidIndex(Index))
					continue;

				StepParams.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8({1})"), {TypeIndex, StepIndexList[StepIndex][Index]}));
				if (TypeIndex < Count - 1)
				{
					StepParams.Append(", ");
				}
			}
			BitonicSort8Code.ReplaceInline(*FString::Format(TEXT("##Merge_8_Columns_With_16_Elements_Step{0}_{1}##"), {StepIndex + 1, Index}), *StepParams);
		}
	}
}

void FISPCSortCodeGenerator::Generate_Bitonic_Merge(const TArray<FSortTypeInfo>& SortTypeInfos,
	FString& BitonicSort8Code)
{
	FString Bitonic_Merge_16_Invoke_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_16_Invoke_Params.Append(FString::Format(TEXT("{0}_Buffer + GetVectorIndex8(N - N % 16)"), {SortType.VariableName}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_16_Invoke_Params.Append(", ");
		}
	}
	
	FString Bitonic_Merge_128_Invoke_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_128_Invoke_Params.Append(FString::Format(TEXT("{0}_Buffer"), {SortType.VariableName}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_128_Invoke_Params.Append(", ");
		}
	}

	FString Merge_Params;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Merge_Params.Append(FString::Format(TEXT("uniform {0} Data_{1}[]"), {SortType.VariableType, Index}));
		if (Index < Count - 1)
		{
			Merge_Params.Append(", ");
		}
	}

	FString Bitonic_Merge_Step0;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step0.Append(FString::Format(TEXT("				Shuffle8_One_Vector({0}, Data_{1} + GetVectorIndex8(L + T - 1 - J), Mask);\n"), {SortType.VariableType, Index}));
		Bitonic_Merge_Step0.Append(FString::Format(TEXT("				Shuffle8_One_Vector({0}, Data_{1} + GetVectorIndex8(L + T - 2 - J), Mask);"), {SortType.VariableType, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step0.Append("\n");
		}
	}

	FString Bitonic_Merge_Step1;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step1.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(L + J), Data_{1} + GetVectorIndex8(L + T - 1 - J)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step1.Append(", ");
		}
	}

	FString Bitonic_Merge_Step2;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step2.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(L + J + 1), Data_{1} + GetVectorIndex8(L + T - 2 - J)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step2.Append(", ");
		}
	}

	FString Bitonic_Merge_Step3;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step3.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J), Data_{1} + GetVectorIndex8(M / 2 + J)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step3.Append(", ");
		}
	}
	
	FString Bitonic_Merge_Step4;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step4.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J + 1), Data_{1} + GetVectorIndex8(M / 2 + J + 1)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step4.Append(", ");
		}
	}
	
	FString Bitonic_Merge_Step5;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step5.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J), Data_{1} + GetVectorIndex8(J + 2)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step5.Append(", ");
		}
	}
	
	FString Bitonic_Merge_Step6;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step6.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J + 1), Data_{1} + GetVectorIndex8(J + 3)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step6.Append(", ");
		}
	}
	
	FString Bitonic_Merge_Step7;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_Step7.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J), Data_{1} + GetVectorIndex8(J + 1)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Step7.Append(", ");
		}
	}
	
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step0##"), *Bitonic_Merge_Step0);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step7##"), *Bitonic_Merge_Step7);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step6##"), *Bitonic_Merge_Step6);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step5##"), *Bitonic_Merge_Step5);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step4##"), *Bitonic_Merge_Step4);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step3##"), *Bitonic_Merge_Step3);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step2##"), *Bitonic_Merge_Step2);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Step1##"), *Bitonic_Merge_Step1);
	BitonicSort8Code.ReplaceInline(TEXT("##Merge_Params##"), *Merge_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_16_Invoke_Params##"), *Bitonic_Merge_16_Invoke_Params);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_128_Invoke_Params##"), *Bitonic_Merge_128_Invoke_Params);

	FString Bitonic_Merge_Remainder16_8;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		Bitonic_Merge_Remainder16_8.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J - 8), Data_{1} + GetVectorIndex8(J)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Remainder16_8.Append(", ");
		}
	}
	
	FString Bitonic_Merge_Remainder8_4;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		Bitonic_Merge_Remainder8_4.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J - 4), Data_{1} + GetVectorIndex8(J)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_Remainder8_4.Append(", ");
		}
	}
	
	for (int32 Index = 0; Index < 8; ++Index)
	{
		FString Code;
		for (int32 TypeIndex = 0, Count = SortTypeInfos.Num(); TypeIndex < Count; ++TypeIndex)
		{
			Code.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J + {1}), Data_{2} + GetVectorIndex8(J + {3})"), {TypeIndex, Index,  TypeIndex, Index + 8}));
			if (TypeIndex < Count - 1)
			{
				Code.Append(", ");
			}
		}
		BitonicSort8Code.ReplaceInline(*FString::Format(TEXT("##Bitonic_Merge_Remainder16_{0}##"), {Index}), *Code);
	}

	for (int32 Index = 0; Index < 4; ++Index)
	{
		FString Code;
		for (int32 TypeIndex = 0, Count = SortTypeInfos.Num(); TypeIndex < Count; ++TypeIndex)
		{
			Code.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(J + {1}), Data_{2} + GetVectorIndex8(J + {3})"), {TypeIndex, Index,  TypeIndex, Index + 4}));
			if (TypeIndex < Count - 1)
			{
				Code.Append(", ");
			}
		}
		BitonicSort8Code.ReplaceInline(*FString::Format(TEXT("##Bitonic_Merge_Remainder8_{0}##"), {Index}), *Code);
	}

	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Remainder16_8##"), *Bitonic_Merge_Remainder16_8);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_Remainder8_4##"), *Bitonic_Merge_Remainder8_4);

	FString Bitonic_Merge_LastStep_1;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		Bitonic_Merge_LastStep_1.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(I)"), {Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_LastStep_1.Append(", ");
		}
	}

	FString Bitonic_Merge_LastStep_2;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		Bitonic_Merge_LastStep_2.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(I + 1)"), {Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_LastStep_2.Append(", ");
		}
	}

	FString Bitonic_Merge_LastStep_Temp;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_LastStep_Temp.Append(FString::Format(TEXT("			uniform {0} Data_{1}_Temp[8];"), {SortType.VariableType, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_LastStep_Temp.Append("\n");
		}
	}

	FString Bitonic_Merge_LastStep_Copy_Temp;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_LastStep_Copy_Temp.Append(FString::Format(TEXT("			Copy_Temp_Vector8(Data_{0}_Temp, Data_{1} + GetVectorIndex8(I));"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_LastStep_Copy_Temp.Append("\n");
		}
	}

	FString Bitonic_Merge_LastStep_Shuffle_Two;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		const auto& SortType = SortTypeInfos[Index];
		Bitonic_Merge_LastStep_Shuffle_Two.Append(FString::Format(TEXT("			Shuffle8_Two_Vectors({0}, Data_{1} + GetVectorIndex8(I), Data_{2} + GetVectorIndex8(I + 1),  Data_{3} + GetVectorIndex8(I), Mask2);\n"), {SortType.VariableType, Index, Index, Index}));
		Bitonic_Merge_LastStep_Shuffle_Two.Append(FString::Format(TEXT("			Shuffle8_Two_Vectors({0}, Data_{1}_Temp, Data_{2} + GetVectorIndex8(I + 1),  Data_{2} + GetVectorIndex8(I + 1), Mask3);"), {SortType.VariableType, Index, Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_LastStep_Shuffle_Two.Append("\n");
		}
	}

	FString Bitonic_Merge_LastStep_3;
	for (int32 Index = 0, Count = SortTypeInfos.Num(); Index < Count; ++Index)
	{
		Bitonic_Merge_LastStep_3.Append(FString::Format(TEXT("Data_{0} + GetVectorIndex8(I), Data_{1} + GetVectorIndex8(I + 1)"), {Index, Index}));
		if (Index < Count - 1)
		{
			Bitonic_Merge_LastStep_3.Append(", ");
		}
	}

	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_LastStep_Temp##"), *Bitonic_Merge_LastStep_Temp);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_LastStep_Copy_Temp##"), *Bitonic_Merge_LastStep_Copy_Temp);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_LastStep_Shuffle_Two##"), *Bitonic_Merge_LastStep_Shuffle_Two);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_LastStep_3##"), *Bitonic_Merge_LastStep_3);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_LastStep_2##"), *Bitonic_Merge_LastStep_2);
	BitonicSort8Code.ReplaceInline(TEXT("##Bitonic_Merge_LastStep_1##"), *Bitonic_Merge_LastStep_1);
}

/////////////////////////////////////////////////////
