#!/bin/bash

##########################################################
# avastでウイルススキャンを行う
##########################################################

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}
declare -r AVAST_CMD=/usr/bin/avast
declare -r AVAST_UPDATE_CMD=/usr/bin/avast-update
declare -r AVAST_DIR=${HOME}/.avast

declare -r DEFAULT_SCAN_TARGET='.'
declare -r REPORT_FILE_NAME=${AVAST_DIR}/report.txt
#感染したファイルを見つけた場合の動作
#1: 削除する, 2: 未使用, 3: 復元する, 4: ユーザ入力を待つ
declare -r CONTINUE_TYPE=1

#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
	cat << EOF
Usage: $SCRIPT_NAME [OPTION] [SCAN_TARGET...]
Start avast virus scan and create report file.

default scan target : ${DEFAULT_SCAN_TARGET}
report file name : ${REPORT_FILE_NAME}

  SCAN_TARGET  scan SCAN_TARGET instead of ${DEFAULT_SCAN_TARGET}
  -u           update avast before scanning
  -h           display this help and exit
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

update='no'

#引数解析
while getopts ':uh' option; do
	case $option in
	u)
		update='yes'
		;;
	h)
		print_usage
		exit 0
		;;
	*)	#不明なオプション
		print_error "invalid option -- $OPTARG"
		exit 1
		;;
	esac
done
shift $(expr $OPTIND - 1)

#updateを行う
if [ "$update" == 'yes' ]; then
	${AVAST_UPDATE_CMD} --quiet
fi

#スキャンを行う
#引数で指定したすべてのターゲットをスキャンする
#引数がない場合はデフォルトターゲットをスキャンする
#
#オプションの内容
#testall: すべてのターゲットをスキャンする
#nostats: スキャン結果の統計情報を出力しない
#continue: 感染したファイルが存在した場合の動作の指定
#report: 結果を記述したレポートファイルを出力する
#
# archivetype オプションは指定せずデフォルトのままとする
# iso ファイル中の VOB ファイルで decompression bomb error が発生することがあるため

${AVAST_CMD} --testall --nostats \
	--continue=${CONTINUE_TYPE} \
	--report=${REPORT_FILE_NAME} \
	"${@:-${DEFAULT_SCAN_TARGET}}" \
	| grep -E -v -e '[[:space:]]+\[OK\]$'

exit $?

