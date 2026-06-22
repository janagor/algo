macro(algo_configure_linker project_name)
  set(algo_USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(algo_USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC" "MSVC")
  set_property(CACHE algo_USER_LINKER_OPTION PROPERTY STRINGS ${algo_USER_LINKER_OPTION_VALUES})
  list(
    FIND
    algo_USER_LINKER_OPTION_VALUES
    ${algo_USER_LINKER_OPTION}
    algo_USER_LINKER_OPTION_INDEX)

  if(${algo_USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${algo_USER_LINKER_OPTION}', explicitly supported entries are ${algo_USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${algo_USER_LINKER_OPTION}")
endmacro()
