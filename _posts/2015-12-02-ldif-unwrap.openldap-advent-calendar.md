---
title: LDIF データの行折り畳みを解除する - OpenLDAP と仲間たち Advent Calendar 2015
tags: [openldap, ldap, shell, sh]
layout: default
---

[OpenLDAP と仲間たち Advent Calendar 2015](http://qiita.com/advent-calendar/2015/openldap) の 2日目の記事です。

今日は LDAP におけるデータのテキスト表現である LDIF
(LDAP Data Interchange Format) データの行折り畳みと、
その解除方法について解説します。

LDIF って何?
----------------------------------------------------------------------

詳しくは
[RFC 2849 The LDAP Data Interchange Format (LDIF) - Technical Specification](https://datatracker.ietf.org/doc/rfc2849/) を読んでいただくとして、
要は LDAP でデータをやりとりするときに利用するテキストデータであり、
次のような形式をしています。

```
dn: エントリのDN(識別名)
属性名: 値
属性名:: 値(Base64表現)

dn: エントリのDN(識別名)
属性名: 値
属性名:: 値(Base64表現)
```

LDIF データは、LDAP DIT (Directory Information Tree。データベースにおける
テーブルのようなもの。構造はだいぶ違うけど) のエントリ (レコードに相当するもの)
そのものを表すだけでなく、エントリの追加や削除、エントリが持つ属性
(カラムに相当するもの) の追加・置換・削除といった操作も表すことができます。

行の折り畳み?
----------------------------------------------------------------------

LDIF データの行の最大長は規定されてないようですが、改行
(LF または CR LF) と空白文字 (SPACE) 一つで折り畳むことができます。

RFC 2849 の「Formal Syntax Definition of LDIF」章の「Notes on LDIF Syntax」
より抜粋:

>     2)  Any non-empty line, including comment lines, in an LDIF file
>         MAY be folded by inserting a line separator (SEP) and a SPACE.
>         Folding MUST NOT occur before the first character of the line.
>         In other words, folding a line into two lines, the first of
>         which is empty, is not permitted. Any line that begins with a
>         single space MUST be treated as a continuation of the previous
>         (non-empty) line. When joining folded lines, exactly one space
>         character at the beginning of each continued line must be
>         discarded. Implementations SHOULD NOT fold lines in the middle
>         of a multi-byte UTF-8 character.

実装によりますが、デフォルトでは 76文字か 78文字で折り畳むものが
多いようです。行折り畳みされた LDIF データの属性値の例を示します。

```
属性名: Blah-blah-blah...,long-long-long-long-long-long-long-long-long-long-lo
 ng-long-long-long-long-long-long value
```

行の折り畳みをなくしたい!
----------------------------------------------------------------------

`ldapsearch`(1) などのコマンドラインの LDAP クライアントを利用すれば、
シェルスクリプトや LL の簡単なコードでも、LDAP DIT のデータを手軽に活用できます。
ただし、LDIF の行の折り畳みをどうにかしないといけません。ときおり、
行の折り畳みを考慮していないスクリプトを見かけるので、注意が必要です。

### LDIF データ出力時に折り畳みを抑制する

幸いなことに、OpenLDAP 2.4.24 以降の `ldapsearch` ならば、
コマンドラインオプションに `-o ldif-wrap=no` を指定することで、
折り畳みを抑制することができます (実際は `unsigned long`
の最大値で折り畳みますが、通常は問題ないでしょう)。
シェルスクリプトで利用する際はこれがお手軽でしょう。

そのほかの LDIF データを出力する実装でも、何バイトで折り畳むかを
指定したり、折り畳みを抑制するオプションが用意されています。
詳細は各実装のマニュアルやソースコードを確認してみてください。
「wrap」や「fold」といったキーワードで探すと見つかると思います。

### 既存 LDIF データの折り畳みを解除する

私はピュアシェル芸人なので、試しにシェルだけで実装してみました。
たぶん遅いでしょうが、素の `sh` でもその実体が新し目の `ash` や
`dash` なら動きます。

{% assign github_quote_file = "2015/12/02/ldifunwrap.sh" %}
{% include github-quote-file.html %}

ああ、手元の Debian GNU/Linux の ksh 93u+20120801-2 だと
バグってて動かねぇ。またかよ。未定義のシェル変数を
`while` ループ中で条件付き変数展開すると誤判定する模様。

```console
$ dpkg -l ksh |tail -n1
ii  ksh            93u+20120801-2 amd64        Real, AT&T version of the Korn shell
$ ksh --version
  version         sh (AT&T Research) 93u+ 2012-08-01
$ for s in '' ba da k mk z; do
  sh=${s}sh
  echo -n "$sh:"
  (echo 1; echo 2; echo 3) \
  |${s}sh -c 'unset v; while read n; do [ -n "${v+set}" ] && echo -n "$v "; v="$n"; done; echo "$v"'
done
sh:1 2 3
bash:1 2 3
dash:1 2 3
ksh:3
mksh:1 2 3
zsh:1 2 3
```

閑話休題。

非ピュアなシェル芸だと `sed` が好みなのですが、古い `sed`
(Solaris 10 とか) までサポートするものは困難なようですし、
GNU sed など現代の `sed` でも暗号めいたスクリプトになってしまうので、
個人的にはお薦めできません。

AWK であれば `awk 'NR>1 && !sub(/^ /,"") { print s; s="" } {s = s $0} END {print s}'`
といったところでしょうか。これも古い `awk` だと動かない場合があるので、
環境によっては GNU AWK や `nawk` に代えて実行する必要があります。

Perl では `perl -p00e 's/\n //g'` といった例がよく紹介されますが、
これは LDIF データをすべてメモリに読み込んで一括で処理するので、
`perl -pe 'BEGIN {$/=""} s/\n //gms'`  のように空行ごとに分割して
処理するほうが安全かもしれません。

参考:

  * Sed/Awk - remove blankspaces / join lines in ldif dump - Stack Overflow
    * http://stackoverflow.com/questions/13139294/sed-awk-remove-blankspaces-join-lines-in-ldif-dump
  * Using sed to unwrap ldif lines - Nunc Fluens
    * http://richmegginson.livejournal.com/18726.html

Perl / Python などの各種 LL や C / Go などのコンパイル言語で実装された
LDIF ライブラリを用いれば、より簡単・確実に折り畳み解除処理できると思います。
しかし、今回のような単純な処理では役不足ですし、厳密な LDIF 解析・出力
処理の分、処理は遅くなると思います。実際に Perl による 1-liner と
Perl の `Net::LDAP::LDIF` を比較したことがありますが、数倍遅くなったと記憶しています。

* * *

{% include wishlist-dec.html %}

