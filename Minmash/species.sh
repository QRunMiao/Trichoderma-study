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
log_warn species.sh

log_info ANI distance within species

cat species.tsv |
tsv-join -f ../summary/ASSEMBLY/pass.lst -k 1 |
tsv-select -f 2 |
    tsv-uniq \
    > species.lst

cat species.lst |
while read SPECIES; do
    log_debug "${SPECIES}"
    mkdir -p "${SPECIES}"

    cat species.tsv |
tsv-join -f ../summary/ASSEMBLY/pass.lst -k 1 |
tsv-filter --str-eq "2:${SPECIES}" |
        tsv-select -f 1 \
        > "${SPECIES}/assembly.lst"#同一个物种的不同菌株基因组组装

#    echo >&2 "Number of assemblies >= 2" # 同一个物种含有多个基因组组装，进行下一步
    N_ASM=$(
        cat "${SPECIES}/assembly.lst" | wc -l
    )
    if [[ $N_ASM -lt 2 ]]; then#根据行数是否小于 2 来决定是否执行后续的代码块。如果行数小于 2，则跳过当前循环的剩余部分。
        continue
    fi

    echo >&2 "    mash distances" # 计算同一个物种含有多个基因组之间的遗传距离
    if [[ ! -s "${SPECIES}/mash.dist.tsv" ]]; then
        mash triangle -E -p 8 -l <(#mash triangle用于计算序列之间的距离矩阵；-E：计算完整距离矩阵；-l <(...): 这里使用了一个进程替代 (process substitution) 作为输入，其中包含一个子命令，用于生成一个要处理的列表。
            cat "${SPECIES}/assembly.lst" |
                parallel --no-run-if-empty --linebuffer -k -j 1 "
                    if [[ -e ${SPECIES}/{}.msh ]]; then
                        echo ${SPECIES}/{}.msh
                    fi
                "
            ) \
            > "${SPECIES}/mash.dist.tsv"
    fi
done

log_info Done.

exit 0
