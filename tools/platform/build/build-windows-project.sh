#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"

usage() {
    cat <<'EOF'
Usage:
  tools/platform/build/build-windows-project.sh [options]

Options:
  --configuration <Release|Shipping>  Build configuration (default: Release)
  --gpu                               Enable Windows GPU build
  --no-gpu                            Disable Windows GPU build (default)
  -h, --help                          Show this help
EOF
}

detect_windows_host() {
    case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        return 0
        ;;
    *)
        return 1
        ;;
    esac
}

require_windows_host() {
    if ! detect_windows_host; then
        echo "this Windows build script is Windows-only" >&2
        exit 1
    fi
}

find_msbuild() {
    # 1) Explicit override wins (POSIX-style path, e.g. from CI or a
    #    nonstandard install): MFX_MSBUILD=/c/.../MSBuild.exe
    if [[ -n "${MFX_MSBUILD:-}" && -x "${MFX_MSBUILD}" ]]; then
        printf '%s\n' "${MFX_MSBUILD}"
        return 0
    fi

    # 2) vswhere-based discovery covers every installed edition/channel.
    local vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
    if [[ -x "$vswhere" ]]; then
        local pattern found converted
        for pattern in 'MSBuild\**\Bin\amd64\MSBuild.exe' 'MSBuild\**\Bin\MSBuild.exe'; do
            found="$("$vswhere" -latest -products '*' -requires Microsoft.Component.MSBuild \
                -find "$pattern" 2>/dev/null | head -n 1 | tr -d '\r')"
            if [[ -n "$found" ]]; then
                converted="$(cygpath -u "$found" 2>/dev/null || printf '%s\n' "$found")"
                if [[ -x "$converted" ]]; then
                    printf '%s\n' "$converted"
                    return 0
                fi
            fi
        done
    fi

    # 3) Static fallback across known VS18 editions (including Build Tools).
    local edition candidate
    for edition in Professional Enterprise Community BuildTools Insiders; do
        for candidate in \
            "/c/Program Files/Microsoft Visual Studio/18/${edition}/MSBuild/Current/Bin/amd64/MSBuild.exe" \
            "/c/Program Files/Microsoft Visual Studio/18/${edition}/MSBuild/Current/Bin/MSBuild.exe"; do
            if [[ -x "$candidate" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done

    echo "MSBuild.exe not found (tried MFX_MSBUILD, vswhere, and VS18 edition paths)" >&2
    exit 1
}

configuration="Release"
enable_windows_gpu_effects=false

while [[ $# -gt 0 ]]; do
    case "$1" in
    --configuration)
        [[ $# -ge 2 ]] || { echo "missing value for --configuration" >&2; exit 1; }
        configuration="$2"
        shift 2
        ;;
    --gpu)
        enable_windows_gpu_effects=true
        shift
        ;;
    --no-gpu)
        enable_windows_gpu_effects=false
        shift
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        echo "unknown argument: $1" >&2
        exit 1
        ;;
    esac
done

case "$configuration" in
Release|Shipping)
    ;;
*)
    echo "unsupported Windows configuration: $configuration" >&2
    exit 1
    ;;
esac

require_windows_host

project_path="$repo_root/MFCMouseEffect/MFCMouseEffect.vcxproj"
if [[ ! -f "$project_path" ]]; then
    echo "missing project file: $project_path" >&2
    exit 1
fi

msbuild_exe="$(find_msbuild)"
MSYS2_ARG_CONV_EXCL='*' "$msbuild_exe" \
    "$(cygpath -w "$project_path")" \
    /t:Build \
    "/p:Configuration=$configuration" \
    /p:Platform=x64 \
    "/p:MfxEnableWindowsGpuEffects=$enable_windows_gpu_effects" \
    /nologo \
    /v:minimal
