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
log_warn Protein/collect.sh

#----------------------------#
# all.pro.fa
#----------------------------#
log_info "Protein/all.pro.fa.gz"
cat species.tsv |
tsv-join -f ../ASSEMBLY/pass.lst -k 1 |
tsv-join -e -f ../MinHash/abnormal.lst -k 1 |
tsv-join -e -f ../ASSEMBLY/omit.lst -k 1 |
parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
        if [[ ! -d "../ASSEMBLY/{2}/{1}" ]]; then
            exit
        fi

        gzip -dcf ../ASSEMBLY/{2}/{1}/*_protein.faa.gz
    ' |
     pigz -p4 \  #使用 4 个线程进行并行压缩
     > all.pro.fa.gz

log_info "Protein/all.uniq.fa.gz" #提取唯一的蛋白质序列
gzip -dcf all.pro.fa.gz |
    perl -nl -e '
        BEGIN { our %seen; our $h; }

        if (/^>/) {
            $h = (split(" ", $_))[0];   #将当前行 $_ 按空格拆分成数组，并取数组中的第一个元素；[0] 表示数组索引，用于获取数组中的第一个元素。
            $seen{$h}++;
            $_ = $h;
        }
        print if $seen{$h} == 1;
    ' |
    pigz -p4 \
    > all.uniq.fa.gz

#----------------------------#
# all.replace.fa
#----------------------------#
log_info "Protein/all.replace.fa.gz" 
rm -f all.strain.tsv all.replace.fa.gz

cat species.tsv |
tsv-join -f ../ASSEMBLY/pass.lst -k 1 |
tsv-join -e -f ../MinHash/abnormal.lst -k 1 |
tsv-join -e -f ../ASSEMBLY/omit.lst -k 1 |
parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
        if [[ ! -d "../ASSEMBLY/{2}/{1}" ]]; then
            exit
        fi

        gzip -dcf ../ASSEMBLY/{2}/{1}/*_protein.faa.gz |
            grep "^>" |
            cut -d" " -f 1 |
            sed "s/^>//" |
            perl -nl -e '\''
                $n = $_;
                $s = $n;
                $s =~ s/\.\d+//;
                printf qq(%s\t%s_%s\t%s\n), $n, {1}, $s, {1};
            '\'' \
            > {1}.replace.tsv

        cut -f 2,3 {1}.replace.tsv >> all.strain.tsv

        faops replace -s \ #replace能够实现对特定序列名的替换；-s 代表 "sequence" 或者 "字符串"。该选项用于指定要替换的源字符串或者序列。
            ../ASSEMBLY/{2}/{1}/*_protein.faa.gz \
            <(cut -f 1,2 {1}.replace.tsv) \
            stdout |
            pigz -p4 \
            >> all.replace.fa.gz

        rm {1}.replace.tsv
    '

log_info "Protein/all.size.tsv"
(echo -e "#name\tstrain" && cat all.strain.tsv)  \
    > temp &&
    mv temp all.strain.tsv

faops size all.replace.fa.gz > all.replace.sizes

(echo -e "#name\tsize" && cat all.replace.sizes) > all.size.tsv

rm all.replace.sizes

#----------------------------#
# `all.info.tsv`
#----------------------------#
log_info "Protein/all.annotation.tsv"
cat species.tsv |
tsv-join -f ../ASSEMBLY/pass.lst -k 1 |
tsv-join -e -f ../MinHash/abnormal.lst -k 1 |
tsv-join -e -f ../ASSEMBLY/omit.lst -k 1 |
parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 4 '
        if [[ ! -d "../ASSEMBLY/{2}/{1}" ]]; then
            exit
        fi

        gzip -dcf ../ASSEMBLY/{2}/{1}/*_protein.faa.gz |
            grep "^>" |
            sed "s/^>//" |
            perl -nl -e '\'' /\[.+\[/ and s/\[/\(/; print; '\'' | #如果一行包含 . 和 [ 字符，则将 [ 替换为 (，然后打印出来。
            perl -nl -e '\'' /\].+\]/ and s/\]/\)/; print; '\'' |
            perl -nl -e '\'' s/\s+\[.+?\]$//g; print; '\'' | #在每一行中删除最后一个空格后的内容（以及方括号和其中的内容）
            sed "s/MULTISPECIES: //g" | #删除行中的 MULTISPECIES: 字符串
            perl -nl -e '\''
                /^(\w+)\.\d+\s+(.+)$/ or next;
                printf qq(%s_%s\t%s\n), {1}, $1, $2;
            '\''
    ' \
    > all.annotation.tsv

(echo -e "#name\tannotation" && cat all.annotation.tsv) \
    > temp &&
    mv temp all.annotation.tsv

log_info "Protein/all.info.tsv"
tsv-join \
    all.strain.tsv \ #第一个输入文件
    --data-fields 1 \ #第一个输入文件中用于连接的字段，这里是字段 1
    -f all.size.tsv \ #第二个输入文件
    --key-fields 1 \ #第二个输入文件中用于连接的字段，这里也是字段 1
    --append-fields 2 \ #在连接结果中添加的字段，这里是第二个输入文件的字段 2
    > all.strain_size.tsv

tsv-join \
    all.strain_size.tsv \
    --data-fields 1 \
    -f all.annotation.tsv \
    --key-fields 1 \
    --append-fields 2 \
    > all.info.tsv


#----------------------------#
# Counts
#----------------------------#
log_info "Counts"

printf "#item\tcount\n" \
    > counts.tsv

gzip -dcf all.pro.fa.gz |
    grep "^>" |
    wc -l |
    perl -nl -MNumber::Format -e ' # Number::Format——用于格式化数字的显示方式
        printf qq(Proteins\t%s\n), Number::Format::format_number($_, 0,);
        ' \
    >> counts.tsv

gzip -dcf all.pro.fa.gz |
    grep "^>" |
    tsv-uniq |
    wc -l |
    perl -nl -MNumber::Format -e '
        printf qq(Unique headers and annotations\t%s\n), Number::Format::format_number($_, 0,);
        ' \
    >> counts.tsv

gzip -dcf all.uniq.fa.gz |
    grep "^>" |
    wc -l |
    perl -nl -MNumber::Format -e '
        printf qq(Unique proteins\t%s\n), Number::Format::format_number($_, 0,);
        ' \
    >> counts.tsv

gzip -dcf all.replace.fa.gz |
    grep "^>" |
    wc -l |
    perl -nl -MNumber::Format -e '
        printf qq(all.replace.fa\t%s\n), Number::Format::format_number($_, 0,);
        ' \
    >> counts.tsv

cat all.annotation.tsv |
    wc -l |
    perl -nl -MNumber::Format -e '
        printf qq(all.annotation.tsv\t%s\n), Number::Format::format_number($_, 0,);
        ' \
    >> counts.tsv

cat all.info.tsv |
    wc -l |
    perl -nl -MNumber::Format -e '
        printf qq(all.info.tsv\t%s\n), Number::Format::format_number($_, 0,);
        ' \
    >> counts.tsv

log_info Done.

exit 0
