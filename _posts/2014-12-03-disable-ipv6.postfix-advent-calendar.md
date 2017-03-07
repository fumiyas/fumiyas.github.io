---
title: Postfix で IPv6 無効化 - Postfix Advent Calendar 2014
tags: [postfix, ipv6]
layout: default
---

[Postfix Advent Calendar 2014](http://qiita.com/advent-calendar/2014/postfix) の 3日目の記事です。

IPv6 は来年で 20歳らしいですね ([RFC 1752](http://tools.ietf.org/html/rfc1752))。
今回は IPv6 20周年を記念して、Postfix で IPv6 を無効化する方法について紹介しましょう。

現代の Postfix は、デフォルトで IPv6 が有効です。
ホスト OS が IPv6 有効で DNS の名前解決の結果 IPv6 アドレスが得られれば
IPv6 を利用しますし、IPv4 と一緒に得られた場合でもデフォルトは IPv6 が優先されます。

しかし悲しいかな、IPv6 の普及はいまだ充分ではありませんし、IPv4 と互換性もありません。
IPv6 によって問題が発生することもあります。
たとえば、IPv4 は問題なくても、IPv6 で問題を抱えている環境があります。

  * IPv6 ネットワークがインターネットに繋っていない。
    * いわゆる「IPv6閉域網におけるフォールバック問題」が起こる。
    * 参考: Geekなぺーじ:NTT IPv6閉域網フォールバック問題
      * <http://www.geekpage.jp/blog/?id=2012/3/28/1>
  * IPv6 がファイアウォールでブロックされている。
    * 設計・構築時に IPv4 しか考慮してなかったなんてことがあるんですよ…。
    * これもフォールバック問題が発生します。
  * そのほか?
    * IPv6 わからないし、知りません! ほかにもあったら教えてください。

できればまともな IPv6 環境を構築して解決したいところですが、
そうも言ってられないときは無効化してしまいましょう。

## IPv6 を無効にする

Postfix のすべてのサービスで IPv6 を無効にするには、
`/etc/postfix/main.cf` に次のように記述します。

```cfg
inet_protocols = ipv4
```

`inet_protocols` パラメーターの変更を反映させるには、
*Postfix を再起動する必要があります。リロードではいけません*。
ご注意ください。

```console
# postfix stop
postfix/postfix-script: stopping the Postfix mail system
# postfix start
postfix/postfix-script: starting the Postfix mail system
```

リロード (`postfix reload`) では変更は無視されて次のような警告ログが出ます。

```
Dec  3 16:38:17 sugar postfix/postfix-script[30745]: refreshing the Postfix mail system
Dec  3 16:38:17 sugar postfix/master[24974]: reload -- version 2.11.3, configuration /etc/postfix
Dec  3 16:38:17 sugar postfix/master[24974]: warning: ignoring inet_protocols parameter value change
Dec  3 16:38:17 sugar postfix/master[24974]: warning: old value: "all", new value: "ipv4"
Dec  3 16:38:17 sugar postfix/master[24974]: warning: to change inet_protocols, stop and start Postfix
```

## IPv6 より IPv4 を優先する

Postfix 2.8 以降であれば、SMTP クライアント `smtp`(8) と
LMTP クライアント `lmtp`(8) において、IPv4 を優先させることができます。
IPv6 を利用するが何らかの理由により IPv4 を優先したいときにお薦めです。

`/etc/postfix/main.cf` に次のように記述します。

```cfg
smtp_address_preference = ipv4
lmtp_address_preference = ipv4
```

リロードして `main.cf` の変更を反映します。

```console
# postfix reload
postfix/postfix-script: refreshing the Postfix mail system
```

## 特定の宛先のみ IPv6 を無効にする

`bogus-ipv6.example.jp` 宛のメール配送で IPv6 無効化、
`prefer-ipv4.example.jp` 宛のメール配送で IPv4 優先する例を示します。

`/etc/postfix/master.cf` で `smtp`(8) のトランスポートサービスを追加します。

```text
smtp-ipv4        unix  -       -       -       -       -       smtp
  -o syslog_name=postfix/ipv4
  -o inet_protocols=ipv4
smtp-ipv4-prefer unix  -       -       -       -       -       smtp
  -o syslog_name=postfix/ipv4-prefer
  -o smtp_address_preference=ipv4
```

次に `transport`(5) で各ドメイン宛のメール配送に
`master.cf` に追加したトランスポートサービスを利用するように設定します。
`/etc/postfix/transport` に次のような内容を記述します。

```text
bogus-ipv6.example.jp	smtp-ipv4:
prefer-ipv4.example.jp	smtp-ipv4-prefer:
```

`postmap`(8) を実行して `/etc/postfix/transport.db` に反映します。

```console
# postmap /etc/postfix/transport
```

`/etc/postfix/main.cf` で `transport_maps` パラメーターを設定します。

```
transport_maps = hash:$config_directory/transport
```

リロードして `master.cf` と `main.cf` の変更を反映します。

```console
# postfix reload
postfix/postfix-script: refreshing the Postfix mail system
```

## IPv6 を完全に無効にする

Postfix をソースからビルドするときに IPv6 機能を完全に無効化することができます。
次のように、`Makefile` を生成するときの引数で `CCARGS` に `-DNO_IPV6` を指定します。

```console
$ tar xf postfix-2.11.3.tar.gz
$ cd postfix-2.11.3
$ make -f Makefile.init makefiles CCARGS="-DNO_IPV6"
…
$ make
…
```

## Linux OS の IPv6 を無効にする

Linux であれば、次のような内容を `/etc/sysctl.d/ipv6-disable.conf`
という名前のファイルに突っ込んでおきましょう
(ファイル名は `*.conf` であれば任意)。
`sysctl`(8) が古く `/etc/sysctl.d` に対応していないなら、
代わりに `/etc/sysctl.conf` に追加します。

```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
```

反映させるには `sysctl --system` を実行(`sysctl`(8) が古い場合は代わりに `sysctl -p`)、
あるいは OS をリブートします。


```console
# echo net.ipv6.conf.all.disable_ipv6 = 1 >>/etc/sysctl.d/ipv6-disable.conf
# echo net.ipv6.conf.default.disable_ipv6 = 1 >>/etc/sysctl.d/ipv6-disable.conf
# sysctl --system
…
* Applying /etc/sysctl.d/ipv6-disable.conf ...
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
…
```

ネットワークインターフェイス設定とルーティング設定に
IPv6 のエントリーが存在しないことを確認しましょう。

```console
# ip -6 address
…何も表示なし…
# ip -6 route
…何も表示なし…
```

* * *

{% include wishlist-dec.html %}

