#!/usr/bin/env fish

# Copyright (C) Volodymyr Zhdanov <wight554@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only


######################
##     WRAPPERS     ##
######################

function bish
  bash -c "$argv"
end

######################
##  ECHO FUNCTIONS  ##
######################

# Prints an error in red and exits the script
function die
  echo (set_color red)$argv[1](set_color normal)
  exit 1
end

# Prints an info message in blue
function info
  echo (set_color blue)$argv[1](set_color normal)
end

# Prints a warn message in yellow
function warn
  echo (set_color yellow)$argv[1](set_color normal)
end

# Prints a formatted info to point out what is being done to the user
function header
  echo $argv[2]
  echo "===="(for i in (seq (string length $argv[1])); echo -e "=\\c"; end)"===="
  echo "==  "$argv[1]"  =="
  echo "===="(for i in (seq (string length $argv[1])); echo -e "=\\c"; end)"===="
  echo (set_color normal)
end

#########################
##  VERBOSE FUNCTIONS  ##
#########################

# Start script with formatted message
function startscript
  header "BUILD STARTED!" (set_color green)
end

# End script with formatted message
function endscript
  header "BUILD COMPLETED!" (set_color green)
end

########################
##  UPLOAD FUNCTIONS  ##
########################

# Notify Telegram chat about smth
function telegram_notify
  curl -s https://api.telegram.org/bot$TOKEN/sendMessage -d parse_mode="Markdown" -d text=$argv[1] -d chat_id=$CHATID >> /dev/null
end

# Upload file to Telegram chat
function telegram_upload
  curl -s https://api.telegram.org/bot$TOKEN/sendDocument -F document=@$argv[1] -F chat_id=$CHATID >> /dev/null
end

# Uploads all the things to specified place
function personal_upload
  # Proper chatid
  set -g CHATID $PM
  # Check if everything is fine
  for FILE in $argv
    info "Uploading "( basename $FILE )" to Telegram..."
    telegram_upload $FILE
  end
end

# Check if compilation output exists
function checkoutput
  for FILE in $argv
    if ! set -q FILE
    or test ! -f $FILE
      die "Nothing to proceed with, output is empty!"
    end
  end
end
