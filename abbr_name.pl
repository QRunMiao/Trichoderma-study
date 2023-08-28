#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Getopt::Long qw();
#Getopt::Long 模块用于处理命令行选项。它允许你定义命令行参数，并解析命令行输入。通过使用 GetOptions 函数，你可以轻松地获取和处理命令行参数的值。
#qw(...) 是 Perl 中的引号词列表（quote word list）的语法结构。qw(...) 表示将括号中的字符串列表转换为一个由空格分隔的单词列表。它的作用是创建一个不包含引号和逗号的字符串列表。

use FindBin;#FindBin 是一个 Perl 模块，用于查找当前执行脚本的目录信息。使用 FindBin 模块可以方便地获取当前脚本的路径、目录和文件名等信息，而无需手动解析路径

use List::MoreUtils::PP;
#List::MoreUtils::PP 模块提供了一些方便的列表操作函数。这些函数包括 any、all、none、uniq、zip 等，可以简化对数组和列表的操作

#----------------------------------------------------------#
# GetOpt section
#----------------------------------------------------------#

=head1 NAME

abbr_name.pl - Abbreviate strain scientific names.#名称-功能简要描述（缩写菌株的学名）

=head1 SYNOPSIS #特殊注释块，用于提供代码示例或模块使用的简单示例；SYNOPSIS 概述

    cat <file> | perl abbr_name.pl [options]
      Options:
        --help              brief help message
        --column    -c  STR Columns of strain, species, genus, default is 1,2,3.#株、种、属的列，默认为1、2、3
                            If there's no strain, use 1,1,2.
                            Don't need the strain part, use 2,2,3
                            When there's only strain, use 1,1,1
        --separator -s  STR separator of the line, default is "\s+"#STR(字符串）行分隔符，默认为"\s+"
        --min INT           mininal length for abbreviation of species#物种缩写的最小长度
        --tight             no underscore between Genus and species#在属和种之间没有下划线
        --shortsub          clean subspecies parts#清除物种名称中的次级分类部分。

=head1 EXAMPLE

    $ echo -e 'Homo sapiens,Homo\nHomo erectus,Homo\n' |#智人；直立人
        perl abbr_name.pl -s ',' -c "1,1,2"
    Homo sapiens,Homo,H_sap
    Homo erectus,Homo,H_ere
    #-s ','：指定字段分隔符为逗号。
-c "1,1,2"：指定要缩写的字段索引。即会缩写输入数据中的第一个字段和第二个字段。
#Homo sapiens,Homo,H_sap
    Homo erectus,Homo,H_ere是输出结果

    $ echo -e 'Homo sapiens,Homo\nHomo erectus,Homo\n' |
        perl abbr_name.pl -s ',' -c "1,1,2" --tight
    Homo sapiens,Homo,Hsap
    Homo erectus,Homo,Here

    $ echo -e 'Homo sapiens,Homo\nHomo erectus,Homo\n' |
        perl abbr_name.pl -s ',' -c "1,2,2"
    Homo sapiens,Homo,H_sap
    Homo erectus,Homo,H_ere

    $ echo -e 'Homo sapiens sapiens,Homo sapiens,Homo\nHomo erectus,Homo erectus,Homo\n' |
        perl abbr_name.pl -s ',' -c "1,2,3" --tight
    Homo sapiens sapiens,Homo sapiens,Homo,Hsap_sapiens
    Homo erectus,Homo erectus,Homo,Here

    $ echo -e 'Homo\nHomo\nGorilla\n' |
        perl abbr_name.pl -s ',' -c "1,1,1"
    Homo,H
    Homo,H
    Gorilla,G

    $ echo -e 'Homo sapiens,Homo\nCandida albicans,Candida\n[Candida] auris,[Candida]\n[Candida] haemuloni,Candida/Metschnikowiaceae\n[Candida] boidinii,Ogataea\n' |
        perl abbr_name.pl -s ',' -c "1,1,2"
    Homo sapiens,Homo,H_sap
    Candida albicans,Candida,C_alb
    [Candida] auris,[Candida],Candida_auris
    [Candida] haemuloni,Candida/Metschnikowiaceae,Candida_haemuloni
    [Candida] boidinii,Ogataea,Candida_boidinii

    $ echo -e 'Legionella pneumophila subsp. pneumophila str. Philadelphia 1\nLeptospira interrogans serovar Copenhageni str. Fiocruz L1-130\n' |
        perl abbr_name.pl -s ',' -m 0 -c "1,1,1" --shortsub
    Legionella pneumophila subsp. pneumophila str. Philadelphia 1,Leg_pneumophila_pneumophila_Philadelphia_1
    Leptospira interrogans serovar Copenhageni str. Fiocruz L1-130,Lep_interrogans_Copenhageni_Fiocruz_L1_130

