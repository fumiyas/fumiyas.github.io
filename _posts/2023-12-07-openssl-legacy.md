---
title: "現代の OpenSSL 環境で古来の暗号アルゴリズムをサッと使う - シェル芸 / 闇の魔術に対する防衛術 Advent Calendar 2023"
tags: [sh, shell, crypto]
layout: default
---

[シェル芸 Advent Calendar 2023](https://qiita.com/advent-calendar/2023/shellgei)、
[闇の魔術に対する防衛術 Advent Calendar 2023](https://qiita.com/advent-calendar/2023/yaminomajutu)、
7日目の記事です。

OpenSSL 3+ で古来の暗号アルゴリズムが使えない!
----------------------------------------------------------------------

みなさん MD4 使ってますよね? 当然ご存知の PEAP とか NTLM とかね?!
[MD4 が誕生したのは 1990 年](https://ja.wikipedia.org/wiki/MD4)だそうですが、いまだ現役! すごい!!

しかし現代の OpenSSL では (デフォルトは) 使えません。残念。

```console
$ openssl version
OpenSSL 3.1.4 24 Oct 2023 (Library: OpenSSL 3.1.4 24 Oct 2023)
$ openssl md4
Error setting digest
408C6395477F0000:error:0308010C:digital envelope routines:inner_evp_generic_fetch:unsupported:../crypto/evp/evp_fetch.c:341:Global default library context, Algorithm (MD4 : 97), Properties ()
408C6395477F0000:error:03000086:digital envelope routines:evp_md_init_internal:initialization error:../crypto/evp/digest.c:272:
```

OpenSSL 設定ファイルで古来の暗号アルゴリズムを有効化
----------------------------------------------------------------------

Web 検索すれば大量に見つかる二番煎じですが、
下記のように `openssl.cnf`(5) ファイルを設定すれば
古来の暗号アルゴリズムを有効化できます。

```ini
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
legacy = legacy_sect

[default_sect]
activate = 1

[legacy_sect]
activate = 1
```

たとえば、上記内容の `openssl.cnf` ファイルがカレントディレクトリにある場合、
下記の要領で OpenSSL に使用させることができます。

```console
$ OPENSSL_CONF=$PWD/openssl.cnf openssl md4
...
```

もちろん、システムのデフォルトの `openssl.cnf` ファイルに同等の設定をすれば、
システム全体で有効化することもできます。

ラッパースクリプトでサッっと古来の暗号アルゴリズムを有効化
----------------------------------------------------------------------

設定ファイルを用意するのは面倒だし、
システム全体で有効化するのは影響範囲が広く気が引けますね?

そこで、サッっと有効化してコマンドを実行できるラッパースクリプト
[openssl-legacy](https://github.com/fumiyas/home-commands/blob/master/openssl-legacy)
を作りました。
このスクリプトを経由して OpenSSL (`libssl` ライブラリ)
を利用しているコマンドをして起動するだけで OK! 簡単、楽チン!!

よかったら `/usr/local/bin/openssl-legacy` あたりにインストールしてみてください。

使い方は簡単、`openssl-legacy` のコマンドライン引数に
実行したいコマンドとコマンドライン引数を与えて実行するだけです。

```console
$ openssl-legacy openssl md4
...
```

指定したコマンドが存在しない場合は `openssl`(1) のサブコマンドを実行します。

```
$ openssl-legacy md4
...
```

OpenSSL `libssl` ライブラリを利用した各種モジュールにも有効です。
下記は Python hashlib での例です。

```console
$ python3 -c 'import hashlib; print(sorted(hashlib.algorithms_available))'
... 'md4' は含まれない ...
$ openssl-legacy python3 -c 'import hashlib; print(sorted(hashlib.algorithms_available))'
... 'md4' が含まれる! ...
```

* * *

{% include wishlist-dec.html %}
