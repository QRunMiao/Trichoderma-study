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
log_warn nr.sh

ANI_VALUE_THRESHOLD=0.005

log_info Non-redundant strains

cat species.lst |
while read SPECIES; do
    log_debug "${SPECIES}"

    # Number of assemblies >= 2
    if [[ ! -s "${SPECIES}/mash.dist.tsv" ]]; then
        continue
    fi

    echo >&2 "    List NR"
    cat "${SPECIES}/mash.dist.tsv" |
        tsv-filter --ff-str-ne 1:2 --le "3:${ANI_VALUE_THRESHOLD}" \
        > "${SPECIES}/redundant.dist.tsv"##遗传距离小于0.005，视为冗余基因组

    echo >&2 "    Connected components"
    cat "${SPECIES}/redundant.dist.tsv" |
        perl -nla -F"\t" -MGraph::Undirected -e '
            BEGIN {
                our $g = Graph::Undirected->new;
            }

            $g->add_edge($F[0], $F[1]);

            END {
                for my $cc ( $g->connected_components ) {
                    print join qq{\t}, sort @{$cc};
                }
            }
        ' \
        > "${SPECIES}/connected_components.tsv"#冗余基因组之间通过无向图找出连通的点

    echo >&2 "    Scores based on rep.lst, omit.lst, and assembly_level"
    cat ${SPECIES}/assembly.lst |
        tsv-join -f ../summary/ASSEMBLY/rep.lst -k 1 -a 1 --write-all "0" |#-k 1 表示按照第一列进行连接；-a 1 表示保留第一个输入文件（从 -f 指定的文件）的所有行/表示输出保留标准输入的所有行;--write-all "0" 表示未匹配上的行填充为 "0"
        tsv-join -f ../summary/ASSEMBLY/omit.lst -k 1 -a 1 --write-all "0" |
        tsv-join -f species.tsv -k 1 -a 3 \
        > ${SPECIES}/scores.tsv

    cat "${SPECIES}/connected_components.tsv" |
        SPECIES=${SPECIES} perl -nla -MPath::Tiny -F"\t" -e '
            BEGIN {#定义三个哈希表
                our %rep_of = map { ($_, 1) } path( q(.../summary/ASSEMBLY/rep.lst) )->lines({chomp => 1});
                #($_, 1)：$_ 是键，1 是值。在某些场景下，我们可能只关注键的存在性而不关心具体的值，因此可以用 1 作为占位符值。
                #lines() 是 Path::Tiny 对象的方法，用于按行读取文件内容。{chomp => 1} 是一个选项哈希，用于指定读取时去除行尾的换行符。
                #=> 符号是用于创建关联数组（也称为哈希）的键值对的分隔符。它实际上是一种写法上的简化形式，可以用来提高代码的可读性。
                # chomp 是键，1 是值
                our %omit_of = map { ($_, 1) } path( q(../summary/ASSEMBLY/omit.lst) )->lines({chomp => 1});
                our %level_of = map { ( split(qq(\t), $_) )[0, 2] } path( q(species.tsv) )->lines({chomp => 1});
                #split(qq(\t), $_) 使用制表符作为分隔符，将每一行拆分成一个数组。[0, 2] 表示只取数组中索引为 0 和 2 的元素。
%level_of = map { (split(qq(\t), $_))[0, 2] }：将 map 函数的结果赋值给 %level_of 哈希表。数组中索引为 0 的元素作为键，索引为 2 的元素作为值。
            }

            my @sorted = @F;

            # Level of "Complete Genome"/1 and Chromosome/2 are preferred
            @sorted =
                map  { $_->[0] }#函数数组引用中的第一个元素取出，即还原为初始的元素。
                sort { $a->[1] <=> $b->[1] }#升序排列
                map { [$_, $level_of{$_}] }
                @sorted;

            # With annotations
            @sorted =
                map  { $_->[0] }
                sort { $a->[1] <=> $b->[1] }
                map { [$_, exists $omit_of{$_} ? 1 : 0 ] }#将 @sorted 数组中的每个元素 $_ 和一个布尔值 [exists $omit_of{$_} ? 1 : 0] 组成的数组进行映射。该布尔值表示当前元素是否存在于 %omit_of 哈希表中，如果存在则为 1，否则为 0。
                #布尔值是一种逻辑数据类型，它只有两个可能的取值：真（true）和假（false）。在 Perl 中，布尔值用关键字 1 表示真，用关键字 0 表示假。这种表示方式也被称为 "真值表达式"，因为在条件判断或逻辑运算中经常使用这些值。
                @sorted;

            # Representative strains
            @sorted =
                map  { $_->[0] }
                sort { $b->[1] <=> $a->[1] }#降序排列
                map { [$_, exists $rep_of{$_} ? 1 : 0 ] }
                @sorted;

            shift @sorted; # The first is NR#将数组 @sorted 的第一个元素移除并返回。这里第一个元素代表 "NR"
            printf qq(%s\n), $_ for @sorted;#将使用每个元素作为参数填充 %s，并在每个元素后添加一个换行符。
            ' \
        > "${SPECIES}/redundant.lst"

    cat "${SPECIES}/assembly.lst" |
        tsv-join --exclude -f "${SPECIES}/redundant.lst" \
        > "${SPECIES}/NR.lst"# 非冗余列表

done

log_info Done.

exit 0
