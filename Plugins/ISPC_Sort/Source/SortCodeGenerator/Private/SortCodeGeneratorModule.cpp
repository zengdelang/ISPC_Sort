#include "SortCodeGeneratorModule.h"
#include "ISPCSortCodeGenerator.h"

void FSortCodeGeneratorModule::StartupModule()
{
	FISPCSortCodeGenerator Generator;
	
	TArray<FSortTypeInfo> SortTypeInfos;

	FSortTypeInfo Data1;
	Data1.VariableType = TEXT("int32");
	Data1.VariableName = TEXT("Data1");
	SortTypeInfos.Emplace(Data1);

	FSortTypeInfo Data2;
	Data2.VariableType = TEXT("int32");
	Data2.VariableName = TEXT("Data2");
	SortTypeInfos.Emplace(Data2);

	FSortTypeInfo Data3;
	Data3.VariableType = TEXT("int32");
	Data3.VariableName = TEXT("Data3");
	SortTypeInfos.Emplace(Data3);
	
	Generator.GenerateCode(TEXT("MultiTypes"), SortTypeInfos);
}

void FSortCodeGeneratorModule::ShutdownModule()
{
}

IMPLEMENT_MODULE(FSortCodeGeneratorModule, SortCodeGenerator)
