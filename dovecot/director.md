---
title: Dovecot Director
tags: [dovecot,nfs]
layout: default
---

メモ。

複数の LMTP/POP3/IMAP/ManageSieve サーバー構成時にフロントに Dovecot Director を立てて利用する。
あるユーザーを同一のサーバーに割り振ることができる (ユーザー名による sticky
あるいは persistent な振り分け機能)。
複数のバックエンド LMTP/POP3/IMAP/ManageSieve サーバーを立て、
メールボックスを共有ファイルシステムに置いたとき、
共有ファイルシステムのキャッシュを有効に活用することが可能。

  * Dovecot Wiki:
    * http://wiki2.dovecot.org/Director
    * http://wiki2.dovecot.org/NFS
  * Dovecot Director 概要
    * http://www.slideshare.net/fumiyas/dovecot-director

バックエンドに接続するときのポート番号と SSL/TLS
----------------------------------------------------------------------

  * LMTP は 24、POP3 は 110、IMAP は 143、ManageSieve は 4190 になる。
    * `passdb` で `port=番号` を返せばそれに従うと思われるが未検証。
    * Director 側が UNIX ドメインソケット (`unix_listener`)
      だとバックエンドのポート番号 0 に接続しようとしてしまう。
      LMTP でローカルの MTA から受ける場合でも `inet_listen` で受ける必要がある。
  * SSL/TLS は利用されない。
    * `passdb` で `ssl=yes` あるいは `starttls=yes` を返せばそれに従うと思われるが未検証。

Director でユーザー認証
----------------------------------------------------------------------

フロントエンドである Director でユーザー認証しない場合は、
Wiki に書かれているように `driver = static` な `passdb` を設定し、
ユーザー属性として Director を有効にするための `proxy=y`、
認証をしないための `nopassword=y` を返すようにする。

```
passdb {
  driver = static
  args = proxy=y nopassword=y
}
```

ユーザー認証する場合は、通常の `passdb` 設定に加え、
ユーザー属性として `proxy=y` を返すようにする。

たとえば LDAP の場合は `pass_attrs` パラメーターに `=proxy=y` を追加すればよい。

```
pass_attrs = \
  =proxy=y \
  …省略…
```

バックエンドに対していマスターユーザーとパスワードで認証するには次のようにする。
Director (フロントエンド) で DIGEST-MD5 認証する場合は必須。

```
pass_attrs = \
  =proxy=y \
  =master=マスターユーザー名, \
  =pass=パスワード, \
  …省略…
```

バックエンドとの中継を実行するプロセス
----------------------------------------------------------------------

POP3 は `pop3-login`、IMAP は `imap-login`、LMTP は `lmtp`、
ManageSieve は `managesieve-login` プロセスが
プロクシーを実行する。各サービスの最大セッション数の設定に注意。

`dovecot.conf` の設定例:

```
service lmtp {
  process_limit = 1000
  …
}
service pop3-login {
  process_limit = 1000
  …
}
service imap-login {
  process_limit = 1000
  …
}
service managesieve-login {
  process_limit = 1000
  …
}
```

TODO
----------------------------------------------------------------------

  * Director サービスのポート (9090/TCP が標準らしい) のアクセス制限どうすんだよ。
  * LMTP サービスのアクセス制限もどうすんだよ。
    * Dovecot に
      [TCP Wrappers サポート](http://wiki2.dovecot.org/LoginProcess#TCP_wrappers_support)
      があるが、こいつはユーザー認証しない Director や LMTP サービスには効かない。
  * バックエンドに Doveadm サーバーを立てればフロントエンドの Director から
    `doveadm` によるメールボックス操作も振り分け可能。
  * ~~Wiki に Doveadm server の設定も載っているが、何が嬉しいのかわからない。
    必須ではない(と思う)ので使わない予定。~~

