# Packaging

Images that turn this repository into a distribution package. Each one builds Latte from the
working tree, runs the test suite, builds the package and then installs it inside the image,
so a package that does not install fails the build here rather than on the machine of whoever
downloads it.

All of them take the repository root as their context, so they are run from there:

| Package                  | Build                                                                            |
| ------------------------ | -------------------------------------------------------------------------------- |
| `.deb`                   | `podman build -f packaging/Dockerfile.deb -t latte-dock:deb .`                     |
| `.rpm`                   | `podman build -f packaging/Dockerfile.rpm -t latte-dock:rpm .`                     |
| `.pkg.tar.zst` (arch/aur)| `podman build -f packaging/Dockerfile.arch -t latte-dock:arch .`                   |
| plain install tree       | `podman build -f build.Dockerfile -t latte-dock .` (the root image, produces a tarball)  |

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

They are pinned to `linux/amd64`, so the result is an x86_64 package whatever the machine
running the build is.

## Publishing the arch package on the aur

`PKGBUILD` builds the working tree, which `Dockerfile.arch` hands to it as a tarball. To
publish it, replace the block marked `BEGIN replace for the aur` with the release it should
build:

```
source=("$pkgname-$pkgver.tar.gz::https://download.kde.org/stable/latte-dock/latte-dock-$pkgver.tar.xz")
sha256sums=('<the checksum of that tarball>')
```

and drop the `_srcdir` line, since that tarball already unpacks into `latte-dock-$pkgver`.
