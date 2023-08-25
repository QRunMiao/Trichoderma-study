# NAME

App::Egaz - **E**asy **G**enome **A**ligner

# SYNOPSIS

    egaz <command> [-?h] [long options...]
            --help (or -h)  show help
                            aka -?

    Available commands:

          commands: list the application's commands
              help: display a command's help screen

         blastlink: link sequences by blastn #通过blastn将序列进行链接
        blastmatch: matched positions by blastn in genome sequences #在基因组序列中使用blastn查找匹配位置
            blastn: blastn wrapper between two fasta files #对两个fasta文件执行blastn分析
        exactmatch: exact matched positions in genome sequences #在基因组序列中查找完全匹配的位置
           fas2vcf: list variations in blocked fasta file #在fasta文件中列出变异
           formats: formats of files use in this project #显示该项目中使用的文件格式
             lastz: lastz wrapper for two genomes or self alignments #用于两个基因组或自我比对的lastz封装程序
           lav2axt: convert .lav files to .axt #将.lav文件转换为.axt文件
           lav2psl: convert .lav files to .psl #将.lav文件转换为.psl文件
            lpcnam: the pipeline of pairwise lav-psl-chain-net-axt-maf #基于pairwise的lav-psl-chain-net-axt-maf流程的流水线
         maskfasta: soft/hard-masking sequences in a fasta file #对fasta文件中的序列进行软/硬屏蔽
            multiz: multiz step by step #分步进行multiz操作
         normalize: normalize lav files #规范化lav文件
         partition: partitions fasta files by size #按大小对fasta文件进行分区
           prepseq: preparing steps for lastz #为lastz做准备工作的步骤
             raxml: raxml wrapper to construct phylogenetic trees #构建系统发育树的raxml封装程序
      repeatmasker: RepeatMasker wrapper #RepeatMasker封装程序
          template: create executing bash files #创建执行bash文件

# 补充
- `blastn`：`blastn` 是一种在两个 DNA 序列之间进行核酸序列比对的标准工具。它使用 BLAST 算法来发现序列之间的相似性，并生成比对结果。
 
- `raxml`：`raxml` 是一个用于构建系统发育树的程序。它可以基于输入的 DNA 或蛋白质序列数据，使用不同的进化模型和方法来推断物种之间的亲缘关系，并生成相应的系统发育树。

- `lastz`：`lastz` 是一个用于比对 DNA 序列的工具。它可以在两个基因组序列之间进行全局或局部比对，找到相似或匹配的区域，并生成比对结果文件，如 `.lav` 或 `.axt` 格式。

- `psl` 文件：`.psl` 文件是一个常见的比对结果文件格式，通常用于存储 BLAST、BLAT 和 LASTZ 等程序的比对结果。它记录了查询序列与目标序列之间的匹配、错配和缺失等信息，以及相应的比对得分和片段坐标等。

- `multiz`：`multiz` 是一种用于多序列比对的工具。它可以将多个相关的基因组序列进行比对，并根据相似性和保守区域进行多序列比对和分析。

- `lav-psl-chain-net-axt-maf`：这是一个流程或流水线，用于将 `.lav` 文件转换为 `.psl`、`.chain`、`.net`、`.axt` 和 `.maf` 等格式，以便进行后续的分析和测序数据处理。

Run `egaz help command-name` for usage information.

# DESCRIPTION

App::Egaz stands for **E**asy **G**enome **A**ligner.

**Caution**: `egaz lpcnam` implements UCSC's chain-net pipeline, but some parts,
e.g. `axtChain`, don't work correctly under macOS. Use `egaz lastz`'s build in
chaining mechanism (`C=2`) instead.

