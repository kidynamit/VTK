include(ExternalProject)

# Convenience variables
set(PREFIX_DIR ${CMAKE_BINARY_DIR}/CMakeExternals/Prefix)
set(BUILD_DIR ${CMAKE_BINARY_DIR}/CMakeExternals/Build)
set(INSTALL_DIR ${CMAKE_BINARY_DIR}/CMakeExternals/Install)

# Remove previous configurations
file(REMOVE_RECURSE ${PREFIX_DIR})
file(REMOVE_RECURSE ${BUILD_DIR})
file(REMOVE_RECURSE ${INSTALL_DIR})

# Define default architectures to compile for
set(IOS_SIMULATOR_ARCHITECTURES "x86_64"
    CACHE STRING "iOS Simulator Architectures")
set(IOS_DEVICE_ARCHITECTURES "arm64"
    CACHE STRING "iOS Device Architectures")
list(REMOVE_DUPLICATES IOS_SIMULATOR_ARCHITECTURES)
list(REMOVE_DUPLICATES IOS_DEVICE_ARCHITECTURES)

# Check that at least one architure is defined
list(LENGTH IOS_SIMULATOR_ARCHITECTURES SIMULATOR_ARCHS_NBR)
list(LENGTH IOS_DEVICE_ARCHITECTURES DEVICE_ARCHS_NBR)
math(EXPR IOS_ARCHS_NBR ${DEVICE_ARCHS_NBR}+${SIMULATOR_ARCHS_NBR})
if(NOT ${IOS_ARCHS_NBR})
  message(FATAL_ERROR "No IOS simulator or device architecture to compile for. Populate IOS_DEVICE_ARCHITECTURES and/or IOS_SIMULATOR_ARCHITECTURES.")
endif()

# iOS Deployment Target
execute_process(COMMAND /usr/bin/xcrun -sdk iphoneos --show-sdk-version
                OUTPUT_VARIABLE IOS_DEPLOYMENT_TARGET_TMP
                OUTPUT_STRIP_TRAILING_WHITESPACE)
set(IOS_DEPLOYMENT_TARGET ${IOS_DEPLOYMENT_TARGET_TMP} CACHE STRING "iOS Deployment Target")

set(IOS_EMBED_BITCODE ON CACHE BOOL "Embed LLVM bitcode")

set(CMAKE_FRAMEWORK_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}/frameworks"
    CACHE PATH "Framework install path")

# Fail if the install path is invalid
if (NOT EXISTS ${CMAKE_INSTALL_PREFIX})
  message(FATAL_ERROR
    "Install path ${CMAKE_INSTALL_PREFIX} does not exist.")
endif()

# Try to make the framework install directory if it doesn't exist
if (NOT EXISTS ${CMAKE_FRAMEWORK_INSTALL_PREFIX})
  file(MAKE_DIRECTORY ${CMAKE_FRAMEWORK_INSTALL_PREFIX})
  if (NOT EXISTS ${CMAKE_FRAMEWORK_INSTALL_PREFIX})
    message(FATAL_ERROR
      "Framework install path ${CMAKE_FRAMEWORK_INSTALL_PREFIX} does not exist.")
  endif()
endif()

# First, determine how to build
if (CMAKE_GENERATOR MATCHES "NMake Makefiles")
  set(VTK_BUILD_COMMAND BUILD_COMMAND nmake)
elseif (CMAKE_GENERATOR MATCHES "Ninja")
  set(VTK_BUILD_COMMAND BUILD_COMMAND ninja)
else()
  set(VTK_BUILD_COMMAND BUILD_COMMAND make)
endif()

# make sure we have a CTestCustom.cmake file
configure_file("${VTK_CMAKE_DIR}/CTestCustom.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/CTestCustom.cmake" @ONLY)

# Compile a minimal VTK for its compile tools
macro(compile_vtk_tools)
  ExternalProject_Add(
    vtk-compile-tools
    SOURCE_DIR ${CMAKE_SOURCE_DIR}
    PREFIX ${CMAKE_BINARY_DIR}/CompileTools
    BINARY_DIR ${CMAKE_BINARY_DIR}/CompileTools
    INSTALL_COMMAND ""
    ${VTK_BUILD_COMMAND} vtkCompileTools
    BUILD_ALWAYS 1
    CMAKE_CACHE_ARGS
      -DCMAKE_BUILD_TYPE:STRING=Release
      -DVTK_BUILD_ALL_MODULES:BOOL=OFF
      -DVTK_Group_Rendering:BOOL=OFF
      -DVTK_Group_StandAlone:BOOL=ON
      -DBUILD_SHARED_LIBS:BOOL=ON
      -DBUILD_EXAMPLES:BOOL=OFF
      -DBUILD_TESTING:BOOL=OFF
      -DCMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM}
  )
