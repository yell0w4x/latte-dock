# Packaging

Images that turn this repository into a distribution package. Each one builds Latte from the
working tree, runs the test suite, builds the package and then installs it inside the image,
so a package that does not install fails the build here rather than on the machine of whoever
downloads it.

The usual way in is [`../build.sh`](../build.sh), which builds the packages and collects them
into `dist/`:

```
./build.sh              # deb, rpm, aur, appimage and the binary tarball
./build.sh --deb --rpm  # only those two
./build.sh --bin        # only the binary tarball
./build.sh --clean      # empty dist/ first
```

It finds podman or docker on its own, reports which targets failed and exits non zero if any
of them did. What it runs underneath is the images below, one build each.

All of them take the repository root as their context, so they are run from there:

| Package                  | Build                                                                            |
| ------------------------ | -------------------------------------------------------------------------------- |
| `.deb`                   | `podman build -f packaging/Dockerfile.deb -t latte-dock:deb .`                     |
| `.rpm`                   | `podman build -f packaging/Dockerfile.rpm -t latte-dock:rpm .`                     |
| `.pkg.tar.zst` (arch/aur)| `podman build -f packaging/Dockerfile.arch -t latte-dock:arch .`                   |
| `.AppImage`              | `podman build -f packaging/Dockerfile.appimage -t latte-dock:appimage .`           |
| `.tar.gz` of the install tree | `podman build -f build.Dockerfile -t latte-dock .` (the root image, `--bin` in the script) |

`docker` understands the same files and the same arguments.

To get the package out of the image instead of into it, build the `artifact` stage, which
carries nothing else:

```
podman build -f packaging/Dockerfile.deb --target artifact -o type=local,dest=./out .
```

## What ends up in the package

The deb and the rpm are written by CPack over the tree `cmake --install` produces, configured
in [`../cmake/LattePackaging.cmake`](../cmake/LattePackaging.cmake). The libraries Latte links
are found by the generators themselves; the qml modules the shipped qml files import at
runtime are not, since nothing links against them, so each image passes the names its
distribution uses for them through `LATTE_PACKAGE_RUNTIME_DEPENDS`.

The arch package is built by [`PKGBUILD`](PKGBUILD) through `makepkg`, which declares its own
dependencies and runs the test suite in its `check()`.

## Bases

| Image             | Base                  | Why                                                                                                                  |
| ----------------- | --------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `Dockerfile.deb`  | `ubuntu:25.10`        | Debian ships no cmake package for the private Qt gui module, which the x11 code needs for `qtx11extras_p.h`            |
| `Dockerfile.rpm`  | `opensuse/tumbleweed` | rolling, so it follows Plasma 6 and KF6 closely                                                                        |
| `Dockerfile.arch` | `archlinux:base-devel`| the distribution the aur recipe targets                                                                                |
| `Dockerfile.appimage` | `archlinux:base-devel` | the AppImage carries plasma itself, and Latte Tasks needs the compiled task manager applet plugin that only Plasma 6.5 and later have |

They are pinned to `linux/amd64`, so the result is an x86_64 package whatever the machine
running the build is.

## The AppImage

`Dockerfile.appimage` installs Latte into an AppDir, adds the plugins, qml modules and plasma
package files nothing links against and therefore no tool can find, and lets `linuxdeploy`
with its qt plugin pull in the libraries.

Three things have to be pointed at explicitly, and an AppImage missing any of them still
starts, only to show a dock with nothing in it:

- the plugins go to `usr/plugins`, where `usr/bin/qt.conf` points Qt, and not into the qt
  directory they are installed in, which nothing inside an AppImage searches. `plasma`
  carries the applets, among them the task manager applet Latte Tasks is built on, and
  `kpackage` the structures that make a plasma package readable at all
- `--deploy-deps-only` hands those directories back to `linuxdeploy`, which pulls in the
  libraries they need and rewrites their rpath, something it does on its own only for what it
  copied itself
- [`AppRun`](AppRun), passed as `--custom-apprun`, points `XDG_DATA_DIRS` at the plasma
  package files of the bundle. The default AppRun is a symlink to the binary and sets nothing,
  and no rpath or `qt.conf` can name a directory that exists only once the AppImage is mounted

The result is unpacked again at the end of the build and started twice: once for its version,
and once with a home of its own, where it imports the default layout and is read back for
whether the tasks plasmoid of that layout came up. An AppImage that starts but can not bring
up a dock fails the build there.

It carries Latte with Qt, the KDE frameworks and the plasma libraries and applets, around
300M of them. What it can not carry is the session Latte docks into: it talks to kwin,
plasmashell and the activity manager of the machine it runs on, so a Plasma 6 session still
has to be there. It is for running this build on a distribution whose own packages are older,
not for running Latte without Plasma.

## Publishing the arch package on the aur

`PKGBUILD` builds the working tree, which `Dockerfile.arch` hands to it as a tarball. To
publish it, replace the block marked `BEGIN replace for the aur` with the release it should
build:

```
source=("$pkgname-$pkgver.tar.gz::https://download.kde.org/stable/latte-dock/latte-dock-$pkgver.tar.xz")
sha256sums=('<the checksum of that tarball>')
```

and drop the `_srcdir` line, since that tarball already unpacks into `latte-dock-$pkgver`.
