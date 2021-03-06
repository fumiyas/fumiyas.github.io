---
title: シェルスクリプト初期化処理のお約束 - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013](http://www.adventar.org/calendars/212)、24日目の記事です。
[アドベントカレンダーって 24までらしい](https://ja.wikipedia.org/wiki/%E3%82%A2%E3%83%89%E3%83%99%E3%83%B3%E3%83%88%E3%82%AB%E3%83%AC%E3%83%B3%E3%83%80%E3%83%BC)ですよ? 今日で最終日ですよね?! ねっ???
あれ、[25日まであるのもチラホラ?](https://www.google.com/search?q=%E3%82%A2%E3%83%89%E3%83%99%E3%83%B3%E3%83%88%E3%82%AB%E3%83%AC%E3%83%B3%E3%83%80%E3%83%BC&tbm=isch)
後半、奇跡的にネタが発生したりしてなんとか間に合いましたが、もう[進捗駄目です](https://www.google.com/search?q=%E9%80%B2%E6%8D%97%E3%83%80%E3%83%A1%E3%81%A7%E3%81%99&tbm=isch)。
明日は期待しないでください。今日も適当な内容でごめんなさい。

実質的に最後の今日のお第は、シェルスクリプトの最初にすべきことです。
Perl スクリプトで `use strict; use warnings;` がお約束になっているように、
シェルにもいくつかお約束があります。

``` sh
#!/bin/sh

set -u
set -e
umask 0750
export PATH="/bin:/usr/bin"
export LANG="C"

## 以降、好きに書け！
```

`set -u` (必須)
----------------------------------------------------------------------

シェルオプション `-u` を有効にすると、未定義の変数 (シェル変数、環境変数)
を参照したときにエラーとなり、スクリプトを中断します。

変数名の綴り間違いをしたときの事故を防ぐのに有効です。

``` sh
#!/bin/sh

set -u
tmpdir="/var/lib/foo"

# …

rm -rf "$tempdir"/*
```

未定義の可能性がある変数を参照したいときは、条件付きの変数展開を利用します。
条件付き変数展開であれば、未定義でもエラーになりません。

``` sh
#!/bin/sh

set -u

## 変数が定義済みならその値を展開、未定義なら空文字列を展開
echo "${foo-}"
## 変数が定義済みならその値を展開、未定義なら指定の文字列を展開
echo "${foo-default}"
## 変数が定義済みなら空文字列を展開、未定義なら空文字列を展開
echo "${foo+}"
## 変数が定義済みなら指定の文字列を展開、未定義なら空文字列を展開
echo "${foo+default}"

if [ -n "${foo+set}" ]; then
  : 変数が設定されている(空文字列の場合も含む)場合の処理…
else
  : 変数が設定されていない場合の処理…
fi
```

`set -e` (~~推奨~~非推奨)
----------------------------------------------------------------------

罠が多いので非推奨にしておきます。気をつけて利用しましょう。

* シェルスクリプトの set -e は罠いっぱい - Togetterまとめ  
  <https://togetter.com/li/1104655>

実行したコマンドの終了コードが 0 以外の場合にスクリプトを中断します。
コマンド実行のたびにちゃんと終了コードをチェックし適切な対応をするコードになっているのであれば不要です。

例えば、以下のスクリプトはもし `cd "$workdir"`
などが失敗しても処理を継続してしまいますが、`set -e` しておけば、
いずれのコマンドが失敗した時点でスクリプトが中断され、安全です。

``` sh
#!/bin/sh

set -u
#set -e

workdir="/srv/project/workdir"

cd "$workdir"
rm -rf lib
make
```

コマンドの終了コードにより処理を分けたい場合は少し工夫が必要です。
下記の例では `{ 〜 }`
による複合コマンドとなっていますが、単一のコマンドでも問題ありません。

``` sh
#!/bin/sh

set -u
set -e

foo-cmd && {
  : 終了コードが 0 の場合の処理…
} || {
  case $? in
  1)
    : 終了コード 1 の場合の処理…
    ;;
  2)
    : 終了コード 2 の場合の処理…
    ;;
  *)
    : 終了コードがそれ以外の場合の処理…
    ;;
  esac
}
```

`set -e` を利用しない場合は次のようにその都度エラーかどうか検査する処理を書くとよいでしょう。

``` sh
#!/bin/sh

set -u

workdir="/srv/project/workdir"

cd "$workdir" || exit 1
rm -rf lib || exit 1
make
```

`umask 0750` (推奨。値は要件次第)
----------------------------------------------------------------------

何かしら機密情報を含むファイルを作成するスクリプトは `umask`
値を明示的に設定しておくべきです。

例えば以下のようなスクリプトは欠陥があります。
スクリプト起動時の `umask` が `077` よりも緩い設定の場合、
ファイルを作成してからファイルのパーミッションを調整して隠すまでの僅かな隙に、
ファイルの内容を盗み読まれる可能性があります。

``` sh
#!/bin/sh

echo '秘密' >secret.txt
chmod 0700 secret.txt
```

`export PATH="/bin:/usr/bin"` (推奨。値は要件次第)
----------------------------------------------------------------------

外部コマンドにパス名を含めていない場合は、
スクリプト起動時の環境変数 `$PATH`
の値に影響されないように設定しておいたほうが無難です。

`export LANG="C"` (要件次第)
----------------------------------------------------------------------

プログラムに依っては出力するメッセージや文字列処理がロケールによって変化するものがあります。
スクリプトがロケール設定に依存する作りになっているのであれば、
最初に環境変数でロケールを設定しておきましょう。

ロケールを設定する環境変数は `$LANG` 以外にも `$LC_種別` がいくつかあります。
オンラインマニュアル `setlocale`(3), `locale`(7) あたりを参照のこと。

おまけ: `IFS="スペース+タブ+改行"` (dash の場合)
----------------------------------------------------------------------

ワード展開と配列変数の変数展開時の結合文字に影響するシェル変数
`$IFS` は、そのデフォルト値はスペース、タブ、改行の 3文字で構成されています。

なんと dash は、環境変数 `$IFS`
が設定されていると、それをデフォルト値とします。
dash では `$IFS` を明示的に初期化したほうが無難です。

``` console
#!/bin/dash

# 見た目では判別は難しいが、$IFS をスペース、タブ、改行で初期化している
IFS=" 	
"

# …
```

BSD 系 OS の `/bin/sh` である ash (dash の派生元) も同じ仕様かもしれません。

* * *

メリークリスマス！！！！！！

* * *

{% include wishlist-dec.html %}
