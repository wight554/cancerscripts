#!/usr/bin/env fish

# Copyright (C) Volodymyr Zhdanov <wight554@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

# Gather parameters
function parse_parameters
  argparse 'd/device=' 't/toolchain=' 'm/miui' 'c/clean' 'r/release' -- $argv

  if set -lq _flag_device
    set -g DEVICE $_flag_device
  else
    set -g DEVICE "chiron"
  end

  if set -lq _flag_toolchain
    set -g TOOLCHAIN $_flag_toolchain
  else
    set -g TOOLCHAIN "gcc"
  end

  if set -lq _flag_clean
    set -g CLEAN true
  end

  if set -lq _flag_miui
    set -g MIUI "-miui"
    set -g TOOLCHAIN "clang"
  end

  if set -lq _flag_release
    set -g RELEASE true
  end

  if test $TOOLCHAIN != "gcc"
  or test $TOOLCHAIN != "clang"
    die "Chose compiler between Clang and GCC!"
  end
end

function enviroment
  info "Setting up build enviroment.."

  # Build dirs
  set -g KERNEL_DIR "$HOME/linux/$DEVICE"
  set -g BUILD_DIR "$HOME/linux/build-$DEVICE"
  if test ! -d $BUILD_DIR
    warn "Build directory doesn't exist..."
    mkdir -p $BUILD_DIR
  end

  # Common ccache variable
  set -g CCACHE (command -v ccache)

  # Make threads
  set -g THREADS (math (nproc --all) + 1)
  set -g JOBS_FLAG "-j$THREADS"

  # Defconfig
  set -g DEFCONFIG "$DEVICE""$MIUI""_defconfig"

  if test $TOOLCHAIN = "clang"
    # Clang paths variables
    set BINUTILS_FOLDER "$HOME/toolchains/binutils"
    set BINUTILS_BIN "$BINUTILS_FOLDER/bin"
    set CLANG_FOLDER (find "$HOME/toolchains/linux-x86"/clang-r* -maxdepth 0 -type d | tail -1)
    set CLANG_BIN "$CLANG_FOLDER/bin"

    set -g fish_user_paths $fish_user_paths $CLANG_BIN $BINUTILS_BIN
    set -g CLANG_VERSION (clang --version | head -n 1 | perl -pe 's/(  | |)\(.*?\)//g')
  else if test $TOOLCHAIN = "gcc"
    # GCC 32-bit paths variables
    set GCC_FOLDER "$HOME/toolchains/gcc"
    set GCC_BIN "$GCC_FOLDER/bin"
    set -g fish_user_paths $fish_user_paths $GCC_BIN
  end
end

function clean
  # Cleanup build directory if needed otherwise clean dtb only
  if set -q CLEAN
  or set -q RELEASE
    info "Cleaning build directory..."
    rm -rf $BUILD_DIR && mkdir -p $BUILD_DIR
  else
    info "Cleaning DTBs directory..."
    rm -rf "$BUILD_DIR/arch/arm64/boot/dts/qcom/"
  end
end

function build
  # Open kernel directory
  cd $KERNEL_DIR; or die "Kernel directory doesn't exist!"
  info "Compiling kernel..."
  # Generate defconfig
  make -s ARCH="arm64" O=$BUILD_DIR $DEFCONFIG $JOBS_FLAG
  # Build kernel
  if test $TOOLCHAIN = "clang"
    make O=$BUILD_DIR $JOBS_FLAG \
		ARCH="arm64" \
		CC="$CCACHE clang" \
		KBUILD_COMPILER_STRING=$CLANG_VERSION \
		KCFLAGS=$KCFLAGS \
		CROSS_COMPILE="aarch64-linux-gnu-" \
		CROSS_COMPILE_ARM32="arm-linux-gnueabi-" \
		Image.gz dtbs
  else if test $TOOLCHAIN = "gcc"
    make O=$BUILD_DIR $JOBS_FLAG \
		ARCH="arm64" \
		CROSS_COMPILE="$CCACHE aarch64-elf-" \
		CROSS_COMPILE_ARM32="arm-eabi-" \
		Image.gz dtbs
  end
  # COMPILED IMAGES
  set -g IMAGE $BUILD_DIR/arch/arm64/boot/Image.gz
  for DTB in (find "$BUILD_DIR/arch/arm64/boot/dts/qcom/" -name \*.dtb -type f 2>/dev/null)
     set -g DTBS $DTBS $DTB
  end
  # Once the work is done, we save date
  set -g DATE (date +'%Y%m%d')
end

# Changelog for specified repo (last week)
function generate_changelog
  if set -q RELEASE
    # Changelog
    set CHANGELOG_DIR "$HOME/changelogs"
    if test ! -d $CHANGELOG_DIR
      warn "Changelogs directory doesn't exist..."
      mkdir -p $CHANGELOG_DIR
    end
    set -g CHANGELOG "$CHANGELOG_DIR/Changelog-$DEVICE-$DATE.txt"

    cd $KERNEL_DIR; or die "Kernel dir doesn't exist!"
    rm -f $CHANGELOG
    for i in (seq 7)
      set AFTER (date --date="$i days ago" +%F)
      set UNTIL (date --date=(math "$i - 1")" days ago" +%F)
        echo "####################" >> $CHANGELOG
        echo "     $UNTIL" >> $CHANGELOG
        echo "####################" >> $CHANGELOG
        git log --after=$AFTER --until=$UNTIL --pretty=tformat:"%h  %s  [%an]" >> $CHANGELOG
        echo "" >> $CHANGELOG
    end
  end
end

#  Zipping AnyKernel2
function ramdisk
  # Common paths
  set AK2_PATH "$HOME/linux/ak2-$DEVICE"

  set -g AK2_ZIP "$AK2_PATH/placeholder-kernel$MIUI-$DEVICE-$DATE.zip"

  # Cleanup AK2 folder
  rm -rf $AK2_PATH/{dtbs,kernel} $AK2_ZIP

  # Re-create kernel folders
  mkdir -p "$AK2_PATH/dtbs/"
  mkdir -p "$AK2_PATH/kernel/"

  # Move kernel image specified in kernel compilation script
  info "Moving kernel image to AnyKernel2 folder..."
  for DTB in $DTBS
    mv -f $DTB "$AK2_PATH/dtbs/"
  end
  mv -f $IMAGE "$AK2_PATH/kernel/"

  # Create flashable AnyKernel2 zip
  cd $AK2_PATH; or endscript "AnyKernel2 folder doesn't exist!"
  zip -r9 $AK2_ZIP ./* -x "README.md" -x "./*.zip"
end

function upload
  if set -q RELEASE
    info "Uploading "(basename $AK2_ZIP)" to Telegram..."; and telegram_upload $AK2_ZIP
    info "Uploading changelog to Telegram..." && telegram_upload $CHANGELOG
  else
    personal_upload $AK2_ZIP
  end
end

#####################
##  RUN THEM ALL!  ##
#####################

# Helper script
source (cd (dirname (status -f)); and pwd)"/common.fish"

# Add trap for catching Ctrl-C
trap 'echo; die "Manually aborted!"' SIGINT SIGTERM

# Parse parameters
parse_parameters $argv

# If parameters are satisfied, print formatted message about build start
startscript

# Setup enviroment
enviroment

# Cleanup
clean

# Compile kernel image
build

# Check if compilation is fine
checkoutput $DTBS
checkoutput $IMAGE

# Make Anykernel2 zip
ramdisk

# Generate changelog
generate_changelog

# Check if zip exists
checkoutput $AK2_ZIP

# Upload if needed
upload

# Print formatted message about script ending
endscript