=cut

Getopt::Long::GetOptions(
    'help|?'        => sub { Getopt::Long::HelpMessage(0) },
    'column|c=s'    => \( my $column      = '1,2,3' ),
    'separator|s=s' => \( my $separator   = '\s+' ),
    'min|m=i'       => \( my $min_species = 3 ),
    'tight'         => \my $tight,
    'shortsub'      => \my $shortsub,
) or Getopt::Long::HelpMessage(1);


这段代码是一个使用 Getopt::Long 模块解析命令行参数的 Perl 脚本。

- `help|?`：如果提供了 `-help` 或 `-?` 参数，则调用 `Getopt::Long::HelpMessage(0)` 函数显示帮助信息。
- `column|c=s`：指定要处理的字段索引，参数值为一个字符串。默认情况下，字段索引为 "1,2,3"。
- `separator|s=s`：指定字段的分隔符，参数值为一个字符串。默认情况下，字段分隔符为空白字符 `\s+`。
- `min|m=i`：指定要处理的最小物种数量，参数值为一个整数。默认情况下，最小物种数量为 3。
- `tight`：启用紧凑输出模式
- `shortsub`：使用短缩写模式

#----------------------------------------------------------#
# init
#----------------------------------------------------------#
$|++;

#----------------------------------------------------------#
# start
#----------------------------------------------------------#
my @columns = map { $_ - 1 } split( /,/, $column );#split 函数将 $column 字符串按逗号分隔成数组 @columns，并将数组中的元素减1
my @fields;#用于存储字段
my @rows;#储存行数据
while ( my $line = <> ) {
    chomp $line;#chomp 函数去除行末的换行符
    next if $line eq '';#如果行为空，跳过当前循环
    my @row = split /$separator/, $line;#将行数据按 s+进行 split，并使用 s/// 语句去除其中的双引号和单引号。
    s/"|'//g for @row;

    my ( $strain, $species, $genus ) = @row[@columns];#将该行指定列索引处的数据依次赋值给变量 $strain、$species 和 $genus。
    my $is_normal = 0;#初始化 $is_normal 变量为0。

    if ( $genus ne $species ) {#$genus 不等于 $species

        # not like [Candida]
        if ( $genus =~ /^\w/ ) {#若 $genus 的开头是一个单词字符（\w）

            # $species starts with $genus
            if ( rindex( $species, $genus, 0 ) == 0 ) {
#在 $species 字符串中从最后一个字符开始向前查找 $genus 子字符串，并返回最后一次出现的位置。第三个参数 0 表示从索引为0的位置开始查找（也就是整个字符串），而不是从末尾开始
#判断 $species 是否以 $genus 开头。如果条件成立（即返回值为0），则表示 $species 以 $genus 开头

                # $strain starts with $species#$species 是以 $genus 开头，继续判断
                if ( rindex( $strain, $species, 0 ) == 0 ) {
                    $strain =~ s/^\Q$species\E ?//;
#从 $strain 字符串中查找并删除以 $species 开头的部分，包括紧随其后的一个可选空格。替换操作会在原始字符串上进行
#$strain 是一个字符串变量，表示要进行替换操作的字符串。
#s/// 替换操作符。^ 表示匹配字符串的开头。\Q 和 \E 是用于转义正则表达式元字符的标记。在这里，它们将 $species 变量的内容视为普通文本，避免其中的特殊字符被解释为正则表达式元字符。
#$species 是一个变量，包含要替换掉的子字符串。
#? 是一个可选的空格字符，表示在替换时要删除的字符。
                    $species =~ s/^\Q$genus\E //;#

                    $is_normal = 1;
                }
            }
        }
    }

    # do not abbr species parts
    else {
        if ( $genus =~ /^\w/ ) {
            if ( rindex( $strain, $genus, 0 ) == 0 ) {
                $strain =~ s/^\Q$genus\E ?//;#若 $strain 是以 $genus 开头的，则将 $genus 从 $strain 的开头移除，
                $species   = '';#将 $species 置为空字符串
                $is_normal = 1;#将 $is_normal 设置为1
            }
        }
    }

#是用于去除字符串中的特定词汇和缩写
    # Remove `Candidatus`
    $genus =~ s/\bCandidatus \b/C/gi;
#将字符串中的所有匹配单词"Candidatus"替换为"C"。其中\b表示单词边界，gi表示全局匹配并忽略大小写。

    # Clean long subspecies names#清理长的亚种名称
    if ( defined $shortsub ) {
        $strain =~ s/\bsubsp\b//gi;#将字符串中的所有匹配单词"subsp"替换为空字符串
        $strain =~ s/\bserovar\b//gi; #血清型变种
        $strain =~ s/\bstr\b//gi;
        $strain =~ s/\bstrain\b//gi;
        $strain =~ s/\bsubstr\b//gi;
        $strain =~ s/\bserotype\b//gi; #血清型
        $strain =~ s/\bbiovar\b//gi; #生物亚种
        $strain =~ s/\bvar\b//gi;
        $strain =~ s/\bgroup\b//gi;
        $strain =~ s/\bvariant\b//gi;
        $strain =~ s/\bgenomovar\b//gi;
        $strain =~ s/\bgenomosp\b//gi;

        $strain =~ s/\bbreed\b//gi;
        $strain =~ s/\bcultivar\b//gi;
        $strain =~ s/\becotype\b//gi; #生态型

        $strain =~ s/\bn\/a\b//;
        $strain =~ s/\bNA\b//;

        $strain =~ s/\bmicrobial\b//gi;
        $strain =~ s/\bclinical\b//gi;
        $strain =~ s/\bpathogenic\b//gi;
        $strain =~ s/\bisolate\b//gi;
    }

    s/\W+/_/g for ( $strain, $species, $genus );#将字符串中的非字母数字字符都替换为下划线。对于数组($strain, $species, $genus)中的每个元素都执行该操作。
    s/_+/_/g  for ( $strain, $species, $genus );#将字符串中连续的多个下划线替换为单个下划线
    s/_$//    for ( $strain, $species, $genus );#将字符串末尾的下划线去除
    s/^_//    for ( $strain, $species, $genus );#将字符串开头的下划线去除

#将处理完的字符串作为元素添加到数组@fields和@rows中
    push @fields, [ $strain, $species, $genus, $is_normal ];

    push @rows, \@row;
}