# INSTALLATION

    cpanm --installdeps https://github.com/wang-q/App-Egaz/archive/0.2.5.tar.gz #下载并安装依赖项
    curl -fsSL https://raw.githubusercontent.com/wang-q/App-Egaz/master/share/check_dep.sh | bash #获取 check_dep.sh 脚本文件，并将其内容传递给 bash 执行
    cpanm -nq https://github.com/wang-q/App-Egaz/archive/0.2.5.tar.gz #安装 "App-Egaz" 库
    # cpanm -nq https://github.com/wang-q/App-Egaz.git #也可以尝试以下命令进行安装

# 解释：

- `cpanm`：`cpanm` 是 Perl 的 CPAN（Comprehensive Perl Archive Network）客户端工具，用于管理和安装 Perl 模块。它可以从 CPAN 或其他源安装模块，并处理依赖关系。

- `curl`：`curl` 是一个支持多种网络协议的命令行工具，用于在终端中进行 URL 相关操作。它可以用于下载文件、发送 HTTP 请求等。这里，curl 用于从指定的 URL 获取脚本，并将其直接传递给 shell 执行。

- `-fsSL`：这是 `curl` 命令的一组选项。
  - `-f` 表示 "fail"，如果请求失败，则返回非零退出代码。
  - `-s` 表示 "silent"，不输出进度或错误信息。
  - `-S` 表示 "show-error"，即使 `-s` 选项开启，也显示错误信息。
  - `-L` 表示 "location"，请求时跟随重定向。

- `-nq`：这是 `cpanm` 命令的一组选项。
  - `-n` 表示 "notest"，跳过运行测试阶段。
  - `-q` 表示 "quiet"，减少输出的详细程度。

# CONTAINER

`egaz` has tons of dependencies, so the simplest way to use it is using a container system.

#egaz有很多依赖项，所以使用它最简单的方法就是使用container系统。

#容器系统是一种虚拟化技术，用于隔离应用程序及其相关依赖项，并以轻量级的方式在主机操作系统上运行。它允许应用程序在一个独立的运行环境中执行，而无需影响主机系统或其他容器。

`Singularity` 3.x is the preferred one.

    # Pull and build the image #令使用 Singularity 将名为 "wangq/egaz:master" 的 Docker 镜像拉取到本地系统中。

    singularity pull docker://wangq/egaz:master

    #singularity pull：这是 Singularity 命令，用于拉取镜像并创建 Singularity 容器。
    #docker://wangq/egaz:master：这是一个指定 Docker 镜像的 URL。在这里，你正在使用 docker:// 前缀指示 Singularity 拉取 Docker 镜像，并通过 wangq/egaz:master 指定了镜像名称和标签。

    # Run a single command #使用 Singularity 运行名为 "egaz_master.sif" 的 Singularity 镜像，并在镜像中执行 "egaz help" 命令。
    singularity run egaz_master.sif egaz help

    #singularity run：这是 Singularity 命令，用于在 Singularity 镜像中运行应用程序。
    #egaz_master.sif：这是 Singularity 镜像文件的名称，指定了要运行的镜像。
    #egaz help：这是要在镜像中执行的命令。具体来说，它是在 egaz 应用程序中执行 "help" 命令，以获取相关的帮助信息。

    # Interactive shell #提供了两种不同的方式来与 egaz_master.sif Singularity 镜像进行交互
    # Note:
    #   * .sif is immutable
    #   * $HOME, /tmp, and $PWD are automatically loaded
    #   * All actions affect the host paths
    #   * Singularity Desktop for macOS isn't Fully functional.
    #       * https://github.com/hpcng/singularity/issues/5215
    singularity shell egaz_master.sif

    #1.使用 Singularity 提供的交互式 shell：
    通过这个命令，Singularity 将创建一个交互式的 shell 环境，以便在容器内部直接与镜像进行交互。在交互式 shell 中，你可以执行各种命令和操作，浏览容器中的文件系统等。需要注意的是，.sif 镜像是不可变的，任何在容器内对镜像的修改都不会影响原始镜像文件。

    # With Docker
    docker run -it --rm -v "$(pwd)"/egaz:/egaz wangq/egaz:master
    
    #2.使用 Docker 运行容器：使用 Docker 来运行 wangq/egaz:master 的 Docker 镜像，并将本地的 ./egaz 目录挂载到容器的 /egaz 目录。通过这种方式，你可以与容器进行交互，并在容器内部执行操作。在这个例子中，-it 参数表示交互式终端，--rm 参数表示容器退出后自动删除，-v 参数用于挂载本地目录到容器内部。

    第二个命令是使用 Docker 运行容器，与 Singularity 相比，它可能具有不同的行为和限制。

