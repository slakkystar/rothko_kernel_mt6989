#!/bin/bash
set -e

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
    local clang_url="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/emu-34-2-release/clang-r487747c.tar.gz"

    if [ -f "$clang_bin" ]; then
        echo "==> [Clang Check] Clang r487747c is already present in $TOOLCHAIN_DIR"
    else
        echo "==> [Clang Check] Downloading Clang..."
        mkdir -p "$TOOLCHAIN_DIR"
        
        echo "==> Downloading and extracting archive..."
        curl -sSL "$clang_url" | tar -xz -C "$TOOLCHAIN_DIR"
        
        if [ -f "$clang_bin" ]; then
            echo "==> [Clang Check] Successfully downloaded and installed to $TOOLCHAIN_DIR"
        else
            echo "==> [Error] Failed to install Clang!"
            exit 1
        fi
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

echo "==> Generating configuration ($DEFCONFIG)..."
mkdir -p "$OUT_DIR"
make O="$OUT_DIR" $DEFCONFIG

echo "==> Compiling Kernel 6.1..."
make -j$(nproc) O="$OUT_DIR" 2>&1 | tee "$WORKROOT/build.log" | tail -150

echo "----------------------------------------"
echo "Build complete!"
echo "Kernel image: $OUT_DIR/arch/arm64/boot/Image"
echo "----------------------------------------"
