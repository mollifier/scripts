#!/bin/bash

##########################################################
# $Date: 2008-06-15 17:51:39 +0900 (日, 15  6月 2008) $
# $Revision: 244 $
#
# 指定した拡張子のファイルを再帰的に探し、
# それらのファイル内を検索する
# ファイル検索にlocateを使用する
##########################################################

#set -x
#grepパターン文字列に'*'などが含まれることを考慮し、
#ワイルドカード展開を禁止する
set -o noglob

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}
declare -r SEPARATOR=':'	#-tオプションで指定する拡張子の分離記号

#locate
declare -r LOCATE=/usr/bin/locate
declare -r DEFAULT_DIR='.'
declare -r DEFAULT_EXTENTION="c${SEPARATOR}h"

#grep
declare -r GREP=/bin/grep
declare -r DEFAULT_GREP_OPT='-E --line-number --with-filename'


#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
	cat << EOF
Usage: $SCRIPT_NAME [-iv] [-t TYPE] [-d PATH] [-g OPTION] [-e] PATTERN
Use \`locate' to find file in current directory, and print lines which match PATTERN.

  -i           ignore case distinctions in PATTERN
  -v           verbosely display error message
  -t TYPE      find files which end with \`.TYPE'
               treat \`$SEPARATOR' as extention separator
               (default=\`$DEFAULT_EXTENTION')
  -d PATH      find file in PATH directory, instead of current directory
  -g OPTION    add OPTION to grep option
               (default=\`$DEFAULT_GREP_OPT')
  -e PATTERN   use PATTERN as search pattern
  -h           display this help and exit
EOF
}

#エラーを出力する
print_error()
{
	echo "$SCRIPT_NAME: $@" 1>&2
	echo "Try \`-h' option for more information." 1>&2
}

#文字列に検索パターンが含まれているかどうか確認する
#$1: 検索対象の文字列
#$2: 検索パターン
match_string()
{
	local target_str=$1
	local pattern=$2

	echo $target_str | grep -e "$pattern" > /dev/null 2>&1
	return $?
}

#相対パスをフルパスに変換する
#$1: 相対パス
get_fullpath()
{
	local relative_path=$1
	local full_path=''

	#ディレクトリの場合、最後の'/'を補う
	#2重に'/'が付加されたとしても、これ以降の処理で余分な'/'は削除される
	if [ -d "$relative_path" ]; then
		relative_path="${relative_path}/"
	fi

	#'/'で始まっていない場合、カレントディレクトリを先頭に追加する
	if ! match_string "$relative_path" '^/'; then
		full_path="${PWD}/${relative_path}"
	else
		full_path="${relative_path}"
	fi

	#'//'を'/'に置換する
	full_path=$(echo $full_path | sed 's!/\{2,\}!/!g')

	#'./'を削除する
	full_path=$(echo $full_path | sed 's!/\(\./\)\+!/!g')

	#'/xxx/../'を'/'に置換する
	while match_string $full_path '/[^/]\+/\.\./'; do
		full_path=$(echo $full_path | sed 's!/[^/]\+/\.\./!/!')
	done

	#先頭の'../'を削除する
	full_path=$(echo $full_path | sed 's!^/\(\.\./\)\+!/!')
	
	echo $full_path
	return $?
}

#####################
#メイン処理
#####################

#変数
error_redirect='2>/dev/null'

#locate
extention=$DEFAULT_EXTENTION
target_dir=$DEFAULT_DIR
name_pattern=""

#grep
grep_pattern=""
grep_opt="$DEFAULT_GREP_OPT"

#引数解析
while getopts ':ivt:d:g:e:h' option; do
	case $option in
	i)	#grepで大文字、小文字の差を無視
		grep_opt="$grep_opt --ignore-case"
		;;
	v)	#find, grepのエラーメッセージを出力する
		error_redirect=''
		;;
	t)	#ファイル拡張子指定
		extention=$OPTARG
		;;
	d)	#find対象ディレクトリ指定
		target_dir=$OPTARG
		;;
	g)	#grepのオプション指定
		grep_opt="$grep_opt $OPTARG"
		;;
	e)	#検索パターン指定
		grep_pattern="$OPTARG"
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

#オプション指定されていないパターン文字列を格納する
grep_pattern="${1:-$grep_pattern}"

#引数エラー処理
if [ -z "$grep_pattern" ]; then
	print_error 'you must specify search pattern'
	exit 1
fi

#検索対象ディレクトリをフルパスに変換する
full_target_dir=$(get_fullpath $target_dir)

#'DIRECTORY/*.EXTENTION'の形でファイル名を指定する
for ext in $(echo $extention | sed "s/$SEPARATOR/ /g"); do
	name_pattern="${name_pattern} ${full_target_dir}*.${ext}"
done

#検索メイン処理
eval \$LOCATE \$name_pattern $error_redirect |
	eval xargs \$GREP \$grep_opt -e \"\$grep_pattern\" $error_redirect

exit $?

