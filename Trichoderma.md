# 安装mwr
```shell
brew install wang-q/tap/nwr
brew install sqlite 
# SQLite 是一种嵌入式关系型数据库管理系统（RDBMS），它是一个轻量级的、零配置的数据库引擎

检查nwr是否安装成功
nwr -h

启动本地数据库
nwr download
nwr txdb

nwr ardb
nwr ardb --genbank

#在后续使用中，nwr版本较低，所以重新进行了安装

cd 
cd app
git clone https://github.com/wang-q/nwr.git
nwr build

配置环境变量
vim ~/.bashrc#.bashrc 文件是 Bash Shell 的启动文件，其中包含了一些设置和配置。

# nwr
export PATH="~/app/nwr6.0/target/debug:$PATH"

#保存并关闭 ~/.bashrc 文件后，运行命令 source ~/.bashrc 将使更新的环境变量立即生效，无需重新登录
source ~/.bashrc
```
# Build alignments across a eukaryotic taxonomy rank 在真核生物分类学等级中建立一致性

以木霉属为例。
Genus *Trichoderma* as an example.

# 查看木霉属的分类上的基本情况
## Strain info 菌株信息

* [Trichoderma](https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=5543)
* [Entrez records](http://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?mode=Info&id=5543)
* [WGS](https://www.ncbi.nlm.nih.gov/Traces/wgs/?view=wgs&search=Trichoderma) is now useless and can
  be ignored.

A nice review article about Trichoderma:

Woo, S.L. et al.
Trichoderma: a multipurpose, plant-beneficial microorganism for eco-sustainable agriculture.
Nat Rev Microbiol 21, 312–326 (2023).
https://doi.org/10.1038/s41579-022-00819-5

### List all ranks 列出所有等级

There are no noteworthy classification ranks other than species.除了物种之外，没有值得注意的分类等级

```shell
nwr member Trichoderma |
    grep -v " sp." |
    tsv-summarize -H -g rank --count |
    mlr --itsv --omd cat |
    perl -nl -e 's/-\s*\|$/-:|/; print'
```

#逐行解释代码：
这个命令是一个由多个命令组成的管道（pipeline），用于处理以 `nwr member Trichoderma` 作为输入的数据。

下面是对每个命令的解释：

1. `nwr member Trichoderma`:  用于从数据源中检索与 Trichoderma 相关的成员信息

2. `grep -v " sp."`: 用 `-v` 参数来反向匹配，过滤掉包含 " sp." 的行，即过滤掉物种名称中包含 " sp." 的行。

3. `tsv-summarize` 工具进行数据汇总。`-H` 参数表示输出带有标题行，`-g rank` 表示按照 "rank" 列进行分组，`--count` 表示统计每个分组中的行数。

4. `mlr --itsv --omd cat`: mlr（Miller）工具，它是一个强大的命令行数据处理工具，用于处理和转换文本数据。输入格式为无标题 TSV (--itsv)，输出格式为 Markdown (--omd)；cat 是 mlr 提供的一个操作，它只是输出输入数据而不进行任何修改或处理

5. `perl -nl -e 's/-\s*\|$/-:|/; print'`:-nl: 在处理输入时自动读取每一行，并在输出时自动添加换行符。-n 表示自动读取输入，-l 自动处理换行符。它在打印输出时自动添加一个换行符，同时在读取输入时自动删除行尾的换行符。

`s/-\s*\|$/-:|/：`匹配以连字符 "-" 开头，后跟零个或多个空白符 \s*，最后以竖线 "|" 结尾的字符串，并将其替换为 "-:|"。具体字符含义如下
- `s/` 开始替换操作。
- `-` 匹配连字符 "-"。
- `\s*` 匹配零个或多个空白字符。
- `\|` 匹配竖线 "|"，由于竖线在正则表达式中是特殊字符，因此使用了转义符 `\` 进行转义。
- `$` 匹配行末尾。
- `-:` 替换匹配到的内容为 "-:"。
- `|` 管道符，用于分隔替换操作和后面的部分。
- `/` 结束替换操作。
```
输出：
| rank     | count |
|----------|------:|
| genus  属  |     1 |
| species 种  |   455 |
| no rank  |     1 |
| varietas变种 |     2 |
| strain   |    14 |
| forma  型  |     2 |
```

```
nwr lineage Trichoderma |
    tsv-filter --str-ne 1:clade |
    tsv-filter --str-ne "1:no rank" |
    sed -n '/kingdom\tFungi/,$p' |
    sed -E "s/\b(genus)\b/*\1*/"| # Highlight genus
    (echo -e '#rank\tsci_name\ttax_id' && cat) |
    mlr --itsv --omd cat
```
#逐行解释代码：
1. `nwr lineage Trichoderma`：获取关于 Trichoderma 属的分类信息

2. `tsv-filter --str-ne 1:clade`：过滤输入数据。`--str-ne` :--str-ne <field>:<value>：仅保留字段 <field> 的值不等于 <value> 的行(按字符串比较)
这里是指第一列的值不等于 "clade"，意味着只保留第一列不等于 "clade" 的行。

3. `tsv-filter --str-ne "1:no rank"`：过滤掉第一列值为 "no rank" 的行。

4. `sed -n '/kingdom\tFungi/,$p'`：-n 选项来禁止默认的自动打印输出；`/kingdom\tFungi/` 是一个正则表达式，匹配以 "kingdom\tFungi" 开头的行。`$` 表示匹配到文件末尾。`p` 命令用于打印匹配到的行。
#将匹配到的行（从含有 "kingdom	Fungi" 的行开始到末尾的所有行）进行打印输出。如果没有找到匹配的行，则不会输出任何内容。

5. `sed -E "s/\b(genus)\b/*\1*/"`：`-E` 选项启用扩展的正则表达式语法。`\b(genus)\b` 是一个正则表达式，\b 是一个单词边界的元字符，(genus) 是要匹配和捕获的内容，\1 是对捕获组的引用，* 是包围符号； 
#`"*\1*"` 将匹配到的 "genus" 替换为 "*genus*"，从而突出显示 "genus" 这个词。

6. `(echo -e '#rank\tsci_name\ttax_id' && cat)`：在开头添加一行标题；`&&`: 是一个逻辑运算符，表示在前一个命令执行成功后，才执行后面的命令。在这里，它用于将两个命令连接起来。


```
输出
| #rank      | sci_name          | tax_id |
|------------|-------------------|--------|
| kingdom    | Fungi             | 4751   |
| subkingdom | Dikarya           | 451864 |
| phylum     | Ascomycota        | 4890   |
| subphylum  | Pezizomycotina    | 147538 |
| class      | Sordariomycetes   | 147550 |
| subclass   | Hypocreomycetidae | 222543 |
| order      | Hypocreales       | 5125   |
| family     | Hypocreaceae      | 5129   |
| *genus*    | Trichoderma       | 5543   |
界（Kingdom） 门（Phylum） 纲（Class） 目（Order） 科（Family） 属（Genus） 种（Species）
```
### Species with assemblies 具有ass的物种

Check also the family Hypocreaceae for outgroups.

Hypocreaceae（拟革菌科）是真菌界中的一个科，它包含了很多种类的拟革菌属（Hypocrea）;Hypocreaceae 科包括了许多种类的拟革菌属，而 Trichoderma 属是拟革菌科中最著名和研究最多的属之一。

```shell
cd /mnt/c/shengxin
mkdir -p data/Trichoderma/summary
cd /mnt/c/shengxin/data/Trichoderma/summary
```
# 找出和木霉同一科(Hypocreaceae)的所有属
```shell
# should have a valid name of genus
nwr member Hypocreaceae -r genus |#-获取属级别的成员
    grep -v -i "Candidatus " |#-i选项表示忽略大小写;Candidatus-暂定种（一种科学分类方法的概念）
    grep -v -i "candidate " |
    grep -v " sp." |
    grep -v " spp." |
    sed '1d' |
    sort -n -k1,1 \ #按照第一列进行数字升序排序；-n 选项表示按照数字进行排序。如果不加此选项，排序将会按照字符串进行。-k1,1 选项表示根据第一列来进行排序。这里的 1,1 表示按照第一个字段进行排序，, 是分隔符。
    > genus.list.tsv


wc -l genus.list.tsv
#18 genus.list
```
# 木霉同属的所有参考物种基因组信息（Hypocreaceae科的所有refseq信息）
```
原代码：
cat genus.list.tsv | cut -f 1 |
while read RANK_ID; do
    echo "
        SELECT
            species_id,
            species,
            COUNT(*) AS count
        FROM ar
        WHERE 1=1
            AND genus_id = ${RANK_ID}
            AND species NOT LIKE '% sp.%'
            AND species NOT LIKE '% x %' -- Crossbreeding of two species
            AND genome_rep IN ('Full')
        GROUP BY species_id
        HAVING count >= 1
        " |
        sqlite3 -tabs ~/.nwr/ar_refseq.sqlite
done |
    tsv-sort -k2,2 \
    > RS1.tsv

代码详解：
cat genus.list.tsv | cut -f 1 |#只提取第一列的内容（即属的信息）
while read RANK_ID; do#将每行的属信息存储在变量 RANK_ID 中
    echo "#打印输出格式化的 SQL 查询语句。这个查询语句将会在 SQLite 数据库中执行。
        SELECT #SELECT 用于指定要查询的列
            species_id,
            species,
            COUNT(*) AS count #COUNT(*)（作为别名为 count）
        FROM ar #FROM 指定要查询的表名或视图名。这里我们查询的是 "ar" 表。
        WHERE 1=1 #WHERE 用于指定筛选条件，这里指定多个条件；WHERE 1=1 是一个没有实际筛选效果的条件，它通常用于起始查询。
            AND genus_id = ${RANK_ID} #物种所属的属的 ID 等于 ${RANK_ID} 变量
            AND species NOT LIKE '% sp.%'#物种名称不含 " sp." ，%可以匹配任意字符（包括空字符）
            AND species NOT LIKE '% x %' -- Crossbreeding of two species #x-两种杂交
            AND genome_rep IN ('Full')#基因组的表示方式为 "Full"
        GROUP BY species_id #GROUP BY 用于按照指定的列进行分组
        HAVING count >= 1 #HAVING 用于筛选分组后的结果
        " |
        sqlite3 -tabs ~/.nwr/ar_refseq.sqlite#命令用于执行 SQLite 数据库查询，其中 "~/.nwr/ar_refseq.sqlite" 是数据库的路径。
done |
    tsv-sort -k2,2 \#按照第二列（物种名称）进行升序排序
    > RS1.tsv
#sqlite3 -tabs 是 SQLite 数据库命令行工具的一个选项，用于在查询结果中以制表符分隔列。
通过使用命令行工具 sqlite3，可以与 SQLite 数据库进行交互。
-tabs 选项告诉 sqlite3 在输出查询结果时使用制表符作为列之间的分隔符。

#HAVING 是在 SQL 查询中用于筛选分组数据的子句。它通常与 GROUP BY 子句一起使用。HAVING 子句允许在分组后对聚合函数结果进行筛选。与 WHERE 子句不同，HAVING 条件是在分组之后应用的，用于过滤已经聚合的结果。
```
# 木霉同属的所有物种信息(genbank)
```
cat genus.list.tsv | cut -f 1 |
while read RANK_ID; do
    echo "
        SELECT
            species_id,
            species,
            COUNT(*) AS count
        FROM ar
        WHERE 1=1
            AND genus_id = ${RANK_ID}
            AND species NOT LIKE '% sp.%'
            AND species NOT LIKE '% x %'
            AND genome_rep IN ('Full')
        GROUP BY species_id
        HAVING count >= 1
        " |
        sqlite3 -tabs ~/.nwr/ar_genbank.sqlite
done |
    tsv-sort -k2,2 \
    > GB1.tsv


wc -l RS*.tsv GB*.tsv
#   8 RS1.tsv
#  39 GB1.tsv

原代码：
for C in RS GB; do
    for N in $(seq 1 1 10); do
        if [ -e "${C}${N}.tsv" ]; then
            printf "${C}${N}\t"
            cat ${C}${N}.tsv |
                tsv-summarize --sum 3
        fi
    done
done
#RS1     8
#GB1     116

代码详解：
for 循环用于检查文件名为 RS1.tsv 到 RS10.tsv、GB1.tsv 到 GB10.tsv 的文件是否存在，如果存在，则使用 tsv-summarize 命令对这些文件进行处理，并输出汇总结果。

1.C 是一个循环变量，将依次取值 "RS" 和 "GB"。
2.N 是一个循环变量，将依次取值 1 到 10。seq 1 1 10 是一个 seq 命令的使用示例，用于生成从1开始到10的数字序列，并且步长为1。
3.${C}${N}.tsv：${C} 和 ${N} 是两个变量，$C 和 $N 的值将在运行时被替换。${C}${N}.tsv 是文件名，${C} 和 ${N} 的值将与文件名的一部分拼接在一起，例如，如果 $C 的值是 RS，$N 的值是 1，那么文件名将会是 RS1.tsv。
4.if 后面的部分用于检查 ${C}${N}.tsv 文件是否存在， -e 是一个测试选项，用于检查文件是否存在。如果文件存在，则执行接下来的命令块。${C}${N} 是一个文件名的组合，例如 "RS1.tsv" 或 "GB5.tsv"。
7.tsv-summarize --sum 3: 对第三列数据进行求和。
8.fi: 结束条件判断语句块。
9.done: 结束内部循环。
10.done: 结束外部循环。
```

## Download all assemblies 下载所有组装集

### Create .assembly.tsv

This step is pretty important

* `nwr kb formats` will give the formatting requirements for `.assembly.tsv`.

#组装集的命名有两个方面：

对于程序操作，它们是唯一标识符;
对于研究人员，他们应该提供分类学信息。
* The naming of assemblies has two aspects:
    * for program operation they are unique identifiers;
    * for researchers, they should provide taxonomic information.

#如果 RefSeq 组件可用，则不会列出相应的 GenBank 组件
If a RefSeq assembly is available, the corresponding GenBank one will not be listed

```shell
cd /mnt/c/shengxin/data/Trichoderma/summary

# Reference genome # 酵母菌属的参考菌株的基因组信息
#用于从 SQLite 数据库中选取特定的数据，并将结果保存到 raw.tsv 文件中
echo " #SQL 查询语句包含在 echo 命令的引号中
.headers ON#是一个 SQLite 命令，用于在查询结果中包含列名的头部信息。通过设置 .headers ON，在执行 SQL 查询后返回的结果集中，会包含一个包含列名的头部行。如果不设置 .headers ON，那么默认情况下结果集将不包含头部行，只有数据。

    SELECT
        *
    FROM ar
    WHERE 1=1
        AND genus IN ('Saccharomyces')
        AND refseq_category IN ('reference genome')
    " |#查询的结果将通过管道（|）传递给 tsv-select 命令
    sqlite3 -tabs ~/.nwr/ar_refseq.sqlite |# SQLite 数据库的文件路径，~ 表示用户主目录。该命令将连接到指定的数据库文件 ar_refseq.sqlite
    tsv-select -H -f organism_name,species,genus,ftp_path,biosample,assembly_level,assembly_accession \#-f:选择指定的列 ;-H 选项用于保留输入数据的标题行。
    > raw.tsv
```

# 木霉同科的各属的参考菌株基因组信息
```
# RS
SPECIES=$(
    cat RS1.tsv |
        cut -f 1 |
        tr "\n" "," |
        sed 's/,$//'
)

echo "
    SELECT
        species || ' ' || infraspecific_name || ' ' || assembly_accession AS name,#|| 用于字符串拼接;name：通过将 species、infraspecific_name 和 assembly_accession 列进行拼接而生成的结果列。
        species, genus, ftp_path, biosample, assembly_level,
        assembly_accession
    #infraspecific_name：种下分类群（种下分类群是植物命名中层级之下的分类单元，用于三名法中）
    ftp_path：FTP 路径。
biosample：生物样本。
assembly_level：组装级别。
assembly_accession：组装编号。
    FROM ar
    WHERE 1=1
        AND species_id IN ($SPECIES)#IN 用于检查 species_id 是否在 $SPECIES 中
        AND genome_rep IN ('Full')
    " |
    sqlite3 -tabs ~/.nwr/ar_refseq.sqlite \
    >> raw.tsv

# Preference for refseq # 提取参考菌株组装基因组编号
cat raw.tsv |
    tsv-select -H -f "assembly_accession" \
    > rs.acc.tsv
```
# 木霉同科的各属的菌株基因组信息（去除参考菌株基因组）
```
# GB
SPECIES=$(
    cat GB1.tsv |
        cut -f 1 |
        tr "\n" "," |
        sed 's/,$//'
)

echo "
    SELECT
        species || ' ' || infraspecific_name || ' ' || assembly_accession AS name,
        species, genus, ftp_path, biosample, assembly_level,
        gbrs_paired_asm
    FROM ar
    WHERE 1=1
        AND species_id IN ($SPECIES)
        AND genome_rep IN ('Full')
    " |
    sqlite3 -tabs ~/.nwr/ar_genbank.sqlite |
    tsv-join -f rs.acc.tsv -k 1 -d 7 -e \
    #-f rs.acc.tsv：指定要进行连接的第二个 TSV 文件
    -k 1：将使用每个输入文件的第一列作为连接键。根据这个键，tsv-join 将匹配具有相同键值的行，并将它们合并为一行
-d 7：指定用于分隔符的列索引，这里是第七列。即用每个输入文件的第七列作为字段分隔符
    -e：启用外连接（outer join），即使在匹配失败的情况下也会保留行。
    tsv-join 命令会将rs.acc.tsv 和先前由 sqlite3 命令输出的结果文件连接起来
    >> raw.tsv
#在 tsv-join 命令中，键值是指用来匹配两个 TSV 文件行的标识符或值。当进行连接操作时，tsv-join 会使用指定的键值来确定哪些行需要合并。

这个代码片段中，-k 1 参数指定了第一个列作为键，意味着连接操作将以第一个列的值作为键值进行匹配。

例如，假设有两个 TSV 文件，每个文件包含多行和多列的数据。连接操作将使用指定的键值（在这种情况下是第一个列的值）在两个文件中查找匹配的行。只有具有相同键值的行才会被合并到结果中。
#infraspecific_name：种下分类群（种下分类群是植物命名中层级之下的分类单元，用于三名法中）

cat raw.tsv |
    tsv-uniq |
    datamash check
#116 lines, 7 fields
```
# 创建简写名称的木霉属水平的各菌株基因组下载文件
```
# Create abbr.
cat raw.tsv |
    grep -v '^#' |
    tsv-uniq |
    tsv-select -f 1-6 |
    perl abbr_name.pl -c "1,2,3" -s '\t' -m 3 --shortsub |
    (echo -e '#name\tftp_path\tbiosample\tspecies\tassembly_level' && cat ) |#在数据开头添加一个表头行
    perl -nl -a -F"," -e '#-a -F",": 在处理输入时自动对每一行进行拆分（按逗号 , 进行拆分），并将拆分后的字段存储在数组 @F 中。
        BEGIN{my %seen};
        /^#/ and print and next;
        /^organism_name/i and next;
        $seen{$F[3]}++; # ftp_path
        $seen{$F[3]} > 1 and next;
        $seen{$F[6]}++; # abbr_name
        $seen{$F[6]} > 1 and next;
        printf qq{%s\t%s\t%s\t%s\t%s\n}, $F[6], $F[3], $F[4], $F[1], $F[5];
        ' |
    tsv-filter --or --str-in-fld 2:ftp --str-in-fld 2:http |
    keep-header -- tsv-sort -k4,4 -k1,1 \#keep-header 是一个选项，用于指示某个工具或脚本在处理数据时是否应该保留头部行（通常是表格中的列标题行）。
    > Trichoderma.assembly.tsv

代码详解：
#perl abbr_name.pl -c "1,2,3" -s '\t' -m 3 --shortsub |
-c "1,2,3"：-c是"columns",表示要缩写的列号，这里是1、2和3列。
-s '\t'：-s是"separator"的缩写,使用制表符作为输入文件中的列分隔符。
-m 3：-m是"maximum"的缩写,对每个缩写的单词使用的最大长度为3个字符。
--shortsub：-- 表示后面的内容是一个长选项（long option），而 shortsub 是该选项的名称。表示将生成的简化名称进行缩写处理。
#长选项通常使用两个减号作为前缀，以区别于单个减号前缀的短选项（short option）。它们用于提供更具描述性的选项名称，并可以更好地表达选项的含义。

 BEGIN{my %seen};
        /^#/ and print and next;#打印并下一行
        /^organism_name/i and next;#i 忽略大小写；直接下一行;排除以 organism_name 开头的行
        $seen{$F[3]}++; # ftp_path#$F 是一个特殊变量，它是 Perl 提供的默认数组，用于存储通过字符串分割得到的字段（使用 -a 命令行选项或者 split 函数）。$F[3] 就是数组 @F 的第四个元素；因为Perl 中的数组索引从 0 开始. 这一行对 ftp_path 字段的值进行统计。每当一个 ftp_path 出现时，将在 %seen 哈希中对应的值加1。这样，我们就可以知道每个 ftp_path 值出现的次数。
        $seen{$F[3]} > 1 and next;# 这是一个条件语句，用于排除重复的 ftp_path 值。如果某个 ftp_path 值已经在 %seen 哈希中出现过，即出现次数大于1，则跳过后续处理。
        $seen{$F[6]}++; # abbr_name
        $seen{$F[6]} > 1 and next;
        printf qq{%s\t%s\t%s\t%s\t%s\n}, $F[6], $F[3], $F[4], $F[1], $F[5];#%s 是格式化字符串，用于输出字符串值；按照指定顺序输出
    
#% 符号在Perl中表示哈希表（hash）变量的前缀，它用于声明一个哈希表。而 seen 是该哈希表的变量名。

在Perl中，哈希表是一种可以存储键-值对的数据结构。它类似于字典或关联数组，可以通过键来访问对应的值。

%seen 表示一个哈希表变量，它用于记录已经出现过的数据。在这个脚本中，%seen 用于记录已经处理的 ftp_path 和 abbr_name，以便后续进行重复性检查或其他处理。
#/^#/ 是一个正则表达式模式，表示匹配以 # 字符开头的行
在正则表达式中，斜杠（/）是用来界定正则表达式模式的开始和结束。在Perl中，斜杠之间的内容被解释为匹配规则，正则表达式通常被包含在两个斜杠之间，以表示要进行匹配或替换的模式。

除了正则表达式之外，Perl中的斜杠还有其他含义。例如，它可用于除法运算符 /，或作为替代分隔符来界定替换操作符 s/// 的模式部分。

#--str-in-fld <field>:<file>：仅保留字段 <field> 的值在指定文件 <file> 中出现的行。
--str-in-fld 用于指定在特定字段中查找指定字符串
--str-in-fld 2:ftp: 这个条件指定对数据的第2列进行筛选，要求该列的值中包含字符串 "ftp"。

--or 表示对这两个条件进行逻辑“或”操作，即只要满足其中一个条件即可。

datamash check < Trichoderma.assembly.tsv
#115 lines, 5 fields
```
# 检查有没有重复
```
# find potential duplicate strains or assemblies
cat Trichoderma.assembly.tsv |
    tsv-uniq -f 1 --repeated
#--repeated 表示只输出重复的行

# 检查下载链接是否正确
cat Trichoderma.assembly.tsv |
    tsv-filter --str-not-in-fld 2:ftp

# Edit .assembly.tsv, remove unnecessary strains, check strain names and comment out poor assemblies.
# vim Trichoderma.assembly.tsv
#
# Save the file to another directory to prevent accidentally changing it
# cp Trichoderma.assembly.tsv /mnt/c/shengxin/data/Trichoderma/assembly

# Cleaning
rm raw*.*sv

```

### Count before download 下载前计数

* `strains.taxon.tsv` - taxonomy info: species, genus, family, order, and class
Strains.taxon.tsv - 分类信息：物种、属、科、目和类

```shell
cd /mnt/c/shengxin/data/Trichoderma/summary

nwr template ../assembly/Trichoderma.assembly.tsv \
    --count \
    --rank genus
#template 为系统基因组研究创建目录、数据和脚本
#--count 是一个选项，用于生成基于组装信息的序列计数信息。
#--rank genus 是另一个选项，用于指定生成模板时使用的分类级别。在这种情况下，模板将根据属级别（genus）进行生成。
输出内容：
Create Count/species.tsv
Create Count/strains.sh
Create Count/rank.sh
Create Count/lineage.sh

进入count目录
# --count: Count/
#     * One TSV file
#         * species.tsv
#     * Three Bash scripts
#         * strains.sh - strains.taxon.tsv, species, genus, family, order, and class
#         * rank.sh - count species and strains
#         * lineage.sh - count strains

# species.tsv   两列分别是：菌株简写名称；物种名species

# strains.taxon.tsv and taxa.tsv
bash Count/strains.sh #strains.taxon.tsv共6列，是为了统计各个菌株的数量以及所在的物种，属，科，目，纲的数量

#taxa.tsv内容：
item	count
strain	113
species	38
genus	7
family	2
order	2
class	2

# genus.lst and genus.count.tsv
bash Count/rank.sh

输出：
genus.lst #文件只有一列，提取了属的名称

mv Count/genus.count.tsv Count/genus.before.tsv#重命名文件

cat Count/genus.before.tsv |
    mlr --itsv --omd cat |#mlr将输入的 TSV 格式输出为 Markdown 格式
    perl -nl -e 'm/^\|\s*---/ and print qq(|---|--:|--:|) and next; print'# -l 表示自动处理行尾换行符；
    #\| 表示匹配竖线字符（|）的转义，因为竖线在正则表达式中是特殊字符。\s表示匹配任意空格。\s* 表示匹配零个或多个空格。m/^\|\s*---/ 表达式用于匹配以 |--- 开头的行（例如 Markdown 表格的分隔线）
    #and: 这是 Perl 的逻辑操作符，用于将多个条件连接在一起。在这里，它表示如果前面的正则表达式匹配成功，就执行接下来的语句。
    #print qq(|---|--:|--:|) and next: 如果前面的正则表达式匹配成功，就输出字符串 |---|--:|--:| 并执行 next 命令。

```

| genus            | #species | #strains |
|------------------|---------:|---------:|
| Cladobotryum     |        1 |        1 |
| Escovopsis       |        1 |        2 |
| Hypomyces        |        2 |        2 |
| Mycogone         |        1 |        1 |
| Saccharomyces    |        1 |        1 |
| Sphaerostilbella |        1 |        1 |
| Trichoderma      |       31 |      105 |

### Download and check 下载并检查

* When `rsync.sh` is interrupted, run `check.sh` before restarting 
  
 #当 rsync.sh 中断时，在重新启动之前运行 check.sh
* For projects that have finished downloading, but have renamed strains, you can run `reorder.sh` to
  avoid re-downloading 
  
  #对于已完成下载但已重命名 strain 的项目，可以运行 reorder.sh 以避免重新下载
    * `misplaced.tsv` 
    * `remove.list` 
* The parameters of `n50.sh` should be determined by the distribution of the description statistics #n50.sh 的参数应由描述统计量的分布决定
* `collect.sh` generates a file of type `.tsv`, which is intended to be opened by spreadsheet #collect.sh 生成一个类型为 .tsv 的文件，该文件旨在通过电子表格软件打开。
  software.
    * Information of assemblies are collected from *_assembly_report.txt *after* downloading #*下载后*从*_assembly_report.txt *中收集程序集信息
    * **Note**: `*_assembly_report.txt` have `CRLF` at the end of the line.
  
  #**注意**:' *_assembly_report.txt '行尾有' CRLF '。crlf 是回车换行的意思
* `finish.sh` generates the following files
    * `omit.lst` - no annotations#- 无注释；
    * `collect.pass.tsv` - passes the n50 check#通过 n50 检查
    * `pass.lst` - passes the n50 check#通过 n50 检查
    * `rep.lst` - representative or reference strains# 代表性或参考菌株
    * `counts.tsv`
  

```shell
cd /mnt/c/shengxin/data/Trichoderma

nwr template ../Trichoderma/assembly/Trichoderma.assembly.tsv\
    --ass#--ass 组装
#基因组组装是将高通量测序生成的短读序列（例如 Illumina 测序数据）重新组合成较长的连续序列，代表目标生物的基因组。组装的过程涉及到将重叠的短读序列拼接起来，形成更长的连续片段，最终得到整个基因组的序列。

# --ass: ASSEMBLY/
#     * One TSV file
#         * url.tsv #三列：菌株简写名称；下载网址；物种名
#     * And five Bash scripts
#         * rsync.sh
#         * check.sh
#         * n50.sh [LEN_N50] [N_CONTIG] [LEN_SUM]
#         * collect.sh
#         * finish.sh

# Run
bash ASSEMBLY/rsync.sh

# Check md5; create check.lst
# rm ASSEMBLY/check.lst
bash ASSEMBLY/check.sh

# Put the misplaced directory into the right place##把放错地方的目录放到正确的位置
#bash ASSEMBLY/reorder.sh

# This operation will delete some files in the directory, so please be careful #该操作将删除目录中的部分文件，请谨慎操作
#cat ASSEMBLY/remove.lst |
#    parallel --no-run-if-empty --linebuffer -k -j 1 '
#        if [[ -e "ASSEMBLY/{}" ]]; then#{} 是 parallel 命令提供的占位符，会依次替换为从输入中读取的每一行数据
#            echo Remove {}#输出一条日志消息，内容为字符串 "Remove " 加上当前行的数据。
#            rm -fr "ASSEMBLY/{}"
#        fi
#    '

# N50 C S; create n50.tsv and n50.pass.tsv
bash ASSEMBLY/n50.sh 100000 1000 1000000
# 10000：最小n50长度
# 1000： contig数量小于1000
# 1000000: 总长度大于1000000.

# Adjust parameters passed to `n50.sh`#调整传递给' n50.sh '的参数
cat ASSEMBLY/n50.tsv |
    tsv-filter -H --str-in-fld "name:_GCF_" |#筛选名为 "name" 的字段中包含 "GCF" 字符串的行,_GCF_ 是一个字符串模式；GCF是NCBI中对参考基因组的缩写  
    #在 NCBI（National Center for Biotechnology Information）中，GCF 是指 "GenBank Assembly accession"，也就是基因组装序列的访问号。每个参考基因组都被分配了一个唯一的 GCF 号码，用于标识该基因组的特定版本和组装。
    tsv-summarize -H --min "N50,S" --max "C"#表示计算 "N50" 和 "S" 字段的最小值,"C"的最大值
#N50_min S_min   C_max
#697391  33215161        533

cat ASSEMBLY/n50.tsv |
    tsv-summarize -H --quantile "S:0.1,0.5" --quantile "N50:0.1,0.5"  --quantile "C:0.5,0.9"
#--quantile 参数用于计算数据的分位数。分位数是统计学中用于刻画数据分布的概念。它将数据集分成几个等分，常见的分位数包括中位数（50% 分位数）、四分位数（25% 和 75% 分位数）和百分位数（例如，10%、90% 分位数）。以中位数为例，它将数据分成两部分，前一半的数据小于或等于中位数，后一半的数据大于或等于中位数。
# 0.1,0.5 表示计算这些列的 10% 和 50% 的分位数。

#S_pct10 S_pct50 N50_pct10       N50_pct50       C_pct50 C_pct90
#32255196.8      37316984        98936.2 1332095 167     1276.4

# After the above steps are completed, run the following commands. 以上步骤完成后，运行以下命令。

# Collect; create collect.tsv
bash ASSEMBLY/collect.sh
#收集已经下载的基因组的详细信息，114行，113个基因组

# 统计下载的文件行数：
# collect.pass.tsv ：下载的基因组通过了n50的检验 -97行（有一行标题）；pass.lst 96行（不含标题），取collect.pass.tsv的第一列名称。
# omit.lst ：没有蛋白序列信息，文件只有一列，基因组名 80个基因组
# rep.lst : 含有参考序列的基因组 31个基因组

# After all completed
bash ASSEMBLY/finish.sh

cp ASSEMBLY/collect.pass.tsv summary/

cat ASSEMBLY/counts.tsv |
    mlr --itsv --omd cat |
    perl -nl -e 'm/^\|\s*---/ and print qq(|---|--:|--:|) and next; print'

```

| #item            | fields | lines |
|------------------|-------:|------:|
| url.tsv          |      3 |   113 |
| check.lst        |      1 |   113 |
| collect.tsv      |     20 |   114 |
| n50.tsv          |      4 |   114 |
| n50.pass.tsv     |      4 |    97 |
| collect.pass.tsv |     23 |    97 |
| pass.lst         |      1 |    96 |
| omit.lst         |      1 |    81 |
| rep.lst          |      1 |    31 |

### Rsync to hpcc 把本地文件与超算同步

```bash
rsync -avP \
    /mnt/c/shengxin/data/Trichoderma/ \
    wangq@202.119.37.251:qyl/data/Trichoderma

rsync -avP \
    -e 'ssh -p 8804' \
    /mnt/c/shengxin/data/Trichoderma/ \
    wangq@58.213.64.36:qyl/data/Trichoderma
    #-e 'ssh -p 8804'：指定使用SSH作为传输协议，并设置SSH连接的端口号为8804。
/mnt/c/shengxin/data/Trichoderma/ ：源目录，指定要复制的本地目录路径。
wangq@58.213.64.36:qyl/data/Trichoderma：目标地址，指定远程服务器的用户名、IP地址和目标目录路径。

```

## BioSample 生物样品

ENA's BioSample missed many strains, so NCBI's was used.

#ENA的生物样本遗漏了许多菌株，因此使用了NCBI的生物样本。

#ENA（European Nucleotide Archive）是一个欧洲的生物信息数据库，专门用于存储和共享核苷酸序列、元数据和相关的生物学信息。ENA 是国际上最重要的核苷酸序列存储库之一，提供了广泛的生物信息资源，包括基因组序列、转录组数据、宏基因组数据等。

```shell
cd /mnt/c/shengxin/data/Trichoderma

#用于设置当前终端会话的文件描述符限制数（ulimit）为操作系统所允许的最大文件描述符数（ulimit -Hn）
ulimit -n `ulimit -Hn`
#ulimit -Hn: 这部分命令获取当前用户的硬文件描述符限制值。-H 参数表示获取硬限制，-n 参数表示获取文件描述符限制

#通过执行 ulimit -Hn 命令，先获取操作系统所允许的最大文件描述符数，然后将其作为参数传递给 ulimit -n 命令，从而将当前终端会话的文件描述符限制数设置为操作系统所允许的最大值。

#文件描述符是操作系统用于标识和管理打开文件的数值。通过调整文件描述符限制数，可以控制一个进程能够同时打开的文件数量，以满足特定应用程序的需求。

nwr template /mnt/c/shengxin/data/Trichoderma/summary/Trichoderma.assembly.tsv \
    --bs

# * --bs: BioSample/
#     * One TSV file
#         * sample.tsv
#     * And two Bash scripts
#         * download.sh
#         * collect.sh [N_ATTR]

head BioSample/sample.tsv

#SAMD00028324    T_atrov_JCM_9410_GCA_001599035_1        Trichoderma_atroviride
#SAMD00028335    T_koningii_JCM_1883_GCA_001950475_1     Trichoderma_koningii

bash BioSample/download.sh
# 下载SAMN文本文件（通常是指 NCBI 的 BioSample 数据库中的文本格式文件）

# Ignore rare attributes#忽略稀少属性
bash BioSample/collect.sh 10
#用于从BioSample目录中收集数据，参数10用来设置一个阈值，只收集那些在数据中至少出现10次（或高于10%）的属性。

datamash check < BioSample/biosample.tsv
#112 lines, 37 fields

cp BioSample/attributes.lst summary/#将 BioSample/attributes.lst文件复制到 summary/ 目录，如果 summary/ 目录不存在，会在复制时自动创建该目录。（attributes属性）
cp BioSample/biosample.tsv summary/

#attributes.lst文件部分内容：
sample name
collection date
geographic location
project name
External Id
Submitter Id
GAL
GAL_sample_id

#biosample.tsv 文件内容
#name	BioSample	sample name	collection date	geographic location	project name	External Id	Submitter Id	GAL	GAL_sample_id	broker name	collected by	collecting institution	habitat	identified by	identifier_affiliation	life stage	tissue	sex	specimen id	specimen voucher	tolid	sample derived from	strain	latitude and longitude	isolation and growth condition	environmental medium	estimated size	number of replicons	ploidy	propagation	isolation source	sample type	host	isolate	depth	elevation
T_atrov_JCM_9410_GCA_001599035_1	SAMD00028324	JCM 9410			NBRP: Genome sequencing of Trichoderma atroviride JCM 9410																		JCM 9410		http://www.jcm.riken.jp/cgi-bin/jcm/jcm_number?JCM=9410		36M											

```

## MinHash

Estimate nucleotide divergences among strains.

#估计菌株之间的核苷酸差异。

* Abnormal strains#异常菌株
    * This [paper](https://doi.org/10.1038/s41467-018-07641-9) showed that >95% intra-species and
      and <83% inter-species ANI values.#在80亿个基因组对中，99.8%的基因组对符合>95%的种内和<83%的种间ANI值

#补充:
ANI（Average Nucleotide Identity）是一种计算两个细菌基因组之间相似性的指标，常用于判断两个菌株是否属于同一物种。ANI值表示两个基因组的核苷酸序列相似性的平均比例。

计算菌株的ANI值通常需要进行以下步骤：

获取两个菌株的基因组序列。
利用合适的比对算法（如BLAST、MUMmer等）将两个基因组序列进行配对比对。

根据比对结果计算两个基因组的核苷酸序列相似性，得到ANI值。

ANI值通常以百分比的形式表示，取值范围在0到100之间。一般来说，ANI值大于95%可以认为两个菌株是同一物种，而小于95%则可能是不同物种。

    * If the maximum value of ANI between strains within a species is greater than *0.05*, the
      median and maximum value will be reported. Strains that cannot be linked by the median
      ANI, e.g., have no similar strains in the species, will be considered as abnormal strains.
      #如果物种内菌株之间的ANI最大值大于0.05，则将报告中位数和最大值。不能通过中间值ANI连接的菌株，例如，在该物种中没有类似菌株的菌株，将被视为异常菌株。 它可能包括两种情况： 错误的物种识别 装配质量差 非冗余菌株
    * It may consist of two scenarios:
        1. Wrong species identification
        2. Poor assembly quality
   
 #如果一个物种内两个菌株之间的ANI值小于0.005，则认为这两个菌株是多余的。 需要这些文件：representative.lst 和 omit.lst 
* Non-redundant strains
    * If the ANI value between two strains within a species is less than *0.005*, the two strains
      are considered to be redundant.
    * Need these files:  representative.lst and omit.lst

#最小哈希树
* MinHash tree
    * A rough tree is generated by k-mean clustering.#粗略树由 k 值聚类生成。 

* These abnormal strains should be manually checked to determine whether to include them in the
  subsequent steps.#应手动检查这些异常菌株，以确定是否将其包含在后续步骤中。

```shell
cd /mnt/c/shengxin/data/Trichoderma

nwr template /mnt/c/shengxin/data/Trichoderma/assembly/Trichoderma.assembly.tsv \
    --mh \#指定使用 "mh"（minhashing）算法进行计算。
    --parallel 16 \
    --in ASSEMBLY/pass.lst \#指定处理的输入文件
    --ani-ab 0.05 \#设置 ANI (Average Nucleotide Identity) 的阈值（下限），这里设为 0.05，意味着只有当两个样本的ANI大于等于0.05时才会被认为是相似的。
    --ani-nr 0.005 \#设置非重复性ANI的阈值（下限），这里设为 0.005，对应于ANI的NR值，即判断两个样本为非重复性的阈值。
    --height 0.4#设置图形的高度为 0.4，用于可视化结果的展示

#ani-nr 表示 "average nucleotide identity non-recursive (ANI-NR)"，是一种衡量两个基因组之间相似性的指标。

ANI-NR 是对平均核苷酸身份 (ANI) 的一种改进算法，它采用非递归的方法进行计算。ANI-NR 通过比较两个基因组的核苷酸序列来评估它们之间的相似性。设置阈值为 0.005 意味着只有当两个基因组的 ANI-NR 值大于等于 0.005 时，才会被认为是相关的或相似的。

# --mh: MinHash/
#     * One TSV file
#         * species.tsv
#     * And five Bash scripts
#         * compute.sh  # 创建msh文件,mash sketch 工具生成了一个用于比较基因组数据相似性的草图文件，并且在指定的目录下保存了这个草图文件。草图文件可以用于后续的数据分析和比较操作。
#         * species.sh
#         * abnormal.sh
#         * nr.sh
#         * dist.sh

head MinHash/species.tsv

# 基因组名加物种名
# C_pro_CCMJ2080_GCA_004303015_1  Cladobotryum_protrusum
# E_web_EWB_GCA_003055145_1       Escovopsis_weberi
# E_web_GCA_001278495_1   Escovopsis_weberi
# H_perniciosus_HP10_GCA_008477525_1      Hypomyces_perniciosus

cd /mnt/c/shengxin/data/Trichoderma/summary

# Compute assembly sketches
bash ../MinHash/compute.sh

# Distances within species
bash ../MinHash/species.sh

# Abnormal strains
bash ../MinHash/abnormal.sh

cat ../MinHash/abnormal.lst
#T_har_CGMCC_20739_GCA_019097725_1
#T_har_Tr1_GCA_002894145_1
#T_har_ZL_811_GCA_021186515_1

# Non-redundant strains within species
bash ../MinHash/nr.sh

# Distances between all selected sketches, then hierarchical clustering
bash ../MinHash/dist.sh

```

### Condense branches in the minhash tree
#简化Minhash树

* This phylo-tree is not really formal/correct, and shouldn't be used to interpret phylogenetic
  relationships
* It is just used to find more abnormal strains
  #这个进化树不是很正式/正确，不应该用来解释系统发育的关系；它只是用来发现更多的异常菌株

```shell
# 安装newick-utils
cd app
brew install brewsci/bio/newick-utils
#brewsci/bio/是 Homebrew 社区中的一个 tap（存储库），专注于提供生物信息学相关的软件包

mkdir -p /mnt/c/shengxin/data/Trichoderma/tree
cd /mnt/c/shengxin/data/Trichoderma/tree

nw_reroot ../MinHash/tree.nwk Sa_cer_S288C |
    nw_order -c n - \
    > minhash.reroot.newick

#详解：   
nw_reroot ../MinHash/tree.nwk Sa_cer_S288C |    #使用 nw_reroot 命令将 ../MinHash/tree.nwk 文件中的 Newick 树以 Sa_cer_S288C 为根重新排列。将Sa_cer_S288C节点作为新的根节点进行重新定位
    nw_order -c n - \   # nw_order命令用于重新排列树的节点顺序。参数-c n指定按照节点名称的字母顺序进行排序，而-表示从标准输入读取树的输入。
    #-c 表示按照节点的特征（characteristic）进行排序，而 n 表示特征为节点的名称。
    #会按照节点名称的特征顺序对树的节点进行重新排序，从而改变树的结构，但不改变树中节点的拓扑关系。
    > minhash.reroot.newick
    
# rank::col
ARRAY=(
#    'order::5'
#    'family::4'
#    'genus::3'
    'species::2'
)
#定义了一个名为 ARRAY 的数组，其中包含了一些字符串元素。这些字符串元素代表了不同的分类级别以及对应的排序顺序;rank 是分类级别的名称，例如 'order'、'family'、'genus' 或 'species'。col 是该分类级别在排序中的顺序值，用于确定分类级别的优先级，值越小表示优先级越高。
#在这里，数组中的元素是被注释掉的。可以根据需要取消注释某个元素或添加新的元素。


rm minhash.condensed.map
CUR_TREE=minhash.reroot.newick #将字符串 'minhash.reroot.newick' 赋值给变量 CUR_TREE
#CUR_TREE 是一个变量，在代码中被用作当前树结构文件的名称。在循环的每个迭代中，它被更新为新创建的树结构文件的名称。在代码中，首次出现时 CUR_TREE 变量没有给出具体的值，因此可能需要在循环之前为其赋予一个初始值。

原代码：
for item in "${ARRAY[@]}" ; do
    GROUP_NAME="${item%%::*}"
    GROUP_COL="${item##*::}"

    bash ../condense_tree.sh ${CUR_TREE} ../summary/Count/strains.taxon.tsv 1 ${GROUP_COL}

    mv condense.newick minhash.${GROUP_NAME}.newick
    cat condense.map >> minhash.condensed.map

    CUR_TREE=minhash.${GROUP_NAME}.newick
done

代码详解：
for item in "${ARRAY[@]}" ; do
    GROUP_NAME="${item%%::*}" #`%%` 表示从字符串的末尾开始，删除最长的匹配模式，并返回剩余的部分。（删除第一个 "::" 及其后面的内容）
    GROUP_COL="${item##*::}" #`##` 表示从字符串的开头开始，删除最长的匹配模式，并返回剩余的部分（删除最后一个 "::" 及其前面的内容）
   
    bash ../condense_tree.sh ${CUR_TREE} ../summary/Count/strains.taxon.tsv 1 ${GROUP_COL}

    mv condense.newick minhash.${GROUP_NAME}.newick
    cat condense.map >> minhash.condensed.map

    CUR_TREE=minhash.${GROUP_NAME}.newick #更新变量 CUR_TREE 的值为新创建的树结构文件名
done

# png #将 minhash.species.newick 树结构文件可视化
nw_display -s -b 'visibility:hidden' -w 1200 -v 20 minhash.species.newick |
    rsvg-convert -o Trichoderma.minhash.png

# -s：表示使用 SVG 格式输出。SVG（Scalable Vector Graphics的缩写）可缩放矢量图形文件
 -b 'visibility:hidden'：设置样式属性，将所有元素的可见性设置为隐藏，这可能是根据实际需求而定的。
 -w 1200：设置输出图像的宽度为 1200 像素。
 -v 20：将绘图的垂直空间设置为 20。
#rsvg-convert 是一个命令行工具，用于将 SVG（可缩放矢量图形）文件转换为其他常见的图像格式

```

## Count valid species and strains #计算有效物种数和菌株数

### For *genomic alignments* 用于*基因组比对*

```shell
cd /mnt/c/shengxin/data/Trichoderma

nwr template /mnt/c/shengxin/data/Trichoderma/assembly/Trichoderma.assembly.tsv \
    --count \  #计算每个分类单元（genus）的统计数。
    --in ASSEMBLY/pass.lst \
    --not-in MinHash/abnormal.lst \
    --rank genus \  #使用 "genus" 级别作为分类单元
    --lineage family --lineage genus # 将家族（family）和属（genus）级别的信息包含在输出结果中。

#lineage（谱系）在生物学中是指描述物种或分类单元之间演化关系的层级结构。它通常以树状图的形式表示，显示了不同分类单元（如物种、属、科、目等）之间的进化关系和共同祖先。

#输出内容：
#Create Count/species.tsv
#Create Count/strains.sh
#Create Count/rank.sh
#Create Count/lineage.sh

cd /mnt/c/shengxin/data/Trichoderma/summary

# strains.taxon.tsv
bash ../Count/strains.sh

# .lst and .count.tsv
bash ../Count/rank.sh

cat ../Count/genus.count.tsv |
    mlr --itsv --omd cat |
    perl -nl -e 'm/^\|\s*---/ and print qq(|---|--:|--:|) and next; print'

# Can accept N_COUNT
bash ../Count/lineage.sh

cat ../Count/lineage.count.tsv |
    mlr --itsv --omd cat |
    perl -nl -e 's/-\s*\|$/-:|/; print'

# copy to summary/
cp ../Count/strains.taxon.tsv ./genome.taxon.tsv
```

| genus         | #species | #strains |
|---------------|----------|----------|
| Cladobotryum  | 1        | 1        |
| Escovopsis    | 1        | 2        |
| Hypomyces     | 2        | 2        |
| Saccharomyces | 1        | 1        |
| Trichoderma   | 26       | 87       | 



| #family            | genus         | species                     | count |
|--------------------|---------------|-----------------------------|------:|
| Hypocreaceae       | Cladobotryum  | Cladobotryum protrusum      |     1 |
|                    | Escovopsis    | Escovopsis weberi           |     2 |
|                    | Hypomyces     | Hypomyces perniciosus       |     1 |
|                    |               | Hypomyces rosellus          |     1 |
|                    | Trichoderma   | Trichoderma afroharzianum   |     4 |
|                    |               | Trichoderma arundinaceum    |     4 |
|                    |               | Trichoderma asperelloides   |     2 |
|                    |               | Trichoderma asperellum      |    13 |
|                    |               | Trichoderma atrobrunneum    |     1 |
|                    |               | Trichoderma atroviride      |     7 |
|                    |               | Trichoderma breve           |     1 |
|                    |               | Trichoderma brevicrassum    |     1 |
|                    |               | Trichoderma citrinoviride   |     3 |
|                    |               | Trichoderma erinaceum       |     2 |
|                    |               | Trichoderma gamsii          |     2 |
|                    |               | Trichoderma gracile         |     1 |
|                    |               | Trichoderma guizhouense     |     1 |
|                    |               | Trichoderma hamatum         |     1 |
|                    |               | Trichoderma harzianum       |     7 |
|                    |               | Trichoderma koningii        |     1 |
|                    |               | Trichoderma koningiopsis    |     4 |
|                    |               | Trichoderma lentiforme      |     1 |
|                    |               | Trichoderma longibrachiatum |     5 |
|                    |               | Trichoderma pseudokoningii  |     1 |
|                    |               | Trichoderma reesei          |    13 |
|                    |               | Trichoderma semiorbis       |     1 |
|                    |               | Trichoderma simmonsii       |     1 |
|                    |               | Trichoderma virens          |     8 |
|                    |               | Trichoderma viride          |     1 |
| Saccharomycetaceae | Saccharomyces | Saccharomyces cerevisiae    |     1 |

### For *protein families* #用于*蛋白质家族*

```shell
cd /mnt/c/shengxin/data/Trichoderma/

nwr template /mnt/c/shengxin/data/Trichoderma/assembly/Trichoderma.assembly.tsv \
    --count \
    --in ASSEMBLY/pass.lst \
    --not-in MinHash/abnormal.lst \
    --not-in ASSEMBLY/omit.lst \
    --rank genus

#输出内容：
#Create Count/species.tsv
#Create Count/strains.sh
#Create Count/rank.sh
#Create Count/lineage.sh

cd /mnt/c/shengxin/data/Trichoderma

# strains.taxon.tsv
bash Count/strains.sh

# .lst and .count.tsv
bash Count/rank.sh

cat Count/genus.count.tsv |
    mlr --itsv --omd cat |
    perl -nl -e 'm/^\|\s*---/ and print qq(|---|--:|--:|) and next; print'

# copy to summary/
cp Count/strains.taxon.tsv protein.taxon.tsv

```

| genus         | #species | #strains |
|---------------|----------|----------|
| Escovopsis    | 1        | 1        |
| Saccharomyces | 1        | 1        |
| Trichoderma   | 16       | 24       |

## Collect proteins

```shell
cd /mnt/c/shengxin/data/Trichoderma/

nwr template /mnt/c/shengxin/data/Trichoderma/assembly/Trichoderma.assembly.tsv \
    --pro \
    --in ASSEMBLY/pass.lst \
    --not-in MinHash/abnormal.lst \
    --not-in ASSEMBLY/omit.lst

# * --pro: Protein/
#     * One TSV file
#         * species.tsv
#     * collect.sh

/mnt/c/shengxin/data/Trichoderma/assembly
# collect proteins
bash ../Protein/collect.sh

cat ../Protein/counts.tsv |
    mlr --itsv --omd cat

```

| #item                          | count   |
|--------------------------------|---------|
| Proteins                       | 275,985 |
| Unique headers and annotations | 275,985 |
| Unique proteins                | 275,985 |
| all.replace.fa                 | 275,985 |
| all.annotation.tsv             | 275,986 |
| all.info.tsv                   | 275,986 |

## Phylogenetics with fungi61 #与真菌的系统发育

### Find corresponding proteins by `hmmsearch` #通过`hmmsearch`查找相应的蛋白质

#hmmsearch是 HMMER 软件包中的一个命令行工具，用于执行隐藏马尔可夫模型（HMM）搜索。HMMER 是一个常用的用于序列比对和分析的工具。马尔可夫模型是一种用于描述序列数据的统计模型，它基于状态和状态之间的转移概率，以及观测结果和状态之间的观测概率。
* 61 fungal marker genes #61个真菌标记基因
    * Ref.: https://doi.org/10.1093/nar/gkac894

* The `E_VALUE` was manually adjusted to 1e-20 to reach a balance between sensitivity and
  speciality. #E_VALUE”手动调整到1e-20，以达到灵敏度和特异性

"E_VALUE" 用于评估序列比对或匹配结果的统计显著性。E 值（Expectation value）是指预期在随机情况下观察到与给定比对或匹配结果同等或更差的结果的次数。E 值越小，表示比对或匹配结果越显著或更可信。通常，E 值小于某个阈值（如0.001或0.05）被认为是统计上显著的。较小的 E 值意味着比对或匹配结果更有可能是由真实的生物学相关性引起的，而不是由于偶然的随机事件。

```shell
cd /mnt/c/shengxin/data/Trichoderma/

# The fungi61 HMM set
nwr kb fungi61 -o HMM #从名为 "fungi61" 的知识库（KB）中提取信息，并将结果输出到 "HMM" 目录中
cp HMM/fungi61.lst HMM/marker.lst

E_VALUE=1e-20 #E 值被设置为 1e-20，即 1 乘以 10 的负 20 次方。这表示 E 值非常小且接近于零。这里表示比对结果非常显著，基本可以排除偶然的随机事件，更可能由真实的生物学相关性引起。

sudo apt install hmmer

# Find all genes #使用HMM模型对给定标记（marker）的蛋白质数据进行搜索和分析，并生成相应的分析结果。
for marker in $(cat HMM/marker.lst); do  #marker :变量
    echo >&2 "==> marker [${marker}]"

    mkdir -p Protein/${marker}

    cat Protein/species.tsv |
        tsv-join -f ASSEMBLY/pass.lst -k 1 |
        tsv-join -e -f MinHash/abnormal.lst -k 1 |
        tsv-join -e -f ASSEMBLY/omit.lst -k 1 |
        parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 "
            if [[ ! -d ASSEMBLY/{2}/{1} ]]; then
                exit
            fi

            gzip -dcf ASSEMBLY/{2}/{1}/*_protein.faa.gz |
                hmmsearch -E ${E_VALUE} --domE ${E_VALUE} --noali --notextw HMM/hmm/${marker}.HMM - |
                grep '>>' |
                perl -nl -e ' m(>>\s+(\S+)) and printf qq(%s\t%s\n), \$1, {1}; '
        " \
        > Protein/${marker}/replace.tsv

    echo >&2
done

```

### Align and concat marker genes to create species tree #比对和合并标记基因，创建物种树

```shell
cd /mnt/c/shengxin/data/Trichoderma/

cat HMM/marker.lst |
    parallel --no-run-if-empty --linebuffer -k -j 4 '
        cat Protein/{}/replace.tsv |
            wc -l
    ' |
    tsv-summarize --quantile 1:0.25,0.5,0.75
#25      25      56

cat HMM/marker.lst |
    parallel --no-run-if-empty --linebuffer -k -j 4 '
        echo {}
        cat Protein/{}/replace.tsv |
            wc -l
    ' |
    paste - - |#用于将两个相邻的行以制表符分隔连接在一起。它通常用于将行进行两两配对，方便进行比较或合并操作。
    tsv-filter --invert --ge 2:20 --le 2:30 |#--invert 命令用于反转筛选结果，即保留未被筛选条件满足的行，并删除满足筛选条件的行；即保留第二列不在20-30之间的
    cut -f 1 \
    > Protein/marker.omit.lst

# Extract sequences ##提取序列
# Multiple copies slow down the alignment process #多个拷贝减慢对齐过程
sudo apt-get install muscle

cat HMM/marker.lst |
    grep -v -Fx -f Protein/marker.omit.lst |
    parallel --no-run-if-empty --linebuffer -k -j 4 '
        echo >&2 "==> marker [{}]"#[{}] 是一个占位符，它表示并行执行的作业编号。在实际运行时，{} 将被具体的作业编号替换。

        cat Protein/{}/replace.tsv \
            > Protein/{}/{}.replace.tsv

        faops some Protein/all.uniq.fa.gz <(
            cat Protein/{}/{}.replace.tsv |
                cut -f 1 |
                tsv-uniq
            ) stdout \
            > Protein/{}/{}.pro.fa
    '

# Align each markers with muscle
cat HMM/marker.lst |
    parallel --no-run-if-empty --linebuffer -k -j 8 '
        echo >&2 "==> marker [{}]"
        if [ ! -s Protein/{}/{}.pro.fa ]; then
            exit
        fi
        if [ -s Protein/{}/{}.aln.fa ]; then
            exit
        fi

        muscle -quiet -in Protein/{}/{}.pro.fa -out Protein/{}/{}.aln.fa
    '
 # MUSCLE （MUltiple Sequence Comparison by Log-Expectation）工具进行蛋白质序列的多重比对。它包含以下参数和选项：
        -quiet：在运行过程中禁止输出额外的信息或警告，使输出更简洁

for marker in $(cat HMM/marker.lst); do
    echo >&2 "==> marker [${marker}]"
    if [ ! -s Protein/${marker}/${marker}.pro.fa ]; then
        continue
    fi

    # sometimes `muscle` can not produce alignments 
    if [ ! -s Protein/${marker}/${marker}.aln.fa ]; then
        continue
    fi

    # 1 name to many names  #处理名称的替换关系，将输入文件中的特定部分的名称替换为 Protein/${marker}/${marker}.replace.tsv 文件中的内容。
    cat Protein/${marker}/${marker}.replace.tsv |
        parallel --no-run-if-empty --linebuffer -k -j 4 "
            faops replace -s Protein/${marker}/${marker}.aln.fa <(echo {}) stdout
        " \
        > Protein/${marker}/${marker}.replace.fa
done


# Concat marker genes
for marker in $(cat HMM/marker.lst); do
    if [ ! -s Protein/${marker}/${marker}.pro.fa ]; then
        continue
    fi
    if [ ! -s Protein/${marker}/${marker}.aln.fa ]; then
        continue
    fi

    # sequences in one line
    faops filter -l 0 Protein/${marker}/${marker}.replace.fa stdout

    # empty line for .fas
    echo
done \
    > Protein/fungi61.aln.fas
#目的是将文件 Protein/${marker}/${marker}.replace.fa 中的序列合并为一行，并将结果保存为 .fas 格式的文件。然后，将所有标记的处理结果输出到文件 Protein/fungi61.aln.fas 中


cat Protein/species.tsv |
    tsv-join -f ASSEMBLY/pass.lst -k 1 |
    tsv-join -e -f MinHash/abnormal.lst -k 1 |
    tsv-join -e -f ASSEMBLY/omit.lst -k 1 |
    cut -f 1 |
    fasops concat Protein/fungi61.aln.fas stdin -o Protein/fungi61.aln.fa #会把 Protein/fungi61.aln.fas 文件和标准输入流（stdin）中的内容连接在一起，并将结果保存到 Protein/fungi61.aln.fa 文件中。

# Trim poorly aligned regions with `TrimAl` #用“TrimAl”修剪比对差的区域
#TrimAl用于对多序列比对结果进行修剪和过滤。它可以去除比对序列中的缺失或低质量的区域，以及处理序列间的间隙。

brew install brewsci/bio/trimal

trimal -in Protein/fungi61.aln.fa -out Protein/fungi61.trim.fa -automated1 #保留保守区域

#计算多个 FASTA 文件中序列的长度，并输出唯一的序列长度。
faops size Protein/fungi61.*.fa |
    tsv-uniq -f 2 |
    cut -f 2
#28706
#20432

# To make it faster
brew install brewsci/bio/fasttree

FastTree -fastest -noml Protein/fungi61.trim.fa > Protein/fungi61.trim.newick
#-fastest选项可以使用最快的算法来构建进化树，而-noml选项表示禁用最大似然优化。

nw_reroot Protein/fungi61.trim.newick Sa_cer_S288C |
    nw_order -c n - \
    > Protein/fungi61.reroot.newick

# png
nw_display -s -b 'visibility:hidden' -w 1200 -v 20 Protein/fungi61.reroot.newick |
    rsvg-convert -o tree/Trichoderma.marker.png

```

## Groups and targets

Grouping criteria: #分组标准

* The mash tree and the marker protein tree
* `MinHash/groups.tsv` #group编号不同

Target selecting criteria:

* `ASSEMBLY/collect.pass.tsv`
* Prefer Sanger sequenced assemblies
* RefSeq_category with `Representative Genome`
* Assembly_level with `Complete Genome` or `Chromosome`

Create a Bash `ARRAY` manually with a format of `group::target`. #"::"表示两个冒号符号的字符串分隔符。它用于将"target"标识符作为"group"的子项或属性。

```shell
mkdir -p /mnt/c/shengxin/data/Trichoderma/taxon
cd /mnt/c/shengxin/data/Trichoderma/taxon

cat ../ASSEMBLY/collect.pass.tsv |
    tsv-filter -H --str-eq annotations:Yes --le C:100 |
    tsv-select -H -f name,Assembly_level,Genome_coverage,Sequencing_technology,N50,C \
    > potential-target.tsv

cat ../ASSEMBLY/collect.pass.tsv |
    tsv-filter -H --or \
        --str-eq Assembly_level:"Complete Genome" \
        --str-eq Assembly_level:"Chromosome" \
        --le C:50 |
    tsv-select -H -f name,Assembly_level,Genome_coverage,Sequencing_technology,N50,C \
    > complete-genome.tsv

echo -e "#Serial\tGroup\tTarget\tCount" > group_target.tsv

# groups according `groups.tsv` #后面的是不同的group，如'C_E_H::E_web_GCA_001278495_1'是该group下的参考菌株
ARRAY=(
    'C_E_H::E_web_GCA_001278495_1' # 1
    'T_afr_har::T_har_CGMCC_20739_GCA_019097725_1' # 3
    'T_asperello_asperellum::T_asperellum_FT101_GCA_020647865_1' # 5
    'T_atrov_koningio::T_atrov_IMI_206040_GCF_000171015_1' # 6
    'T_cit_lon_ree::T_ree_QM6a_GCF_000167675_1' # 7
    'T_vire::T_vire_Gv29_8_GCF_000170995_1' # 8
)

for item in "${ARRAY[@]}" ; do
    GROUP_NAME="${item%%::*}"
    TARGET_NAME="${item##*::}" #`##` 表示从字符串的开头开始

    SERIAL=$(
        cat ../MinHash/groups.tsv |
            tsv-filter --str-eq 2:${TARGET_NAME} |
            tsv-select -f 1
    )

    cat ../MinHash/groups.tsv |
        tsv-filter --str-eq 1:${SERIAL} |
        tsv-select -f 2 |
        tsv-join -f ../ASSEMBLY/url.tsv -k 1 -a 3 \  #-a 附加
        > ${GROUP_NAME}

    COUNT=$(cat ${GROUP_NAME} | wc -l )

    echo -e "${SERIAL}\t${GROUP_NAME}\t${TARGET_NAME}\t${COUNT}" >> group_target.tsv

done

# Custom groups #自定义分组
ARRAY=(
    'Trichoderma::T_ree_QM6a_GCF_000167675_1'
    'Trichoderma_reesei::T_ree_QM6a_GCF_000167675_1'
    'Trichoderma_asperellum::T_asperellum_FT101_GCA_020647865_1'
    'Trichoderma_harzianum::T_har_CGMCC_20739_GCA_019097725_1'
    'Trichoderma_atroviride::T_atrov_IMI_206040_GCF_000171015_1'
    'Trichoderma_virens::T_vire_Gv29_8_GCF_000170995_1'
)

SERIAL=100
for item in "${ARRAY[@]}" ; do
    GROUP_NAME="${item%%::*}"
    TARGET_NAME="${item##*::}"

    SERIAL=$((SERIAL + 1))
    GROUP_NAME_2=$(echo $GROUP_NAME | tr "_" " ")

    if [ "$GROUP_NAME" = "Trichoderma" ]; then
        cat ../ASSEMBLY/collect.pass.tsv |
            tsv-filter -H --not-blank RefSeq_category | #过滤出 RefSeq_category 列不为空的行。
            sed '1d' |
            tsv-select -f 1 \
            > T.tmp
        echo "C_pro_CCMJ2080_GCA_004303015_1" >> T.tmp
        echo "E_web_EWB_GCA_003055145_1" >> T.tmp
        echo "E_web_GCA_001278495_1" >> T.tmp
        echo "H_perniciosus_HP10_GCA_008477525_1" >> T.tmp
        echo "H_ros_CCMJ2808_GCA_011799845_1" >> T.tmp
        cat T.tmp |
            tsv-uniq |
            tsv-join -f ../ASSEMBLY/url.tsv -k 1 -a 3 \
            > ${GROUP_NAME}

    else
        cat ../ASSEMBLY/collect.pass.tsv |
            tsv-select -f 1,2 |
            grep "${GROUP_NAME_2}" |
            tsv-select -f 1 |
            tsv-join -f ../ASSEMBLY/url.tsv -k 1 -a 3 \
            > ${GROUP_NAME}
    fi

    COUNT=$(cat ${GROUP_NAME} | wc -l )

    echo -e "${SERIAL}\t${GROUP_NAME}\t${TARGET_NAME}\t${COUNT}" >> group_target.tsv

done

cat group_target.tsv |
    mlr --itsv --omd cat |
    perl -nl -e 's/-\s*\|$/-:|/; print'

```

| #Serial | Group                  | Target                             | Count |
|---------|------------------------|------------------------------------|------:|
| 1       | C_E_H                  | E_web_GCA_001278495_1              |     5 |
| 3       | T_afr_har              | T_har_CGMCC_20739_GCA_019097725_1  |    20 |
| 5       | T_asperello_asperellum | T_asperellum_FT101_GCA_020647865_1 |    16 |
| 6       | T_atrov_koningio       | T_atrov_IMI_206040_GCF_000171015_1 |    15 |
| 7       | T_cit_lon_ree          | T_ree_QM6a_GCF_000167675_1         |    25 |
| 8       | T_vire                 | T_vire_Gv29_8_GCF_000170995_1      |     9 |
| 101     | Trichoderma            | T_ree_QM6a_GCF_000167675_1         |    32 |
| 102     | Trichoderma_reesei     | T_ree_QM6a_GCF_000167675_1         |    13 |
| 103     | Trichoderma_asperellum | T_asperellum_FT101_GCA_020647865_1 |    13 |
| 104     | Trichoderma_harzianum  | T_har_CGMCC_20739_GCA_019097725_1  |    10 |
| 105     | Trichoderma_atroviride | T_atrov_IMI_206040_GCF_000171015_1 |     7 |
| 106     | Trichoderma_virens     | T_vire_Gv29_8_GCF_000170995_1      |     8 |

## Prepare sequences for `egaz`

* `--perseq` for Chromosome-level assemblies and targets
    * means split fasta by names, targets or good assembles should set it

#'perseq'用于染色体水平的组装和目标
 表示按名称拆分fasta，目标或良好的组装应该设置它

```shell
cd /mnt/c/shengxin/data/Trichoderma

# /share/home/wangq/homebrew/Cellar/repeatmasker@4.1.1/4.1.1/libexec/famdb.py \
#   -i /share/home/wangq/homebrew/Cellar/repeatmasker@4.1.1/4.1.1/libexec/Libraries/RepeatMaskerLib.h5 \#"-i" 是一种常见的参数选项语法，用于指定输入文件或输入数据。这里指输入
#   lineage Fungi

#Cellar是 Homebrew 包管理器在 macOS 系统上的默认安装目录之一
#famdb.py 是 RepeatMasker 软件套件中的一个 Python 脚本，用于管理和查询 RepeatMasker 库中的元数据信息。famdb.py 脚本使用 HDF5 库来解析和操作 RepeatMaskerLib.h5 文件，从中提取有关重复元素的信息。
#RepeatMaskerLib.h5 是 RepeatMasker 库的文件，它包含了用于重复元素分析和注释的参考序列数据。RepeatMaskerLib**.h5 文件使用 HDF5 (Hierarchical Data Format 5 分层数据格式5) 格式进行存储。
#"libexec" 是一个特定的目录，常见于许多软件包的文件系统结构中。在一个软件包中，"libexec" 目录通常用于存放可执行文件或脚本，这些文件是供软件包内部使用的，并不直接暴露给用户或其他程序。"libexec" 目录与其他目录（如 "bin" 目录）的区别在于，它更多地用于存放对软件包的实现和内部功能有关的文件，而不是供用户直接调用的命令行工具或可执行文件。


# prep
egaz template \
    ASSEMBLY \
    --prep -o Genome \
    $( cat taxon/group_target.tsv |
        sed -e '1d' | cut -f 3 |
        parallel -j 1 echo " --perseq {} " #将前面输出内容其作为 --perseq 的参数传递给 egaz 命令
    ) \
    $( cat taxon/complete-genome.tsv |
        sed '1d' | cut -f 1 |
        parallel -j 1 echo " --perseq {} "
    ) \
    --min 5000 --about 5000000 \
    -v --repeatmasker "--parallel 16" 
    #-v: 用于打开详细的输出模式
    #RepeatMasker 是一个用于 DNA 序列的重复元素注释工具。它可以识别和屏蔽（或 "遮蔽"）DNA 序列中的重复元素，通过注释和遮蔽这些重复元素，可以避免在基因组研究和分析中对它们的重复计数或影响造成困扰。

bash Genome/0_prep.sh

# gff
for n in \
    $(cat taxon/group_target.tsv | sed -e '1d' | cut -f 3 ) \
    $( cat taxon/potential-target.tsv | sed -e '1d' | cut -f 1 ) \
    ; do
    FILE_GFF=$(find ASSEMBLY -type f -name "*_genomic.gff.gz" | grep "${n}")
    echo >&2 "==> Processing ${n}/${FILE_GFF}"  #输出一条提示信息到标准错误流，指示正在处理哪个目录和文件

    gzip -dcf ${FILE_GFF} > Genome/${n}/chr.gff
done

```

## Generate alignments 生成比对

```shell
cd /mnt/c/shengxin/data/Trichoderma

cat taxon/group_target.tsv |
    sed -e '1d' |
    parallel --colsep '\t' --no-run-if-empty --linebuffer -k -j 1 '
        echo -e "==> Group: [{2}]\tTarget: [{3}]\n"  #显示当前处理的组和目标

        egaz template \
            Genome/{3} \
            $(cat taxon/{2} | cut -f 1 | grep -v -x "{3}" | xargs -I[] echo "Genome/[]") \
            --multi -o groups/{2}/ \ 
            --tree MinHash/tree.nwk \
            --parallel 16 -v

        bash groups/{2}/1_pair.sh
        bash groups/{2}/3_multi.sh
    '
# --multi：用于指定多样性分析模式。

在分析基因组数据时，不同的基因组可能包含不同的目标序列。使用 --multi 选项可以同时处理多个目标序列，并生成相应的结果。

当使用 --multi 选项时，egaz template 命令会对每个目标序列分别进行处理，并生成独立的结果文件。这样，可以一次性处理多个目标序列，而不需要多次运行命令。

# clean
find groups -mindepth 1 -maxdepth 3 -type d -name "*_raw" | parallel -r rm -fr
find groups -mindepth 1 -maxdepth 3 -type d -name "*_fasta" | parallel -r rm -fr
find . -mindepth 1 -maxdepth 3 -type f -name "output.*" | parallel -r rm

#-r 参数用于避免同时并行执行太多的任务，以保持系统资源的合理利用
```
