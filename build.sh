#!/bin/bash
set -eo pipefail

export ARCH=arm64
export SUBARCH=arm64
export WORKROOT="$(pwd)"
export OUT_DIR="$WORKROOT/out"
export TOOLCHAIN_DIR="$WORKROOT/toolchains/r487747c"
export SOURCE_DATE_EPOCH=$(date +%s)
export LLVM=1
export CROSS_COMPILE=aarch64-linux-gnu-
DEFCONFIG="gki_defconfig"

download_clang() {
    local clang_bin="$TOOLCHAIN_DIR/bin/clang"
    local repo_url="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86"
    local branch="android14-release"
    local tmp="$WORKROOT/clang-repo"

    if [ -f "$clang_bin" ]; then
        echo "==> [Clang Check] Clang r487747c is already present in $TOOLCHAIN_DIR"
        return 0
    fi

    echo "==> [Clang Check] Downloading Clang (git sparse checkout)..."
    rm -rf "$TOOLCHAIN_DIR" "$tmp"
    mkdir -p "$(dirname "$TOOLCHAIN_DIR")"

    local ok=0
    for i in 1 2 3 4 5; do
        echo "==> Attempt $i/5"
        if git clone --depth 1 --filter=blob:none --sparse -b "$branch" "$repo_url" "$tmp" \
           && git -C "$tmp" sparse-checkout set clang-r487747c; then
            ok=1
            break
        fi
        rm -rf "$tmp"
        sleep 10
    done

    if [ "$ok" -ne 1 ]; then
        echo "==> [Error] Could not clone Clang!"
        exit 1
    fi

    mv "$tmp/clang-r487747c" "$TOOLCHAIN_DIR"
    rm -rf "$tmp"

    if [ -f "$clang_bin" ]; then
        echo "==> [Clang Check] Successfully installed to $TOOLCHAIN_DIR"
    else
        echo "==> [Error] Failed to install Clang!"
        exit 1
    fi
}

if [ "$1" = "--tool" ]; then
    download_clang
    echo "==> Toolchain setup finished."
    exit 0
fi

if [ ! -f "$TOOLCHAIN_DIR/bin/clang" ]; then
    echo "==> [Error] Toolchain not found in $TOOLCHAIN_DIR"
    echo "==> Please run './build.sh --tool' to download and set up the toolchain first."
    exit 1
fi

export PATH="$TOOLCHAIN_DIR/bin:$PATH"

BUILD_CONFIG="${BUILD_CONFIG:-build.config.gki.aarch64}"
export ROOT_DIR="$WORKROOT"
export KERNEL_DIR="."

if [ ! -f "$ROOT_DIR/$BUILD_CONFIG" ]; then
    echo "==> [Error] $BUILD_CONFIG not found in $ROOT_DIR"
    exit 1
fi

check_defconfig() { :; }

echo "==> Loading $BUILD_CONFIG..."
set -a
. "$ROOT_DIR/$BUILD_CONFIG"
set +a

DEFCONFIG="${DEFCONFIG:-gki_defconfig}"
echo "==> DEFCONFIG=$DEFCONFIG LTO=${LTO:-default} MAKE_GOALS=${MAKE_GOALS:-<default>}"

mkdir -p "$OUT_DIR"

[ -n "$PRE_DEFCONFIG_CMDS" ] && eval "$PRE_DEFCONFIG_CMDS"
echo "==> Generating configuration ($DEFCONFIG)..."
make O="$OUT_DIR" "$DEFCONFIG"
[ -n "$POST_DEFCONFIG_CMDS" ] && eval "$POST_DEFCONFIG_CMDS"

if [ -n "$LTO" ]; then
    echo "==> Applying LTO=$LTO"
    CFG="$WORKROOT/scripts/config --file $OUT_DIR/.config"
    case "$LTO" in
        none) $CFG -e LTO_NONE -d LTO_CLANG -d LTO_CLANG_THIN -d LTO_CLANG_FULL ;;
        thin) $CFG -d LTO_NONE -e LTO_CLANG -e LTO_CLANG_THIN -d LTO_CLANG_FULL ;;
        full) $CFG -d LTO_NONE -e LTO_CLANG -d LTO_CLANG_THIN -e LTO_CLANG_FULL ;;
    esac
    make O="$OUT_DIR" olddefconfig
fi

echo "==> Compiling Kernel 6.1..."
make -j"$(nproc)" O="$OUT_DIR" $MAKE_GOALS 2>&1 | tee "$WORKROOT/build.log" | tail -150

echo "----------------------------------------"
echo "Build complete!"
echo "Kernel image: $OUT_DIR/arch/arm64/boot/Image"
echo "----------------------------------------"
