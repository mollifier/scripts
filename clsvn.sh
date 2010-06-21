#!/bin/bash

##########################################################
# 重複したSubversionリポジトリのバックアップを削除する
#
# hot-backupを使用してリポジトリのバックアップをとると、
# 同じリビジョンのバックアップファイルが存在していたとしても
# さらにバックアップファイルが作成されてしまう
# それら不要なバックアップを削除する
# リビジョンが異なるバックアップは削除せず、そのまま残す
#
# バックアップファイルは以下の形式である
# リポジトリ名 - リビジョン [ -通し番号 ] サフィックス
#
# サポートするサフィックスは以下のとおり
#   .tar.gz : tar+gz形式のアーカイブ
#   /       : 非圧縮のリポジトリディレクトリ
#
# lsの--sort=version, --indicator-style=slashオプションを
# 必要とする
##########################################################

set -o noglob

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}

#バックアップが格納されているディレクトリ
#このディレクトリの直下のファイルを
#Subversionリポジトリのバックアップと扱う
#最後に'/'を付加しないこと
declare -r BACKUP_DIR_PATH=/var/local/${LOGNAME}/backup/svn

#バックアップファイルのサフィックス
declare -r BACKUP_SUFFIX_TAR_GZ='.tar.gz'
declare -r BACKUP_SUFFIX_DIR='/'

#バックアップファイルの種類
#-tオプションの引数として使用する
declare -r BACKUP_TYPE_TAR_GZ='gz'
declare -r BACKUP_TYPE_DIR='dir'

#デフォルト設定
#変更する際は両方ともあわせて変更すること
declare -r DEFAULT_BACKUP_SUFFIX=$BACKUP_SUFFIX_TAR_GZ
declare -r DEFAULT_BACKUP_TYPE=$BACKUP_TYPE_TAR_GZ

#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
	cat << EOF
Usage: $SCRIPT_NAME [-t TYPE] [rm]
Remove duplicative Subversion backup files.
With no 'rm' option, not remove, but list target files
Subversion backup directory: $BACKUP_DIR_PATH

