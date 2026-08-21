#!/usr/bin/env bash
#
# Builds distribution packages of Latte in containers and puts them into ./dist.
#
#   ./build.sh                     every deb, rpm, aur, the appimage and the binary tarball
#   ./build.sh --deb               both debs
#   ./build.sh --deb-ubuntu26      only the deb for ubuntu 26.04
#   ./build.sh --appimage          only the appimage
#   ./build.sh --bin               only the binary tarball
#
# Every package is built by the image of the same name under packaging/, which compiles
# Latte, runs the test suite and installs the package it produced, so what lands in ./dist
# has been built and installed at least once. The binary tarball comes from build.Dockerfile
# in the root, which is the plain install tree of the same build.

set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIST="${ROOT}/dist"

#! Each target names the file it is built from and, where the file serves more than one of
#! them, the arguments that say which one. Adding a distribution is a line in each table, not
#! a file of its own.
#!
#! The debs come one per release because a deb can not be anything else: dpkg-shlibdeps pins
#! them to the exact Qt of the machine that built them. ubuntu24 is ubuntu 24.04 with the KDE
#! neon archive over it, because stock 24.04 is on plasma 5.27 and does not build Latte 6.
#!
#! The AppImage is not one per distribution, it is one, built on the oldest base that has what
#! the bundle must hold: neon's plasma 6.7 for the task manager applet plugin Latte Tasks
#! needs, over the glibc 2.39 of ubuntu 24.04 so it starts on as much as possible.
#! packaging/README.md has the whole story.
declare -A DOCKERFILES=(
    [deb-ubuntu24]="packaging/Dockerfile.deb"
    [deb-ubuntu26]="packaging/Dockerfile.deb"
    [appimage]="packaging/Dockerfile.appimage"
    [rpm]="packaging/Dockerfile.rpm"
    [aur]="packaging/Dockerfile.arch"
    [bin]="build.Dockerfile"
)

declare -A BUILD_ARGS=(
    [deb-ubuntu24]="BASE_IMAGE=docker.io/library/ubuntu:24.04 NEON_SUITE=noble DEPS=neon PACKAGE_RELEASE=neon24.04"
    [deb-ubuntu26]="BASE_IMAGE=docker.io/library/ubuntu:26.04 NEON_SUITE= DEPS=ubuntu PACKAGE_RELEASE=ubuntu26.04"
    [appimage]="BASE_IMAGE=docker.io/library/ubuntu:24.04 NEON_SUITE=noble DEPS=neon VARIANT=neon24.04 GLIBC_FLOOR=2.39"
)

readonly ALL_TARGETS=(deb-ubuntu24 deb-ubuntu26 rpm aur appimage bin)

ENGINE=""
JOBS=""
CLEAN="no"
WITH_DEBUG="no"
targets=()

usage()
{
    cat <<'EOF'
Usage: ./build.sh [options]

Builds distribution packages in containers and copies them into ./dist.

Targets, all of them when none is given:
  --deb-ubuntu24     debian package for ubuntu 24.04 with the KDE neon archive
  --deb-ubuntu26     debian package for ubuntu 26.04
  --deb              both debs above
  --rpm              rpm package, built on opensuse tumbleweed
  --aur              arch package, built from packaging/PKGBUILD
  --appimage         appimage, built on ubuntu 24.04 with the KDE neon archive
  --bin              binary tarball of the install tree, from build.Dockerfile
  --all              the six above, the default

Options:
  --clean            empty ./dist before building
  --with-debug       keep the debug package as well, the arch build makes one
  --jobs N           compiler jobs, defaults to what the container decides
  --engine CMD       container engine to use, podman or docker are found on their own
  -h, --help         this text
EOF
}

fail()
{
    echo "build.sh: $*" >&2
    exit 1
}

detect_engine()
{
    if [[ -n "${ENGINE}" ]]; then
        command -v "${ENGINE}" > /dev/null 2>&1 || fail "the engine '${ENGINE}' was not found"
        return
    fi

    for candidate in podman docker; do
        if command -v "${candidate}" > /dev/null 2>&1; then
            ENGINE="${candidate}"
            return
        fi
    done

    fail "neither podman nor docker was found, one of them builds the packages"
}

