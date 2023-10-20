---
title: Dovecot Director
tags: [dovecot,nfs]
layout: default
---

メモ。

Dovecot 3 (2.4?) から Dovecot Director 機能は削除される。
商用製品の Dovecot クラスターを使ってくれとのこと。
すでにドキュメントが消されている様子。

複数の LMTP/POP3/IMAP/ManageSieve サーバー構成時にフロントに Dovecot Director を立てて利用する。
あるユーザーを同一のサーバーに割り振ることができる (ユーザー名による sticky
あるいは persistent な振り分け機能)。
複数のバックエンド LMTP/POP3/IMAP/ManageSieve サーバーを立て、
メールボックスを共有ファイルシステムに置いたとき、
共有ファイルシステムのキャッシュを有効に活用することが可能。

* [Dovecot Director — Dovecot documentation](https://doc.dovecot.org/admin_manual/director/dovecotdirector/)
* [Dovecot Director 概要](http://www.slideshare.net/fumiyas/dovecot-director)

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

バックエンドに対してマスターユーザーとパスワードで認証するには次のようにする。
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

バックエンド Dovecot ホストの切り離しと切り戻し
----------------------------------------------------------------------

FIXME: WIP

### 構成

* Dovecot LMTP/POP3/IMAP (バックエンド)
    * dovecot1 (10.0.0.1)
    * dovecot2 (10.0.0.2)
* Dovecot Director (フロントエンド)
    * director1
    * director2
* poolmon
    * サービス名を `dovecot-poolmon` とする。

### 手順

dovecot2 を切り離す例を示す。

(0) ロードバランサーで director2 への振り分けを停止する。

(1) director1, director2 の両ホストで poolmon を停止

```console
director1# service dovecot-poolmon stop
```

```console
director2# service dovecot-poolmon stop
```

(2) director1 で、停止する Dovecot バックエンドホスト (dovecot2)
    への新規振り分けを無効化 (director2 での操作は不要※)

```console
director1# /opt/osstech/bin/doveadm director add 10.0.0.2 0
```

※ director2 側で dovecot2 との組合せで動作テストする必要がある場合、
director2 で dovecot1 への新規振り分けを無効化する必要がある。

```console
director2# /opt/osstech/bin/doveadm director add 10.0.0.2 0
```

(3) director1 で、停止する Dovecot バックエンドホストへの既存振り分け
    情報を削除 (director2 での操作は不要※)

```console
director1# /opt/osstech/bin/doveadm director flush 10.0.0.2
```

※ director2 側で dovecot2 との組合せで動作テストする必要がある場合、
director2 で dovecot1 への振り分け情報を削除する必要がある。

```console
director2# /opt/osstech/bin/doveadm director flush 10.0.0.1
```

(4) dovecot2 で既存のセッションを切断

```console
dovecot2# /opt/osstech/bin/doveadm kick 0.0.0.0/0
```

(5) director2, dovecot2 で各種保守、テスト作業を実施

(6) director1 で、停止した Dovecot バックエンドホスト(dovecot2)への
    新規振り分けを有効化 (director2 での操作は不要※)

```console
director1# /opt/osstech/bin/doveadm director add 10.0.0.2 100
```

※ 手順(2)で director2 で dovecot1 への振り分けを停止した場合は、
これも戻す必要がある。

```console
director2# /opt/osstech/bin/doveadm director add 10.0.0.1 100
```

(7) director1, director2 の両ホストで poolmon を起動

```console
director1# service dovecot-poolmon start
```

```console
director2# service dovecot-poolmon start
```

TODO
----------------------------------------------------------------------

* Director サービスのポート (9090/TCP が標準らしい) のアクセス制限どうすんだよ。
* LMTP サービスのアクセス制限もどうすんだよ。
    * Dovecot に TCP Wrappers サポートがあるが、
      こいつはユーザー認証しない Director や LMTP サービスには効かない。
* バックエンドに Doveadm サーバーを立てればフロントエンドの Director から
  `doveadm` によるメールボックス操作も振り分け可能。
* ~~Wiki に Doveadm server の設定も載っているが、何が嬉しいのかわからない。
  必須ではない(と思う)ので使わない予定。~~
