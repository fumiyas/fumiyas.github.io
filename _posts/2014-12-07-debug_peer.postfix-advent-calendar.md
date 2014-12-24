---
title: Postfix の詳細ログを採取する - Postfix Advent Calendar 2014
tags: [postfix]
layout: default
---

[Postfix Advent Calendar 2014]
(http://qiita.com/advent-calendar/2014/postfix) の 7日目の記事です。

Postfix の詳細ログの取得方法について紹介します。

## `debug_peer_list`、`debug_peer_level`

Postfix の問題を解決するには、大抵は syslog の `mail`
ファシリティに送られるログを読めば解決することができますが、
複雑な設定だったり複数のホストと連携するなどした場合は困難なときがあります。

そんなときに便利なのが `debug_peer_list` パラメーターです。
パラメーターに指定した特定のホストとのメール処理内容の詳細ログをとることが可能です。
以下に `main.cf` での記述例を示します。

```cfg
debug_peer_list =
        ## IPアドレスで対象を指定
        10.0.1.20	  
        ## ネットワークアドレス/マスクで対象を指定
        192.168.0.0/16
        ## ホスト名で対象を指定
        client.example.jp
        ## ドメイン名で対象を指定
        .test.example.jp
        ## 外部ファイルで対象リストを指定
        $config_directory/debug_peer_list
        ## 外部テーブルで対象リストを指定
        ## (テーブル中の各エントリーのキーのみ評価され値は無視される)
        ldap:$config_directory/debug_peer_list.ldap.cf
```

どの程度の詳細ログとするかは `debug_peer_level` パラメーターで数値を指定します。
デフォルト値は `2` です。有効範囲はマニュアルには記載されていませんが、
ソースコードを確認したところ、`0` から `3` だということがわかりました。
`0` を指定すると `debug_peer_list` が空 (デフォルト) の場合と変わらず、
通常のログのみとなります。
`3` を超える値を指定してもエラーにはなりませんが、ログの内容に差は生じません。

`debug_peer_level` の設定値によるログの違いを見てみましょう。
以下のログは、Postfix の Submission ポートに接続し、TLS 開始 (`STARTTLS`)、
SMTP 認証が失敗して切断されるまでのものです。

まずは `debug_peer_level=0` の場合 (`debug_peer_level` が空の場合も同じ) です。
クライアントの名前と IP アドレス、認証の失敗、切断だけが記録されます。

```
Dec  8 18:30:05 server postfix/submission/smtpd[4231]: connect from client.example.jp[10.0.1.20]
Dec  8 18:30:07 server postfix/submission/smtpd[4231]: warning: client.example.jp[10.0.1.20]: SASL PLAIN authentication failed: 
Dec  8 18:30:07 server postfix/submission/smtpd[4231]: disconnect from client.example.jp[10.0.1.20]
```

`debug_peer_level=1` の場合です。
ネットワーク I/O などの一部の内部処理情報、テーブルのエントリーとの照合内容、
送受信された SMTP コマンドとその応答内容が追加されます。

```
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: connect from client.example.jp[10.0.1.20]
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: smtp_stream_setup: maxtime=300 enable_deadline=0
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 127.0.0.1
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 127.0.0.1
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 10.0.0.0/16
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 10.0.0.0/16
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 220 server.example.jp ESMTP Postfix
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: < client.example.jp[10.0.1.20]: EHLO sugar.sfo.jp
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 127.0.0.1
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 127.0.0.1
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 10.0.0.0/16
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 10.0.0.0/16
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-server.example.jp
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-PIPELINING
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-SIZE 30480000
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-VRFY
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-ETRN
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-STARTTLS
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-XVERP
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-ENHANCEDSTATUSCODES
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-8BITMIME
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250 DSN
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: < client.example.jp[10.0.1.20]: STARTTLS
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 220 2.0.0 Ready to start TLS
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: send attr request = seed
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: send attr size = 32
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: private/tlsmgr: wanted attribute: status
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute name: status
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute value: 0
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: private/tlsmgr: wanted attribute: seed
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute name: seed
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute value: LSGw7/nIDKYyNn6LEIDNdIBmFIEE3uPowmi6h99arO0=
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: private/tlsmgr: wanted attribute: (list terminator)
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute name: (end)
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: send attr request = tktkey
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: send attr keyname = [data 0 bytes]
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: private/tlsmgr: wanted attribute: status
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute name: status
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute value: 0
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: private/tlsmgr: wanted attribute: keybuf
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute name: keybuf
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute value: iLejKJNgKbZxSr+9JU65nqQLj04qsmQedgBq8HYQOBJU6/V82cm8MAYt2qzi4h0YEXeFVAAAAAA=
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: private/tlsmgr: wanted attribute: (list terminator)
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: input attribute name: (end)
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_create: SASL service=smtp, realm=(null)
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: name_mask: noanonymous
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_connect: Connecting
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_connect: auth reply: VERSION?1?1
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_connect: auth reply: MECH?PLAIN?plaintext
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: name_mask: plaintext
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_connect: auth reply: SPID?4140
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_connect: auth reply: CUID?7
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_connect: auth reply: COOKIE?b3f94d3c4e503cf144541eef4fbfd5bc
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_connect: auth reply: DONE
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_mech_filter: keep mechanism: PLAIN
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: < client.example.jp[10.0.1.20]: EHLO sugar.sfo.jp
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 127.0.0.1
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 127.0.0.1
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 10.0.0.0/16
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 10.0.0.0/16
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-server.example.jp
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-PIPELINING
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-SIZE 30480000
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-VRFY
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-ETRN
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-AUTH PLAIN
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-XVERP
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-ENHANCEDSTATUSCODES
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250-8BITMIME
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 250 DSN
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: < client.example.jp[10.0.1.20]: AUTH PLAIN AGZvbwBiYXI=
Dec  8 18:31:54 server postfix/submission/smtpd[4292]: xsasl_dovecot_server_first: sasl_method PLAIN, init_response AGZvbwBiYXI=
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: xsasl_dovecot_handle_reply: auth reply: FAIL?1?user=foo
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: warning: client.example.jp[10.0.1.20]: SASL PLAIN authentication failed: 
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 435 4.7.8 Error: authentication failed: 
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: < client.example.jp[10.0.1.20]: QUIT
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: > client.example.jp[10.0.1.20]: 221 2.0.0 Bye
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 127.0.0.1
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 127.0.0.1
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: match_hostname: client.example.jp ~? 10.0.0.0/16
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: match_hostaddr: 10.0.1.20 ~? 10.0.0.0/16
Dec  8 18:31:56 server postfix/submission/smtpd[4292]: disconnect from client.example.jp[10.0.1.20]
```

TLS 有効の場合はパケットキャプチャーによる SMTP コマンド追跡は面倒ですが、
`debug_peer_list` と `debug_peer_level=1` 以上なら簡単に追跡できます。

詳細ログを有効にすると **SMTP 認証で送られるパスワードもそのままログに含まれる**ため、
注意が必要です。 上記ログ中の `AUTH PLAIN AGZvbwBiYXI=` からユーザー名
(`foo`) と生パスワード (`bar`) を求めることができます。

```console
$ echo AGZvbwBiYXI= |base64 -d |od -tcx1
0000000  \0   f   o   o  \0   b   a   r
         00  66  6f  6f  00  62  61  72
0000010
```

`debug_peer_level=2` 以上になると、さらに内部の情報が含まれます。
通常はデフォルトの `2` もしくは `1` で充分です。

## `smtpd_tls_loglevel`、`smtp_tls_loglevel`、`lmtp_tls_loglevel`

`smtpd`(8) の TLS のログは別途 `smtpd_tls_loglevel` パラメーターで数値を指定します。
このパラメーターは `debug_peer_list`、`debug_peer_level`
とは独立しており、お互いに影響は受けません。

有効な値は `0` (デフォルト) から `4` です。
`3` 以上にすると TLS 関連の生データが 16進数ダンプされるので、
通常は不要でしょう。

`smtpd_tls_loglevel=2` の場合のログの例を示します。
TLS ネゴシエーションの経過と結果が含まれています。

```
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: initializing the server-side TLS engine
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: connect from client.example.jp[10.0.1.20]
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: setting up TLS connection from client.example.jp[10.0.1.20]
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: client.example.jp[10.0.1.20]: TLS cipher list "aNULL:-aNULL:ALL:!EXPORT:!LOW:+RC4:@STRENGTH"
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:before/accept initialization
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: client.example.jp[10.0.1.20]: Issuing session ticket, key expiration: 1418040119
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: SSL_accept:unknown state
Dec  8 20:32:00 land postfix/submission/smtpd[6111]: Anonymous TLS connection established from client.example.jp[10.0.1.20]: TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits)
Dec  8 20:32:02 land postfix/submission/smtpd[6111]: warning: client.example.jp[10.0.1.20]: SASL PLAIN authentication failed: 
Dec  8 20:32:02 land postfix/submission/smtpd[6111]: disconnect from client.example.jp[10.0.1.20]
```

`smtp`(8) には `smtp_tls_loglevel`、`lmtp`(8) には `lmtp_tls_loglevel`
パラメーター別途用意されています。

* * *

{% include wishlist-dec.html %}