my $count = scalar @fields;#通过 scalar @fields 计算 @fields 数组中元素的个数，将结果赋值给变量 $count

#map 函数对 @fields 数组进行处理，提取符合条件的元素到新的数组中。对于数组中的每个元素，如果其第四个值为真（非空），则分别将第三个和第二个值添加到 @ge 和 @sp 数组中
my @ge = map { $_->[3] ? $_->[2] : () } @fields;
#箭头操作符 ->，取出当前元素 $_ 中的第四个值 $_->[3]
#三元运算符 ? :，如果第四个值为真，则返回当前元素中的第三个值 $_->[2]；否则返回空列表 ()。
my @sp = map { $_->[3] ? $_->[1] : () } @fields;

my $ge_of = abbr_most( [ List::MoreUtils::PP::uniq(@ge) ], 1, "Yes" );
#函数 abbr_most 的作用是找到数组中出现频率最高的缩写，并返回对应的哈希引用
#这里的参数 [ List::MoreUtils::PP::uniq(@ge) ] 表示对 @ge 数组使用 List::MoreUtils::PP 模块中的 uniq 函数去除重复元素，然后将结果作为数组引用传递给 abbr_most 函数。
#YES表示缩写出现次数最高的那个键对应的值
my $sp_of =
  abbr_most( [ List::MoreUtils::PP::uniq(@sp) ], $min_species, "Yes" );# $min_species表示最小的物种数量阈值。

