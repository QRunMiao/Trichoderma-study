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
log_warn dist.sh

log_info Distances between assembly sketches#组装草图图之间的距离
mash triangle -E -p 16 -l <(
    cat species.tsv |
tsv-join -f ../ASSEMBLY/pass.lst -k 1 |
parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
            if [[ -e "{2}/{1}.msh" ]]; then
                echo "{2}/{1}.msh"
            fi
        '
    ) \
    > mash.dist.tsv

log_info Fill distance matrix with lower triangle#用下三角形填充距离矩阵
tsv-select -f 1-3 mash.dist.tsv |
    (tsv-select -f 2,1,3 mash.dist.tsv && cat) | # && 是一个命令连接符，用于在一条命令执行成功后才执行下一条命令。它的作用是将两个命令串联起来，确保第一个命令执行成功后再执行第二个命令
    (
        cut -f 1 mash.dist.tsv |
            tsv-uniq |
            parallel -j 1 --keep-order 'echo -e "{}\t{}\t0"' &&
        cat
    ) \
    > mash.dist_full.tsv#全矩阵


log_info "Clusting via R hclust(), and grouping by cutree(h=0.4)"#“通过R hclust()进行聚类，并通过cutree(h=0.4)进行分组”
cat mash.dist_full.tsv |
    Rscript -e '
        library(readr);
        library(tidyr);
        library(ape);

        pair_dist <- read_tsv(file("stdin"), col_names=F);
        tmp <- pair_dist %>%
            pivot_wider( names_from = X2, values_from = X3, values_fill = list(X3 = 1.0) )
        tmp <- as.matrix(tmp)
        mat <- tmp[,-1]
        rownames(mat) <- tmp[,1]

        dist_mat <- as.dist(mat)
        clusters <- hclust(dist_mat, method = "ward.D2")
        tree <- as.phylo(clusters)
        write.tree(phy=tree, file="tree.nwk")

        group <- cutree(clusters, h=0.4)
        groups <- as.data.frame(group)
        groups$ids <- rownames(groups)
        rownames(groups) <- NULL
        groups <- groups[order(groups$group), ]
        write_tsv(groups, "groups.tsv")
    '

log_info Done.

exit 0
