include_guard(GLOBAL)

function(bext_add_supply_chain_tool)
  if (TARGET bext_supply_chain)
    return()
  endif ()
  add_executable(bext_supply_chain
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/InstallTransform.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/Process.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/QtAttributions.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/ReleaseBuild.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/Scan.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/Updates.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/main.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/Generate.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/Validate.cpp"
    "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/SupplyChain/Vex.cpp")
  target_compile_features(bext_supply_chain PRIVATE cxx_std_17)
endfunction()
