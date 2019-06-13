#!/usr/bin/env fish
# Android ROM signing wrapper
# Copyright (C) 2017-2018 Albert I (krasCGQ)
# Copyright (C) 2019 Volodymyr Zhdanov <wight554@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
#
# This snippet contains portions of code taken from AOSP documentation and has
# been modified accordingly to make it compatible with both AOSP and custom
# ROMs, which usually have backuptool (aka addon.d support).
#
# Due to such reason, this snippet is licensed under either GPL-3.0+ as part of
# my scripts or Apache-2.0 following same license used by most AOSP projects.
#
# Refer to the following AOSP documentation on how things work:
# https://source.android.com/devices/tech/ota/sign_builds


function rom_sign
  # The following ROMs don't support backuptool
  set NO_BACKUPTOOL "nitrogen"

  # Must be run at root of ROM source
  if test ! -d (pwd)/build/tools
    die "This function must be run at root of ROM source!"
  end

  # Make sure only one target files package exists prior to running the function
  if test (find "$BUILD_PATH/obj/PACKAGING/target_files_intermediates" -name \*target_files\*.zip | wc -l) -ne 1
    die "Less or more than one target files package detected!"
  end

  # Must have signing keys in .android-certs at root of home folder before proceeding
  for SIGNKEYS in {media,platform,releasekey,shared}.{pk8,x509.pem}
    if test ! -f "$HOME/.android-certs/$SIGNKEYS"
      die "Missing one or more signing keys in $HOME/.android-certs folder!"
    end
  end

  # Let's assume the ROM has backuptool support
  set BACKUP_FLAG "--backup=true"

  # Check what ROM we're going to sign by looking inside vendor folder
  for ROMS in $NO_BACKUPTOOL
    if test $ROM = $ROMS
      # ROM lacks backuptool support
      set -e BACKUP_FLAG
      break
    end
  end

  # Add jdk prebuilts to path manually
  set fish_user_paths $fish_user_paths "$ROM_PATH/prebuilts/jdk/jdk9/linux-x86/bin/"

  # Sign target files package
  ./build/tools/releasetools/sign_target_files_apks \
    -o -d "$HOME/.android-certs" \
    "$BUILD_PATH"/obj/PACKAGING/target_files_intermediates/*-target_files-*.zip \
    signed-target_files.zip

  # Convert signed target files package to signed OTA package
  ./build/tools/releasetools/ota_from_target_files \
    --block $BACKUP_FLAG -k "$HOME/.android-certs/releasekey" \
    signed-target_files.zip signed-ota_update.zip

  # Remove signed target files because we don't need it anymore
  rm -f signed-target_files.zip
end
