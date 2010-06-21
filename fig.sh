#!/bin/bash

##########################################################
# 指定した拡張子のファイルを再帰的に探し、
# それらのファイル内を検索する
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

#find
declare -r FIND=/usr/bin/find
declare -r DEFAULT_DIR='.'
declare -r DEFAULT_FIND_OPT='-type f'
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
Find file in current directory recursively, and print lines which match PATTERN.

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


#####################
#メイン処理
#####################

#変数
error_redirect='2>/dev/null'

#find
extention=$DEFAULT_EXTENTION
target_dir=$DEFAULT_DIR
name_pattern=""
find_opt=$DEFAULT_FIND_OPT

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

#.'EXTENTION'で終わるファイル名を指定する正規表現をつくる

#SEPARATORを'\|'に置換する
extention=$(echo $extention | sed "s/$SEPARATOR/\\\\|/g")
name_pattern=".*\.\($extention\)"


#検索メイン処理
eval \$FIND \$target_dir \$find_opt -regex \$name_pattern -print0 $error_redirect |
	eval xargs -0 \$GREP \$grep_opt -e \"\$grep_pattern\" $error_redirect

exit $?

