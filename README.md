About
=====
Latte is a dock based on plasma frameworks that provides an elegant and intuitive experience for your tasks and plasmoids. It animates its contents by using parabolic zoom effect and tries to be there only when it is needed.

**"Art in Coffee"**

This tree is the Plasma 6 port of Latte: it builds against KF6 and Qt 6 and runs on a Plasma 6
session, on X11 as well as on wayland.

Screenshots
===========

![](https://cdn.kde.org/screenshots/latte-dock/latte-dock_regular.png)

![](https://cdn.kde.org/screenshots/latte-dock/latte-dock_settings.png)

Development
============

- Official KDE repo in which you can also send your MRs is located at: https://invent.kde.org/plasma/latte-dock
- Bug reports can be sent at: https://bugs.kde.org/enter_bug.cgi?product=lattedock


Installation
============

## Requirements

We need to use at least:

- **Plasma >= 6.0**
- **PlasmaWaylandProtocols >= 1.6.0**
- **Qt >= 6.5**

Minimum requirements:

**tools:**
```
 bash
```

**development packages for:**
```
 QtCore >= 6.5.0
 QtGui >= 6.5.0
 QtDbus >= 6.5.0

 KF6Plasma >= 6.0
 KF6PlasmaQuick >= 6.0
 KF6Activities >= 6.0
 KF6CoreAddons >= 6.0
 KF6GuiAddons >= 6.0
 KF6DBusAddons >= 6.0
 KF6Declarative >= 6.0
 KF6Kirigami2 >= 6.0
 KF6Wayland >= 6.0
 KF6Package >= 6.0
 KF6XmlGui >= 6.0
 KF6IconThemes >= 6.0
 KF6KIO >= 6.0
 KF6I18n >= 6.0
 KF6Notifications >= 6.0
 KF6NewStuff >= 6.0
 KF6Archive >= 6.0
 KF6GlobalAccel >= 6.0
 KF6Crash >= 6.0

  For X11 support:
    KF6WindowSystem >= 6.0
    libxcb
    libxcb-randr
    libxcb-shape
    libSM
```

## Packages built from this repository

[`./build.sh`](./build.sh) builds Latte in containers and collects the results into `dist/`.
It needs podman or docker and nothing else, the build dependencies live in the images.

```
./build.sh                   # deb, rpm, aur, appimage and the binary tarball
./build.sh --deb             # only one of them
./build.sh --rpm --appimage  # or a few
./build.sh --clean           # empty dist/ first
```

| Target       | Result                                    | Built on            |
| ------------ | ----------------------------------------- | ------------------- |
| `--deb`      | `latte-dock_<version>_amd64.deb`          | ubuntu              |
| `--rpm`      | `latte-dock-<version>-1.x86_64.rpm`       | opensuse tumbleweed |
| `--aur`      | `latte-dock-<version>-1-x86_64.pkg.tar.zst` | arch, from [packaging/PKGBUILD](packaging/PKGBUILD) |
| `--appimage` | `Latte_Dock-<version>-x86_64.AppImage`    | ubuntu              |
| `--bin`      | `latte-dock-<version>-x86_64.tar.gz`, the plain install tree | opensuse tumbleweed |

Each image compiles Latte, runs the test suite, builds its package and installs it inside the
image, so a package that does not build or does not install fails there rather than on the
machine of whoever downloads it. [packaging/README.md](packaging/README.md) describes the
images and how to publish the arch recipe on the aur.

The AppImage carries Qt, the KDE frameworks and the plasma libraries, but not the session
Latte docks into: it talks to kwin, plasmashell and the activity manager of the machine it
runs on, so a Plasma 6 session still has to be there.

## Building from source

```
cmake -S . -B build -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build
cmake --install build
```

Installing into `$HOME/.local` needs no root. For a system wide installation use
`-DCMAKE_INSTALL_PREFIX=/usr` and install with `sudo`.

## Tests

The suite drives the real Latte objects together with the real KDE and Qt classes they
collaborate with, and is built along with everything else:

```
ctest --test-dir build
```

The tests that talk over dbus, e.g. the one covering the window selection Latte asks kwin for,
need a session bus. In a session there already is one; without it, run them under
`dbus-run-session -- ctest --test-dir build`. Every container build above runs the same suite.

## Run Latte-Dock

Latte is now ready to be used by executing
```
latte-dock
```

or activating **Latte Dock** from the applications menu.


Contributors
============
[Varlesh](https://github.com/varlesh): Logos and Icons.
