#!/bin/bash

##########################################################
# $Date: 2009-08-24 19:09:30 +0900 (月, 24  8月 2009) $
# $Revision: 429 $
#
# darバックアップ実行スクリプト
# ホームディレクトリをバックアップする
#
# バックアップアーカイブ名には日付を付加するため、
# 1日1回しか実行できない
# 2回以上実行したとしても、エラーを出力して終了する
#
# フルバックアップモードでの動作
#   BACKUP_DEST_DIR以下にその日の日付でディレクトリを作成し、
#   その下に'full + 日付'というサフィックスを付加して
#   アーカイブを作成する
#   例: 2008-01-31/home-full-2008-01-31.1.dar
#   すでに同じ名前のファイルが存在する場合、何もしない
#
# 差分バックアップモードでの動作
#   最も新しいフルバックアップを探し、
#   同じディレクトリに、そのフルバックアップに対する
#   差分アーカイブを作成する
#   作成するアーカイブには'diff + 日付'というサフィックスを付加する
#   例: 2008-01-31/home-diff-2008-02-01.1.dar
#   すでに同じ名前のファイルが存在する場合、何もしない
#
# 自動判定モードでの動作
#   最も新しいフルバックアップを基準とする
#   差分バックアップの数を数える
#   差分バックアップの数が指定数より小さい場合、
#   差分バックアップを行う
#   指定数と等しい、または大きい場合、
#   フルバックアップを行う
#
# メモ:
#   アーカイブから復元する方法
#   (1)復元ファイルを展開するディレクトリに移動する
#   (2)フルバックアップを展開する
#   (3)差分バックアップを展開する
#      例:
#         % cd basedir
#         % dar -x ~/.backup/home-full-2008-01-31
#         % dar -x ~/.backup/home-diff-2008-02-01
#   展開時のオプション
#     -wa : ファイルを上書き、または削除する場合でも警告しない
# 
##########################################################

set -o noglob

#####################
#定数
#####################
declare -r SCRIPT_NAME=${0##*/}

#何度もdateコマンドを実行して日付を取得すると
#スクリプト実行中に日付が変わってしまった場合に
#整合性がとれなくなる
#そのため、1回だけ取得して日付を固定させておく
declare -r NOW_DATE=$(date '+%Y-%m-%d')

#バックアップアーカイブを作成するディレクトリ
#最後に'/'を付加すること
declare -r BACKUP_DEST_DIR=/var/local/${LOGNAME}/backup/darbak-data/

#バックアップ対象の起点となるディレクトリ
#-gオプションで指定するターゲットは
#このルートディレクトリからの相対パスで指定する
declare -r DAR_ROOT_DIR=/home

#バックアップ対象
#DAR_ROOT_DIRからの相対パスで指定すること
#ディレクトリの場合でも最後に'/'をしないこと
declare -r BACKUP_TARGET=${LOGNAME}

#作成するアーカイブの名前のサフィックス
declare -r ARCHIVE_BASE_NAME='home'

#アーカイブ作成時の共通オプション
#-n: ファイルを上書きしない
#-Q: 端末から起動していない場合は、警告を表示しない
#-y: bzip2形式で圧縮したアーカイブを作成する
#-P: 除外するディレクトリを指定する
declare -r DAR_EXCLUDE_SUBDIR_OPTION="-P ${BACKUP_TARGET}/.backup \
    -P ${BACKUP_TARGET}/var/download -P ${BACKUP_TARGET}/var/tmp \
    -P ${BACKUP_TARGET}/Dropbox \
    -P ${BACKUP_TARGET}/.VirtualBox/HardDisks \
    -P ${BACKUP_TARGET}/.VirtualBox/Machines \
    -P ${BACKUP_TARGET}/tmp -P ${BACKUP_TARGET}/.ssh"
#-X: 除外するファイルを指定する
declare -r DAR_EXCLUDE_FILE_OPTION='-X lock -X *~ -X *.swp'
#-Z: 圧縮しないファイルを指定する
declare -r DAR_EXCLUDE_COMPRESSION_OPTION='-Z *.gz -Z *.png -Z *.jpg -Z *.jpeg -Z *.bz2'
declare -r DAR_COMMON_OPTION="-n -Q -y \
    $DAR_EXCLUDE_SUBDIR_OPTION $DAR_EXCLUDE_FILE_OPTION $DAR_EXCLUDE_COMPRESSION_OPTION"

#####################
#関数
#####################

#ヘルプを出力する
print_usage()
{
    cat << EOF
Usage: $SCRIPT_NAME [-f|-d|-a NUM]
Backup home directory to dar archive.
Backup files will be created in '$BACKUP_DEST_DIR'.
This directory have to exist before this script is run.

Your home directory is ${DAR_ROOT_DIR}/${BACKUP_TARGET}.

  -f           make a full backup
               [default]
  -d           make a differential backup
  -a NUM       if the number of differential backups
               is NUM or more, make a full backup
               else, make a differential backup
  -h           display this help and exit
EOF
}

#エラーを出力する
print_error()
{
    echo "$SCRIPT_NAME: $@" 1>&2
    echo "Try \`-h' option for more information." 1>&2
}

#日付が最も新しいディレクトリ名を取得する
#引数
#$1: バックアップ対象の起点となるディレクトリ
#    '/'から始まるフルパスで指定すること
#戻り値: 最も新しいディレクトリ名
#        最後に'/'を付加しない
#説明: 引数で指定されたディレクトリの下から
#      名前が日付形式になっているディレクトリを探し、
#      その中で最も日付が新しいディレクトリ名を返す
get_latest_directory()
{
    local target_dir=$1

    find $target_dir -type d -printf '%f\n' \
    | perl -lne "
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
        && print" \
    | sort -r \
    | head -n 1
}

#差分バックアップの数を取得する
#引数
#$1: 差分バックアップを探すディレクトリ
#    '/'から始まるフルパスで指定すること
#戻り値: 差分バックアップの数
#説明: 引数で指定されたディレクトリの下から
#      差分バックアップアーカイブを探し、
#      その数を返す
get_num_of_differential_backup()
{
    local target_dir=$1

    find $target_dir -maxdepth 1 -type f -printf '%f\n' \
    | perl -lne "
        /
            ^
            \\Q$ARCHIVE_BASE_NAME\\E
            -diff-
            [[:digit:]]+  #年
            -
            (?: #月
                0[1-9] | 1[012]
            )
            -
            (?: #日
                0[1-9] | [12][0-9] | 3[01]
            )
            \.[1-9][0-9]*\.dar
            $
        /x
        && print" \
    | wc -l
}

#####################
#メイン処理
#####################

#変数

#バックアップモード
#FULL: フルバックアップ
#DIFF: 差分バックアップ
#AUTO: フル/差分のいずれかを自動的に判定する
backup_mode="FULL"

#新しく作成するアーカイブ名
archive_name=""
#差分バックアップの際に基準とするフルバックアップのアーカイブ名
reference_archive_name=""
#最新のフルバックアップが行われたディレクトリ名
latest_directory=""
#自動判定モードで作成する差分バックアップの数
diff_backup_num=""

#引数解析
while getopts ':fda:h' option; do
    case $option in
    f)
        backup_mode="FULL"
        ;;
    d)
        backup_mode="DIFF"
        ;;
    a)  #自動判定モード
        #1以上の整数以外が指定されていたらエラーとする
        if ! echo $OPTARG | grep '^[1-9][0-9]*$' >/dev/null 2>&1; then
            print_error "number must be greater than 0 -- $OPTARG"
            exit 1
        fi
        backup_mode="AUTO"
        diff_backup_num=$OPTARG
        ;;
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

