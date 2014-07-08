---
title: Dovecot サービスの制限設定
tags: [dovecot]
layout: default
---

警告 WARNING 警告 WARNING 警告 WARNING 警告 WARNING 警告 WARNING 警告 WARNING

まだ書きかけ。間違いが含まれている可能性大。

警告 WARNING 警告 WARNING 警告 WARNING 警告 WARNING 警告 WARNING 警告 WARNING

  * Service limits - Dovecot Wiki
    * http://wiki2.dovecot.org/Services#Service_limits

サービス毎のデフォルト値
----------------------------------------------------------------------

Dovecot 2.2.13 調べ。

``` console
$ doveconf -ad |grep '^default_.*_limit'
default_client_limit = 1000
default_process_limit = 100
default_vsz_limit = 256 M
```

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

`client_limit`
----------------------------------------------------------------------

サービスの 1プロセスあたりの最大クライアント数。
0 に設定すると `default_client_limit` (デフォルト値 1000）の値になる。

`pop3`, `imap`, `managesieve` サービスでは 1 が推奨値(デフォルト) であり、
同時接続数を調整する場合は `process_limit` を設定すべき。FIXME

`service_count` が 1 以上に設定している場合、そちらが優先される。
たとえば `service_count = 1` に設定すると `client_limit = 1` 相当になる。

参考:

  * [Dovecot] difference between client_limit and process_limit
    * http://dovecot.org/pipermail/dovecot/2012-June/083844.html

`process_limit`
----------------------------------------------------------------------

サービスあたりの最大プロセス数。
未設定あるいは 0 に設定すると `default_process_limit` (デフォルト値 100）の値になる。

`service_count`
----------------------------------------------------------------------

サービスの 1プロセスあたりのクライアントの対応数。
サービスプロセスは、指定の数のクライアント接続を完了したあとに終了する。
0 に設定すると無制限を意味する。

Apache HTTPD の `MaxRequestsPerChild` 相当。

0 (無制限) もしくは 2
以上に設定することでプロセスの終了・生成の分の負荷が減らすことができるが、
ほかのユーザー(クライアント接続)とプロセスを共有するため、
脆弱性を突かれた場合のリスクが増大する。

参考:

  * LoginProcess High-performance mode - Dovecot Wiki
    * http://wiki2.dovecot.org/LoginProcess#High-performance_mode

`vsz_limit`
----------------------------------------------------------------------

サービスの 1プロセスあたりの最大メモリ量 (データセグメントサイズ)。

Proxy / Director の制限設定
----------------------------------------------------------------------

POP3 / IMAP の Proxy / Director は `pop3-login`, `imap-login`
プロセスで実行される。同機能を利用する場合は
`pop3-login`, `imap-login` サービスの設定に注意。

LMTP は `lmtp` サービスで実行される。

