---
title: 既存スクリプトを改造なしにハックする - 拡張 POSIX シェルスクリプト Advent Calendar 2013
tags: [sh, shell]
layout: default
---

[zsh Advent Calendar 2013]
(http://qiita.com/advent-calendar/2013/zsh) 兼
[拡張 POSIX シェルスクリプト Advent Calendar 2013]
(http://www.adventar.org/calendars/212)、9日目の記事です。

今日は既存のシェルスクリプトを書き換えることなく動作を変える方法を紹介します。
当初は zsh 向けの記事にしようと思っていたのですが、
一部限定的ながら bash, ksh にも適用できることに気付いたため、
最初は bash での例を示し、最後に zsh ならではの特徴を挙げます。

今回は例として bash スクリプトである `xzgrep` を uuencode に対応してみます。
`xzgrep` は xz だけでなく、gzip, bzip2, lzo
で圧縮されたファイルを指定すると自動的に展開し、その出力に対して `grep`
を実行するコマンドです。

``` console
$ xzgrep pattern msg.txt.xz
… `xz -dc msg.txt.xz |grep pattern` 相当の出力…
```

材料を用意する
----------------------------------------------------------------------

`xzgrep` と `uuencode`, `uudecode` コマンドが含まれているパッケージをインストールします。

``` console
RHEL 等の場合
# yum install xz sharutils
Debian 等の場合
# apt-get install xz-utils sharutils
…
$ file /usr/bin/xzgrep
/usr/bin/xzgrep: Bourne-Again shell script, ASCII text executable
```

`xzgrep` 対象のテキストファイル `msg.txt` と、
xz で圧縮した `msg.txt.xz`、uuencode でエンコードした `msg.txt.uu`
を作成します。

``` console
$ (echo しにたい; echo もうだめだ; echo つらぽよ) >msg.txt
$ xz <msg.txt >msg.txt.gz
$ uuencode msg.txt <msg.txt >msg.txt.uu
$ cat msg.txt.uu
begin 664 msg.txt
JXX&7XX&KXX&?XX&$"N."@N.!AN.!H.."@>.!H`KC@:3C@HGC@;WC@H@*
`
end
```

`xzgrep` の動作を確認します。
`msg.txt.uu` に対しては uuencode 形式には対応していないため、何も表示されません。

``` console
$ xzgrep だめ msg.txt*
msg.txt:もうだめだ
msg.txt.xz:もうだめだ
```

`xzgrep` を uuencode 対応してみる
----------------------------------------------------------------------

こんなスクリプトを別途用意します。

{% assign github_quote_file = "2013/12/09/xzuugrep.bash" %}
{% include github-quote-file.html %}

これを実行してみましょう。

``` console
$ bash ./xzuugrep.bash だめ msg.txt*
msg.txt:もうだめだ
msg.txt.uu:もうだめだ
msg.txt.xz:もうだめだ
```

このように、間接的に `xzgrep` を呼び出す形ではありますが、
無改造で uuencode 形式対応することができました。

解説
----------------------------------------------------------------------

bash が環境変数 `$BASH_ENV`
に指定されたファイル内のスクリプトを起動時に実行するという挙動を利用し、
本来のスクリプト実行前にシェル関数でコマンドを上書きしただけの簡単なハックです。

`xzuugrep.bash` スクリプトの動作を簡単に解説します。

  1. bash が `xzuugrep.bash` スクリプトを開始する。
  2. `$XZUUGREP` が未定義であるため、次の処理を行なう:
    1. 環境変数 `$XZUUGREP` を設定する。(値は何でもよい)
    2. 環境変数 `$BASH_ENV` に自スクリプト名 (`xzuugrep.bash`) を設定する。
    3. `xzgrep` を起動する。(`exec` なので戻ってこない)
  3. `xzgrep` の shebang が `#!/bin/bash` であるため、
     bash が起動する。
  4. 環境変数 `$BASH_ENV` が設定されているため、
     bash はその値が示す `xzuubash.bash` スクリプトを実行する。
     (`source xzuubash.bash` 相当)
     結果、シェル関数 `xz()` が定義される。
  5. bash は続いて `xzgrep` スクリプトを実行する。
  6. `xzgrep` の実行中、通常時 `xz` コマンドを実行される代わりに
     `xz()` が実行される。
  7. `xz()` は指定されたファイルから最初の一行を抽出し、
     それが uuencode 形式と認識したら `uudecode` コマンドでデコード、
     そうでなければ `xz` コマンドで展開する。

`xzuugrep.bash` からの `xzgrep` 実行は `exec xzgrep` でなく
`source xzgrep` でもよいのですが、その場合、`xzgrep` 内で `$0` の値が
`xzgrep` ではなく `xzuugrep.bash` になります。
`$0` の値に依存しているスクリプトではうまく動作しないでしょう。

ksh の場合
----------------------------------------------------------------------

ksh は起動時に環境変数 `$ENV` を参照しますが、
シェルスクリプト(非対話)の場合は無視されます。
よって今回のハックは不可能です。

代わりに zsh の ksh エミュレーションを利用しましょう。

zsh の場合
----------------------------------------------------------------------

zsh は起動時の名前が `ksh` あるいは `sh` の場合に環境変数 `$ENV` を参照します。
上記ハックを参考に `$BASH_ENV` の代わりに `$ENV` を利用し、
本来のスクリプトの起動は `exec -a /bin/sh /bin/zsh <スクリプト名> <引数>`
のように実装すれば同様のハックが実現できます。

bash の場合はパス名を含むコマンドの上書きはできませんが、
zsh の場合はシェル関数やコマンドエイリアスの名前に `/`
を含めることができるため、パス名を含むコマンドも上書き可能です。

もし仮に `xzgrep` スクリプト内で `xz` コマンドが `/usr/bin/xz`
のように絶対パスで指定されていると bash では対応できませんが、
zsh なら対応できます。

{% assign github_quote_file = "2013/12/09/xzuugrep.zsh" %}
{% include github-quote-file.html %}

ユースケース
----------------------------------------------------------------------

色々考えられると思いますが、私の場合は Linux 向けに作成されたシェルスクリプトを
Linux 以外 (具体的には Solaris、AIX) で動作させるため、
Linux 互換のコマンドとこのハックを組み合わせて利用しています。

* * *

{% include wishlist-dec.html %}

