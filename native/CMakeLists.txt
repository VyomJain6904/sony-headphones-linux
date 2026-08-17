add_library(sony-headphones-core STATIC
  src/backend_factory.cpp
  src/command.cpp
  src/mock_backend.cpp
  src/null_backend.cpp
  src/state.cpp
)

target_include_directories(sony-headphones-core PUBLIC include)
target_compile_definitions(sony-headphones-core PUBLIC SONY_HEADPHONES_VERSION="${PROJECT_VERSION}")
target_compile_options(sony-headphones-core PRIVATE -Wall -Wextra -Wpedantic -Wconversion -Wshadow)

if(SONY_WITH_LIBMDR)
  if(NOT SONY_LIBMDR_SOURCE_DIR OR NOT SONY_LIBMDR_BUILD_DIR)
    message(FATAL_ERROR "SONY_WITH_LIBMDR requires SONY_LIBMDR_SOURCE_DIR and SONY_LIBMDR_BUILD_DIR")
  endif()

  find_package(PkgConfig REQUIRED)
  pkg_check_modules(DBUS REQUIRED IMPORTED_TARGET dbus-1)
  find_library(BLUETOOTH_LIBRARY bluetooth REQUIRED)

  set(MDR_LIBRARY "${SONY_LIBMDR_BUILD_DIR}/libmdr/src/libmdr.a")
  set(MDR_BT_LIBRARY "${SONY_LIBMDR_BUILD_DIR}/libmdr-bt/src/libmdr-bt.a")
  set(FMT_LIBRARY "${SONY_LIBMDR_BUILD_DIR}/_deps/fmt-build/libfmt.a")
  foreach(required_file IN ITEMS "${MDR_LIBRARY}" "${MDR_BT_LIBRARY}" "${FMT_LIBRARY}")
    if(NOT EXISTS "${required_file}")
      message(FATAL_ERROR "Required pinned dependency artifact not found: ${required_file}")
    endif()
  endforeach()

  add_library(sony-libmdr STATIC IMPORTED)
  set_target_properties(sony-libmdr PROPERTIES
    IMPORTED_LOCATION "${MDR_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${SONY_LIBMDR_SOURCE_DIR}/libmdr/include"
  )
  add_library(sony-libmdr-bt STATIC IMPORTED)
  set_target_properties(sony-libmdr-bt PROPERTIES
    IMPORTED_LOCATION "${MDR_BT_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${SONY_LIBMDR_SOURCE_DIR}/libmdr-bt/include"
  )
  add_library(sony-fmt STATIC IMPORTED)
  set_target_properties(sony-fmt PROPERTIES IMPORTED_LOCATION "${FMT_LIBRARY}")

  target_sources(sony-headphones-core PRIVATE src/mdr_backend.cpp)
  target_compile_definitions(sony-headphones-core PRIVATE SONY_WITH_LIBMDR=1)
  target_link_libraries(sony-headphones-core PRIVATE
    sony-libmdr-bt
    sony-libmdr
    sony-fmt
    PkgConfig::DBUS
    "${BLUETOOTH_LIBRARY}"
  )
endif()

add_executable(sony-headphonesd src/daemon_main.cpp)
target_link_libraries(sony-headphonesd PRIVATE sony-headphones-core)
target_compile_options(sony-headphonesd PRIVATE -Wall -Wextra -Wpedantic)

add_executable(sony-headphonesctl src/ctl_main.cpp)
target_link_libraries(sony-headphonesctl PRIVATE sony-headphones-core)
target_compile_options(sony-headphonesctl PRIVATE -Wall -Wextra -Wpedantic)

install(TARGETS sony-headphonesd sony-headphonesctl RUNTIME DESTINATION bin)

if(BUILD_TESTING)
  add_executable(sony-state-test tests/state_test.cpp)
  target_link_libraries(sony-state-test PRIVATE sony-headphones-core)
  add_test(NAME state-schema COMMAND sony-state-test)

  add_executable(sony-command-test tests/command_test.cpp)
  target_link_libraries(sony-command-test PRIVATE sony-headphones-core)
  add_test(NAME command-schema COMMAND sony-command-test)

  add_executable(sony-mock-test tests/mock_test.cpp)
  target_link_libraries(sony-mock-test PRIVATE sony-headphones-core)
  add_test(NAME mock-backend COMMAND sony-mock-test)
endif()