# 补充：
```
1.Singularity 是一个用于创建和管理容器的开源工具，旨在提供高度可移植性和复现性，并与底层主机系统集成。

Singularity 支持以用户模式（user mode）运行容器。这意味着容器内的进程可以直接访问底层主机系统的资源，如文件系统、网络和设备，而无需特权或虚拟化支持。这种设计使得 Singularity 容器更适合于在多个主机之间共享和迁移工作负载。

Singularity 的另一个重要特性是它支持使用基于镜像定义的方式来构建容器。你可以从现有的 Docker 镜像、Singularity 镜像或其他格式的镜像来创建 Singularity 容器。这种灵活性使得容器的创建和使用变得更加简单和方便。


2.Docker 镜像
是一种可执行软件包，其中包含了运行应用程序所需的所有文件、依赖项和配置信息。它是 Docker 容器的基础模板，用于创建和运行容器化的应用程序。

Docker 镜像采用分层存储的方式进行构建和管理。每一层都包含了一组文件系统的更改或增量，并且可以被复用、共享和重新组合，以构建不同的应用镜像。这种分层机制使得镜像的构建和分发更加高效，并节省存储空间。

#Docker 镜像通常通过以下两种方式获取：

从 Docker Hub 或其他容器镜像仓库下载：Docker Hub 是一个公共的容器镜像仓库，你可以在其中找到各种各样的预构建镜像。你可以使用 docker pull 命令从 Docker Hub 下载一个镜像，并在本地系统上使用该镜像来创建和运行容器。

通过 Dockerfile 构建：Dockerfile 是一个文本文件，其中包含了一系列指令和配置，用于构建自定义的 Docker 镜像。你可以编写一个 Dockerfile 文件来描述应用程序的构建过程和所需的环境设置，然后使用 docker build 命令根据 Dockerfile 来构建镜像。

Docker 镜像具有以下优点：

可移植性：Docker 镜像可以在不同的主机上运行，无需担心环境差异和依赖问题。
环境复现性：Docker 镜像包含了应用程序及其依赖项的所有信息，可以实现环境的快速复制和重现。
轻量级：Docker 镜像采用分层存储机制，只需存储差异部分，使得镜像更轻量、启动更快，并节省存储空间。
可扩展性和可伸缩性：Docker 镜像可以通过容器的水平和垂直扩展来满足不同负载需求。

3..sif 文件是由 Singularity 容器系统使用的一种镜像文件格式。

与 Docker 使用的 .tar 文件格式不同，Singularity 使用的 .sif 文件格式是一种可执行的只读文件，它直接包含了容器的完整文件系统、应用程序和依赖项等。.sif 文件可以被视为单个文件，通过该文件可以快速、轻松地传递和部署 Singularity 容器。

.sif 文件的优点包括：

可执行性：.sif 文件是可执行的，意味着你可以直接运行它，就像运行任何其他可执行文件一样。这使得 .sif 文件在共享和沙箱化环境中特别有用。

只读性：由于 .sif 文件是只读的，它们是不可变的和可靠的。这意味着容器内部的内容是固定的，不会被修改或污染。

安全性：.sif 文件的只读属性也有助于提高安全性，因为它确保容器的内容在不同环境中保持一致，并防止恶意软件的篡改。

要使用 .sif 文件，你需要安装和配置 Singularity 容器系统。一旦安装好 Singularity，你可以使用 singularity run、singularity exec 或 singularity shell 等命令来运行、执行或与 .sif 文件中的容器进行交互。
```
