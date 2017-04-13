---
title: 連続する数列をハイフンでまとめるピュアシェルスクリプト
tags: [sh, shell]
layout: default
---

Twitter の俺の TL にこんなネタが流れてきた。現実逃避にはもってこいのネタ。

* 連続する数列をハイフンでまとめるシェルスクリプト - ザリガニが見ていた...。
    * <http://d.hatena.ne.jp/zariganitosh/20131127/succession_hyphen_number>
* Rubyでどう書く？：連続した数列を範囲形式にまとめたい．いや，Rubyで書かない． | 上田さんのブログ
    * <http://blog.ueda.asia/?p=1663>
* awkで連続した数列を範囲形式に - jarp,
    * <http://jarp.does.notwork.org/diary/201311c.html#201311271>
* TL で見かけた回答ツイート
    * <https://twitter.com/RobustHunter/status/405552789876523008>
    * <https://twitter.com/uspmag/status/405730524733247488>
    * <https://twitter.com/masaru0714/status/405740108948598784>

真の shellist たるもの、外部コマンドに頼ってはいけない(適当)。
というわけで、ピュアシェルスクリプトをどうぞ。

``` bash
read i;s=${i%% *};let p=x=s-1;for n in $i x;do((n-p-1))&&{((p-x))&&o=$o-$p;o=$o,\ $n;x=$n;};p=$n;done;o=$s${o#-$s};echo ${o%, x}.
```

…ツイート用に 140文字以内に収めるのに必死ですみません。
ふつうの `sh` だと流石に無理(?)なので、`bash`, `ksh` 前提です。
ちなみに、負数を与えても大丈夫です。

インデントして少し見易くしたのが以下。超適当ですな。


``` bash
#!/bin/bash
# or
#!/bin/ksh

read i
s=${i%% *}
let p=x=s-1


for n in $i x; do
  ((n-p-1)) && {
    ((p-x)) && o=$o-$p
    o=$o,\ $n
    x=$n
  }
  p=$n
done

o=$s${o#-$s}
echo ${o%, x}.
```

