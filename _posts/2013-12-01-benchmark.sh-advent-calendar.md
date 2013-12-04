---
title: bash, ksh, zsh の速度比較 - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013]
(http://www.adventar.org/calendars/212)、1日目の記事です。

「このくらいの要件ならシェルで書ける!」と意気込んで実装を開始して、
たとえやりきっても「あー、やっぱり (あなたの好きな LL) で書けばよかった」
なんてことありませんか? 私はあまりありません。
POSIX シェルやそれ以前の非力なシェルはともかく、bash や ksh、zsh
のような拡張 POSIX シェルであれば、少し無理をすれば、大抵の処理は書けます。
老害ですね、わかります。

しかし実装は問題ないのですが、速度がいまひとつなのはどうしても否めません。
そこで一つ、少しでも実行速度を改善する簡単な方法を伝授しましょう。
それは「bash は避ける」です。

過去の経験から bash が遅いということに気付いていたのですが、
今回はベンチマークを取ることで検証してみました。

環境:

``` console
$ grep 'model name' /proc/cpuinfo |head -n1
model name      : Intel(R) Core(TM) i7-2620M CPU @ 2.70GHz
$ lsb_release -a
No LSB modules are available.
Distributor ID: Debian
Description:    Debian GNU/Linux unstable (sid)
Release:        unstable
Codename:       sid
$ bash --version |head -n1
GNU bash, バージョン 4.2.45(1)-release (x86_64-pc-linux-gnu)
$ ksh --version
  version         sh (AT&T Research) 93u+ 2012-08-01
$ zsh --version
zsh 5.0.2 (x86_64-pc-linux-gnu)
```

結果: 各数値は「秒数 (bash比)」です。

``` console
$ zsh ./sh-benchmark.zsh
| bash           | ksh            | zsh            |
|  0.32 ( 100.0) |  0.06 (  18.9) |  0.05 (  16.0) | Parameter Expansion 1: "$PARAMETER"
|  0.91 ( 100.0) |  0.11 (  12.2) |  0.10 (  11.0) | Parameter Expansion 2: $PARAMETER
|  4.61 ( 100.0) |  2.34 (  50.8) |  3.08 (  67.0) | Parameter Expansion 3: "${PARAMETER##*/}" (modifier)
|  5.43 ( 100.0) |  0.10 (   1.8) | 78.74 (1449.0) | Array Parameter Expansion 1: "${ARRAY[1]}" (one element)
|  7.08 ( 100.0) |  0.63 (   8.9) | 11.12 ( 157.2) | Array Parameter Expansion 2: "${ARRAY[@]}" (all elements)
| 13.19 ( 100.0) | 11.37 (  86.2) |  6.31 (  47.8) | Arithmetic Evaluation 1: let EXPRESSION
|  9.32 ( 100.0) |  4.65 (  49.9) |  3.33 (  35.8) | Arithmetic Evaluation 2: ((EXPRESSION))
| 13.02 ( 100.0) |  9.97 (  76.6) |  4.82 (  37.0) | Arithmetic Expansion 1: $((EXPRESSION))
| 16.67 ( 100.0) | 10.86 (  65.2) |  5.31 (  31.9) | Arithmetic Expansion 2: $(($PARAMETER+EXPRESSION))
|  6.53 ( 100.0) |  3.50 (  53.6) |  2.38 (  36.5) | Test 1: [[ EXPRESSION ]]
| 16.13 ( 100.0) |  4.20 (  26.0) | 10.30 (  63.8) | Test 2: [ EXPRESSION ]
|  6.65 ( 100.0) | 38.53 ( 579.3) |  5.63 (  84.6) | Fork
| 13.76 ( 100.0) |  7.96 (  57.8) | 14.48 ( 105.2) | Fork & Exec
|  2.91 ( 100.0) |  0.21 (   7.2) |  1.77 (  60.9) | Iterate Parameters 1; for
| 29.57 ( 100.0) |  0.08 (   0.3) |  5.18 (  17.5) | Iterate Parameters 2: while shift
| 72.66 ( 100.0) |  0.19 (   0.3) |  5.65 (   7.8) | Iterate Parameters 3: while ((n++<$#))
```

ksh は fork 以外 (プロセス置換以外かも)、zsh は配列パラメーターの展開以外、
bash より高速であることがわかりました。

各ベンチマークの内容: {% assign github_quote_file = "2013/12/01/sh-benchmark-scripts.sh" %}
{% include github-quote-file.html %}

変なところに bash, ksh, zsh の違いがあったり、
`{1..1000000}` の右辺を増やしすぎると ksh が `Memory fault` と言って死んだり、
意外と作るのに苦労しました。

ベンチマークの前処理で `$(zsh -c "echo {1..1000000}")` のように一部
zsh を利用していますが、これは今回利用した bash 4.2 に
`{1..1000000}` に絡む処理をやらせた場合に、異様に遅い問題があったためです。
たとえば次の例を実行したとき数分待っても終わらないんですが。
bash 3.0, 3.2, 4.1 では数秒で終了します。

``` console
$ time bash -c 'i=( {1..1000000} );'
```

ベンチマークスクリプト: {% assign github_quote_file = "2013/12/01/sh-benchmark.zsh" %}
{% include github-quote-file.html %}

* * *

{% include wishlist-dec.html %}

