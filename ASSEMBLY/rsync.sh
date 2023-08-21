#!/usr/bin/env bash

BASH_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd "${BASH_DIR}"

#----------------------------#
# Colors in term
#----------------------------#
GREEN=
RED=
NC=
if tty -s < /dev/fd/1 2> /dev/null; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color
fi

log_warn () {
    echo >&2 -e "${RED}==> $@ <==${NC}"
}

log_info () {
    echo >&2 -e "${GREEN}==> $@${NC}"
}

log_debug () {
    echo >&2 -e "==> $@"
}

export -f log_warn
export -f log_info
export -f log_debug

#----------------------------#
# helper functions
#----------------------------#
set +e

# set stacksize to unlimited
if [[ "$OSTYPE" != "darwin"* ]]; then
    ulimit -s unlimited
fi

signaled () {
    log_warn Interrupted
    exit 1
}
trap signaled TERM QUIT INT

readlinkf () {
    perl -MCwd -l -e 'print Cwd::abs_path shift' "$1";
}

export -f readlinkf

#----------------------------#
# Run
#----------------------------#
log_warn rsync.sh#日志记录命令，用于输出警告级别的日志消息，消息内容为 "rsync.sh"。

touch check.lst#用于创建一个空的文件 "check.lst"。

#这段命令用于将 url.tsv 文件中的数据联接到 check.lst 文件中的数据，并根据联接后的结果进行文件复制和目录创建操作。最终结果是根据联接后的数据复制文件到指定的目标目录，并在标准错误输出中记录日志信息。
cat url.tsv |
    tsv-join -f check.lst -k 1 -e |#-k 1：指定第一个表格和第二个表格的连接键为第一列
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 4 '
        echo >&2
        log_info "{3}\t{1}"#是一个日志记录命令，用于输出信息级别的日志消息。 {3} 是联接后的数据中的第 3 列的值，{1} 是联接后的数据中的第 1 列的值。
        mkdir -p "{3}/{1}"#目录名由 {3} 和 {1} 组成的路径构成
        rsync -avP --no-links {2}/ {3}/{1}/ --exclude="assembly_status.txt"
    '
#--colsep '\t'：指定输入数据的列分隔符为制表符（\t）。
#rsync -avP --no-links {2}/ {3}/{1}/ --exclude="assembly_status.txt": 使用 rsync 命令进行文件同步操作，将数据从 url.tsv 中的列（第 2 列）指定的源目录复制到之前创建的目标目录。-avP 选项表示以归档模式进行同步（保留文件属性、递归同步子目录、显示进度信息），--no-links 表示不复制符号链接文件，--exclude="assembly_status.txt" 表示排除名为 "assembly_status.txt" 的文件。

log_info Done.

exit 0
