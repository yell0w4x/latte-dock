# Packaging

Images that turn this repository into a distribution package. Each one builds Latte from the
working tree, runs the test suite, builds the package and then installs it inside the image,
so a package that does not install fails the build here rather than on the machine of whoever
downloads it.

There is one image per packaging family, not one per distribution. Which release a family
builds for is decided by build arguments, and [`../build.sh`](../build.sh) keeps the table of
them, so adding a distribution is a line in that table rather than a file of its own.

The usual way in is that script, which builds the packages and collects them into `dist/`:

```
./build.sh                    # every deb, rpm, aur, the appimage and the binary tarball
./build.sh --deb              # both debs
./build.sh --deb-ubuntu26     # only the deb for ubuntu 26.04
./build.sh --appimage         # only the appimage
./build.sh --clean            # empty dist/ first
```

It finds podman or docker on its own, reports which targets failed and exits non zero if any
of them did.

All of the images take the repository root as their context, so they are run from there:

| Package                  | Build                                                                     |
| ------------------------ | ------------------------------------------------------------------------- |
| `.deb`                   | `podman build -f packaging/Dockerfile.deb -t latte-dock:deb .`             |
| `.rpm`                   | `podman build -f packaging/Dockerfile.rpm -t latte-dock:rpm .`             |
| `.pkg.tar.zst` (arch/aur)| `podman build -f packaging/Dockerfile.arch -t latte-dock:arch .`          |
| `.AppImage`              | `podman build -f packaging/Dockerfile.appimage -t latte-dock:appimage .`  |
| `.tar.gz` of the install tree | `podman build -f build.Dockerfile -t latte-dock .` (the root image, `--bin` in the script) |

`docker` understands the same files and the same arguments. Building one of the shared files
by hand builds its default target; `--build-arg` picks another, as `build.sh` does:

```
podman build -f packaging/Dockerfile.deb \
    --build-arg BASE_IMAGE=docker.io/library/ubuntu:24.04 \
    --build-arg NEON_SUITE=noble \
    --build-arg PACKAGE_RELEASE=neon24.04 \
    --target artifact -o type=local,dest=./out .
```

## The targets

| Target           | Base                                | glibc | Plasma | Latte Tasks |
| ---------------- | ----------------------------------- | ----- | ------ | ----------- |
| `--deb-ubuntu24` | `ubuntu:24.04` + KDE neon `user/noble` | 2.39 | 6.7  | yes         |
| `--deb-ubuntu26` | `ubuntu:26.04`                      | 2.43  | 6.6    | yes         |
| `--appimage`     | `ubuntu:24.04` + KDE neon `user/noble` | 2.39 | 6.7  | yes         |
| `--rpm`          | `opensuse/tumbleweed`               | rolling | rolling | yes      |
| `--aur`          | `archlinux:base-devel`              | rolling | rolling | yes      |

They are pinned to `linux/amd64`, so the result is an x86_64 package whatever the machine
running the build is.

### Why ubuntu 24.04 is KDE neon and not ubuntu

Stock ubuntu 24.04 is on plasma 5.27 with no KF6 plasma libraries, so Latte 6 does not build
on it at all. KDE neon is that same 24.04 with KDE's own archive over it, carrying plasma 6.7,
KF6 and Qt 6.11, and Latte builds there without a complaint.

The images add `archive.neon.kde.org` to an `ubuntu` base rather than starting from the neon
image, which is the same thing and two gigabytes.

## The deb is bound to the release it was built on

A deb is not portable between releases, and there is no packaging change that makes it one.
`dpkg-shlibdeps` reads the libraries Latte links out of the packages of the build machine and
writes their versions into the dependencies, and Latte includes `qtx11extras_p.h`, so among
the dependencies it writes is `qt6-base-private-abi`, pinned to the exact Qt of that release:

```
Depends: ... qt6-base-private-abi (= 6.10.2), libqt6core6t64 (>= 6.10.0), ...
```

