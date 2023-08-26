#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "ISPCSortBlueprintLibrary.generated.h"

UCLASS(meta=(ScriptName="ISPCSortLibrary"))
class ISPC_SORT_API UISPCSortBlueprintLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	UFUNCTION(BlueprintCallable, Category = "ISPC Sort")
	static void Sort_Int32_ASC(TArray<int32>& Array);
	
	UFUNCTION(BlueprintCallable, Category = "ISPC Sort")
	static void Sort_Int32_DESC(TArray<int32>& Array);
};
