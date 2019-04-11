
#!/usr/bin/env fish

# Copyright (C) Volodymyr Zhdanov <wight554@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

function rom_enviroment
  # Check ROM
  if test $argv[1] != "lineage"; and test $argv[1] != "nitrogen"
    endscript "Only LineageOS and NitrogenOS are supported!"
  end

  set -gx ROM_PATH "$HOME/$argv[1]"
  set -gx BUILD_PATH "$ROM_PATH/out/target/product/$argv[2]"
  set -gx LOGS_DIR "$HOME/logs"
  if test ! -d $LOGS_DIR
    warn "Logs directory doesn't exist..."
    mkdir -p $LOGS_DIR
  end

  # Setup environment
  cd $ROM_PATH; or endscript "ROM dir doesn't exist!"
  set -gx COMMANDS $COMMANDS "source $ROM_PATH/build/envsetup.sh;"

  # Set the device
  if test $argv[1] = "lineage"
    set COMMANDS $COMMANDS "breakfast $argv[2];"
  else if test $argv[1] = "nitrogen"
    set COMMANDS $COMMANDS "lunch nitrogen_$argv[2]-userdebug;"
  end

  # Set ccache flags
  set COMMANDS $COMMANDS "export USE_CCACHE=1;"
  set COMMANDS $COMMANDS "export CCACHE_DIR=$HOME/.ccache-$argv[1];"
end

