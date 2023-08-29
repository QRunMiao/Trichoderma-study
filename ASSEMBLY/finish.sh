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
log_warn finish.sh

log_info "Strains without protein annotations"#查看是否下载了蛋白序列信息或者CDS序列信息
cat url.tsv |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 4 '
        if ! compgen -G "{3}/{1}/*_protein.faa.gz" > /dev/null; then# {3} 表示引用第三列的值，{1} 表示引用第一列的值
        #!表示取反；正行代码意思是如果 compgen -G 返回的结果为空（没有找到匹配的文件），则条件为真，执行 then 块中的命令。
        #compgen 用于生成匹配指定模式的一组字符串。它常用于自动补全和文件名扩展等场景中。compgen 命令可以结合不同的选项来生成匹配模式的结果。-G 选项用于指定一个文件名匹配模式，并生成与该模式匹配的文件列表。在模式中，可以使用通配符（如 * 和 ?）和大括号扩展来表示多个可能的文件名。
        #/dev/null 是一个特殊的文件路径，代表空设备。在 Linux 和类 Unix 系统中，它被用作一个丢弃数据的目标.当将输出重定向到 /dev/null 时，任何写入该文件的数据都会被丢弃，并且不会在终端上打印出来。
        #将 compgen 命令的输出结果丢弃，而不打印到终端。这意味着如果没有找到匹配的文件，将没有任何内容输出到终端，保持终端的整洁。
            echo {1}
        fi
        if ! compgen -G "{3}/{1}/*_cds_from_genomic.fna.gz" > /dev/null; then
            echo {1}
        fi
    ' |
    tsv-uniq \
    > omit.lst

log_info "ASMs passes the N50 check"
cat collect.tsv |
    tsv-join \
        -H --key-fields 1 \#指定第一列为连接键，即将根据第一列的值进行连接操作
        --filter-file n50.pass.tsv \#tsv-join 命令的一个选项，用于指定要连接的文件为 n50.pass.tsv。具体来说，--filter-file 选项用于筛选连接操作的输入数据，只有当输入数据中的列与指定文件（n50.pass.tsv）中的列匹配时，才进行连接操作。
        --append-fields N50,C |#--append-fields 选项用于在连接操作的结果中添加额外的字段；即tsv-join 命令会将 N50 和 C 字段从输入数据中提取出来，并将其附加到连接操作的结果中
    tsv-join \
        -H --key-fields 1 \
        --filter-file <(
            cat omit.lst |
                sed 's/$/\tNo/' |#s/old/new/ 是sed的替换命令的语法，即在每行的末尾添加一个制表符和字母 "No" 
                (echo -e "name\tannotations" && cat)
        ) \
        --append-fields annotations --write-all "Yes" \#在omit.lst中查找不到菌株名称的注释为Yes
    > collect.pass.tsv

cat "collect.pass.tsv" |
    sed '1d' |
    tsv-select -f 1 \
    > pass.lst

log_info "Representative or reference strains"
cat collect.pass.tsv |
    tsv-filter -H --not-empty "RefSeq_category" |#category 类别
    tsv-select -f 1 |
    sed '1d' \
    > rep.lst

log_info "Counts of lines"
printf "#item\tfields\tlines\n" \#项目 字段 行
    > counts.tsv

for FILE in \#一个循环语句，用于遍历指定的文件列表
    url.tsv check.lst collect.tsv \
    n50.tsv n50.pass.tsv \
    collect.pass.tsv pass.lst \
    omit.lst rep.lst \
    ; do
    cat ${FILE} |
        datamash check |#对输入的 TSV 数据进行检查。这个命令会输出行数和字段数的统计信息。
        FILE=${FILE} perl -nl -MNumber::Format -e '#将当前文件的路径存储在 Perl 的环境变量 FILE 中；将当前文件的路径存储在 Perl 的环境变量 FILE 中，以便在 Perl 脚本中使用。
            m/(\d+)\s*lines?.+?(\d+)\s*fields?/ or next;
            # (\d+)：表示匹配一个或多个数字，并使用括号进行捕获。此部分用于捕获行数。
\s*lines?：表示匹配零个或多个空白字符，后跟可选的 "line" 或 "lines"。此部分用于匹配表示行数的文本。
.+?：表示匹配至少一个字符，并尽可能少地匹配。此部分用于匹配行数和字段数之间的任意相邻文本。
(\d+)：表示再次匹配一个或多个数字，并使用括号进行捕获。此部分用于捕获字段数。
\s*fields?：表示匹配零个或多个空白字符，后跟可选的 "field" 或 "fields"。此部分用于匹配表示字段数的文本。
            printf qq($ENV{FILE}\t%s\t%s\n),#$ENV{FILE} 会被当前文件名所替代；%s 是一个占位符，用于替换后面的参数
                Number::Format::format_number($2, 0,),#调用 Number::Format 模块中的 format_number 函数，将第二个参数（字段数）作为输入，并将其格式化为一个不带小数位的整数。
                Number::Format::format_number($1, 0,);
                #即最终输出格式为文件名\t字段数\t行数\n
            ' \
        >> counts.tsv
done

log_info Done.

exit 0
