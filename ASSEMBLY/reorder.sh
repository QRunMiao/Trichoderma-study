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
log_warn reorder.sh

log_info "Put the misplaced directory in the right place"

#原代码：
find . -maxdepth 3 -mindepth 2 -type f -name "*_genomic.fna.gz" |
    grep -v "_from_" |
    parallel --no-run-if-empty --linebuffer -k -j 1 '
        echo {//}
    ' |
    tr "/" "\t" |
    perl -nla -F"\t" -MPath::Tiny -e '
        BEGIN {
            our %species_of = map {(split)[0, 2]}
                grep {/\S/}
                path(q{url.tsv})->lines({chomp => 1});
        }

        # Should like ".       Saccharomyces_cerevisiae        Sa_cer_S288C"
        @F != 3 and print and next;

        # Assembly is not in the list
        if (! exists $species_of{$F[2]} ) {
            print;
            next;
        }

        # species is the correct one
        if ($species_of{$F[2]} ne $F[1]) {
            print;
            next;
        }
    ' |
    perl -nla -F"\t" -e '
        m((GC[FA]_\d+_\d+$)) or next;
        my $acc = $1;
        my $dir = join q(/), @F;
        print join qq(\t), $dir, $acc;
    ' \
    > misplaced.tsv

#代码详解：
    #读取名为 "url.tsv" 的文件，将内容按空格分割并存入 %species_of 哈希表。
    perl -nla -F"\t" -MPath::Tiny -e '
        BEGIN {
            our %species_of = map {(split)[0, 2]}#our 关键字声明一个全局变量 %species_of，用于存储处理后的数据。
                grep {/\S/}#对读取到的每一行进行过滤，只保留非空行（即包含非空白字符的行）。
                path(q{url.tsv})->lines({chomp => 1});#q{} 是一种引号操作符，用于创建一个单引号字符串。它与单引号 ' ' 的作用类似，都表示创建一个字面量的字符串，不进行变量替换和转义字符处理。
                #-> 是用于对象方法调用的操作符;lines 方法是 Path::Tiny 模块提供的一个用于按行读取文件内容的方法。选项 {chomp => 1} 指定在读取每一行时去除末尾的换行符。
                #->lines({chomp => 1}) 的作用是读取文件的内容，并将每一行作为一个字符串元素存入一个数组中，同时去除每行末尾的换行符。
        }

        # Should like ".       Saccharomyces_cerevisiae        Sa_cer_S288C"
        @F != 3 and print and next;#查输出结果是否符合预期的格式（包含三列），如果不符合，则直接打印并跳过后续操作

        # Assembly is not in the list#检查第二列对应的物种是否在 %species_of 哈希表中，如果不存在，则直接打印并跳过后续操作。
        if (! exists $species_of{$F[2]} ) {
            print;
            next;
        }

        # species is the correct one#检查第二列对应的物种是否与 %species_of 哈希表中对应的值相等，如果不相等，则直接打印并跳过后续操作。
        if ($species_of{$F[2]} ne $F[1]) {
            print;
            next;
        }
    ' |
    perl -nla -F"\t" -e '
        m((GC[FA]_\d+_\d+$)) or next;#使用正则表达式匹配处理的数据行。如果匹配失败，则跳过当前行（next），继续处理下一行。
        #m-匹配；GC[FA]：表示以 "GC" 后跟一个 "F" 或 "A" 的字符开头。方括号 [ ] 用于表示字符集。方括号内可以包含多个字符或字符范围，用来匹配一个字符的任意一个位置。
        #_\d+：表示下划线后跟一个或多个数字;_：表示下划线;$：表示匹配到字符串的结尾

        my $acc = $1;#将匹配结果中的第一个捕获组（括号内的内容）保存在变量 $acc 中
        my $dir = join q(/), @F;#将特殊数组 @F 中的字段使用斜杠 / 连接起来，存储在变量 $dir 中
        print join qq(\t), $dir, $acc;#将 $dir、$acc 以制表符作为分隔符连接起来，并打印输出。
    ' \
    > misplaced.tsv

cat misplaced.tsv |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
        SPECIES=$(
            tsv-filter url.tsv --str-in-fld "1:{2}" |#--string-in-field；1:{2} 表示要匹配的字段为第一列的第二行。换句话说，它将会查找在 url.tsv 文件的第一列中出现的字段，并输出满足条件的所有行。
                tsv-select -f 3
            )
        NAME=$(
            tsv-filter url.tsv --str-in-fld "1:{2}" |
                tsv-select -f 1
            )
        if [ ! -z "${NAME}" ]; then#如果 NAME 变量不为空（即非空字符串）则执行下面的操作
            if [ -e "${SPECIES}/${NAME}" ]; then#指定路径 ${SPECIES}/${NAME} 存在，则输出错误信息。
                echo >&2 "${SPECIES}/${NAME} exists"
            else
                echo >&2 "Moving {1} to ${SPECIES}/${NAME}"
                mkdir -p "${SPECIES}"
                mv {1} "${SPECIES}/${NAME}"#将当前行指定的文件 {1} 移动到 ${SPECIES}/${NAME} 目录下
            fi
        fi
    '


log_info "Temporary files, possibly caused by an interrupted rsync process"
find . -type f -name ".*" |
    grep -v "DS_Store" \
    > remove.lst

log_info "List dirs (species/assembly) not in the list"
cat url.tsv |
    tsv-select -f 3 |
    tsv-uniq |
while read SPECIES; do
    find "./${SPECIES}" -maxdepth 1 -mindepth 1 -type d |#在当前目录下的 ${SPECIES} 目录中搜索所有的子目录，但不包括子目录的子目录。-d：目录
        tr "/" "\t" |
        tsv-select -f 3 |
        tsv-join --exclude -k 1 -f url.tsv -d 1 |#--exclude：表示排除不匹配的行，即只输出匹配的行。d 用于指定字段的分隔符；-d 参数后面的数字表示字段的索引。这个数字表示要使用的字段在每行数据中的位置。
        xargs -I[] echo "./${SPECIES}/[]"#将标准输入中的每一行作为参数，通过 echo 命令输出 ${SPECIES} 目录下的对应文件路径。
done \
    >> remove.lst

log_info "List dirs (species) not in the list"
find . -maxdepth 1 -mindepth 1 -type d |
    tr "/" "\t" |
    tsv-select -f 2 |
    tsv-join --exclude -k 3 -f url.tsv -d 1 |
    xargs -I[] echo "./[]" \
    >> remove.lst

if [ -s remove.lst ]; then#-s 选项用于判断文件是否非空。
    log_info "remove.lst is not empty."
fi

log_info Done.

exit 0