for my $i ( 0 .. $count - 1 ) {#使用 for 循环遍历数组 @fields 中的元素，其中 $i 从 0 到 $count - 1。
    if ( $fields[$i]->[3] ) {#当前元素的第四个值为真

        my $spacer = $tight ? '' : '_'; #选择合适的分隔符 $spacer（空字符串或下划线
        my $ge_sp  = join $spacer,
          grep { defined $_ and length $_ } $ge_of->{ $fields[$i]->[2] },
          $sp_of->{ $fields[$i]->[1] };#将经过筛选和去除空字符串后的 $ge_of->{ $fields[$i]->[2] } 和 $sp_of->{ $fields[$i]->[1] } 进行拼接，结果赋值给变量 $ge_sp。
        my $organism = join "_", grep { defined $_ and length $_ } $ge_sp,
          $fields[$i]->[0];#将经过筛选和去除空字符串后的 $ge_sp 和 $fields[$i]->[0] 进行拼接，结果赋值给变量 $organism。

        print join( ",", @{ $rows[$i] }, $organism ), "\n";#print 函数输出将 $rows[$i] 数组的元素、 $organism 变量的值以逗号分隔拼接的字符串，并换行。
    }
    else {#如果当前元素的第四个值为假，直接使用 print 函数输出将 $rows[$i] 数组的元素和 $fields[$i]->[0] 拼接的字符串，并换行。
        print join( ",", @{ $rows[$i] }, $fields[$i]->[0] ), "\n";
    }
}

exit;

# from core module Text::Abbrev#来自核心模块 Text::Abbrev 中的 abbr 子程序。它实现了生成缩写和对应原词的功能。
sub abbr {
    my $list = shift;#$list 是一个数组引用，包含要生成缩写的词列表。
    #在 Perl 中，shift 是一个数组函数，用于从数组的开头提取并返回第一个元素，并将数组中的其余元素向前移动。
#注意，shift 函数会修改原始数组，将其第一个元素移除。因此，在执行 shift 后，原始传入的参数列表将不再包含已移除的第一个元素。
    my $min  = shift;#$min 是一个表示最小缩写长度的参数，可选。如果不提供，则默认为 1。
    return {} unless @{$list};#如果 $list 是空数组，则返回一个空哈希引用 {}。

    $min = 1 unless $min;
    my $hashref = {};#创建一个空哈希引用 $hashref 和一个空哈希 %table
    my %table;

  WORD: for my $word ( @{$list} ) {#循环遍历 $list 中的每个单词，存储在变量 $word 中。
        for ( my $len = length($word) - 1 ; $len >= $min ; --$len ) {#从长度为 length($word) - 1 的子串开始，逐渐减小长度直到达到 $min
            my $abbrev = substr( $word, 0, $len );#substr 函数从 $word 中提取长度为 $len 的子串作为缩写
            #从字符串 $word 中提取从索引 0 开始的 $len 个字符
            my $seen   = ++$table{$abbrev};#增加 %table 中对应缩写的计数
            if ( $seen == 1 ) {    # We're the first word so far to have
                                   # this abbreviation.
                $hashref->{$abbrev} = $word;#如果是第一个出现该缩写的单词，将其存储在 $hashref 中以缩写为键，完整词为值。
                #$hashref 是一个哈希引用，存储了单词的缩写和原始单词的映射关系。$abbrev 是当前单词的缩写形式，而 $word 是对应的原始单词。通过将 $abbrev 作为键，$word 作为值，将它们存储在 $hashref 中，可以实现根据缩写快速查找到对应的原始单词。
            }
            elsif ( $seen == 2 ) {    # We're the second word to have this
                                      # abbreviation, so we can't use it.
                delete $hashref->{$abbrev};#如果是第二个出现该缩写的单词，说明该缩写已经有两个对应的词，删除 $hashref 中的对应项。
            }
            else {                    # We're the third word to have this
                                      # abbreviation, so skip to the next word.
                next WORD;#如果是第二个出现该缩写的单词，说明该缩写已经有两个对应的词，删除 $hashref 中的对应项。
            }
        }
    }

#这段代码的作用是将列表中的单词添加到哈希表中，并确保即使不是唯一的非缩写形式也会被输入到哈希表中。这意味着即使列表中有重复的单词，它们也会被全部添加到哈希表中，并且在哈希表中的键和值都是相同的。
    # Non-abbreviations always get entered, even if they aren't unique
    for my $word ( @{$list} ) {
        $hashref->{$word} = $word;#在每次循环中，将 $word 作为键和值，添加到哈希表 $hashref 中。
    }
    return $hashref;
}

