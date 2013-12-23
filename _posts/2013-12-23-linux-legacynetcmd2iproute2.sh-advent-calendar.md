---
title: "Linux: ifconfig, netstat を iproute2 コマンドラインに変換 - 拡張 POSIX シェルスクリプト Advent Calendar 2013"
tags: [sh, shell, linux]
layout: default
---

[拡張 POSIX シェルスクリプト Advent Calendar 2013]
(http://www.adventar.org/calendars/212)、23日目の記事です。
ネタの在庫はともかく、書く気力がありません。
いくつかの記事がそれなりにうけたこともあり、頭が満足してしまったようです。

https://twitter.com/satoh_fumiyasu/status/415045480477765633

> 燃え尽きたぜ．．．真っ白に、 真っ白な灰に．．．
> (Advent Calendar 書けない

仕方ないので、過去に作成した bash スクリプト作品を紹介する内容で誤魔化します。
すみません。Linux 向けの話です。

Linux のネットワークコマンドと iproute2
----------------------------------------------------------------------

ネットワーク設定を管理するコマンドと言うと何を思い浮かべますか?
一般的には `ifconfig`, `netstat`, `route`, `arp` あたりですよね。
UNIX 系の OS
であれば、まず間違いなくデフォルトでインストールされているでしょう。
OS の種類により一部非互換な仕様はありますが、ほとんどの OS
で似たような機能とインターフェイスを備えています。

一方、Linux には `ip`(8) というコマンドも用意されています。
iproute (REHL 系、旧 Debian 系) あるいは iproute2 (Debian 系)
という名前のパッケージに含まれているコマンドです。
(正式名称は「iproute2」のようですが何が「2」なのかは調べていません)
`ip` コマンドは 1990 年代後半には各種 Linux
ディストリビューションに含まれており、Linux の歴史の中では比較的古い存在です。

`ip` は `ifconfig` などでは対応できない Linux
の低レベルなネットワーク設定の表示・変更に対応しています。
その昔はドキュメントがほとんど用意されておらず、
一部マニアがマニアックなネットワーク設定をするために利用する程度で、
一般的な Linux ユーザーには認知されていませんでした。
特に `ip` が利用されていたのは「ポリシールーティング」が必要な場面でした。
[「linux ip route ポリシー」で Web 検索]
(https://www.google.com/search?q=linux+ip+route+%E3%83%9D%E3%83%AA%E3%82%B7%E3%83%BC)
すると、多くの例が紹介されています。

iproute2 にはほかにもネットワーク統計情報を表示する `ss`(8)、
トラフィックコントロールを管理するための `tc`(8) などが含まれています。

非推奨になる Linux のネットワークコマンド
----------------------------------------------------------------------

旧来からの UNIX / Linux ユーザーに悲しいお知らせです。
Linux 向けに `ifconfig`, `netstat`, `route`, `arp` などを提供してきた
net-tools パッケージは非推奨となり、iproute2 で置き換えられることになりました。
まだしばらくは旧来のコマンドも残されるようですが、
標準ではインストールされなくなったり、その先の将来はなくなる可能性すらあります。

幸い、最近の iproute2 はマニュアルが整備されていますし、関連情報も増えつつあります。
しかし、旧来のコマンドに慣れたユーザーにとっては辛いところです。

旧来のコマンドと iproute2 のコマンドの対応表を用意してくれているページを紹介します。

  * Deprecated Linux networking commands and their replacements | Doug Vitale Tech
Blog
    * https://dougvitale.wordpress.com/2011/12/21/deprecated-linux-networking-commands-and-their-replacements/

旧来のネットワークコマンドラインを iproute2 コマンドラインに変換する
----------------------------------------------------------------------

`ifconfig`, `netstat` のコマンドラインを `ip`, `ss`
のコマンドラインに変換する bash スクリプトを作ってみました。

  * Convert to Linux iproute2 command-line from legacy networking command-line
    * https://github.com/fumiyas/linux-legacynetcmd2iproute2

ダウンロード:

``` console
$ git clone https://github.com/fumiyas/linux-legacynetcmd2iproute2.git
$ cd linux-legacynetcmd2iproute2
```

`ifconfig`, `netstat` のコマンドラインから `ip`, `ss`
のコマンドラインを表示する:

``` console
$ ./ifconfig2.bash
ip address
$ ./ifconfig2.bash eth0
ip address show dev eth0
$ ./ifconfig2.bash eth0 192.168.0.1 netmask 255.255.0.0
ip address add 192.168.0.1/255.255.0.0 dev eth0
$ ./netstat2.bash
ss -r
$ ./netstat2.bash -i
ip -r -s link
$ ./netstat2.bash -a
ss -r -a
$ ./netstat2.bash -antp
ss -a -n -t -p
```

`ifconfig`, `netstat` のコマンドラインから `ip`, `ss`
のコマンドラインを表示して実行:

``` console
$ ./ifconfig2.bash --x <ifconfig(8) のオプション>
…
$ ./netstat2.bash --x <netstat(8) のオプション>
…
```

`ifconfig`, `netstat` のコマンドラインから `ip`, `ss`
のコマンドラインを実行(コマンドラインの表示はしない):

``` console
$ ./ifconfig2.bash --xx <ifconfig(8) のオプション>
…
$ ./netstat2.bash --xx <netstat(8) のオプション>
…
```

インストールしてラッパーとして利用する:

``` console
$ sudo install -m 0755 ifconfig2.bash /usr/local/sbin/ifconfig
$ sudo install -m 0755 netstat2.bash /usr/local/bin/netstat
$ /usr/local/sbin/ifconfig <ifconfig(8) のオプション>
…
$ /usr/local/bin/netstat <netstat(8) のオプション>
…
```

Enjoy!

…

一部対応していないオプションもあります。
その際はエラーを表示するようにしていますが不完全かもしれません。
需要がありそうなら `arp`, `route` のラッパースクリプトも検討します。

* * *

{% include wishlist-dec.html %}

