cmake_minimum_required(VERSION 3.22)
project(solidexpress LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo)
endif()

if(MSVC)
    add_compile_definitions(_USE_MATH_DEFINES)
    # Force shared CRT (/MD) for ALL targets. godot-cpp defaults to
    # GODOTCPP_USE_STATIC_CPP=ON (/MT); sxkernel/miniz are created before
    # godot-cpp and default to /MD, so sxcore (/MT) then fails to link with
    # unresolved __imp_* CRT symbols (hypot, miniz time/stdio, etc.).
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
        CACHE STRING "MSVC runtime library" FORCE)
    set(GODOTCPP_USE_STATIC_CPP OFF CACHE BOOL
        "Link MSVC CRT dynamically for GDExtension" FORCE)
    link_libraries(legacy_stdio_definitions.lib)
endif()

option(SX_BUILD_GDEXTENSION "Build the sxcore Godot GDExtension" ON)
option(SX_BUILD_TESTS "Build kernel unit tests" ON)
option(SX_BUILD_VOICE "Build sxvoice with whisper.cpp when vendored" OFF)

# --- system deps ---
find_package(OpenCASCADE REQUIRED)
find_package(Eigen3 REQUIRED NO_MODULE)
find_package(Boost REQUIRED)

# --- vendored: miniz (MIT, static) ---
add_library(miniz STATIC thirdparty/miniz/miniz.c)
target_include_directories(miniz PUBLIC thirdparty/miniz)
if(MSVC)
  set_property(TARGET miniz PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
endif()

# --- vendored: nlohmann/json + catch2 (header-only) ---
add_library(sx_json INTERFACE)
target_include_directories(sx_json INTERFACE thirdparty)

# --- vendored: PlaneGCS (LGPL-2.1+, MUST stay a shared library) ---
file(GLOB PLANEGCS_SOURCES thirdparty/planegcs/*.cpp)
add_library(planegcs SHARED ${PLANEGCS_SOURCES})
target_include_directories(planegcs PUBLIC thirdparty/planegcs thirdparty/planegcs-shim)
target_link_libraries(planegcs PUBLIC Eigen3::Eigen Boost::headers)
target_include_directories(planegcs SYSTEM PUBLIC ${Boost_INCLUDE_DIRS})
if(MSVC)
  target_compile_options(planegcs PRIVATE /w)
  # MSVC only emits planegcs.lib (needed to link sxcore.dll) when symbols are exported.
  set_target_properties(planegcs PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
else()
  target_compile_options(planegcs PRIVATE -w)  # vendored code: silence warnings
endif()

add_subdirectory(sxkernel)
# Always build sxvoice (stub by default). Whisper links only when SX_BUILD_VOICE=ON
# and thirdparty/whisper.cpp is present — see sxvoice/CMakeLists.txt.
add_subdirectory(sxvoice)

if(SX_BUILD_GDEXTENSION)
    # Pin the API to the exact 4.7-stable binary in tools/godot (dumped via
    # --dump-extension-api). The interface JSON comes bundled with godot-cpp.
    set(GODOTCPP_CUSTOM_API_FILE "${CMAKE_SOURCE_DIR}/thirdparty/godot-api/extension_api.json" CACHE PATH "" FORCE)
    add_subdirectory(thirdparty/godot-cpp)
    add_subdirectory(sxcore)
endif()