endmacro()
compile_vtk_tools()


# Hide some CMake configs from the user
mark_as_advanced(FORCE
  BUILD_SHARED_LIBS
  BUILD_TESTING
  CMAKE_INSTALL_PREFIX
  CMAKE_OSX_ARCHITECTURES
  CMAKE_OSX_DEPLOYMENT_TARGET
  CMAKE_OSX_ROOT
  VTK_RENDERING_BACKEND
)
if(BUILD_SHARED_LIBS)
  message(WARNING "Can not build shared libraries for iOS framework. BUILD_SHARED_LIBS will be ignored.")
endif()
if(BUILD_TESTING)
  message(WARNING "Tests not supported for the iOS framework. BUILD_TESTING will be ignored.")
endif()

# expose some module options
option(Module_vtkRenderingOpenGL2 "Include Polygonal Rendering Support" ON)
option(Module_vtkInteractionStyle "Include InteractionStyle module" ON)
option(Module_vtkInteractionWidgets "Include InteractionWidgets module" OFF)
option(Module_vtkIOXML "Include IO/XML Module" OFF)
option(Module_vtkDICOM "Turn on or off this module" OFF)
option(Module_vtkFiltersModeling "Turn on or off this module" OFF)
option(Module_vtkFiltersSources "Turn on or off this module" OFF)
option(Module_vtkIOGeometry "Turn on or off this module" OFF)
option(Module_vtkIOLegacy "Turn on or off this module" OFF)
option(Module_vtkIOImage "Turn on or off this module" OFF)
option(Module_vtkIOPLY "Turn on or off this module" OFF)
option(Module_vtkIOInfovis "Turn on or off this module" OFF)
option(Module_vtkRenderingFreeType "Turn on or off this module" OFF)
option(Module_vtkRenderingImage "Turn on or off this module" OFF)
option(Module_vtkRenderingVolumeOpenGL2 "Include Volume Rendering Support" ON)
option(Module_vtkRenderingLOD "Include LOD Rendering Support" OFF)


if (Module_vtkDICOM)
  set(DICOM_OPTION -DModule_vtkDICOM:BOOL=ON)
endif()

mark_as_advanced(Module_${vtk-module})

# Now cross-compile VTK with custom toolchains
set(ios_cmake_flags
  -DBUILD_SHARED_LIBS:BOOL=OFF
  -DBUILD_TESTING:BOOL=OFF
  -DBUILD_EXAMPLES:BOOL=${BUILD_EXAMPLES}
  -DVTK_USE_64BIT_IDS:BOOL=OFF
  -DVTK_Group_Rendering:BOOL=OFF
  -DVTK_Group_StandAlone:BOOL=OFF
  -DVTK_Group_Imaging:BOOL=OFF
  -DVTK_Group_MPI:BOOL=OFF
  -DVTK_Group_Views:BOOL=OFF
  -DVTK_Group_Qt:BOOL=OFF
  -DVTK_Group_Tk:BOOL=OFF
  -DVTK_Group_Web:BOOL=OFF
  -DModule_vtkRenderingOpenGL2:BOOL=${Module_vtkRenderingOpenGL2}
  -DModule_vtkInteractionStyle:BOOL=${Module_vtkInteractionStyle}
  -DModule_vtkInteractionWidgets:BOOL=${Module_vtkInteractionWidgets}
  -DModule_vtkIOXML:BOOL=${Module_vtkIOXML}
  ${DICOM_OPTION}
  -DModule_vtkFiltersModeling:BOOL=${Module_vtkFiltersModeling}
  -DModule_vtkFiltersSources:BOOL=${Module_vtkFiltersSources}
  -DModule_vtkIOGeometry:BOOL=${Module_vtkIOGeometry}
  -DModule_vtkIOLegacy:BOOL=${Module_vtkIOLegacy}
  -DModule_vtkIOImage:BOOL=${Module_vtkIOImage}
  -DModule_vtkIOPLY:BOOL=${Module_vtkIOPLY}
  -DModule_vtkIOInfovis:BOOL=${Module_vtkIOInfovis}
  -DModule_vtkRenderingFreeType:BOOL=${Module_vtkRenderingFreeType}
  -DModule_vtkRenderingImage:BOOL=${Module_vtkRenderingImage}
  -DModule_vtkRenderingVolumeOpenGL2:BOOL=${Module_vtkRenderingVolumeOpenGL2}
  -DModule_vtkRenderingLOD:BOOL=${Module_vtkRenderingLOD}
)

