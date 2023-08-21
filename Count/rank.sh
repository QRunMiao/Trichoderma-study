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
log_warn rank.sh

log_info "Count genus"

log_debug "genus.lst"
#从 "strains.taxon.tsv" 文件中提取 "genus" 列的数据，去重并进行排序，最终将结果保存到 "genus.lst" 文件中。
cat strains.taxon.tsv |
    tsv-select -f 3 |#从输入中选择第 3 列的数据。即它提取了 "strains.taxon.tsv" 文件中的 "genus" 列数据。
    tsv-uniq |#去重
    grep -v "NA" |#排除具有 "NA" 值的行
    sort \
    > genus.lst

## 统计木霉属以及各属的species和strains数量
log_debug "genus.count.tsv"
cat genus.lst |
    parallel --no-run-if-empty --linebuffer -k -j 8 '
        n_species=$(
            cat strains.taxon.tsv |
                tsv-filter --str-eq "3:{}" |
                tsv-select -f 3,2 |#选择第 3 列（属名称）和第 2 列（物种名称）的数据
                tsv-uniq |#去重
                wc -l#计算去重后的物种数量，并将结果赋值给变量 n_species
        )
#tsv-filter --str-eq "3:{}"的作用是选择 "strains.taxon.tsv" 文件中第三列（属名称）与指定的属名称相等的行数据。
#--str-eq 是 tsv-filter 命令的选项之一，用于指定字符串相等的条件。
"3:{}" 是条件字符串，其中 {} 是占位符，表示将在运行时用实际的属名称取代。
        
        n_strains=$(
            cat strains.taxon.tsv |
                tsv-filter --str-eq "3:{}" |
                tsv-select -f 3,1 |
                tsv-uniq |
                wc -l
        )

        printf "%s\t%d\t%d\n" {} ${n_species} ${n_strains}
        #该命令的作用是按照指定的格式输出属名称、物种数量和菌株数量，并使用制表符进行分隔。每行输出对应着原始数据中的一个属名称及其对应的物种数量和菌株数量。
        #%s 表示属名称的占位符，%d 表示整数的占位符；{} 是一个占位符，表示在运行时会被实际的属名称替换。
        #${n_species} 是变量 n_species 的值，用于替换第一个 %d 占位符，表示物种数量。${n_strains} 是变量 n_strains 的值，用于替换第二个 %d 占位符，表示菌株数量。
    ' |
    tsv-sort -k1,1 |
    (echo -e 'genus\t#species\t#strains' && cat) \
    > genus.count.tsv


log_info Done.

exit 0