parse_arguments()
{
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --deb-ubuntu24|--deb-ubuntu26|--rpm|--aur|--appimage|--bin)
                targets+=("${1#--}")
                ;;
            --deb)
                #! every release of it, whoever wants one of them asks for it by name
                targets+=(deb-ubuntu24 deb-ubuntu26)
                ;;
            --arch)
                #! the arch package and the aur recipe are the same thing
                targets+=(aur)
                ;;
            --all)
                targets+=("${ALL_TARGETS[@]}")
                ;;
            --clean)
                CLEAN="yes"
                ;;
            --with-debug)
                WITH_DEBUG="yes"
                ;;
            --jobs)
                [[ $# -ge 2 ]] || fail "--jobs wants a number"
                JOBS="$2"
                shift
                ;;
            --jobs=*)
                JOBS="${1#--jobs=}"
                ;;
            --engine)
                [[ $# -ge 2 ]] || fail "--engine wants a command"
                ENGINE="$2"
                shift
                ;;
            --engine=*)
                ENGINE="${1#--engine=}"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                fail "unknown argument '$1'"
                ;;
        esac
        shift
    done

    if [[ ${#targets[@]} -eq 0 ]]; then
        targets=("${ALL_TARGETS[@]}")
    fi

    #! asking for the same target twice would only build it twice
    mapfile -t targets < <(printf '%s\n' "${targets[@]}" | awk '!seen[$0]++')
}

#! Builds one target and copies what it produced into ./dist.
#!
#! The images carry their result in an "artifact" stage holding nothing else, which is
#! exported into a directory of its own first; that stage also carries the recipe of the
#! arch build, and only the packages and the tarball are wanted here.
build_target()
{
    local target="$1"
    local dockerfile="${DOCKERFILES[${target}]}"
    local exported
    exported="$(mktemp -d)"

    local -a arguments=(build
        -f "${ROOT}/${dockerfile}"
        --target artifact
        -o "type=local,dest=${exported}")

    if [[ -n "${JOBS}" ]]; then
        arguments+=(--build-arg "JOBS=${JOBS}")
    fi

    #! what makes one release of a shared file different from the next
    local argument
    for argument in ${BUILD_ARGS[${target}]:-}; do
        arguments+=(--build-arg "${argument}")
    done

    arguments+=("${ROOT}")

    echo
    echo "==> ${target}: ${ENGINE} ${arguments[*]}"

    if ! "${ENGINE}" "${arguments[@]}"; then
        rm -rf "${exported}"
        echo "==> ${target}: the image did not build" >&2
        return 1
    fi

    local -a packages=()
    local file

    while IFS= read -r file; do
        if [[ "${WITH_DEBUG}" == "no" && "$(basename "${file}")" == *-debug-* ]]; then
            continue
        fi

        packages+=("${file}")
    done < <(find "${exported}" -type f \( -name '*.deb' -o -name '*.rpm' -o -name '*.pkg.tar.zst' \
                                        -o -name '*.AppImage' -o -name '*.tar.gz' \) | sort)

    if [[ ${#packages[@]} -eq 0 ]]; then
        rm -rf "${exported}"
        echo "==> ${target}: the image produced nothing to collect" >&2
        return 1
    fi

    for file in "${packages[@]}"; do
        cp -f "${file}" "${DIST}/"
        echo "==> ${target}: dist/$(basename "${file}")"
    done

    rm -rf "${exported}"
}

main()
{
    parse_arguments "$@"
    detect_engine

    if [[ "${CLEAN}" == "yes" ]]; then
        rm -rf "${DIST}"
    fi

    mkdir -p "${DIST}"

    local -a built=()
    local -a failed=()
    local target

    for target in "${targets[@]}"; do
        if build_target "${target}"; then
            built+=("${target}")
        else
            failed+=("${target}")
        fi
    done

    echo
    echo "built: ${built[*]:-none}"
    echo "in dist/:"
    find "${DIST}" -maxdepth 1 -type f -printf '  %f\n' | sort

    if [[ ${#failed[@]} -gt 0 ]]; then
        echo
        echo "failed: ${failed[*]}" >&2
        exit 1
    fi
}

main "$@"
