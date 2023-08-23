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
log_warn compute.sh

cat species.tsv |
tsv-join -f ../ASSEMBLY/pass.lst -k 1 |
parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 8 '
        if [[ -e "{2}/{1}.msh" ]]; then
            exit
        fi
        log_info "{2}\t{1}"
        mkdir -p "{2}"

        find ../ASSEMBLY/{2}/{1} -name "*_genomic.fna.gz" |
            grep -v "_from_" |
            xargs gzip -dcf |
            mash sketch -k 21 -s 100000 -p 2 - -I "{1}" -o "{2}/{1}"
            #-k 21 表示使用长度为 21 的 k-mer 进行计算。
-s 100000 表示使用一个大小为 100,000 的样本来生成 sketch。
-p 2 表示使用 2 个线程来进行计算。
- 表示从标准输入中读取数据作为输入。
-I "{1}" 表示设置输入文件名的格式。-I 是 mash sketch 命令的一个参数，用于指定输入序列的标识符。在命令中，-I "{1}" 表示将标识符的占位符 {1} 替换为输入文件的名称。
-o "{2}/{1}" 表示设置输出文件名的格式，其中 {2} 会被替换为指定的目录路径，{1} 会被替换为输入文件的名称。
    '

log_info Done.

exit 0
