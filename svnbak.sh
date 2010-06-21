#!/bin/bash

##########################################################
# subversionリポジトリのバックアップを行う
# hot-backupを使用する
##########################################################

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}

#バックアップコマンド
declare -r SVN_BACKUP_CMD="/usr/bin/svn-hot-backup"

#リポジトリが格納されているディレクトリ
#このディレクトリの直下のディレクトリをリポジトリと扱う
#最後に'/'を付加すること
declare -r REPOSITORY_DIR="/var/local/${LOGNAME}/svnrepos/"

#バックアップ先のディレクトリ
declare -r BACKUP_DIR=/var/local/${LOGNAME}/backup/svn/


#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
	cat << EOF
Usage: $SCRIPT_NAME backup|gz|list|help
Backup all subversion repositories.

Backup command: $SVN_BACKUP_CMD
Repository directory: $REPOSITORY_DIR
Backup directory: $BACKUP_DIR

  backup             backup all repositories
  gz                 create gzip compressed tar archives of the backups
  list               list all repositories
  help, -h, --help   display this help and exit
EOF
}

#エラーを出力する
print_error()
{
	echo "$SCRIPT_NAME: $@" 1>&2
	echo "Try '$SCRIPT_NAME help' for more information." 1>&2
}


#####################
#メイン処理
#####################

#変数
#実行モード
#backup: リポジトリをバックアップする
#list: リポジトリをリスト出力する
execute_mode=''
#バックアップコマンドのオプション
backup_opt=''

#引数解析
case "$1" in
backup)
	execute_mode='backup'
	;;
gz)
	execute_mode='backup'
	backup_opt='--archive-type=gz'
	;;
list)
	execute_mode='list'
	;;
help|-h|--help)
	print_usage
	exit 0
	;;
*)	#エラー
	print_error "unknown argument -- $1"
	exit 1
	;;
esac

#コマンド、ディレクトリのチェック
if [ ! -x "$SVN_BACKUP_CMD" ]; then
	print_error "can't execute backup command: $SVN_BACKUP_CMD"
	exit 1
fi

if [ ! -d "$REPOSITORY_DIR" ]; then
	print_error "not found repository directory: $REPOSITORY_DIR"
	exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
	print_error "not found backup directory: $BACKUP_DIR"
	exit 1
fi

#バックアップ実行
for trydir in $REPOSITORY_DIR*; do
	#ディレクトリのみを対象とする
	if [ -d "$trydir" ]; then
		if [ "$execute_mode" == "backup" ]; then
			#バックアップモードの場合
			"$SVN_BACKUP_CMD" $backup_opt "$trydir" "$BACKUP_DIR"
		else
			#リスト出力モードの場合
			ls -d "$trydir"
		fi
	fi
done

exit $?


