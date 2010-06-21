#!/bin/bash

##########################################################
# 新しいファイル40個を残してエディタのバックアップファイル
# を削除する
##########################################################

#set -x
set -o noglob

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}

#削除せずに残すファイル数
declare -r NUM_OF_LEAVE_FILES=40
#削除ファイルが入っているディレクトリ(最後に'/'を付加すること)
declare -r BACKUP_DIR=${HOME}/.backup/vi/


#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
	cat << EOF
Usage: $SCRIPT_NAME [-if] [-n NUM] [rm]
Remove backup files but the $NUM_OF_LEAVE_FILES most recent modified.
With no 'rm' option, not remove, but list target files
Backup files are in \`$BACKUP_DIR'.

  rm           perform removal
  -n NUM       leave NUM files, instead of $NUM_OF_LEAVE_FILES
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

#変数
execute_cmd=ls	#デフォルトでlsを実行する
number=$NUM_OF_LEAVE_FILES

#引数解析
while getopts ':n:h' option; do
	case $option in
	n)	#削除せずに残すファイル数を指定する
		#0以上の整数以外が指定されていたらエラーとする
		if ! echo $OPTARG | grep '^[0-9][0-9]*$' >/dev/null 2>&1; then
			print_error "number must be greater or equal than 0 -- $OPTARG"
			exit 1
		fi
		number=$OPTARG
		;;
	h)
		print_usage
		exit 0
		;;
	:)	#オプション引数欠如
		print_error "option requires an argument -- $OPTARG"
		exit 1
		;;
	*)	#不明なオプション
		print_error "invalid option -- $OPTARG"
		exit 1
		;;
	esac
done
shift $(expr $OPTIND - 1)

if [ "$1" == "rm" ]; then
	#削除を実行する
	execute_cmd='rm -f'
	shift
fi

if [ ! -z "$1" ]; then
	#不要な引数が指定されている場合
	print_error "unknown argument -- $1"
	exit 1
fi


#残すファイル数+1個目からを削除対象とする
number=$(expr $number + 1)

for tryfile in $(ls -At $BACKUP_DIR | sed -n "${number},\$p"); do
	$execute_cmd "$BACKUP_DIR$tryfile"
done

exit $?

