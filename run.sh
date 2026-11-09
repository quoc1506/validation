#!/usr/bin/env bash
# Auto re-exec with bash if invoked via /bin/sh (dash) on Ubuntu/Debian/Google Colab
if [ -z "${BASH_VERSION:-}" ]; then
    exec /usr/bin/env bash "$0" "$@"
fi
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
ARCH="$(uname -m)"
BIN=""
GPU_FLAG=""
HAS_GPU_ARG=0
FORCE_CPU=0
ARGS=()

for arg in "$@"; do
    if [ "$arg" = "-gpu" ]; then
        HAS_GPU_ARG=1
        ARGS+=("$arg")
    elif [ "$arg" = "--cpu-only" ]; then
        FORCE_CPU=1
    else
        ARGS+=("$arg")
    fi
done

if [ "$OS" = "Darwin" ]; then
    BIN="$DIR/bin/sysd_darwin_all"
elif [ "$OS" = "Linux" ]; then
    if [ "$FORCE_CPU" -eq 0 ] && [ "$ARCH" = "x86_64" ] && command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1 && (ldconfig -p 2>/dev/null | grep -q "libcuda.so" || [ -f /usr/lib/x86_64-linux-gnu/libcuda.so.1 ] || [ -f /usr/lib64/libcuda.so.1 ] || [ -f /usr/lib/wsl/lib/libcuda.so.1 ] || [ -f /usr/lib64-nvidia/libcuda.so.1 ] || [ -f /usr/lib64-nvidia/libcuda.so ] || [ -d /usr/lib64-nvidia ]); then
        BIN="$DIR/bin/sysd_linux_gpu_cuda"
        if [ "$HAS_GPU_ARG" -eq 0 ]; then
            GPU_FLAG="-gpu"
        fi
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        if [ -f "$DIR/bin/sysd_linux_cpu_arm64" ]; then
            BIN="$DIR/bin/sysd_linux_cpu_arm64"
        else
            echo "[-] Fatal: Native ARM64 binary missing: $DIR/bin/sysd_linux_cpu_arm64" >&2
            exit 1
        fi
    elif [ -f /proc/cpuinfo ] && grep -q "avx2" /proc/cpuinfo; then
        BIN="$DIR/bin/sysd_linux_cpu_x86_64"
    elif [ -f "$DIR/bin/sysd_linux_cpu_generic" ]; then
        BIN="$DIR/bin/sysd_linux_cpu_generic"
    else
        echo "[-] Fatal: CPU lacks required AVX2 instruction set support and generic binary is missing: $DIR/bin/sysd_linux_cpu_generic" >&2
        exit 1
    fi
else
    echo "[-] Fatal: Unsupported operating system: $OS" >&2
    exit 1
fi

if [ ! -f "$BIN" ]; then
    echo "[-] Fatal: Required binary missing for detected hardware: $BIN" >&2
    exit 1
fi

if [ ! -x "$BIN" ]; then
    chmod +x "$BIN"
fi

if [ -n "$GPU_FLAG" ]; then
    exec "$BIN" "$GPU_FLAG" ${ARGS[@]+"${ARGS[@]}"}
else
    exec "$BIN" ${ARGS[@]+"${ARGS[@]}"}
fi
