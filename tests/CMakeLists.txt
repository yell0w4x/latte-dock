#! Integration tests. They deliberately exercise the real Latte objects together with the
#! real KDE/Qt classes they collaborate with; test doubles are only introduced where an
#! object can not exist outside of a running plasma shell.

find_package(GTest REQUIRED)

set(LATTE_TEST_LIBS
    GTest::gtest
    GTest::gmock
    lattedock-core
)

#! every test drives real QObjects, a few of them real QWidgets, so they all need a
#! QApplication which the shared main() below creates on the offscreen platform
add_library(lattetestmain STATIC testmain.cpp)
target_link_libraries(lattetestmain PUBLIC GTest::gtest Qt::Widgets)

macro(latte_add_test _name)
    add_executable(${_name} ${_name}.cpp ${ARGN})
    target_link_libraries(${_name} ${LATTE_TEST_LIBS} lattetestmain)
    target_include_directories(${_name} PRIVATE
        ${CMAKE_SOURCE_DIR}/app
        ${CMAKE_BINARY_DIR}/app
        ${CMAKE_SOURCE_DIR}/containment
        ${CMAKE_BINARY_DIR}/containment)
    add_test(NAME ${_name} COMMAND ${_name})
    set_tests_properties(${_name} PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endmacro()

latte_add_test(windowidtest)
latte_add_test(schemecolorstest)
latte_add_test(indicatorfactorytest)

#! the containment layout manager is built into a qml plugin, compile the very same
#! sources into the test so the tested code is identical to the shipped one
latte_add_test(layoutmanagertest
    ${CMAKE_SOURCE_DIR}/containment/plugin/layoutmanager.cpp
    ${CMAKE_SOURCE_DIR}/containment/plugin/types.cpp)
