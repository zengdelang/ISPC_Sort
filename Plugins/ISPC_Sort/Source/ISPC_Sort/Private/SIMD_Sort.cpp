#include "ISPC_Sort.h"

#define LOCTEXT_NAMESPACE "FISPC_SortModule"

DEFINE_LOG_CATEGORY(LogISPC_Sort);

void FISPC_SortModule::StartupModule()
{
	// This code will execute after your module is loaded into memory; the exact timing is specified in the .uplugin file per-module
}

void FISPC_SortModule::ShutdownModule()
{
	// This function may be called during shutdown to clean up your module.  For modules that support dynamic reloading,
	// we call this function before unloading the module.
}

#undef LOCTEXT_NAMESPACE
	
IMPLEMENT_MODULE(FISPC_SortModule, ISPC_Sort)