if (Module_vtkDICOM AND IOS_EMBED_BITCODE)
  # libvtkzlib does not contain bitcode
  list (APPEND ios_cmake_flags
    -DBUILD_DICOM_PROGRAMS:BOOL=OFF
    )
endif()

if (Module_vtkRenderingOpenGL2 OR Module_vtkRenderingVolumeOpenGL2)
  list (APPEND ios_cmake_flags
    -DVTK_RENDERING_BACKEND:STRING=OpenGL2
    )
else()
  list (APPEND ios_cmake_flags
    -DVTK_RENDERING_BACKEND:STRING=None
    )
endif()

macro(crosscompile target toolchain_file)
  ExternalProject_Add(
    ${target}
    SOURCE_DIR ${CMAKE_SOURCE_DIR}
    PREFIX ${PREFIX_DIR}/${target}
    BINARY_DIR ${BUILD_DIR}/${target}
    INSTALL_DIR ${INSTALL_DIR}/${target}
    DEPENDS vtk-compile-tools
    ${BUILD_ALWAYS_STRING}
    CMAKE_ARGS
      -DCMAKE_CROSSCOMPILING:BOOL=ON
      -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE}
      -DCMAKE_TOOLCHAIN_FILE:FILEPATH=${toolchain_file}
      -DVTKCompileTools_DIR:PATH=${CMAKE_BINARY_DIR}/CompileTools
      -DCMAKE_INSTALL_PREFIX:PATH=${INSTALL_DIR}/${target}
      -DCMAKE_MAKE_PROGRAM:FILEPATH=${CMAKE_MAKE_PROGRAM}
      ${ios_cmake_flags}
  )
  #
  # add an INSTALL_ALWAYS since we want it and cmake lacks it
  #
  ExternalProject_Get_Property(${target} binary_dir)
  _ep_get_build_command(${target} INSTALL cmd)
  ExternalProject_Add_Step(${target} always-install
    COMMAND ${cmd}
    WORKING_DIRECTORY ${binary_dir}
    DEPENDEES build install
    ALWAYS 1
    )
endmacro()

# for simulator architectures
if (${SIMULATOR_ARCHS_NBR})
  configure_file(CMake/ios.simulator.toolchain.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/CMake/ios.simulator.toolchain.cmake
    @ONLY
  )
  crosscompile(vtk-ios-simulator
    ${CMAKE_CURRENT_BINARY_DIR}/CMake/ios.simulator.toolchain.cmake
  )
  set(VTK_GLOB_LIBS "${VTK_GLOB_LIBS} \"${INSTALL_DIR}/vtk-ios-simulator/lib/libvtk*.a\"" )
  list(APPEND IOS_ARCHITECTURES vtk-ios-simulator )
endif()

# for each device architecture
foreach (arch ${IOS_DEVICE_ARCHITECTURES})
  set(CMAKE_CC_ARCH ${arch})
  configure_file(CMake/ios.device.toolchain.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/CMake/ios.device.toolchain.${arch}.cmake
    @ONLY
  )
  crosscompile(vtk-ios-device-${arch}
    ${CMAKE_CURRENT_BINARY_DIR}/CMake/ios.device.toolchain.${arch}.cmake
  )
  set(VTK_GLOB_LIBS "${VTK_GLOB_LIBS} \"${INSTALL_DIR}/vtk-ios-device-${arch}/lib/libvtk*.a\"" )
  list(APPEND IOS_ARCHITECTURES vtk-ios-device-${arch} )
endforeach()

# Pile it all into a framework
list(GET IOS_ARCHITECTURES 0 IOS_ARCH_FIRST)
set(VTK_INSTALLED_HEADERS
    "${INSTALL_DIR}/${IOS_ARCH_FIRST}/include/vtk-${VTK_MAJOR_VERSION}.${VTK_MINOR_VERSION}")
configure_file(CMake/MakeFramework.cmake.in
               ${CMAKE_CURRENT_BINARY_DIR}/CMake/MakeFramework.cmake
               @ONLY)
add_custom_target(vtk-framework ALL
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/CMake/MakeFramework.cmake
  DEPENDS ${IOS_ARCHITECTURES})
