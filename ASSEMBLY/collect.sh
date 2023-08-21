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
log_warn collect.sh

touch check.lst

echo -e "#name\tOrganism_name\tTaxid\tAssembly_name\tInfraspecific_name\tBioSample\tBioProject\tSubmitter\tDate\tAssembly_type\tRelease_type\tAssembly_level\tGenome_representation\tWGS_project\tAssembly_method\tGenome_coverage\tSequencing_technology\tRefSeq_category\tRefSeq_assembly_accession\tGenBank_assembly_accession" \
    > collect.tsv

cat url.tsv |
    tsv-join -f check.lst -k 1 |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
        log_debug "{3}\t{1}"
        find "{3}/{1}" -type f -name "*_assembly_report.txt" |
            xargs cat |
            perl -nl -e '\'' #'\''：在单引号字符串中，为了表示一个单引号字符本身，需要使用两个连续的单引号来转义。因此，'\'' 表示一个单引号字符。
                BEGIN { our %stat = (); }

                m{^#\s+} or next;#\s+至少一个空白字符（包括空格和制表符）
                s/^#\s+//;
                @O = split /\:\s*/;#将字符串按照冒号和零个或多个空白字符的模式进行分割，将结果存储在 @O 数组中
                scalar @O == 2 or next;#检查 @O 数组的长度是否为 2。如果不是，说明分割后的结果不符合预期格式，跳过当前循环。
                $O[0] =~ s/\s*$//g;#移除字段名（$O[0]）末尾可能存在的空白字符。
                $O[0] =~ s/\W/_/g;#非单词字符（除了字母、数字和下划线之外的字符）替换为下划线
                $O[1] =~ /([\w =.-]+)/ or next;用正则表达式匹配字段值（$O[1]），并将匹配结果存储在变量 $1 中。如果匹配失败，说明字段值格式不符合预期，跳过当前循环。[\w =.-] 表示匹配一个单词字符（字母、数字、下划线）、空格、等号、点号或减号。
                $stat{$O[0]} = $1;#这行代码将字段名作为键，匹配结果作为值，存储到 %stat 哈希表中。

                END {
                    my @c;
                    #用 exists 函数检查 %stat 哈希中是否存在对应的键。如果存在，则将该键的值添加到 @c 数组中；如果不存在，则添加一个空字符串（q()）到 @c 数组中。
                    for my $key ( qw( Organism_name Taxid Assembly_name Infraspecific_name BioSample BioProject Submitter Date Assembly_type Release_type Assembly_level Genome_representation WGS_project Assembly_method Genome_coverage Sequencing_technology RefSeq_category RefSeq_assembly_accession GenBank_assembly_accession ) ) {
                       #`qw()` 是 `quote word` 的缩写，它将括号内的内容解析为一个由空白符分隔的字符串列表。每个字符串都被视为一个独立的单词，并且不需要使用引号或逗号进行分隔。
                        if (exists $stat{$key}) {
                            push @c, $stat{$key};
                        }
                        else {
                            push @c, q();#如果某个字段在 %stat 哈希表中不存在，将存入一个空字符串。
                        }
                    }
                    print join(qq(\t), q({1}), @c);
                }
            '\'' \
            >> collect.tsv
    '

log_info Done.

exit 0
