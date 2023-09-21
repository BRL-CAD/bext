# This setting is here because semicolon separated lists are a problem
# in ExternalProject_Add - they just get interpreted as separate arguments
# rather than a list.

set(LLVM_TARGETS_TO_BUILD "ARM;X86" CACHE STRING "Enabled backends")
set(LLVM_EXPERIMENTAL_TARGETS_TO_BUILD "AArch64" CACHE STRING "Enabled backends")
