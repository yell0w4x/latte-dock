#! Integration tests. They deliberately exercise the real Latte objects together with the
#! real KDE/Qt classes they collaborate with; test doubles are only introduced where an
#! object can not exist outside of a running plasma shell.

find_package(GTest REQUIRED)

#! QSignalSpy lives in QtTest and is used to assert that the tested objects announce their
#! changes, it is only needed by the tests themselves
find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS Test)

set(LATTE_TEST_LIBS
    GTest::gtest
    lattedock-core
)

#! gmock ships separately from gtest on some distributions. None of the tests mock anything,
#! they drive the real objects, so it is linked when it is around and skipped when it is not.
if(TARGET GTest::gmock)
    list(APPEND LATTE_TEST_LIBS GTest::gmock)
endif()

#! every test drives real QObjects, a few of them real QWidgets, so they all need a
#! QApplication which the shared main() below creates on the offscreen platform
add_library(lattetestmain STATIC testmain.cpp)
target_link_libraries(lattetestmain PUBLIC GTest::gtest Qt::Widgets Qt::Test)

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
latte_add_test(viewdatatest)
latte_add_test(universalsettingstest)

#! the qml package test compiles the shipped qml files, so it needs to know where they are
latte_add_test(qmlpackagetest)
target_compile_definitions(qmlpackagetest PRIVATE LATTE_SOURCE_DIR="${CMAKE_SOURCE_DIR}")
target_link_libraries(qmlpackagetest Qt::Qml)

#! the window view is built into the tasks qml plugin, compile it into the test the same way
latte_add_test(windowviewtest ${CMAKE_SOURCE_DIR}/plasmoid/plugin/windowview.cpp)
target_include_directories(windowviewtest PRIVATE ${CMAKE_SOURCE_DIR}/plasmoid)
target_link_libraries(windowviewtest Qt::DBus)

#! the containment layout manager is built into a qml plugin, compile the very same
#! sources into the test so the tested code is identical to the shipped one
latte_add_test(layoutmanagertest
    ${CMAKE_SOURCE_DIR}/containment/plugin/layoutmanager.cpp
    ${CMAKE_SOURCE_DIR}/containment/plugin/types.cpp)
