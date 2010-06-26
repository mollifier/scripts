#!/bin/bash

##########################################################
# prism ウェブアプリケーション 軌道スクリプト
##########################################################

#set -o noglob

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}

declare -r FIREFOX_PATH="/usr/bin/firefox"
declare -r FIREFOX_PROFILE_DIR_PATH="${HOME}/.mozilla/firefox"
declare -r FIREFOX_DEFAULT_PROFILE_DIR_PATH="$(find $FIREFOX_PROFILE_DIR_PATH -maxdepth 1 -type d -name '*.default' | head -n 1)"


#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
    cat << EOF
Usage: $SCRIPT_NAME WEBAPP_NAME
Run prism web application.

   WEBAPP_NAME  specify web application name
                not include @prism.app
  -h            display this help and exit
EOF
}

#エラーを出力する
print_error()
{
    echo "$SCRIPT_NAME: $@" 1>&2
    echo "Try \`-h' option for more information." 1>&2
}


#####################
#メイン処理
#####################

#引数解析
while getopts ':h' option; do
    case $option in
    h)
        print_usage
        exit 0
        ;;
    :)  #オプション引数欠如
        print_error "option requires an argument -- $OPTARG"
        exit 1
        ;;
    *)  #不明なオプション
        print_error "invalid option -- $OPTARG"
        exit 1
        ;;
    esac
done
shift $(expr $OPTIND - 1)

webapp_name="$1"

if [ -z "${FIREFOX_DEFAULT_PROFILE_DIR_PATH}" ]; then
    print_error "firefox profile was not found : ${FIREFOX_DEFAULT_PROFILE_DIR_PATH}"
    exit 1
fi

if [ -z "$webapp_name" ]; then
    print_error 'you must specify web application name'
    exit 1
fi

webapp_name="${webapp_name}@prism.app"
override_name="${HOME}/.webapps/${webapp_name}/override.ini"

# ウェブアプリが存在することを確認する
if [ ! -e "$override_name" ]; then
    print_error "web application was not found : ${webapp_name}"
    exit 1
fi

# 起動する
"$FIREFOX_PATH" \
  -app "${FIREFOX_DEFAULT_PROFILE_DIR_PATH}/extensions/refractor@developer.mozilla.org/prism/application.ini" \
  -override "${override_name}" \
  -webapp "${webapp_name}" &

exit $?

