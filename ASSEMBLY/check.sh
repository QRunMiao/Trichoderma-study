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
log_warn check.sh

touch check.lst

#对check.lst 去重，根据 url.tsv 文件中的数据，检查目标目录 {3}/{1} 是否存在，并在目标目录中使用 md5sum 命令检查文件的完整性。
如果目标目录或校验和失败，将输出相应的日志信息。

# Keep only the results in the list
cat check.lst |
    sort |
    tsv-uniq |
    tsv-join -f url.tsv -k 1 \
    > tmp.list
mv tmp.list check.lst

cat url.tsv |
    tsv-join -f check.lst -k 1 -e |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 8 '
        if [[ ! -e "{3}/{1}" ]]; then#判断文件是否存在，如果不存在，则终止当前循环
            exit
        fi
        log_debug "{3}\t{1}"#输出一条日志消息，使用制表符分隔 {3} 和 {1} 的内容
        cd "{3}/{1}"
        md5sum --check md5checksums.txt --status#校验文件的 MD5 校验和
        #md5sum 是一个用于计算和校验文件 MD5 校验和的工具。--check 参数表示执行校验操作。
#md5checksums.txt 是包含了期望的文件和对应的 MD5 校验和值的文本文件。--status 参数指定只输出校验的状态信息，而不显示具体的校验和结果。
#当执行 md5sum --check md5checksums.txt --status 命令后：
如果校验成功，命令会返回状态码 0。如果校验失败，命令会返回非零状态码。
#MD5（Message Digest Algorithm 5 消息摘要算法5）是一种常用的哈希函数算法，用于将任意长度的数据映射为固定长度的哈希值（通常为128位）。MD5 哈希值在数学上被认为具有较高的唯一性和不可逆性，因此常用于验证文件完整性、密码存储等场景。

        if [ "$?" -eq "0" ]; then#"$?" 是一个特殊变量，用于获取上一个命令的退出状态码（返回值）。
            echo "{1}" >> ../../check.lst#如果返回值为 0（即校验成功），则将 {1} 追加写入 ../../check.lst 文件。
        else
            log_warn "{1} checksum failed"#如果返回值不为 0（即校验失败），则输出一条警告日志。
        fi
    '

log_info Done.

exit 0
