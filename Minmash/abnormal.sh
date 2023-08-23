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
log_warn abnormal.sh

ANI_VALUE_THRESHOLD=0.05

log_info Abnormal strains

cat species.lst |
while read SPECIES; do
#    log_debug "${SPECIES}"

    # Number of assemblies >= 2
    if [[ ! -s "${SPECIES}/mash.dist.tsv" ]]; then
        continue
    fi

    D_MAX=$(
        cat "${SPECIES}/mash.dist.tsv" |
            tsv-summarize --max 3#计算指定文件中某一列（可能是第三列）的最大值，并将结果存储在变量 D_MAX 中
    )
    if (( $(echo "$D_MAX < $ANI_VALUE_THRESHOLD" | bc -l) )); then
        continue#同物种内不同菌株之间的最大遗传距离小于0.05，继续往下，否则跳此循环，继续进行下一个物种
    fi

    # "Link assemblies with median ANI"
    D_MEDIAN=$(
        cat "${SPECIES}/mash.dist.tsv" |
            tsv-filter --lt "3:$ANI_VALUE_THRESHOLD" |#--lt <field>:<value>`：仅保留字段 `<field>` 小于 `<value>` 的行。
            tsv-summarize --median 3
    )
    cat "${SPECIES}/mash.dist.tsv" |
        tsv-filter --ff-str-ne 1:2 --le "3:$D_MEDIAN" |#第三列的值小于等于变量 D_MEDIAN
        perl -nla -F"\t" -MGraph::Undirected -e '
            BEGIN {
                our $g = Graph::Undirected->new;
            }

            $g->add_edge($F[0], $F[1]);

            END {
                for my $cc ( $g->connected_components ) {
                    print join qq{\n}, sort @{$cc};
                }
            }
        ' \
        > "${SPECIES}/median.cc.lst"#遗传距离小于中位数的基因组之间通过无向图找出连通的点

    log_info "${SPECIES}\t${D_MEDIAN}\t${D_MAX}"
    cat ${SPECIES}/assembly.lst |
        grep -v -Fw -f "${SPECIES}/median.cc.lst"#-Fw 选项表示进行完全匹配。
done |
    tee abnormal.lst#将上述处理得到的结果同时输出到标准输出和 abnormal.lst 文件中。

log_info Done.

exit 0
