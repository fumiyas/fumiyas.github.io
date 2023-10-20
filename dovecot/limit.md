---
title: Dovecot サービスの制限設定
tags: [dovecot]
layout: default
---

* [Service configuration](https://doc.dovecot.org/configuration_manual/service_configuration/)
* [Login processes — Dovecot documentation](https://doc.dovecot.org/admin_manual/login_processes/)

サービス毎のデフォルト値
----------------------------------------------------------------------

Dovecot 2.2.13 調べ。

``` console
$ doveconf -ad |grep '^default_.*_limit'
default_client_limit = 1000
default_process_limit = 100
default_vsz_limit = 256 M
```

<!--
doveconf -ad \
|sed -n \
  -e '/vsz_limit/d' \
  -e 's/^service \([^ ]*\).*/\1/p' \
  -e 's/^ .*limit = //p' \
  -e 's/^ .*count = //p' \
|sed 'N;N;N;s/\n/ /g' 
|awk '
    $2==0 {$2="$default_client_limit"}
    $3==0 {$3="$default_process_limit"}
    {printf("| %-19s | %21s | %22s | %15s |\n",$1,$2,$3,$4) }
  '
-->

| サービス名          | client_limit          | process_limit          | service_count   |
|:------------------- | ---------------------:| ----------------------:| ---------------:|
| aggregator          | $default_client_limit | $default_process_limit |               0 |
| anvil               | $default_client_limit |                      1 |               0 |
| auth-worker         |                     1 | $default_process_limit |               1 |
| auth                | $default_client_limit |                      1 |               0 |
| config              | $default_client_limit | $default_process_limit |               0 |
| dict                |                     1 | $default_process_limit |               0 |
| director            | $default_client_limit |                      1 |               0 |
| dns_client          |                     1 | $default_process_limit |               0 |
| doveadm             |                     1 | $default_process_limit |               1 |
| imap-login          | $default_client_limit | $default_process_limit |               1 |
| imap-urlauth-login  | $default_client_limit | $default_process_limit |               1 |
| imap-urlauth-worker |                     1 |                   1024 |               1 |
| imap-urlauth        |                     1 |                   1024 |               1 |
| imap                |                     1 |                   1024 |               1 |
| indexer-worker      |                     1 |                     10 |               0 |
| indexer             | $default_client_limit |                      1 |               0 |
| ipc                 | $default_client_limit |                      1 |               0 |
| lmtp                |                     1 | $default_process_limit |               0 |
| log                 | $default_client_limit |                      1 |               0 |
| pop3-login          | $default_client_limit | $default_process_limit |               1 |
| pop3                |                     1 |                   1024 |               1 |
| replicator          | $default_client_limit |                      1 |               0 |
| ssl-params          | $default_client_limit | $default_process_limit |               0 |
| stats               | $default_client_limit |                      1 |               0 |
| tcpwrap             |                     1 | $default_process_limit |               0 |

上の表の `$default_client_limit` と
`$default_process_limit` の項目は、`doveconf` の出力上は値が `0` と表示される。
`dovecot.conf` ファイル中では `client_limit=$default_client_limit`
のようには記述できず、`client_limit=0` のように記述する必要がある。

`client_limit`
----------------------------------------------------------------------

サービスの 1 プロセスあたりの最大クライアント数。
サービスあたりの最大クライアント数**ではない**ので**注意**。
0 に設定すると `default_client_limit` (デフォルト値 1000）の値になる。

`pop3`, `imap`, `managesieve` サービスでは 1 が推奨値(デフォルト) であり、
同時接続数を調整する場合は `process_limit` を設定すべき。FIXME

`service_count` を 1 以上に設定している場合、そちらが優先される。
たとえば `service_count = 1` に設定すると `client_limit = 1` 相当になる。

参考:

* [Dovecot] difference between client_limit and process_limit
    * <http://dovecot.org/pipermail/dovecot/2012-June/083844.html>

`process_limit`
----------------------------------------------------------------------

サービスあたりの最大プロセス数。
0 に設定すると `default_process_limit` (デフォルト値 100）の値になる。

`service_count`
----------------------------------------------------------------------

サービスの 1プロセスあたりのクライアントの対応数。
サービスプロセスは、指定の数のクライアント接続を完了したあとに終了する。
0 に設定すると無制限を意味する。

~~Apache HTTPD の `MaxRequestsPerChild` 相当。~~
FIXME: 0 か 1 以外を設定することを想定していないっぽい。

0 (無制限) もしくは 2
以上に設定することでプロセスの終了・生成の分の負荷が減らすことができるが、
ほかのユーザー(クライアント接続)とプロセスを共有するため、
脆弱性を突かれた場合のリスクが増大する。

参考:

* LoginProcess High-performance mode - Dovecot Wiki
    * <http://wiki2.dovecot.org/LoginProcess#High-performance_mode>

`vsz_limit`
----------------------------------------------------------------------

サービスの 1 プロセスあたりの最大メモリ量 (データセグメントサイズ)。
`ulimit -d` の値に相当。

備考
----------------------------------------------------------------------

### `anvil` サービスのクライアント数

`pop3-login`, `imap-login`, `managesieve-login` プロセスは、
`anvil` サービスを利用する。よって、`anvil` サービスの
`client_limit` の値は全 `*-login` プロセスの最大数以上に設定する必要がある。

### TLS(SSL) / Proxy / Director の制限設定

POP3 / IMAP / ManageSieve プロトコルの TLS (SSL) / Proxy / Director は
`pop3-login`, `imap-login`, `managesieve-login` プロセスで実行される。
同機能を利用する場合は `pop3-login`, `imap-login`, `managesieve-login`
サービスの設定に注意。

LMTP プロトコルは TLS (SSL) に非対応、Proxy / Director は
`lmtp` プロセスで実行される。

