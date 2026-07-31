# sxcore: GDExtension shared library bridging sxkernel to Godot.

file(GLOB SXCORE_SOURCES CONFIGURE_DEPENDS src/*.cpp)
add_library(sxcore SHARED ${SXCORE_SOURCES})
# planegcs is PUBLIC on sxkernel; MSVC still needs the shared import lib when linking sxcore.dll.
if(MSVC)
  target_link_libraries(sxcore PRIVATE legacy_stdio_definitions.lib)
endif()
target_link_libraries(sxcore PRIVATE sxkernel sxvoice godot-cpp planegcs)
# Match game/sxcore.gdextension (libsxcore.*). On MSVC, DLLs use RUNTIME_OUTPUT_DIRECTORY.
set_target_properties(sxcore PROPERTIES
    OUTPUT_NAME "sxcore"
    PREFIX "lib"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/game/bin"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/game/bin"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/game/bin"
)
# Packaged releases put OCCT/PlaneGCS beside libsxcore; prefer $ORIGIN / @loader_path.
if(APPLE)
  set_target_properties(sxcore PROPERTIES
    BUILD_RPATH "@loader_path"
    INSTALL_RPATH "@loader_path"
    BUILD_WITH_INSTALL_RPATH TRUE)
elseif(UNIX)
  set_target_properties(sxcore PROPERTIES
    BUILD_RPATH "\$ORIGIN"
    INSTALL_RPATH "\$ORIGIN"
    BUILD_WITH_INSTALL_RPATH TRUE)
endif()
