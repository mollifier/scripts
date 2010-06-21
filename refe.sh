#!/bin/bash

declare -r REFE_DIR=$HOME/local/rubies/ruby-refm-latest
declare -r REFE_CMD=$REFE_DIR/refe-1_8_7

if [ -t 1 ]; then
    $REFE_CMD "$@" | ${PAGER:-less}
else
    $REFE_CMD "$@"
fi

