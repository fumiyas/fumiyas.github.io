---
title: 連続する数列をハイフンでまとめるピュアシェルスクリプト
tags: [sh, shell]
layout: default
---

Twitter の俺の TL にこんなネタが流れてきた。現実逃避にはもってこいのネタ。

  * 連続する数列をハイフンでまとめるシェルスクリプト - ザリガニが見ていた...。
    * http://d.hatena.ne.jp/zariganitosh/20131127/succession_hyphen_number
  * TL で見かけた回答ツイート
    * https://twitter.com/uspmag/status/405719369071616001
    * https://twitter.com/RobustHunter/status/405552789876523008

真の shellist たるもの、外部コマンドに頼ってはいけない(適当)。
というわけで、ピュアシェルスクリプトをどうぞ。

``` bash
read i;s=${i%% *};let p=x=s-1;f(){((n-p-1))&&{((p-x))&&o=$o-$p;o=$o,$n;x=$n;};};for n in $i;do f;p=$n;done;let n++;f;echo $s${o#-$s}
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

f() {
  ((n-p-1)) && {
    ((p-x)) && o=$o-$p
    o=$o,$n
    x=$n
  }
}

for n in $i; do
  f
  p=$n
done
let n++
f
echo $s${o#-$s}
```

