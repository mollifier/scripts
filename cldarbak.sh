#!/bin/bash

##########################################################
# 重複したdarバックアップアーカイブを削除する
#
# バックアップ先ディレクトリの構造
#   バックアップ先の起点となるディレクトリの下には
#   いくつかのディレクトリが存在し、各ディレクトリ内には
#   一連の差分バックアップアーカイブが格納されている
#   このひとつのディレクトリをシリーズ(series)と
#   呼ぶことにする
#
#   例
#    $BACKUP_DEST_DIR
#    |-- 2008-06-22/
#    |   |-- home-diff-2008-06-23.1.dar
#    |   `-- home-full-2008-06-22.1.dar
#    `-- 2008-06-23/
#        |-- home-diff-2008-06-25.1.dar
#        |-- home-diff-2008-06-24.1.dar
#        `-- home-full-2008-06-23.1.dar
#
# このスクリプトでは、シリーズの数が高々MAX_SERIES_NUM (3)個に
# なるように古いシリーズを削除する
###########################################################

#set -o noglob

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}

#darアーカイブが格納される起点となるディレクトリ
#末尾に'/'を付加しないこと
declare -r BACKUP_DEST_DIR=/var/local/${LOGNAME}/backup/darbak-data/

#削除せずに残すシリーズ数
declare -r MAX_SERIES_NUM=3

#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
    cat << EOF
Usage: $SCRIPT_NAME [rm]
Remove old dar backup archive.
With no 'rm' option, not remove, but list target files
Backup directory is ${BACKUP_DEST_DIR}.

  rm           perform removal
  -h           display this help and exit
EOF
}

#エラーを出力する
print_error()
{
    echo "$SCRIPT_NAME: $@" 1>&2
    echo "Try \`-h' option for more information." 1>&2
}

#シリーズであるかどうかを判定する
#$1: シリーズかどうかの判定対象とするディレクトリ
#      '/'から始まるフルパスで指定し、
#      末尾に'/'を付加しないこと
#説明: 引数が以下の条件をすべて満たす場合は0(true)を、
#      そうでない場合は0以外(false)を戻り値として返す
#      (1)存在するディレクトリである
#      (2)パス部分を除いたディレクトリ名が
#         以下の日付フォーマットである
#           '年'-'月'-'日'
#      (3)少なくとも1つの'*.dar'というファイルを含んでいる
is_series()
{
    local target_dir="$1"
    local base_dir_name=${target_dir##*/}

    [ -d "$target_dir" ] && \
    perl -e "exit (
        \"$base_dir_name\" =~
        /
            ^
            [[:digit:]]+  #年
            -
            (?: #月
                0[1-9] | 1[012]
            )
            -
            (?: #日
                0[1-9] | [12][0-9] | 3[01]
            )
            $
        /x
    ? 0 : 1)" && \
    ls $target_dir/*.dar > /dev/null 2>&1

    return $?
}

#すべてのシリーズを出力する
#引数
#$1: バックアップ起点ディレクトリ
#出力: すべてのシリーズのパス名
#      '/'から始まるフルパスで出力し、末尾に'/'を付加しない
print_all_series()
{
    local backup_dest_dir="$1"

    for try in $(find $backup_dest_dir \
        -mindepth 1 -maxdepth 1 -print); do

        if is_series $try; then
            echo $try
        fi
    done
}

#####################
#メイン処理
#####################

#変数
#発見した古いアーカイブに対して実行するコマンド
#デフォルトではlsで名前を出力するだけで、削除しない
execute_cmd='ls -1d'

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

#すべてのシリーズのうち、新しいものを$MAX_SERIES_NUM 個残し、
#それ以外を削除、またはリスト出力の対象とする
for try in $(print_all_series $BACKUP_DEST_DIR \
    | sort -r | sed -e "1,${MAX_SERIES_NUM}d"); do

    $execute_cmd $try
done

exit $?

