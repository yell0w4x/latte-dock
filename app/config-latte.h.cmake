#ifndef CONFIG_LATTE_H
#define CONFIG_LATTE_H

#cmakedefine01 HAVE_X11

#cmakedefine KF6_VERSION_MINOR @KF6_VERSION_MINOR@

#cmakedefine VERSION "@VERSION@"

#cmakedefine WEBSITE "@WEBSITE@"

#cmakedefine BUG_ADDRESS "@BUG_ADDRESS@"

//! Install locations of the Latte qml modules and binary plugins. Qt only searches
//! its own prefix by default, so for any installation outside of it (e.g. ~/.local)
//! they must be registered explicitly during startup.
#define LATTE_QMLDIR "@KDE_INSTALL_FULL_QMLDIR@"

#define LATTE_PLUGINDIR "@KDE_INSTALL_FULL_PLUGINDIR@"

#endif // CONFIG_LATTE_H