sub abbr_most {
    my $list  = shift;
    my $min   = shift;
    my $creat = shift; # don't abbreviate 1 letter. "I'd spell creat with an e."
    return {} unless @{$list};#函数检查 $list 是否为空，如果为空，则返回一个空的哈希引用 {}。

    # don't abbreviate
    #如果 $min 等于 0，则创建一个空的哈希 %abbr_of，遍历 $list 中的每个单词，并将其作为键和值存入哈希 %abbr_of 中。最后，返回 %abbr_of 的引用 \%abbr_of
    if ( defined $min and $min == 0 ) {
        my %abbr_of;
        for my $word ( @{$list} ) {
            $abbr_of{$word} = $word;
        }
        return \%abbr_of;#在 Perl 编程语言中，\ 符号用于引用某个变量的引用（reference）。当在一个标量变量前添加 \ 时，表示对该变量的引用。
#\%abbr_of 表示对 %abbr_of 哈希变量的引用。
    }

    # do abbreviate#如果 $min 不为 0，则执行缩写逻辑
    else {
        my $hashref = $min ? abbr( $list, $min ) : abbr($list);
        my @ks      = sort keys %{$hashref};#对 $hashref 中的键进行排序，并将排序后的键存入数组 @ks 中
        my %abbr_of;#创建一个空的哈希 %abbr_of
        for my $i ( reverse( 0 .. $#ks ) ) {#逆序遍历 @ks 数组中的键
            if ( index( $ks[$i], $ks[ $i - 1 ] ) != 0 ) {
                $abbr_of{ $hashref->{ $ks[$i] } } = $ks[$i];  
            }
            #index($ks[$i], $ks[$i - 1]) != 0 是一个条件判断语句，用于检查 $ks[$i] 字符串中是否包含了 $ks[$i - 1] 子字符串，且子字符串出现的位置不是在开头（即索引不为0）。
#$ks[$i] 表示数组 @ks 的第 $i 个元素，$ks[$i - 1] 表示数组 @ks 的第 $i - 1 个元素，都是一个字符串。
#index($ks[$i], $ks[$i - 1]) 会在 $ks[$i] 字符串中搜索 $ks[$i - 1] 子字符串的第一次出现，并返回其起始位置索引。
#!= 0 则检查上一步返回的索引是否不等于0，即表示子字符串存在且不在开头。

            if ($creat) {
                for my $key ( keys %abbr_of ) {#遍历 %abbr_of 哈希表中的每个键，并将每个键赋值给变量 $key
                    if ( length($key) - length( $abbr_of{$key} ) == 1 ) {#检查当前键的长度减去对应值的长度是否等于1。如果条件满足，则执行条件块中的代码。
                        $abbr_of{$key} = $key;#将当前键的值设置为该键本身。这行代码的作用是将长度为键长度减1的值更新为键本身。
                    }
                }
            }
        }

        return \%abbr_of;
    }
}

__END__
