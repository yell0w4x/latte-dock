# Packaging

Images that turn this repository into a distribution package. Each one builds Latte from the
working tree, runs the test suite, builds the package and then installs it inside the image,
so a package that does not install fails the build here rather than on the machine of whoever
downloads it.

The usual way in is [`../build.sh`](../build.sh), which builds the packages and collects them
into `dist/`:

```
./build.sh                 # deb, rpm, aur, every appimage and the binary tarball
./build.sh --deb --rpm     # only those two
./build.sh --deb-2504      # the deb for ubuntu 25.04, which kubuntu 25.04 is
./build.sh --appimage      # every appimage variant
./build.sh --appimage-arch # only the one built on arch
./build.sh --bin           # only the binary tarball
./build.sh --clean         # empty dist/ first
```

It finds podman or docker on its own, reports which targets failed and exits non zero if any
of them did. What it runs underneath is the images below, one build each.

All of them take the repository root as their context, so they are run from there:

| Package                  | Build                                                                            |
| ------------------------ | -------------------------------------------------------------------------------- |
| `.deb` (ubuntu 25.10)    | `podman build -f packaging/Dockerfile.deb -t latte-dock:deb .`                     |
| `.deb` (ubuntu 25.04)    | `podman build -f packaging/Dockerfile.deb-2504 -t latte-dock:deb-2504 .`           |
| `.rpm`                   | `podman build -f packaging/Dockerfile.rpm -t latte-dock:rpm .`                     |
| `.pkg.tar.zst` (arch/aur)| `podman build -f packaging/Dockerfile.arch -t latte-dock:arch .`                   |
| `.AppImage` (arch)       | `podman build -f packaging/Dockerfile.appimage-arch -t latte-dock:appimage-arch .`   |
| `.AppImage` (ubuntu 25.10)| `podman build -f packaging/Dockerfile.appimage-ubuntu -t latte-dock:appimage-ubuntu .` |
| `.AppImage` (ubuntu 25.04)| `podman build -f packaging/Dockerfile.appimage-ubuntu-2504 -t latte-dock:appimage-2504 .` |
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
| `Dockerfile.deb`  | `ubuntu:25.10`        | the release the package is for; debian is untried                                                                     |
| `Dockerfile.deb-2504` | `ubuntu:25.04`    | the same package for the release kubuntu 25.04 is; a deb is bound to the release it was built on, see below            |
| `Dockerfile.rpm`  | `opensuse/tumbleweed` | rolling, so it follows Plasma 6 and KF6 closely                                                                        |
| `Dockerfile.arch` | `archlinux:base-devel`| the distribution the aur recipe targets                                                                                |
| `Dockerfile.appimage-arch` | `archlinux:base-devel` | the AppImage carries plasma itself, and Latte Tasks needs the compiled task manager applet plugin that only Plasma 6.5 and later have |
| `Dockerfile.appimage-ubuntu` | `ubuntu:25.10`   | an older glibc, so the AppImage loads on hosts the arch one does not                                                   |
| `Dockerfile.appimage-ubuntu-2504` | `ubuntu:25.04` | the oldest base Latte 6 still builds on, so the AppImage from it loads on the most hosts                          |

They are pinned to `linux/amd64`, so the result is an x86_64 package whatever the machine
running the build is.

## The deb is bound to the release it was built on

A deb is not portable between ubuntu releases, and there is no packaging change that makes it
one. `dpkg-shlibdeps` reads the libraries Latte links out of the packages of the build machine
and writes their versions into the dependencies, and Latte includes `qtx11extras_p.h`, so among
the dependencies it writes is `qt6-base-private-abi`, pinned to the exact Qt of that release:

```
Depends: ... qt6-base-private-abi (= 6.9.2), libqt6core6t64 (>= 6.9.1), ...
```

Ubuntu 25.04 carries Qt 6.8.3 and no `qt6-base-private-abi` package at all, so apt refuses the
deb built on 25.10 there, and the same happens the other way round. A release that is to have a
deb needs an image that builds on it: `Dockerfile.deb` is 25.10, `Dockerfile.deb-2504` is 25.04,
and a further release is a further file with a further base.

Each image passes its release to `LATTE_PACKAGE_RELEASE`, which reaches the version of the
package and through it the file name, so the two are told apart both in `dist/` and by dpkg:

```
latte-dock_1.10.240-ubuntu25.10_amd64.deb
latte-dock_1.10.240-ubuntu25.04_amd64.deb
```

## The AppImage

An AppImage, unlike the deb, is not bound to the release it was built on. It is bound to that
release's glibc, the one library it can not carry: every bundled library resolves against the
glibc of the host, and the host has to be at least as new. So these variants are not one per
distribution, they are one per trade between how new the host has to be and what the bundle can
carry, and none of them is a better version of the other:

| Variant       | Built by                          | Latte Tasks | Runs on                                                      |
| ------------- | --------------------------------- | ----------- | ------------------------------------------------------------ |
| arch          | `Dockerfile.appimage-arch`        | yes         | hosts whose glibc is at least the one arch had at build time  |
| ubuntu 25.10  | `Dockerfile.appimage-ubuntu`      | no          | glibc 2.42 and newer: ubuntu 25.10 onwards                    |
| ubuntu 25.04  | `Dockerfile.appimage-ubuntu-2504` | no          | glibc 2.39 and newer: kubuntu 25.04, 25.10, 26.04, debian 13  |

The tasks plasmoid is built on the task manager applet, which plasma publishes as a compiled
applet plugin only since Plasma 6.5. Arch is rolling and has it; ubuntu 25.10 is on Plasma 6.4
and 25.04 on 6.3, and neither has it anywhere, so both ubuntu variants bring up a dock without
its tasks. What they have is the older glibc: an AppImage built on arch does not load at all on
a host that far behind, not even to print its version.

There is no base with Plasma 6.5 and a glibc old enough for ubuntu 24.04, so an AppImage that
does both does not exist. 24.04 is out of reach anyway: it is on plasma 5.27 with no KF6 plasma
libraries, so Latte 6 does not build on it, which makes 25.04 the oldest base there is and the
25.04 variant the one that reaches furthest back.

One library is enough to take that reach away again. The 25.10 bundle pulls in a `libssh` that
wants `GLIBC_2.42`, through `libavformat` and `libKPipeWireRecord`, which is why the
`org.kde.pipewire` module of that variant, the one behind window previews on wayland, can not
load on 25.04 even though everything else in it would. The 25.04 image therefore ends with a
check over every bundled library, asking which glibc symbols it wants and refusing an answer
newer than the base's own. What that check reports for the current build is `GLIBC_2.39`, below
the 2.41 of the base, so what actually limits this variant is not its glibc but the Plasma 6
session it needs around it.

All variants install Latte into an AppDir, add the plugins, qml modules and plasma package
files nothing links against and therefore no tool can find, and let `linuxdeploy` with its qt
plugin pull in the libraries.

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
and once with a home of its own, where it imports the default layout and is read back. The
arch variant is asked whether the tasks plasmoid of that layout came up, the ubuntu ones
whether every package that layout names was found. An AppImage that starts but can not bring
up a dock fails the build there.

Each carries Latte with Qt, the KDE frameworks and the plasma libraries and applets, 170M to
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
