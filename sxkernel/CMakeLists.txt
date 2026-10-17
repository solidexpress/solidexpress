# sxkernel: pure C++ modeling kernel. No Godot dependencies — headless testable.

# GLOB with CONFIGURE_DEPENDS so parallel agents can add sources without
# editing this file (merge-conflict avoidance is worth the non-idiomatic glob).
file(GLOB SXKERNEL_SOURCES CONFIGURE_DEPENDS src/*.cpp src/features/*.cpp)

# OCCT data-exchange libs differ by version (7.6: TKSTEP/TKIGES/TKSTL;
# 7.7+/8.x: TKDESTEP/TKDEIGES/TKDESTL). SolidExpress pins OCCT 8.0.1
# (packaging/occt.version); the 7.6 names remain only as a local fallback.
# Re-probe when the OCCT install changes (e.g. system 7.9 -> pinned 8.0.1);
# otherwise cached paths from the old install get linked next to the new one.
if(NOT "${_SX_OCCT_DE_FOR}" STREQUAL "${OpenCASCADE_LIBRARY_DIR}")
    foreach(_v PROBE TKDESTEP TKDEIGES TKDESTL TKSTEP TKIGES TKSTL)
        unset(_SX_OCCT_DE_${_v} CACHE)
    endforeach()
    set(_SX_OCCT_DE_FOR "${OpenCASCADE_LIBRARY_DIR}" CACHE INTERNAL "OCCT lib dir the DE probe ran against")
endif()
set(_SX_OCCT_DE_NAMES TKDESTEP TKDEIGES TKDESTL)
find_library(_SX_OCCT_DE_PROBE NAMES TKDESTEP
    HINTS ${OpenCASCADE_LIBRARY_DIR} PATHS /usr/lib/x86_64-linux-gnu /usr/lib)
if(NOT _SX_OCCT_DE_PROBE)
    set(_SX_OCCT_DE_NAMES TKSTEP TKIGES TKSTL)
endif()
set(_SX_OCCT_DE_LIBS "")
foreach(_n IN LISTS _SX_OCCT_DE_NAMES)
    find_library(_SX_OCCT_DE_${_n} NAMES ${_n}
        HINTS ${OpenCASCADE_LIBRARY_DIR} PATHS /usr/lib/x86_64-linux-gnu /usr/lib)
    if(_SX_OCCT_DE_${_n})
        list(APPEND _SX_OCCT_DE_LIBS ${_SX_OCCT_DE_${_n}})
    else()
        message(FATAL_ERROR "OpenCASCADE data-exchange library ${_n} not found")
    endif()
endforeach()
unset(_SX_OCCT_DE_PROBE)

add_library(sxkernel STATIC ${SXKERNEL_SOURCES})
target_include_directories(sxkernel PUBLIC include ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_include_directories(sxkernel SYSTEM PUBLIC ${OpenCASCADE_INCLUDE_DIR})
target_link_libraries(sxkernel
    PUBLIC
        TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo
        TKPrim TKBO TKShHealing TKBool TKFillet TKOffset TKFeat TKMesh TKHLR
        TKXSBase
        ${_SX_OCCT_DE_LIBS}
        miniz
        sx_json
        planegcs
)

if(SX_BUILD_TESTS)
    file(GLOB SXKERNEL_TEST_SOURCES tests/*.cpp)
    add_executable(sxkernel_tests ${SXKERNEL_TEST_SOURCES})
    target_include_directories(sxkernel_tests PRIVATE
        ${CMAKE_SOURCE_DIR}/thirdparty/catch2
        ${CMAKE_CURRENT_SOURCE_DIR}/src)
    target_link_libraries(sxkernel_tests PRIVATE sxkernel)
    # planegcs RUNTIME_OUTPUT_DIRECTORY is game/bin (Godot load path). On Windows
    # the loader only searches the exe directory first — without this copy,
    # sxkernel_tests.exe fails to start (Git Bash exit 127, no output).
    if(WIN32)
        add_custom_command(TARGET sxkernel_tests POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                $<TARGET_FILE:planegcs>
                $<TARGET_FILE_DIR:sxkernel_tests>
            COMMENT "Stage planegcs.dll beside sxkernel_tests.exe")
    endif()
    enable_testing()
    add_test(NAME sxkernel_tests COMMAND sxkernel_tests)
endif()

if(MSVC)
  target_link_libraries(sxkernel PUBLIC legacy_stdio_definitions.lib)
endif()
