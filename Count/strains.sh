#!/usr/bin/env bash
#这是一个 Shebang 行，指定要使用的解释器。在这个脚本中，它指定使用 Bash 解释器。

#这一行将当前脚本的目录路径赋值给变量 BASH_DIR。
BASH_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
#${BASH_SOURCE[0]} 是一个 Bash 变量，经常用于获取脚本所在的目录或处理脚本的文件路径。
#basename 函数用于提取文件名，而 dirname 函数则返回不包含文件名的路径部分。

cd "${BASH_DIR}"#将工作目录切换到 $BASH_DIR 变量所存储的路径，即当前脚本所在的目录。

#----------------------------#
# Colors in term
#----------------------------#
GREEN=
RED=
NC=
if tty -s < /dev/fd/1 2> /dev/null; then 
#tty -s: tty 命令用于打印当前与终端设备关联的名称。-s：如果标准输入是一个终端，则返回 0，否则返回非零值。
#< /dev/fd/1: 这部分将标准输出作为输入进行重定向。/dev/fd/1 是指标准输出的文件描述符，而 < 表示将其作为输入流。
#2> /dev/null: 这部分将标准错误输出重定向到 /dev/null，即丢弃错误消息。
综合起来，这行代码的作用是检查标准输出是否连接到终端并产生可见的输出。即标准输入连接到一个终端设备，那么它将不会产生任何输出。相反，它输出或返回非零的退出状态码。在这种情况下，它将返回错误消息，指示标准输入未连接到终端。

    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color
fi

log_warn () {
    echo >&2 -e "${RED}==> $@ <==${NC}"#log_warn() 函数用于打印警告信息，前缀为红色。
}

log_info () {
    echo >&2 -e "${GREEN}==> $@${NC}"#log_info() 函数用于打印信息，前缀为绿色。
}

log_debug () {
    echo >&2 -e "==> $@"#log_debug() 函数用于打印调试信息，前缀没有颜色
}

export -f log_warn
export -f log_info
export -f log_debug

#----------------------------#
# helper functions
#----------------------------#
set +e#set 命令，用于更改 Bash 的行为选项；+e 选项表示禁用脚本的错误终止。也就是说，脚本将继续执行即使遇到错误。这个语句是将该选项设置为禁用（关闭）状态。

# set stacksize to unlimited
if [[ "$OSTYPE" != "darwin"* ]]; then #如果操作系统不是 macOS（即非 Darwin 类型），则会执行这个命令。Darwin 是MacOSX 操作环境的操作系统成份。
    ulimit -s unlimited #ulimit 命令，用于设置 shell 进程的资源限制。这里使用它来将栈的大小设为无限制。
fi

signaled () {# 这是一个自定义函数，用于在收到 TERM、QUIT 或 INT 信号时发出警告并退出脚本。
    log_warn Interrupted
    exit 1
}
trap signaled TERM QUIT INT#trap 命令，用于捕捉并处理信号。在这里，它捕捉 TERM、QUIT 和 INT 信号，并在收到信号时调用 signaled 函数进行处理。

readlinkf () {#一个自定义函数，用于获取给定文件的绝对路径。它使用 Perl 命令来实现，通过解析链接和返回文件的绝对路径。
    perl -MCwd -l -e 'print Cwd::abs_path shift' "$1";#-M 选项用于加载指定的模块（这里是 Cwd 模块）。调用 Cwd::abs_path 函数来获取给定路径的绝对路径；-l 选项用于启用自动换行模式，打印时会自动添加换行符。$1 是传递给命令的第一个参数（通常使用双引号引起来），即要获取绝对路径的路径。
}

export -f readlinkf #将 readlinkf 函数导出为环境变量，使得其他子进程或脚本能够调用这个函数。

#----------------------------#
# Run
#----------------------------#
log_warn strains.sh#用于记录一个警告消息，消息的内容是 "strains.sh"。

log_info "strains.taxon.tsv"#用于记录一个信息消息，消息的内容是 "strains.taxon.tsv"
cat species.tsv |
nwr append stdin -c 2 -r genus -r family -r order -r class \#nwr append，它将输入的每一行附加到之前已经处理过的内容之后，并将结果输出到 "strains.taxon.tsv" 文件
#-c 2：表示使用 species.tsv 第 2 列的值作为合并的键（即用于分组的列）。
#-r genus -r family -r order -r class：表示在后面添加 genus、family、order 和 class 列。所以strains.taxon.tsv一共有6列。
    > strains.taxon.tsv

log_info "taxa.tsv"
cat strains.taxon.tsv |
    tsv-summarize --unique-count 1-6 |# 对1-6列的唯一值进行计数 
    (echo -e "strain\tspecies\tgenus\tfamily\torder\tclass" && cat) |
    datamash transpose |# 转置数据的工具，将行转换为列，列转换为行。
    (echo -e "item\tcount" && cat) \
    > taxa.tsv
 # 统计各个菌株的数量以及所在的物种，属，科，目，纲的数量

log_info Done.#记录了一个信息消息，内容为 "Done."

exit 0#exit 0 命令显式地退出脚本，返回状态码 0，表示脚本执行成功。