#バックアップアーカイブを作成するディレクトリが
#存在しない場合、エラーとする
if [ ! -d "$BACKUP_DEST_DIR" ]; then
    print_error "not found backup destination directory: $BACKUP_DEST_DIR"
    exit 1
fi

#自動判定モードの場合の処理
#差分バックアップの数によってフルバックアップか
#差分バックアップかを切り換える
if [ "$backup_mode" == "AUTO" ]; then
    #最新のフルバックアップが行われたディレクトリ名を取得する
    latest_directory=$(get_latest_directory $BACKUP_DEST_DIR)

    if [ -z "$latest_directory" ]; then
        #フルバックアップが見つからなかった場合
        #フルバックアップを行う
        backup_mode="FULL"
    else
        #フルバックアップが見つかった場合

        #差分バックアップの数を取得する
        if [ $(get_num_of_differential_backup ${BACKUP_DEST_DIR}${latest_directory}) \
            -ge "$diff_backup_num" ]; then

            #差分バックアップの数が指定数と等しい、または大きい場合
            backup_mode="FULL"
        else
            #差分バックアップの数が指定数より小さい場合
            backup_mode="DIFF"
        fi
    fi

    latest_directory=""
fi

#$backup_modeによってモードを切り換える
if [ "$backup_mode" == "DIFF" ]; then
    #差分バックアップ

    #最新のフルバックアップが行われたディレクトリ名を取得する
    latest_directory=$(get_latest_directory $BACKUP_DEST_DIR)

    if [ -z "$latest_directory" ]; then
        #フルバックアップが見つからなかった場合
        print_error "could not find a full backup in $BACKUP_DEST_DIR"
        exit 1
    fi

    #基準とするフルバックアップのアーカイブ名を取得する
    reference_archive_name=${ARCHIVE_BASE_NAME}-full-${latest_directory}
    
    archive_name=${BACKUP_DEST_DIR}${latest_directory}/${ARCHIVE_BASE_NAME}-diff-${NOW_DATE}

    dar $DAR_COMMON_OPTION -c $archive_name \
        -R $DAR_ROOT_DIR -g $BACKUP_TARGET \
        -A ${BACKUP_DEST_DIR}${latest_directory}/${reference_archive_name}
else
    #フルバックアップ

    if ! mkdir ${BACKUP_DEST_DIR}${NOW_DATE}; then
        #ディレクトリ作成に失敗した場合
        print_error "could not make a full backup"
        exit 1
    fi

    archive_name=${BACKUP_DEST_DIR}${NOW_DATE}/${ARCHIVE_BASE_NAME}-full-${NOW_DATE}
    #アーカイブを作成する
    dar $DAR_COMMON_OPTION -c $archive_name \
        -R $DAR_ROOT_DIR -g $BACKUP_TARGET
fi

exit $?


