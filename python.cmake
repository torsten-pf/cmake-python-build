string(JSON python_url GET ${json_meta} python url)

if(NOT python_tag)
  string(JSON python_tag GET ${json_meta} python tag)
endif()
# extract the version number from python_tag
string(REGEX REPLACE "^v(.*)" "\\1" PYTHON_VER "${python_tag}")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(BUILD_LAYOUT_OPTIONS "-d")
endif()

if(WIN32)
  # https://pythondev.readthedocs.io/windows.html

  if(NOT MSVC)
    message(FATAL_ERROR "On Windows, Python is available from Microsoft Store. Python building on Windows requires Visual Studio.")
  endif()
  # PCBUILD may contain binaries in win32 / amd64 / arm32 / arm64 subdirs
  # Todo: add ARM support
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    # 64 bits
    set(BINARY_DIR PCbuild/amd64/)
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
    # 32 bits
    set(BINARY_DIR PCbuild/x86/)
  endif()

  ExternalProject_Add(python
  GIT_REPOSITORY ${python_url}
  GIT_TAG ${python_tag}
  GIT_SHALLOW true
  CONFIGURE_COMMAND ""
  BUILD_COMMAND <SOURCE_DIR>/PCBuild/build.bat ${BUILD_LAYOUT_OPTIONS}
  INSTALL_COMMAND <SOURCE_DIR>/python.bat <SOURCE_DIR>/PC/layout/ ${BUILD_LAYOUT_OPTIONS} -s <SOURCE_DIR> -b <SOURCE_DIR>/${BINARY_DIR} -vv --copy ${CMAKE_CURRENT_BINARY_DIR}/install --preset-default
  TEST_COMMAND ""
  CONFIGURE_HANDLED_BY_BUILD ON
  INACTIVITY_TIMEOUT 60
  )
  # setup install components
  
  install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/install/ DESTINATION python COMPONENT runtime PATTERN "*.pdb" EXCLUDE PATTERN "include" EXCLUDE PATTERN "libs" EXCLUDE EXCLUDE PATTERN "tcl" EXCLUDE)
  
  install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/install/include DESTINATION python COMPONENT develop)
  install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/install/libs DESTINATION python COMPONENT develop)
  install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/install/tcl DESTINATION python COMPONENT develop)
  
  # package all components
  get_cmake_property(CPACK_COMPONENTS_ALL COMPONENTS)
  SET(CPACK_ARCHIVE_COMPONENT_INSTALL ON) 
  
  SET(CPACK_GENERATOR "TGZ")
  SET(CPACK_INCLUDE_TOPLEVEL_DIRECTORY 0)
  string(TOLOWER "python-${PYTHON_VER}-${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-${CMAKE_BUILD_TYPE}" CPACK_PACKAGE_FILE_NAME)
  include(cpack)
else()
  # Linux prereqs: https://devguide.python.org/setup/#linux

  if(NOT Autotools_FOUND)
    message(FATAL_ERROR "Python on Unix-like systems needs Autotools")
  endif()

  # prereqs
  foreach(l bzip2 expat ffi lzma readline ssl zlib)
    include(${l}.cmake)
  endforeach()

  # Python build
  set(python_args
  --prefix=${CMAKE_INSTALL_PREFIX}
  CC=${CC}
  --with-system-expat
  --disable-test-modules
  )
  if(CMAKE_BUILD_TYPE STREQUAL "Release")
    list(APPEND python_args --enable-optimizations --enable-shared)
  endif()

  set(python_cflags "${CMAKE_C_FLAGS}")
  set(python_ldflags "${LDFLAGS}")

  if(OPENSSL_FOUND)
    get_filename_component(openssl_dir ${OPENSSL_INCLUDE_DIR} DIRECTORY)
    list(APPEND python_args --with-openssl=${openssl_dir})
  else()
    list(APPEND python_args --with-openssl=${CMAKE_INSTALL_PREFIX})
  endif()

  ExternalProject_Add(python
  GIT_REPOSITORY ${python_url}
  GIT_TAG ${python_tag}
  GIT_SHALLOW true
  CONFIGURE_COMMAND <SOURCE_DIR>/configure ${python_args} CFLAGS=${python_cflags} LDFLAGS=${python_ldflags}
  BUILD_COMMAND ${MAKE_EXECUTABLE} -j
  INSTALL_COMMAND ${MAKE_EXECUTABLE} -j install
  TEST_COMMAND ""
  CONFIGURE_HANDLED_BY_BUILD ON
  INACTIVITY_TIMEOUT 60
  DEPENDS "bzip2;expat;ffi;readline;ssl;xz;zlib"
  )

endif()
