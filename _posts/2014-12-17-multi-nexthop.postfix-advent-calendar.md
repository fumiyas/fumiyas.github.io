---
title: 中継メールサーバーの高可用性・負荷分散に対応する - Postfix Advent Calendar 2014
tags: [postfix,ha]
layout: default
---

[Postfix Advent Calendar 2014](http://qiita.com/advent-calendar/2014/postfix) の 17日目の記事です。
安定の 4日遅れです。毎度すみません。

今回は、メールの中継処理の高可用性・負荷分散を実現するため、
複数の中継メールサーバーを用意し、それに対応するための
Postfix とその周辺の設定方法について解説します。

筆が乗らず、後半は説明が雑になっています。すみません。
おいおい改善します。

構成
----------------------------------------------------------------------

### 要件

`ユーザー名@example.jp` をホストするメールサイトであると仮定します。

`example.jp` ドメインの DNS MX RR は中継用の SMTP サーバー
(Postfix でも何でも構いません)
`relay1.example.jp` と `relay2.example.jp` を指しており、
インターネットから来るメールはこれを経由して
LAN 内の Postfix SMTP サーバーである `mail.example.jp` に配送するものとします。

LAN 内の MUA は Postfix SMTP サーバー `mail.example.jp` を送信用
SMTP サーバーとして利用しており、
インターネット宛のメールは `relay1.example.jp` か `relay2.example.jp`
を経由して配送するものとします。

### ネットワーク構成

```
{インターネット}
       |
   [ルーター]
       |
-------+------------+--------------------+------------- DMZ
       |            |10.0.0.1            |10.0.0.2      10.0.0.0/24
   [ルーター]  [relay1.example.jp]  [relay2.example.jp]
       |
--+----+----------------+------+----------------------- LAN
  |192.168.0.1          |      |                        192.168.0.0/24
[mail.example.jp]     [MUA]  [MUA]  ...
```

### mail.example.jp の Postfix 設定

`main.cf` の設定内容です。
現段階では、`relayhost` パラメーターで中継メールサーバー `relay1.example.jp`
だけを利用する設定になっています。

```cfg
## mail.example.jp:/etc/postfix/main.cf
myhostname = mail.example.jp
myorigin = $mydomain
mynetworks =
        127.0.0.1 [::1]
        192.168.0.0/24

parent_domain_matches_subdomains =

mydestination = $mydomain
relay_domains =
relayhost = [relay1.example.jp]

## Postfix 2.10 向けの設定
## Postfix 2.9 以前は代わりに smtpd_recipient_restrictions を使用すること
smtpd_relay_restrictions =
        permit_mynetworks
        reject_unauth_destination
```

### relay1, relay2.example.jp の Postfix 設定

本題ではありませんが、参考までに、中継メールサーバーを Postfix にした場合の
`main.cf` の設定例を載せておきます。

```cfg
## relay1.example.jp:/etc/postfix/main.cf
myhostname = relay1.example.jp
myorigin = $mydomain
mynetworks =
        127.0.0.1 [::1]
        192.168.0.1

parent_domain_matches_subdomains =

mydestination =
relay_domains = example.jp

## Postfix 2.10 向けの設定
## Postfix 2.9 以前は代わりに smtpd_recipient_restrictions を使用すること
smtpd_relay_restrictions =
        permit_mynetworks
        reject_unauth_destination
        reject_unverified_recipient
```

`myhostname` 以外は `relay1.example.jp` と `relay2.example.jp` で共通です。
1台でも2台でもそれ以上でも、設定内容に変わりはありません。

### DNS RR の設定

```
example.jp.             IN MX   10 relay1.example.jp.
example.jp.             IN MX   20 relay2.example.jp.

relay1.example.jp.      IN A    10.0.0.1
relay2.example.jp.      IN A    10.0.0.2

mail.example.jp.        IN A    192.168.0.1
```

Postfix `smtp`(8) の配送先 (next-hop) の指定方法
----------------------------------------------------------------------

Postfix の `smtp`(8) が利用する配送先の中継メールサーバーを指定する方法や条件はいくつかありますが、
代表的なものが `relayhost` パラメーターです。
その値には、中継メールサーバーを**一つだけ**指定できます。

```cfg
relayhost = [relay1.example.jp]
```

実は古の Postfix 1.X 以前は、中継先を複数指定することができました。
成功するまで順番にメール配送を試みるため、
このような設定だけで中継メールサーバーの冗長化に対応できました。

```cfg
## Postfix 1.X 以前にのみ許される記述なので注意!!!!
relayhost = [relay1.example.jp] [relay2.example.jp]
```

`relayhost` の値に指定できる形式は次の 3形式があります。
いずれも一つしか指定できません。

  * `relayhost = ドメイン名`
    * `ドメイン名` が指す DNS MX RR 宛に配送します。
    * MX RR が存在しない場合は A RR も索きます。
    * ドメイン名ということになっていますが、ホスト名でも構いません。
  * `relayhost = [ホスト名]`
    * `ホスト名` が指す DNS A RR 宛に配送します。
  * `relayhost = [IPアドレス]`
    * `IPアドレス` 宛に配送します。

FIXME: CNAME も見るんだっけ?

複数の中継メールサーバーによる中継の高可用性
----------------------------------------------------------------------

### 既存の MX RR を利用する場合

既存の `example.jp` の MX RR を利用できるなら、`main.cf` の
`relayhost` を次のように書き換えるだけで済みます。

```cfg
relayhost = example.jp
```

### 別に MX RR を用意して利用する場合

既存の MX RR ではなく、中継メールサーバー用の MX RR を別途用意する方法もあります。
例えば `relay.example.jp` という名前の MX RR を追加します。

```
relay.example.jp.       IN MX   10 relay1.example.jp.
relay.example.jp.       IN MX   20 relay2.example.jp.
```

`main.cf` の `relayhost` を次のように書き換えて、`relay.example.jp`
を利用するようにします。

```cfg
relayhost = relay.example.jp
```

複数の中継メールサーバーによる中継の負荷分散
----------------------------------------------------------------------

### Postfix の機能で負荷分散する場合

同一優先度の MX RR を複数用意すれば、Postfix
がランダムな順番で配送試行してくれます。

```
relay.example.jp.       IN MX   10 relay1.example.jp.
relay.example.jp.       IN MX   10 relay2.example.jp.
```

`main.cf` の `relayhost` を次のように書き換えて、`relay.example.jp`
を利用するようにします。

```cfg
relayhost = relay.example.jp
```

### DNS キャッシュサーバーの機能で負荷分散する場合

DNS キャッシュサーバーから得た返答節の同一優先度の MX
をランダムに選択するかどうかは、`smtp_randomize_addresses`
の設定値に依存します。デフォルト値は `yes` です。

これを `no` に設定することで、DNS
キャッシュサーバーの応答の順番通りに配送試行するようになります。

```cfg
smtp_randomize_addresses = no
```

DNS キャッシュサーバーが返答節をラウンドロビンする機能を持っている場合や、
外部要因による応答節の並び換え機能を持っている場合、
それを利用することができるようになります。

* * *

{% include wishlist-dec.html %}

