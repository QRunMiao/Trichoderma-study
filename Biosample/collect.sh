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
# Usage
#----------------------------#
USAGE="
Usage: $0 [N_ATTR]

Default values:
    N_ATTR  larger than 50

$ bash collect.sh 100

"

if ! [ -z "$1" ]; then
    if ! [[ $1 =~ ^[0-9]+$ ]]; then
        echo >&2 "$USAGE"
        exit 1
    fi
fi

N_ATTR=${1:-50}

#----------------------------#
# Run
#----------------------------#
log_warn collect.sh

log_info attributes.lst
cat sample.tsv |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 4 '
        if [ -s "{3}/{1}.txt" ]; then
            cat "{3}/{1}.txt" |
                perl -nl -e '\''
                    print $1 if m(\s+\/([\w_ ]+)=);#\s+:表示匹配一个或多个空白字符（包括空格、制表符等）。
\/: 用于匹配正斜杠字符 "/ "。([\w_ ]+): 用于匹配一个或多个字母、数字、下划线或空格字符。
=: 用于匹配等号字符 "="。
#整体来看，这个正则表达式的目的是匹配形如 " /属性名= " 的字符串，并提取其中的属性名部分。注意，括号 ( ) 指定了一个捕获组，它用于从匹配的字符串中提取子字符串。
                '\''
        fi
    ' |
    tsv-uniq --at-least ${N_ATTR} | # ignore rare attributes#该命令的作用是过滤掉属性数量少于 ${N_ATTR} 的行，只保留属性数量达到或超过 ${N_ATTR} 的行。
    grep -v "^INSDC" |
    grep -v "^ENA" \
    > attributes.lst

log_info biosample.tsv

# Headers
cat attributes.lst |
    (echo -e "#name\nBioSample" && cat) |
    tr '\n' '\t' |
    sed 's/\t$/\n/' \
    > biosample.tsv

cat sample.tsv |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
        log_debug "{1}"

        cat "{3}/{1}.txt"  |
            perl -nl -MPath::Tiny -e '\''
                BEGIN {
                    our @keys = grep {/\S/} path(q{attributes.lst})->lines({chomp => 1});#\S-非空格,和 [^\n\t\r\f] 语法一样
                    our %stat = ();
                }

                m(\s+\/([\w_ ]+)=\"(.+)\") or next;
                my $k = $1;
                my $v = $2;
                if ( $v =~ m(\bNA|missing|Not applicable|not collected|not available|not provided|N\/A|not known|unknown\b)i ) {
                    $stat{$k} = q();
                } else {
                    $stat{$k} = $v;
                }

                END {
                    my @c;
                    for my $key ( @keys ) {
                        if (exists $stat{$key}) {
                            push @c, $stat{$key};
                        }
                        else {
                            push @c, q();
                        }
                    }
                    print join(qq(\t), q({2}), q({1}), @c);
                }
            '\''
    ' \
    >> biosample.tsv

log_info Done.

exit 0
