---
title: コマンド種別の判定と使い分け - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013]
(http://www.adventar.org/calendars/212)、17日目の記事です。
時間がないのでやっつけです。間違いがあったらすみません…。

今日はシェルから起動するコマンドが何者かを知る方法と使い分ける方法を紹介します。

コマンドの種類
----------------------------------------------------------------------

シェルのコマンドラインから起動されるコマンドの種類として以下の 4つがあります。
(`for` などの制御構文は除く)

  1. シェルのコマンドエイリアス
  2. シェルの関数
  3. シェルの組込みコマンド
  4. 外部のコマンド

ほかにもあったっけ? いまいち自信なし。
エイリアスがコマンドかどうかはさておく。

コマンド種別の判定方法
----------------------------------------------------------------------

シェルの種類に依って色々な判定方法があるのですが、
一番ポータブルなのは組込みコマンド `type` を利用する方法です
旧来の sh でも使えます。

``` console
$ type コマンド名
```

bash での `type` コマンドの出力例:

``` console
$ alias aliasname='echo foo'
$ type aliasname
aliasname は `echo foo' のエイリアスです
$ function functionname { echo foo; }
$ type functionname
functionname は関数です
functionname ()
{
    echo foo
}
$ type type
type はシェル組み込み関数です
$ type ls
ls はハッシュされています (/bin/ls)
$ type for
for はシェルの予約語です
```

bash の `type` はシェル関数の内容も表示してくれますが、
ksh, zsh では `関数名 is a shell function` とだけ表示します。
関数の内容を表示するには `typeset -f 関数名` を実行します。
(bash でも使用可能)

同名のコマンドが存在する場合の優先順位
----------------------------------------------------------------------

各コマンド種類に同名のものが存在する場合は、
エイリアス、関数、組込みコマンド、外部コマンドの順位でコマンドが決まります。

以下は zsh での例です。
(`disable true` は組込みコマンド `true` の無効化、`enable true`
は有効化をしています)

``` console
$ zsh
% disable true
% type true
true is /bin/true
% enable true
% type true
true is a shell builtin
% function true { /bin/true; }
% type true
true is a shell function
% alias true='/bin/true'
% exit
```

コマンド種別を使い分ける方法
----------------------------------------------------------------------

外部コマンドを明示的に起動するには、
組込みコマンド `command` に外部コマンド名を指定します。

``` console
$ command コマンド名 [引数]...
```

bash や ksh
であれば、コマンドにパス名を含めることでも外部コマンドの起動になります。
しかし zsh はエイリアス名や関数名にパス名を含めることができるため、確実ではありません。
`command` コマンドの利用を推奨します。

組込みコマンドを明示的に起動するには、
組込みコマンド `builtin` に組込みコマンド名を指定します。

``` console
$ builtin コマンド名 [引数]...
```

シェル関数を明示的に起動する方法は…わかりません。あったら教えてください。

シェル関数より優先される同名のコマンドエイリアスを避ける方法ならあります。
コマンド名の先頭に `\` を付けてエスケープするか、
コマンド名をクォートすればエイリアス展開はされません。

``` console
$ alias foo='echo foo-alias'
$ function foo { echo foo-function; }
$ foo
foo-alias
$ \foo
foo-function
$ 'foo'
foo-function
$ "foo"
foo-function
```

* * *

{% include wishlist-dec.html %}

