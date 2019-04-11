#!/usr/bin/env fish

# Copyright (C) Volodymyr Zhdanov <wight554@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

# Gather parameters
function parse_parameters
  argparse 'd/device=' 'r/rom=' 'b/buildtype=' 'c/clean' 'o/off' 's/sync' -- $argv

  if set -lq _flag_device
    set -g DEVICE $_flag_device
  else
    set -g DEVICE "chiron"
  end

  if set -lq _flag_rom
    set -g ROM $_flag_rom
  else
    set -g ROM "nitrogen"
  end

  if set -lq _flag_buildtype
    set -g BUILDTYPE $_flag_buildtype
  else
    set -g BUILDTYPE "personal"
  end

  if set -lq _flag_clean
    set -g CLEAN true
  end

  if set -lq _flag_off
    set -g POWEROFF true
  end

  if set -lq _flag_sync
    set -g SYNC true
  end

  if test $BUILDTYPE != "personal"
  or test $BUILDTYPE != "release"
  or test $BUILDTYPE != "test"
    die "Choose build type between personal, release and test!"
  end
end

# Pretty small one
function sync
  if ! set -q $SYNC
    repo sync
  end
end

# Go clean if needed, otherwise installclean
function clean
  if ! set -q $CLEAN
    set COMMANDS $COMMANDS "mka clobber;"
  else
    set COMMANDS $COMMANDS "mka installclean;"
  end
end

function build
  #  Start compilation
  set COMMANDS $COMMANDS "mka bacon  2>&1 | tee $LOGS_DIR/build-rom.log;"
end


# Print some useful verbose
function printparams
  set -l PARAMINFO "Compiling $BUILDTYPE $ROM build for $DEVICE" 
  for PARAM in CLEAN POWEROFF SYNC
    if set -q $PARAM
      set PARAMS "$PARAMS $PARAM"
    end
  end
  info "Compiling $BUILDTYPE $ROM build for $DEVICE"
  if set -q PARAMS
    info "These parameters were set:$PARAMS"
  else
    info "No additional parameters were set"
  end
end

function getoutput
  # Once build finished we need to know it's date
  set -g FILENAME (basename (find $BUILD_PATH -maxdepth 1 -iname "$ROM*"(date +'%Y%m%d')"*.zip"))
  if test $ROM = "nitrogen"
    if test $BUILDTYPE = "personal"
      set FILENAME (string replace -- '.zip' '-UNSTABLE.zip' $FILENAME)
    end
    if test $BUILDTYPE = "test"
      set FILENAME (string replace -- '.zip' '-TEST.zip' $FILENAME)
    end
  end
  mv $ROM_PATH/signed-ota_update.zip $ROM_PATH/$FILENAME
  set -g ROM_ZIP $ROM_PATH/$FILENAME
  if test $ROM = "nitrogen"
    set -g CHANGELOG "$BUILD_PATH/nitrogen_$DEVICE-Changelog.txt"
  end
end


function upload
  set SF "https://sourceforge.net"
  set FRS "wight554@web.sourceforge.net:/home/frs"
  if test $BUILDTYPE = "personal"
    set -gx CHATID $PM
  end
  info "Uploading $FILENAME to wight554.tk..."; and rsync -av -e ssh $ROM_ZIP "$FRS/project/wightroms/$ROM/$FILENAME"
  telegram_notify "$FILENAME can be downloaded [here]($SF/projects/wightroms/files/$ROM/$FILENAME)"
  if test $BUILDTYPE != "personal"
    info "Uploading changelog to Telegram..."
    telegram_upload $CHANGELOG
  end
end

function power_off
  if set -q POWEROFF
    sudo poweroff
  end
end

#####################
##  RUN THEM ALL!  ##
#####################

# Common script
source (cd (dirname (status -f)); and pwd)"/common.fish"

# Snippets
source (cd (dirname (status -f)); and pwd)"/env/rom_enviroment.fish"
source (cd (dirname (status -f)); and pwd)"/snippets/rom_sign.fish"

# Add trap for catching Ctrl-C
trap 'echo; die "Manually aborted!"' SIGINT SIGTERM

# Add poweroff trap for catching exit
trap 'power_off' EXIT

# Pare parameters
parse_parameters $argv

# If parameters are satisfied, print formatted message about build start
startscript

# Setup enviroment
rom_enviroment $ROM $DEVICE

# Sync if needed
sync

# Cleanup
clean

# Compile ROM
build

# We want to know params we set
printparams

# Run all bash commands
bish $COMMANDS

# Sign build
rom_sign $BUILD_PATH

# Get compilation result
getoutput

# Check if compilation is fine
checkoutput $ROM_ZIP

# Upload if needed
upload

# Print formatted message about script ending
endscript