Require GNU ls with --sort=version, and
--indicator-style=slash option.

  rm           perform removal

  -t TYPE      only TYPE files are targeted
               and don't remove other files
               TYPE is as follows:
               \`$BACKUP_TYPE_TAR_GZ'
                  gzip compressed tar file
                  whose name ends with \`$BACKUP_SUFFIX_TAR_GZ'
               \`$BACKUP_TYPE_DIR'
                  no compressed repository directry
               [default=$DEFAULT_BACKUP_TYPE]

  -h           display this help and exit
EOF
}

#エラーを出力する
print_error()
{
	echo "$SCRIPT_NAME: $@" 1>&2
	echo "Try \`-h' option for more information." 1>&2
}

#引数のうち'/'を'\'でエスケープし、標準出力に出力する
#perlの正規表現に使用する文字列をエスケープするために使用する
#
#引数
#$1: エスケープ前の文字列
escape_delimiter()
{
	echo "$1" \
	| perl -lpe 's{ (?= / ) }{\\}xg'
}

#バックアップディレクトリにあるファイルから
#リポジトリ名を抽出し、
#'リポジトリ名-リビジョン'という形式で出力する
#
#lsの--indicator-style=slashオプションを使用して
#ディレクトリである場合には最後に'/'を付加し、
#ディレクトリかどうかを判別する
#
#引数
#$1: バックアップディレクトリ
#$2: バックアップファイルのサフィックス
print_repo_name()
{
	local backup_dir="$1"
	local backup_suffix=$(escape_delimiter "$2")

	#以下の形式にマッチする行を探し、
	#通し番号、サフィックスを削除してリポジトリ名を一覧出力する
	#  リポジトリ名 - リビジョン [ -通し番号 ] サフィックス
	#
	#形式にマッチしないファイルは無視し、出力しない
	ls --indicator-style=slash "$backup_dir" \
	| perl -lne \
		"s/
			( -[[:digit:]]+ )     #リビジョン番号
			(?: -[[:digit:]]+ )?  #追加の通し番号があってもよい
			\\Q$backup_suffix\\E  #サフィックス \Q, \Eでメタ文字を無効化する
			\$
		//x
		&& print \$_ . \$1" \
	| sort -u #重複したリポジトリ名は1つだけ出力する
}

#通し番号なしのバックアップファイル名のみを出力する
#ファイル名はフルパスで出力する
#
#lsの--indicator-style=slashオプションを使用して
#ディレクトリである場合には最後に'/'を付加し、
#ディレクトリかどうかを判別する
#
#引数
#$1: バックアップディレクトリ
#$2: 対象となるリポジトリ
#    リポジトリ名-リビジョン という形式で指定すること
#$3: バックアップファイルのサフィックス
print_repo_without_serial_num()
{
	local backup_dir="$1"
	local repo_name_with_rev=$(escape_delimiter "$2")
	local backup_suffix=$(escape_delimiter "$3")

	ls --indicator-style=slash "$backup_dir" \
	| perl -lne \
		"/
			^
			\\Q$repo_name_with_rev\\E   #リポジトリ名 \Q, \Eでメタ文字を無効化する
			\\Q$backup_suffix\\E        #サフィックス \Q, \Eでメタ文字を無効化する
			\$
		/x
		&& print '$backup_dir/' . \$_"
}

#通し番号付きのバックアップファイル名のみを出力する
#ファイル名はフルパスで出力する
#lsの--sort=version オプションを使用し、
#バージョン番号の順番にソートして出力する
#
#lsの--indicator-style=slashオプションを使用して
#ディレクトリである場合には最後に'/'を付加し、
#ディレクトリかどうかを判別する
#
#引数
#$1: バックアップディレクトリ
#$2: 対象となるリポジトリ
#    リポジトリ名-リビジョン という形式で指定すること
#$3: バックアップファイルのサフィックス
print_repo_with_serial_num()
{
	local backup_dir="$1"
	local repo_name_with_rev=$(escape_delimiter "$2")
	local backup_suffix=$(escape_delimiter "$3")

	ls --sort=version --indicator-style=slash "$backup_dir" \
	| perl -lne \
		"/
			^
			\\Q$repo_name_with_rev\\E   #リポジトリ名 \Q, \Eでメタ文字を無効化する
			-[[:digit:]]+               #通し番号
			\\Q$backup_suffix\\E        #サフィックス \Q, \Eでメタ文字を無効化する
			\$
		/x
		&& print '$backup_dir/' . \$_"
}

#重複したバックアップファイル名を出力する
#ファイル名はフルパスで出力する
#
#引数
#$1: バックアップディレクトリ
#$2: 対象となるリポジトリ
#    リポジトリ名-リビジョン という形式で指定すること
#$3: バックアップファイルのサフィックス
print_duplicative_repo()
{
	local backup_dir="$1"
	local repo_name_with_rev="$2"
	local backup_suffix="$3"

	#重複ファイルの選択方法
	#
	# +"通し番号"がないものが存在する場合、
	#   そのファイルを残すべきファイルとみなし、
	#   それ以外のファイルを重複ファイルとして出力する
	#
	# +すべてのファイルに"通し番号"がある場合、
	#  "通し番号"が最も小さいファイルを残すべきファイルとみなし、
	#   それ以外のファイルを重複ファイルとして出力する

	local num=$(
		print_repo_without_serial_num \
			"$backup_dir" "$repo_name_with_rev" "$backup_suffix" \
		| wc -l
	)

	if [ "$num" -gt 0 ]; then
		#"通し番号"がないものが存在する場合
		print_repo_with_serial_num "$backup_dir" "$repo_name_with_rev" "$backup_suffix"
	else
		#すべてのファイルに"通し番号"がある場合、
		#"通し番号"付きファイルのうち最も数字が小さいものを除き、
		#それ以外を重複ファイルとみなして出力する

		#呼び出された関数側でバージョン番号に基づき
		#ソート済みであることを前提とする
		print_repo_with_serial_num "$backup_dir" "$repo_name_with_rev" "$backup_suffix" \
		| sed '1d'
	fi
}

#####################
#メイン処理
#####################

#変数
backup_suffix=$DEFAULT_BACKUP_SUFFIX
#重複したファイルに対して実行するコマンド
#デフォルトではlsで名前を出力するだけで、削除しない
execute_cmd='ls -1d'

#引数解析
while getopts ':t:h' option; do
	case $option in
	t)	#バックアップファイルの種類を指定する
		if [ "$OPTARG" == "$BACKUP_TYPE_TAR_GZ" ]; then
			backup_suffix=$BACKUP_SUFFIX_TAR_GZ
		elif [ "$OPTARG" == "$BACKUP_TYPE_DIR" ];then
			backup_suffix=$BACKUP_SUFFIX_DIR
		else
			print_error "invalid backup type -- $OPTARG"
			exit 1
		fi
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
	execute_cmd='rm -rf'
	shift
fi

if [ ! -z "$1" ]; then
	#不要な引数が指定されている場合
	print_error "unknown argument -- $1"
	exit 1
fi

for try in $(print_repo_name "$BACKUP_DIR_PATH" "$backup_suffix"); do
	print_duplicative_repo "$BACKUP_DIR_PATH" "$try" "$backup_suffix" \
	| xargs --no-run-if-empty $execute_cmd
done

exit $?

