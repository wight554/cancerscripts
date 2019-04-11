#!/usr/bin/env fish

# Copyright (C) Volodymyr Zhdanov <wight554@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

# Gather parameters
function parse_parameters
  argparse 'd/device=' 'p/package=' 'r/rom=' -- $argv

  if set -lq _flag_device
    set -g DEVICE $_flag_device
  else
    set -g DEVICE "chiron"
  end

  if set -lq _flag_package
    set -g PACKAGE $_flag_package
  else
    die "Package must be specified!"
  end

  if set -lq _flag_rom
    set -g ROM $_flag_rom
  else
    set -g ROM "nitrogen"
  end
end

function build
  # Print some useful stuff
  info "Compiling $PACKAGE from $ROM build for $DEVICE"

  # Deodex is cool
  set COMMANDS $COMMANDS "export WITH_DEXPREOPT_BOOT_IMG_AND_SYSTEM_SERVER_ONLY=true;"

  # Cleanup first
  set COMMANDS $COMMANDS "mka installclean;"

  # Compilation
  set COMMANDS $COMMANDS "mka $PACKAGE 2>&1 | tee $LOGS_DIR/rom-package.log;"
end

function filteroutput
  for FILE in (find "$ROM_PATH/out/target/product/$DEVICE"/{system,vendor} -name $PACKAGE\* -type f 2>/dev/null)
    if string match -r -- $PACKAGE\*[^a-zA-Z^_] $FILE
    or test ( basename $FILE ) = $PACKAGE
      set -g PACKAGE_FILES $PACKAGE_FILES $FILE
    end
  end
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

# Print formatted message about build start
startscript

# Parse parameters and setup enviroment
parse_parameters $argv

# Setup enviroment
rom_enviroment $ROM $DEVICE

# Compile package
build

# Run all bash commands
bish $COMMANDS

# Filter output packages
filteroutput

# Check if compilation is fine
checkoutput $PACKAGE_FILES

# Upload if needed
personal_upload $PACKAGE_FILES

# Print formatted message about script ending
endscript
