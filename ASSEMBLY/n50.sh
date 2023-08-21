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
# Usage
#----------------------------#
USAGE="
Usage: $0 [LEN_N50] [N_CONTIG] [LEN_SUM]

Default values:
    LEN_N50     longer than 100000
    N_CONTIG    less than   1000
    LEN_SUM     longer than 1000000

$ bash n50.sh 100000 100

"

if ! [ -z "$1" ]; then#这一行判断 $1 是否存在且非空。$1 是脚本的第一个参数，-z 判断一个字符串是否为空。[ -z "$1" ] 返回真（true）表示参数未提供或为空，前面的 ! 取反符号表示条件取反，即参数不为空时执行 if 语句块中的代码。
    if ! [[ $1 =~ ^[0-9]+$ ]]; then#用正则表达式判断 $1 是否全由数字组成。[[ $1 =~ ^[0-9]+$ ]] 使用 =~ 来对 $1 进行匹配，^[0-9]+$ 是一个匹配一个或多个数字的正则表达式。[[ ... ]] 是 Bash 中用于条件判断的结构，
        echo >&2 "$USAGE"#将 $USAGE 的内容输出到标准错误输出（stderr）
        exit 1#这一行使脚本退出，并返回状态码 1。在这种情况下，脚本将以非零状态码退出，表示发生了错误或参数不正确。
    fi
fi

LEN_N50=${1:-100000}#${1} 表示脚本的第一个参数，即通过命令行传递给脚本的第一个值。
:- 是一个默认值设定符号，表示如果前面的变量没有被设置或为空，则使用后面的值作为默认值。
100000 是为 LEN_N50 提供的默认值。如果脚本没有接收到第一个参数或者第一个参数为空，那么 LEN_N50 将被设定为 100000。
N_CONTIG=${2:-1000}
LEN_SUM=${3:-1000000}

#----------------------------#
# Run
#----------------------------#
log_warn n50.sh

touch n50.tsv

log_info Keep only the results in the list
cat n50.tsv |
    (echo -e "name\tN50\tS\tC" && cat) | # Headers
    tsv-uniq | # keep the first header line
    tsv-filter -H --gt "N50:0" | # unfinished downloads #过滤出 N50 列中大于 0 的行。
    keep-header -- tsv-join -f url.tsv -k 1 \
    > tmp.tsv
mv tmp.tsv n50.tsv

log_info Calculate N50 not in the list
cat url.tsv |
    tsv-join -f n50.tsv -k 1 -e |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 8 '
        if [[ ! -e "{3}/{1}" ]]; then
            exit
        fi
        log_debug "{3}\t{1}"

        find "{3}/{1}" -type f -name "*_genomic.fna.gz" |
            grep -v "_from_" | # exclude CDS and rna
            xargs cat |
            faops n50 -H -S -C stdin | # do not display header#N50是一组contig或scaffold的统计数据。N50类似于长度的平均值或中值，但对于较长的contig具有更重要的意义
            #-H（header）只返回统计值，没有统计值名称； -S（sum）同时显示碱基总数；
            -C（count） 同时显示总序列数;stdin表示从标准输入读取FASTA文件内容
            (echo -e "{1}" && cat) |# echo 命令输出第一个参数的值
            datamash transpose
    ' \
    > tmp1.tsv

# Combine new results with the old ones
cat n50.tsv tmp1.tsv | 
    tsv-uniq |
    keep-header -- sort \
    > tmp2.tsv
mv tmp2.tsv n50.tsv
rm tmp*.tsv

# Filter results with custom criteria
cat n50.tsv |
    tsv-filter -H --ge "N50:${LEN_N50}" |#-H：保留输入文件的头部（包括列标题行）。${LEN_N50} 是通过变量传递的 N50 长度阈值
    tsv-filter -H --le "C:${N_CONTIG}" |
    tsv-filter -H --ge "S:${LEN_SUM}" \
    > n50.pass.tsv

log_info Done.

exit 0
