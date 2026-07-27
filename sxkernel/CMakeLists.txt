# sxkernel: pure C++ modeling kernel. No Godot dependencies — headless testable.

# GLOB with CONFIGURE_DEPENDS so parallel agents can add sources without
# editing this file (merge-conflict avoidance is worth the non-idiomatic glob).
file(GLOB SXKERNEL_SOURCES CONFIGURE_DEPENDS src/*.cpp src/features/*.cpp)

# OCCT data-exchange libs differ by distro OCCT version (7.6: TKSTEP/TKIGES/TKSTL;
# 7.7+: TKDESTEP/TKDEIGES/TKDESTL). GitHub ubuntu-24.04 runners still ship 7.6.
set(_SX_OCCT_DE_NAMES TKDESTEP TKDEIGES TKDESTL)
find_library(_SX_OCCT_DE_PROBE NAMES TKDESTEP
    PATHS ${OpenCASCADE_LIBRARY_DIR} /usr/lib/x86_64-linux-gnu /usr/lib)
if(NOT _SX_OCCT_DE_PROBE)
    set(_SX_OCCT_DE_NAMES TKSTEP TKIGES TKSTL)
endif()
set(_SX_OCCT_DE_LIBS "")
foreach(_n IN LISTS _SX_OCCT_DE_NAMES)
    find_library(_SX_OCCT_DE_${_n} NAMES ${_n}
        PATHS ${OpenCASCADE_LIBRARY_DIR} /usr/lib/x86_64-linux-gnu /usr/lib)
    if(_SX_OCCT_DE_${_n})
        list(APPEND _SX_OCCT_DE_LIBS ${_SX_OCCT_DE_${_n}})
    else()
        message(FATAL_ERROR "OpenCASCADE data-exchange library ${_n} not found")
    endif()
endforeach()
unset(_SX_OCCT_DE_PROBE)

add_library(sxkernel STATIC ${SXKERNEL_SOURCES})
target_include_directories(sxkernel PUBLIC include)
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
    target_include_directories(sxkernel_tests PRIVATE ${CMAKE_SOURCE_DIR}/thirdparty/catch2)
    target_link_libraries(sxkernel_tests PRIVATE sxkernel)
    enable_testing()
    add_test(NAME sxkernel_tests COMMAND sxkernel_tests)
endif()
