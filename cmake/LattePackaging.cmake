#! Turns the installed tree into a distribution package.
#!
#! The images under packaging/ configure with the prefix of their distribution and then run
#! "cpack -G DEB" or "cpack -G RPM" over this. Only what "cmake --install" writes ends up in
#! the package, so the tests and everything else built next to it stay out of it.
#!
#! The libraries Latte links are discovered by the generators themselves, dpkg-shlibdeps for
#! the deb and the rpm dependency generator for the rpm. What neither of them can see are the
#! qml modules the shipped qml files import at runtime, e.g. the task manager or pipewire
#! ones, since nothing links against those. Each image passes the names its distribution uses
#! for them through LATTE_PACKAGE_RUNTIME_DEPENDS.

set(LATTE_PACKAGE_RUNTIME_DEPENDS "" CACHE STRING
    "Runtime packages carrying the qml modules Latte imports, comma separated")

#! The distribution release a binary package was built on, e.g. "ubuntu25.04". A deb or an rpm
#! resolves against the libraries of the release it was built on and is installable on that
#! release only, so the images under packaging/ name theirs here. It reaches the version of the
#! package and through it the file name, which is what keeps two builds of the same Latte
#! version apart, both in a directory of downloads and in the eyes of dpkg and rpm.
set(LATTE_PACKAGE_RELEASE "" CACHE STRING
    "Distribution release a binary package is built for, e.g. ubuntu25.04")

set(CPACK_PACKAGE_NAME "latte-dock")
set(CPACK_PACKAGE_VERSION "${VERSION}")
set(CPACK_PACKAGE_VENDOR "KDE")
set(CPACK_PACKAGE_CONTACT "Michail Vourlakos <mvourlakos@gmail.com>")
set(CPACK_PACKAGE_HOMEPAGE_URL "${WEBSITE}")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Dock and panel for the Plasma desktop")
set(CPACK_PACKAGE_DESCRIPTION
    "Latte is a dock based on plasma frameworks that provides an elegant and intuitive\n\
experience for your tasks and plasmoids. It animates its contents by using parabolic\n\
zoom effect and tries to be there only when it is needed.")
set(CPACK_PACKAGE_FILE_NAME "latte-dock-${VERSION}-${CMAKE_SYSTEM_PROCESSOR}")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSES/GPL-2.0-or-later.txt")
set(CPACK_STRIP_FILES ON)

#! the package installs into the prefix it was configured with, which the images set to the
#! one of their distribution
set(CPACK_PACKAGING_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

#! BEGIN deb
set(CPACK_DEBIAN_PACKAGE_SECTION "kde")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "${LATTE_PACKAGE_RUNTIME_DEPENDS}")

if(LATTE_PACKAGE_RELEASE)
    set(CPACK_DEBIAN_PACKAGE_RELEASE "${LATTE_PACKAGE_RELEASE}")
endif()
#! END deb

#! BEGIN rpm
set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
set(CPACK_RPM_PACKAGE_LICENSE "GPL-2.0-or-later")
set(CPACK_RPM_PACKAGE_GROUP "System/GUI/KDE")
set(CPACK_RPM_PACKAGE_URL "${WEBSITE}")

if(LATTE_PACKAGE_RELEASE)
    set(CPACK_RPM_PACKAGE_RELEASE "${LATTE_PACKAGE_RELEASE}")
endif()

if(LATTE_PACKAGE_RUNTIME_DEPENDS)
    #! rpm separates its requirements by commas as well, so the value is shared with the deb
    set(CPACK_RPM_PACKAGE_REQUIRES "${LATTE_PACKAGE_RUNTIME_DEPENDS}")
endif()

#! The rpm dependency generator of openSUSE reads the imports of the shipped qml as
#! requirements. Two kinds of them can not be satisfied by any package:
#!
#! The tasks applet builds on the qml of the plasma task manager, which that applet publishes
#! from its own process while it runs and which exists in no file of any distribution. The
#! three files importing it are kept out of the generator, which offers no way to drop a
#! single dependency, only the file it was read from. Everything those files need beyond it
#! is imported by other files as well or named in LATTE_PACKAGE_RUNTIME_DEPENDS.
#!
#! org.kde.latte.private.app is registered by the application itself while it starts, so
#! nothing on disk carries it either, but there the package it is missing from is this one,
#! and it says so.
#! written as a bracket argument so that cmake passes the backslashes through untouched, and
#! doubled because the macro expansion of rpm takes one level of them away again
set(CPACK_RPM_SPEC_MORE_DEFINE [=[%define __qml_exclude_path /org\\.kde\\.latte\\.plasmoid/contents/ui/(main|task/TaskIcon|task/TaskItem)\\.qml$]=])
set(CPACK_RPM_PACKAGE_PROVIDES "qt6qmlimport(org.kde.latte.private.app.0) = 1")

#! directories that belong to the distribution itself. Without this the package claims to
#! own them and conflicts with whichever package really does
set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/applications
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/dbus-1
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/dbus-1/services
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/icons
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/kglobalaccel
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/knotifications6
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/kservicetypes6
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/kwin
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/locale
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/metainfo
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/plasma
    ${CMAKE_INSTALL_FULL_DATAROOTDIR}/templates)
#! END rpm

include(CPack)
