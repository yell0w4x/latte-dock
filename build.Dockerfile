# Builds Latte Dock for x86_64.
#
# The platform is pinned so the result is an x86_64 build regardless of the machine running
# the build; on arm hosts docker will emulate it.
#
# The base is a rolling distribution on purpose. Latte builds against Plasma 6 and KF6, and
# fixed releases lag behind them, so a distribution that follows them is what keeps this
# buildable.
#
#   build:     podman build -t latte-dock .
#   artifacts: podman build --target artifact -o type=local,dest=./out .
#   shell:     podman run --rm -it latte-dock bash
#
# docker understands the same file and the same arguments.
#
# The install tree is staged under /opt/latte-dock and also packed into a tarball, so it can
# be dropped onto a host that already runs a matching Plasma.

ARG BASE_IMAGE=opensuse/tumbleweed

FROM --platform=linux/amd64 ${BASE_IMAGE} AS builder

ARG BUILD_TYPE=Release
ARG INSTALL_PREFIX=/opt/latte-dock
ARG JOBS=

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Toolchain, then the dependencies CMakeLists.txt declares, taken from the distribution
# itself rather than guessed. The plasma runtime packages at the end are not needed to
# compile, they carry the qml modules the shipped files import, which the qml test resolves
# while it compiles them.
RUN zypper --non-interactive refresh \
 && zypper --non-interactive install --no-recommends \
        gcc-c++ \
        cmake \
        ninja \
        make \
        git \
        which \
        tar \
        gzip \
        AppStream \
        dbus-1-daemon \
        kf6-extra-cmake-modules \
        gtest \
        gmock \
        qt6-base-devel \
        qt6-base-private-devel \
        qt6-declarative-devel \
        qt6-declarative-private-devel \
        qt6-tools-devel \
        qt6-wayland-devel \
        qt6-wayland-private-devel \
        kf6-karchive-devel \
        kf6-kcoreaddons-devel \
        kf6-kcrash-devel \
        kf6-kdbusaddons-devel \
        kf6-kdeclarative-devel \
        kf6-kglobalaccel-devel \
        kf6-kguiaddons-devel \
        kf6-ki18n-devel \
        kf6-kiconthemes-devel \
        kf6-kio-devel \
        kf6-kirigami-devel \
        kf6-knewstuff-devel \
        kf6-knotifications-devel \
        kf6-kpackage-devel \
        kf6-ksvg-devel \
        kf6-kwindowsystem-devel \
        kf6-kxmlgui-devel \
        kf6-kconfig-devel \
        libplasma6-devel \
        plasma6-activities-devel \
        plasma6-workspace-devel \
        kwayland6-devel \
        plasma-wayland-protocols \
        wayland-devel \
        plasma6-workspace \
        plasma6-activities-imports \
        kf6-kwindowsystem-imports \
        kpipewire6-imports \
        plasma6-pa \
        libX11-devel \
        libSM-devel \
        libICE-devel \
        libxcb-devel \
        xcb-util-devel \
 && zypper --non-interactive clean --all

WORKDIR /src

# The sources are copied in one step; .dockerignore keeps the build directory, the scratch
# files and the git history out of the context.
COPY . /src

# Configuring and building are separate layers so that a source change does not repeat the
# dependency resolution above.
RUN cmake -S /src -B /src/build \
        -G Ninja \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DCMAKE_SUPPRESS_REGENERATION=ON \
        -DBUILD_TESTING=ON

RUN cmake --build /src/build ${JOBS:+--parallel ${JOBS}}

# Installing before testing on purpose: the appstream test validates the metadata that was
# installed, and the qml test compiles the shipped files against the installed qml modules,
# so both of them need the install to have happened.
RUN cmake --install /src/build

# The tests drive real Qt objects and need a platform plugin; offscreen is the one that works
# without a display. HOME is set because they write into the configuration paths of the user
# running them, which is root here. The session bus is started for them as well: the window
# view is asked for over it, and the test publishes a stand in for kwin to receive that.
ENV QT_QPA_PLATFORM=offscreen \
    HOME=/tmp/latte-build-home
RUN mkdir -p "${HOME}" \
 && dbus-run-session -- ctest --test-dir /src/build --output-on-failure

# A tarball of the install tree, so the build can be carried to a host without rebuilding.
RUN LATTE_VERSION="$(sed -n 's/^set(VERSION *\([^)]*\))/\1/p' /src/CMakeLists.txt | head -1)" \
 && mkdir -p /out \
 && tar -czf "/out/latte-dock-${LATTE_VERSION:-unknown}-x86_64.tar.gz" -C "$(dirname ${INSTALL_PREFIX})" "$(basename ${INSTALL_PREFIX})" \
 && ls -lh /out

# Carries only the results, for "docker build --target artifact --output type=local,dest=./out"
FROM scratch AS artifact
COPY --from=builder /out/ /