A release that is to have a deb needs a line in the table in `build.sh` naming its base image
and its release label. The label reaches the version of the package and through it the file
name, so the packages are told apart both in `dist/` and by dpkg:

```
latte-dock_1.10.240-neon24.04_amd64.deb
latte-dock_1.10.240-ubuntu26.04_amd64.deb
```

## The AppImage

There is one, and one is the point of it. An AppImage is not bound to the release it was built
on, it is bound to that release's glibc, the one library it can not carry: every bundled
library resolves against the glibc of the host, and the host has to be at least as new. So the
base to build it on is the oldest one that still holds everything the bundle needs.

That base is ubuntu 24.04 with the KDE neon archive: glibc 2.39, older than any other base
Latte 6 builds on, and plasma 6.7, which carries the compiled task manager applet plugin that
Latte Tasks is built on and that plasma publishes only since 6.5. Everything else is one or
the other — 25.04 and 25.10 have the older glibc but a plasma too old for the tasks, arch and
26.04 have the tasks but a glibc that shuts out every older host.

It installs Latte into an AppDir, adds the plugins, qml modules and plasma package files
nothing links against and therefore no tool can find, and lets `linuxdeploy` with its qt
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
and once with a home of its own, where it imports the default layout and is read back, for
whether the corona found its shell package and every package that layout names, and whether
the tasks plasmoid found the applet plugin it is built on. An AppImage that starts but can not
bring up a dock fails the build there.

Then every bundled library is asked which glibc symbols it wants, and the newest answer has to
be one the base itself has. Without that check the bundle can be quietly narrower than its
base promises: an earlier one built on 25.10 pulled in a `libssh` wanting `GLIBC_2.42` through
`libavformat` and `libKPipeWireRecord`, and that single library kept its pipewire module from
loading on anything older.

It carries Latte with Qt, the KDE frameworks and the plasma libraries and applets, some 180M
of them. What it can not carry is the session Latte docks into: it talks to kwin, plasmashell
and the activity manager of the machine it runs on, so a Plasma 6 session still has to be
there. It is for running this build on a distribution whose own packages are older, not for
running Latte without Plasma.

## What ends up in the package

The deb and the rpm are written by CPack over the tree `cmake --install` produces, configured
in [`../cmake/LattePackaging.cmake`](../cmake/LattePackaging.cmake). The libraries Latte links
are found by the generators themselves; the qml modules the shipped qml files import at
runtime are not, since nothing links against them, so each image passes the names its
distribution uses for them through `LATTE_PACKAGE_RUNTIME_DEPENDS`.

The arch package is built by [`PKGBUILD`](PKGBUILD) through `makepkg`, which declares its own
dependencies and runs the test suite in its `check()`.

## Reaching further than this

These images are for building and verifying a handful of targets locally. Covering every
distribution that matters is a different job, and containers are the wrong tool for it: each
release needs its own rebuild, which is exactly the per-release pin above, and that is what
the [openSUSE Build Service](https://build.opensuse.org) exists to do. It builds debs and rpms
for debian, ubuntu, fedora and openSUSE releases from one source package and rebuilds them as
those releases move. Keep these images for local verification and the AppImage, and let OBS do
the fan out.

Flatpak is not a way out here. A dock needs kwin, plasmashell and the session bus, which is
what the sandbox is designed to withhold.

## Publishing the arch package on the aur

`PKGBUILD` builds the working tree, which `Dockerfile.arch` hands to it as a tarball. To
publish it, replace the block marked `BEGIN replace for the aur` with the release it should
build:

```
source=("$pkgname-$pkgver.tar.gz::https://download.kde.org/stable/latte-dock/latte-dock-$pkgver.tar.xz")
sha256sums=('<the checksum of that tarball>')
```

and drop the `_srcdir` line, since that tarball already unpacks into `latte-dock-$pkgver`.
