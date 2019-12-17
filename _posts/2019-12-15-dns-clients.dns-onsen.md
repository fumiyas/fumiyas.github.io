---
title: "DNS クライアントを作ったので紹介してみる - DNS 温泉 / OSSTech Advent Calendar 2019"
tags: [dns, getaddrinfo]
layout: default
---

[DNS 温泉 Advent Calendar 2019](https://adventar.org/calendars/4346)、
兼 [OSSTech Advent Calendar 2019](https://qiita.com/advent-calendar/2019/osstech)
の15日目の記事です。

DNS のテストに役立つ DNS クライアントをいくつか書いたのですが、
宣伝等せずに放置していました。せっかくなので紹介します。

`dnsq`, `dnsqr` (DNS 権威/キャッシュサーバーへの DNS RR 問合せツール)
======================================================================

<https://github.com/fumiyas/dnsq-go>

[djbdns](https://cr.yp.to/djbdns.html) 付属の `dnsq`(1), `dnsqr`(1)
のクローンコマンドです。Go 言語製なのでシングルバイナリー、
Linux だけでなく Windows や macOS 向けのクロスビルドも簡単です。

DNS 実装部分は [github.com/miekg/dns](https://github.com/miekg/dns)
を使ったので、自分はコマンドラインインターフェイスを作っただけですがね…。

`dnsq`, `dnsqr` のインストール
----------------------------------------------------------------------

`go`(1) が使える環境を用意して次のように実行すると
`$GOPATH/bin/` (デフォルトは `$HOME/go/bin/`) 以下にバイナリーが作成されます。
ここを `PATH` に追加しておくとよいでしょう。

```console
$ go get github.com/fumiyas/dnsq-go/cmd/dnsq
$ go get github.com/fumiyas/dnsq-go/cmd/dnsqr
$ ls ~/go/bin/dnsq*
...
```

Windows 向けバイナリーをクロスビルドしたいときは、次のように
`git` リポジトリーをクローンしてからビルドしてください。

```console
$ git clone https://github.com/fumiyas/dnsq-go.git
...
$ cd dnsq-go
$ GOOS=windows go build ./cmd/dnsq
$ GOOS=windows go build ./cmd/dnsqr
$ ls *.exe
...
```

`dnsq` の使い方
----------------------------------------------------------------------

`dnsq` は DNS 権威サーバー (DNS コンテンツサーバー)
に DNS RR を問合せるコマンドです。
(BIND 付属の `dig`(1) の `dig +norec ...` 相当)

例えば `dig +norec -t ns jp @a.root-servers.net`
(DNS 権威サーバー a.root-servers.net にドメイン名 jp の NS RR を問合せ)
に相当する `dnsq` コマンドラインと出力は次のようになります。

```console
$ dnsq ns jp a.root-servers.net
2 jp:
1+0+11+16 records, response, noerror
query: 2 jp.
authority: jp. 172800 NS a.dns.jp.
authority: jp. 172800 NS d.dns.jp.
...省略...
authority: jp. 86400 DS 39595 8 2 2871D562754FD45AC0452440D806ABB8E6BA967B2032B166FD2761E873553387
...省略...
additional: a.dns.jp. 172800 A 203.119.1.1
additional: a.dns.jp. 172800 AAAA 2001:dc4::1
additional: d.dns.jp. 172800 A 210.138.175.244
additional: d.dns.jp. 172800 AAAA 2001:240::53
...省略...
```

`dnsqr` の使い方
----------------------------------------------------------------------

`dnsq` は DNS キャッシュサーバー (フルサービスリゾルバー)
に DNS RR を問合せるコマンドです。
(BIND 付属の `dig`(1) の `dig +rec ...` 相当)

例えば `dig +rec -t a www.google.com @8.8.8.8`
(DNS キャッシュサーバー 8.8.8.8 にドメイン名 www.google.com の A RR を問合せ)
に相当する `dnsqr` コマンドラインと出力は次のようになります。

```console
$ dnsqr a www.google.com 8.8.8.8
1 www.google.com:
1+1+0+1 records, response, noerror
query: 1 www.google.com.
answer: www.google.com. 171 A 172.217.25.100
```

オリジナルの djbdns `dnsqr` はキャッシュサーバーの IP アドレスを
環境変数 `DNSCACHEIP` で指定しますが、私の `dnsqr` は対応していません。

`dnsstubq` (スタブリゾルバーへのホスト名 / IP アドレス問合せツール)
======================================================================

<https://gist.github.com/fumiyas/a462843421be93c8288f001f24e93045>

OS (`libc`(7)) のネームサービス (`nsswitch.conf`(5))
を利用してホスト名や IP アドレスの名前解決を行なうコマンドです。
正確には DNS と直接の関係はありません。
DNS スタブリゾルバーであるネームサービスモジュール `libnss_dns.so`
を利用する設定なっていれば `resolv.conf`(5) で
指定されている DNS キャッシュサーバーに問合せることがあります。
(実際に DNS を利用するかどうかはほかのモジュールの設定や状態による)

「ネームサービスによるホスト名や IP アドレスの名前解決」と言われても
ピンとこない人もいらっしゃるかと思います。
もっと「具体的に何」なのか説明しておくと、
「`getaddrinfo`（3) によるホスト名や IP アドレスの名前解決」ことです。
えっ? 余計にわからない? `getaddrinfo` は、例えば
`ping a.dns.jp` したときの a.dns.jp、
`git clone git@github.com:fumiyas/dnsq-go.git` したときの github.com
から IP アドレスを得るために利用されます。
また、Apache HTTPD や SSH デーモンがクライアントの
IP アドレスからホスト名を得るときにも利用されます。

`dnsstubq` のインストール
----------------------------------------------------------------------

先に紹介した
[URL](https://gist.github.com/fumiyas/a462843421be93c8288f001f24e93045)
 (GitHub Gist) ページの `dnsstub.c` の右にある `Raw` ボタンを押すと
C 言語のソースコードが表示されるので、適当にダウンロードして、
適当な C コンパイラーでコンパイル、インストールしてください。

```console
$ wget https://gist.githubusercontent.com/fumiyas/a462843421be93c8288f001f24e93045/raw/93aeb51afcfe3f02a61823ec3b20372110a0601a/dnsstubq.c
...
$ gcc -o dnsstubq dnsstubq.c
$ ls -l dnsstubq
...
$ sudo install -m 0755 dnsstubq /usr/local/bin/
```

`dnsstubq` の使い方
----------------------------------------------------------------------

コマンドライン引数にホスト名を与えると IP アドレスに、
IP アドレスを与えるとホスト名に解決して表示します。

```console
$ dnsstubq localhost
::1
127.0.0.1
$ dnsstubq www.google.com
2404:6800:4004:80a::2004
172.217.161.36
$ dnsstubq ::1
localhost
$ dnsstubq 172.217.161.36
nrt12s23-in-f4.1e100.net
```

`dnsstubq` の使い所
----------------------------------------------------------------------

`dnsstubq` で何ができて何が嬉しいのかわからない人も多そうなので、
いくつか使用例を紹介しておきましょう。
地味に便利だと思っているのですが、いかがでしょうか?

* `nsswitch.conf`(5) の `hosts` 設定のデバッグ
* `gai.conf`(5) 設定 (`getaddrinfo`(3) 設定ファイル) のデバッグ
    * `getaddrinfo` の結果をただ表示するだけのコマンドが存在しない!
* `hosts`(5) のデバッグ
    * 同じホスト名や IP アドレスを複数のエントリーに記述したときに
      どのように解釈されるかわかります。
    * 記述ミスもわかるのではないかと。
* `resolv.conf`(5) 設定 (`libnss_dns.so` 設定ファイル) のデバッグ
* DNS ラウンドロビンなんて多くの場合に役に立たないことがわかる。
    * DNS 権威 / キャッシュが返す DNS RR の順番は無視されることがわかります。
    * `getaddrinfo` がどのような順番で返すかは `gai.conf` 次第。(RFC 3484)
    * `getaddrinfo` で得られた複数の結果をどう扱うかは実装次第。

* * *

{% include wishlist-dec.html %}
