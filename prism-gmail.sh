#!/bin/bash

# prism gmail startup script

declare -r FIREFOX_PATH="/usr/bin/firefox"
declare -r FIREFOX_PROFILE_DIR_PATH="${HOME}/.mozilla/firefox"
declare -r FIREFOX_DEFAULT_PROFILE_DIR_PATH="$(find $FIREFOX_PROFILE_DIR_PATH -maxdepth 1 -type d -name '*.default' | head -n 1)"

if [ -n "${FIREFOX_DEFAULT_PROFILE_DIR_PATH}" ]; then
  "$FIREFOX_PATH" \
    -app "${FIREFOX_DEFAULT_PROFILE_DIR_PATH}/extensions/refractor@developer.mozilla.org/prism/application.ini" \
    -override "${HOME}/.webapps/gmail@prism.app/override.ini" \
    -webapp gmail@prism.app
fi

