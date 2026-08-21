#!/usr/bin/env bash
#
# Builds distribution packages of Latte in containers and puts them into ./dist.
#
#   ./build.sh                     deb, rpm, aur, every appimage and the binary tarball
#   ./build.sh --deb               only the deb for ubuntu 25.10
#   ./build.sh --deb-2504          only the deb for ubuntu 25.04
#   ./build.sh --rpm --appimage    the rpm and every appimage
#   ./build.sh --appimage-arch     only the appimage built on arch
#   ./build.sh --bin               only the binary tarball
#
# Every package is built by the image of the same name under packaging/, which compiles
# Latte, runs the test suite and installs the package it produced, so what lands in ./dist
# has been built and installed at least once. The binary tarball comes from build.Dockerfile
# in the root, which is the plain install tree of the same build.

set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIST="${ROOT}/dist"

#! the file each target is built from, the aur one produces the arch package its recipe
#! describes
#!
#! The deb comes once per ubuntu release, because it has to: dpkg-shlibdeps pins it to the Qt
#! of the release it was built on, so the one built on 25.10 does not install on 25.04 and the
#! other way round.
#!
#! The appimage comes in variants that differ in the plasma and the glibc they carry: the one
#! built on arch can bring up Latte Tasks and needs a host as new as arch, the ubuntu ones run
#! on older hosts and can not, and of those the 25.04 one reaches furthest back.
#! packaging/README.md has the whole story.
declare -A DOCKERFILES=(
    [deb]="packaging/Dockerfile.deb"
    [deb-2504]="packaging/Dockerfile.deb-2504"
    [rpm]="packaging/Dockerfile.rpm"
    [aur]="packaging/Dockerfile.arch"
    [appimage-arch]="packaging/Dockerfile.appimage-arch"
    [appimage-ubuntu]="packaging/Dockerfile.appimage-ubuntu"
    [appimage-ubuntu-2504]="packaging/Dockerfile.appimage-ubuntu-2504"
    [bin]="build.Dockerfile"
)

readonly ALL_TARGETS=(deb deb-2504 rpm aur appimage-arch appimage-ubuntu appimage-ubuntu-2504 bin)

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
  --deb                    debian package, built on and for ubuntu 25.10
  --deb-2504               debian package, built on and for ubuntu 25.04, kubuntu 25.04
  --rpm                    rpm package, built on opensuse tumbleweed
  --aur                    arch package, built from packaging/PKGBUILD
  --appimage-arch          appimage built on arch, carries Latte Tasks, needs a host as new
  --appimage-ubuntu        appimage built on ubuntu 25.10, no Latte Tasks
  --appimage-ubuntu-2504   appimage built on ubuntu 25.04, runs on the most hosts, no
                           Latte Tasks
  --appimage               every appimage
  --bin                    binary tarball of the install tree, from build.Dockerfile
  --all                    the eight above, the default

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
            --deb|--deb-2504|--rpm|--aur|--appimage-arch|--appimage-ubuntu|--appimage-ubuntu-2504|--bin)
                targets+=("${1#--}")
                ;;
            --appimage)
                #! every variant of it, whoever wants one of them asks for it by name
                targets+=(appimage-arch appimage-ubuntu appimage-ubuntu-2504)
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
