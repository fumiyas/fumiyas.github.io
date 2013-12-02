---
title: zsh でシェルスクリプトを書くときの留意点 - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013]
(http://www.adventar.org/calendars/212)、3日目の記事です。

[初日に「bash を避けて ksh や zsh で書くとスクリプトが速くなるよ!」]
(/2013/12/01/benchmark.sh-advent-calendar.html)
と紹介しましたが、実は zsh でふつうの sh なシェルスクリプトを書くと、色々ハマれます。
何が問題でどうすればいいのでしょうか。
いきなりですが、最初にどうすればいいかを紹介します。
スクリプトの先頭を以下のように書くだけです。
(`setopt BSD_ECHO` は後述します)

``` sh
#!/bin/zsh

## ksh エミュレーションモード
emulate -R ksh
## echo 組込みコマンドを BSD echo 互換にする
setopt BSD_ECHO

## 以下、ふつうに sh なシェルスクリプトを実装…
```

zsh は sh, ksh, csh (誰が使うの?) のエミュレーション機能を持っていて、
それを切り替えるのが組込みコマンド `emulate` です。
`-R` オプションを指定すると、各種シェルオプション (`zshoptions`(1) を参照)
を指定したシェルエミュレーションに合ったデフォルト値にリセットします。
こうすることで概ね ksh 互換の動きとなり、概ね POSIX sh や bash
に近い動きになります。

では、`emulate -R ksh` で具体的にどんなオプションが変化するのか見てみましょう。
`setopt` は `zshoptions`(1) 記載のオプションを設定する組込みコマンドですが、
引数なしに実行すると現在の設定を表示します。
ただし `KSH_OPTION_PRINT` オプションを有効にしないと既定値のものが表示されないので、
次のようにして一覧表示します。

``` console
$ zsh -c 'setopt KSH_OPTION_PRINT; setopt'
noaliases             off
allexport             off
...省略...
kshoptionprint        on
...省略...
nohashdirs            on
...省略...
```

この実行例のように、オプション名は `zshoptions`(1) 記載の
「大文字とアンダーバー」ではなく「小文字」で表示されます。
また、オプションは `setopt NO_オプション名` や `setopt NOオプション名`
のように指定(オプション名は大文字・小文字無視!、アンダーバー無視!)
すると無効にできるのですが、`setopt`
による一覧表示では左辺のオプション名の先頭に `no` が付いたり、 
代わりに右辺が `off` になったり、`no` であって `off` になったり(二重否定死ね)、
統一されていません。なんてわかりにくいんだ…。

そこで、まずはこの表示を正規化するフィルターを用意します。
(すべてシェルで実装してもいいのだけど素直に sed で :-)

``` console
$ zshoptions_normalize() {
  sed '/^nomatch/n; /^notify/n; s/^no\(.*\)on$/\1  off/; s/^no\(.*\)off$/\1  on/'
}
```

これを利用して、zsh の既定時と ksh エミュレーション時のオプションを比較してみます。

``` console
$ diff --side-by-side \
  <(zsh -c 'setopt KSH_OPTION_PRINT;setopt' |zshoptions_normalize) \
  <(zsh -c 'emulate ksh; setopt' |zshoptions_normalize) \
  |awk '/\|/{printf "%-20s%-4s%-4s\n", $1,$2,$5}'
badpattern          on  off 
banghist            on  off 
bareglobqual        on  off 
bgnice              on  off 
checkjobs           on  off 
cprecedences        off on  
equals              on  off 
evallineno          on  off 
functionargzero     on  off 
globalexport        on  off 
globsubst           off on  
hashdirs            off on  
hup                 on  off 
interactivecomments off on  
ksharrays           off on  
kshautoload         off on  
kshglob             off on  
kshtypeset          off on  
localoptions        off on  
localtraps          off on  
multifuncdef        on  off 
multios             on  off 
nomatch             on  off 
notify              on  off 
pathscript          off on  
posixaliases        off on  
posixbuiltins       off on  
posixcd             off on  
posixidentifiers    off on  
posixjobs           off on  
posixstrings        off on  
posixtraps          off on  
promptbang          off on  
promptpercent       on  off 
promptsubst         off on  
rmstarsilent        off on  
sharehistory        off on  
shfileexpansion     off on  
shglob              off on  
shnullcmd           off on  
shoptionletters     off on  
shortloops          on  off 
shwordsplit         off on  
singlelinezle       off on  
typesetsilent       off on  
```

思ったより沢山あったわ…。
左がオプション名、真ん中が zsh デフォルト時の設定、
右が ksh エミュレーション時の設定になります。

すべてを解説するのは面倒なので、sh なシェルスクリプトを書く上で特徴的なものだけ解説してみます。
ついでに後回しにしていた `BSD_ECHO` オプションの解説も。
(詳細は `zshoptions`(1) を参照。括弧内のオプション名は `zshoptions`(1) 記載の名前)

  * `bsdecho` (`BSD_ECHO`)
    * echo 組込みコマンドを BSD echo 互換にする。
      bash 互換。ksh は Linux や *BSD など、SystemV でない OS 上なら互換(だと思う。後述)。
    * zsh のデフォルトは bash の `echo -e <引数>` 相当、
      つまり引数中のエスケープシーケンスを解釈する。余計なことをしやがる…。
  * `ksharrays` (`KSH_ARRAYS`)
    * 配列パラメーターの添字を 0 オリジンにする。ksh, bash と互換。
    * zsh のデフォルトは 1 オリジン。なんでだよ…。
  * `globsubst` (`GLOB_SUBST`)
    * クォートなしのパラメーター展開時に展開後の値で glob 展開する。
    * zsh のデフォルトは glob 展開しない。
  * `nomatch` (`NOMATCH`)
    * glob 展開でマッチするファイルが存在しない場合に展開後の値を glob パターンそのままとする。
    * zsh のデフォルトはエラーになる。`zsh: no matches found: <glob パターン>`
    * 無効にするには `setopt NONOMATCH` のように二重否定にする。気持ち悪い。
  * `shwordsplit` (`SH_WORD_SPLIT`)
    * クォートなしのパラメーター展開時に展開された値を空白文字で分割(ワード分割)する。
    * zsh のデフォルトは空白文字分割しない。

`globsubst` と `shwordsplit` がよくわからない人のためのデモ:

``` console
$ zsh -c 'v="/*"; echo $v; setopt GLOB_SUBST; echo $v'
/*
/bin /boot /dev /etc /home /lib /lib32 /lib64 /lost+found /media /mnt /opt /proc /root /run /sbin /srv /sys /tmp /usr /var
$ zsh -c 'v=" foo "" bar "; echo $v; setopt SH_WORD_SPLIT; echo $v'
 foo  bar 
foo bar
```

なお `rmstarsilent` (`RM_STAR_SILENT`。`rm *` 実行時にユーザーに確認をとる)
は対話シェルの場合だけ機能するので、
シェルスクリプトの場合は `on` でも `off` でも関係ありません。

* * *

`emulate -R ksh` を利用せずに個別にオプションを設定して他 sh
との互換性を高める例を示します。
zsh 特有の挙動を利用したスクリプトを書く場合、
一部の挙動だけ他 sh 互換にしたいときはこのようにします。

``` sh
#!/bin/zsh

setopt BSD_ECHO
setopt KSH_ARRAYS
setopt GLOB_SUBST
setopt NO_NOMATCH
setopt SH_WORD_SPLIT
## ほかにもあれば、適宜 on / off する

## 以下、ふつうに sh なシェルスクリプトを実装…
```

zsh 専用のモジュールの中には zsh の既定のシェルオプション設定に依存しているものがあります。
外部モジュールを利用した zsh シェルスクリプトを書く場合は注意しましょう。
ログインシェルに zsh を利用しているなら、
`~/.zshrc` の先頭のほうに `emulate -R ksh` と書いてログインしてみると実感できるかと。

* * *

ちなみに、ksh の組込みコマンド `echo` は環境 (OS)
に依って動作が異なるというクソ仕様だったりします。
わざわざ OS の `echo`(1) (`/bin/echo`) に合わせているらしい。
なんてこった。

Advent Calendar ネタが尽きたら `echo` コマンドの闇に迫りたいと思います。

* * *

ところで12月25日はクリスマスな上に、
OSS 界隈で地味に活躍されているふみやすさんの誕生日ですね。

っ http://www.amazon.co.jp/registry/wishlist/27M7TV8CEEF6G?sort=priority
