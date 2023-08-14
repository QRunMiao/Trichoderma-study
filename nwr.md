详细信息参见[此页面](https://github.com/wang-q/nwr) 
# nwr

`nwr` is a command line tool for working with NCBI taxonomy, assembly reports and Newick files, written in Rust.
nwr是一个命令行工具，用于处理NCBI分类法、汇编报告和Newick文件，用Rust编写。

## Install

Current release: 0.6.2

```shell
cargo install nwr

#Cargo是Rust编程语言的官方构建系统和包管理器。这个命令将会从 Rust 的 crates.io 包索引中查找并安装名为 nwr 的软件包。
# or
brew install wang-q/tap/nwr

# local repo 在当前目录中安装 Rust 项目，并在离线模式下强制重新安装已经存在的软件包
cargo install --path . --force --offline

#. 表示当前目录；--force 强制安装，该选项将会覆盖旧版本并安装新版本；--offline 在离线模式下执行操作，对于在没有网络连接的环境下进行安装和构建操作很有用。

# build under WSL 2
export CARGO_TARGET_DIR=/tmp #通过设置 CARGO_TARGET_DIR 环境变量来指定构建目标的临时目录/tmp
cargo build #构建项目;构建完成后，生成的输出文件将保存在 /tmp 目录中

```

## `nwr help`

```text
`nwr` is a command line tool for working with NCBI taxonomy, assembly reports and Newick files

Usage: nwr [COMMAND]

Commands:
  append    Append fields of higher ranks to a TSV file #附加更高级别的字段到TSV文件
  ardb      Init the assembly database#初始化程序集数据库
  comment   Add comments to node(s) in a Newick file#向Newick文件中的节点添加注释
  download  Download the latest releases of `taxdump` and assembly reports#下载最新版本的“taxdump”和汇编报告
  indent    Indent the Newick file#缩进Newick文件
  info      Information of Taxonomy ID(s) or scientific name(s)#分类号或学名信息
  kb        Prints docs (knowledge bases)#打印文档
  lineage   Output the lineage of the term#输出术语的沿袭
  member    List members (of certain ranks) under ancestral term(s)
  order     Order nodes in a Newick file#Newick文件中节点的排序
  restrict  Restrict taxonomy terms to ancestral descendants#将分类学术语限制为祖先的后代
  template  Create dirs, data and scripts for a phylogenomic research#为系统基因组研究创建目录、数据和脚本
  txdb      Init the taxonomy database#初始化分类法数据库
  help      Print this message or the help of the given subcommand(s)#打印此消息或给定子命令的帮助

Options:
  -h, --help     Print help
  -V, --version  Print version

#Taxdump 是一个用于生物分类学的数据库，提供了关于生物分类和命名的信息。它是NCBI（美国国家生物技术信息中心）提供的一个公共数据库。包括了各种不同组织生物的名称、描述、层级关系等信息
```

## EXAMPLES

### Usage of each command


- 准备工作

在使用nwr时，首先使用 nwr download 命令来获得NCBI上的相关信息，再使用nwr txdb。
```shell
nwr download

nwr txdb

nwr info "Homo sapiens" 4932# 提取ID是4932的物种的信息

nwr lineage "Homo sapiens"#"Homo sapiens" 作为参数来获取人类的谱系信息
nwr lineage 4932# 提取ID是4932的物种的系统发育树上各term的信息

nwr restrict "Vertebrata" -c 2 -f tests/nwr/taxon.tsv
#筛选tsv文件中包含限定term"Vertebrata"的物种信息
# -c, --column <column> ID所在的列，从1开始[默认：1] 。

##sci_name       tax_id
#Human   9606

nwr member "Homo"

# 给已有的tsv文件增加描述分类信息
nwr append tests/nwr/taxon.tsv -c 2 -r species -r family --id

append: 表示将信息追加到文件中。
tests/nwr/taxon.tsv: 指定要追加信息的目标文件路径
-c 2: 指定列索引为 2 的列进行操作。
-r species: 在指定的列上提取物种信息。-r 表示 "retrieve" 或 "extract" 的缩写。它用于指定要从数据中检索或提取的特定字段或属性。
-r family: 在指定的列上提取科属信息。
--id: 在输出中包含物种的唯一标识符。

nwr ardb
nwr ardb --genbank

```

### Development

```shell
#针对 Rust 项目进行测试和运行的
# Concurrent tests may trigger sqlite locking
并发测试可能触发sqlite锁定

#针对 nwr 包中的名为 cli_nwr 的测试模块中的 command_template 测试
cargo test -- --test-threads=1#-- --test-threads=1 是传递给测试代码的参数，它指定只使用一个线程来运行测试，这样可以避免并发测试时可能触发的 SQLite 锁定问题。

cargo test --color=always --package nwr --test cli_nwr command_template -- --show-output#--color=always 在测试中启用彩色输出，--package nwr 指定只对 nwr 包中的测试进行操作，--show-output 则打印出测试运行的详细输出

