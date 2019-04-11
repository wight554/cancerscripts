#!/usr/bin/env fish

# Copyright (C) Volodymyr Zhdanov <wight554@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

# Gather parameters
function parse_parameters
  argparse 'd/device=' 'r/rom=' -- $argv

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
end

# Build kernel image by using ROM sources
function build
  # Print some useful stuff
  info "Compiling boot.img from $ROM for $DEVICE"

  # Small cleanup
  rm -f "$BUILD_PATH/boot.img"

  # Compilation
  set COMMANDS $COMMANDS "mka bootimage 2>&1 | tee $LOGS_DIR/rom-kernel.log;"
  echo $COMMANDS
end

# We use bootimage as output for further commands
function choose_output
  set -g BOOTIMG "$BUILD_PATH/boot.img"
end

#####################
##  RUN THEM ALL!  ##
#####################

# Common script
source (cd (dirname (status -f)); and pwd)"/common.fish"

# Snippets
source (cd (dirname (status -f)); and pwd)"/env/rom_enviroment.fish"

# Add trap for catching Ctrl-C
trap 'echo; die "Manually aborted!"' SIGINT SIGTERM

# If parameters are satisfied, print formatted message about build start
parse_parameters $argv
startscript

# Setup enviroment
rom_enviroment $ROM $DEVICE

# Compile boot and kernel images
build

# Run all bash commands
bish $COMMANDS

# Choose which image to use as output one
choose_output

# Check if compilation is fine
checkoutput $BOOTIMG

# Upload if needed
personal_upload $BOOTIMG

# Print formatted message about script ending
endscript
