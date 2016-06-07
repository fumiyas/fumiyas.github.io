---
title: UNIXユーザーネームサービス障害時の宛先存在確認問題と対策 - Postfix Advent Calendar 2014
tags: [postfix]
layout: default
---

[Postfix Advent Calendar 2014](http://qiita.com/advent-calendar/2014/postfix) の 19日目の記事です。
今回も安定の 5日遅れです。毎度毎度すみません。

今回は、`/etc/passwd` に加え、LDAP サーバーやデータベースシステムを UNIX
ユーザー情報源として利用している場合に発生する問題と、その回避方法について紹介します。

Postfix ローカルユーザー = UNIX ユーザー
----------------------------------------------------------------------

Postfix の標準の設定 (かつデフォルト) では、`mydestination`
パラメーターで示されるドメインのユーザー(ローカルユーザー)は、
Postfix 稼動ホスト OS のユーザーになります。
Postfix は UNIX 系の OS 向けに実装されているため、
Postfix ローカルユーザー = UNIX ユーザーと言えます。

一方、UNIX のユーザーは、様々なサービスで維持・管理することができます。
もっとも代表的なものは `/etc/passwd` ファイルに保持される、旧来からの
`passwd`(5) 情報です。
これ以外にも、ネームサービススイッチと呼ばれる仕組み (`nsswitch.conf`(5))
によって、LDAP サーバーやデータベースシステムなどを利用することができます。

ネームサービス障害時の Postfix の挙動
----------------------------------------------------------------------

### `/etc/passwd` の障害

`/etc/passwd` を読み込みを阻害して障害をシミュレートしてみましょう。

```console
# chmod go-r /etc/passwd
```

適当なクライアントから `/etc/passwd` に存在するユーザー `passwduser`
宛にメールを送ってみます。以下の例では `telnet` コマンドで試行しています。

```console
$ telnet mail.example.jp 25
Trying 10.0.0.1...
Connected to mail.example.jp.
Escape character is '^]'.
220 mail.example.jp ESMTP Postfix
mail from:<>
250 2.1.0 Ok
rcpt to:<passwduser@example.jp>
451 4.3.0 <passwduser@example.jp>: Temporary lookup failure
quit
221 2.0.0 Bye
Connection closed by foreign host.
```

宛先アドレス `passwduser@example.jp` が拒否されましたが、
応答コードが `4XX` なので一時エラー扱いです。
これなら、障害復旧後に再送してもらえることを期待できます。

このときのログは次のようになります。

```
Dec 24 00:26:45 mail postfix/proxymap[26447]: warning: cannot access UNIX password database: Connection refused
Dec 24 00:26:45 mail postfix/smtpd[26446]: NOQUEUE: reject: RCPT from mua.example.jp[10.0.0.4]: 451 4.3.0 <passwduser@example.jp>: Temporary lookup failure; from=<> to=<passwduser@example.jp> proto=SMTP
```

### ネームサービスサーバーの障害

ネームサービスに LDAP サーバーを利用している状態であると仮定します。
LDAP サービスを停止した状態で、LDAP サーバー上に存在するユーザー `ldapuser`
宛にメールを送ってみます。

```console
$ telnet mail.example.jp 25
Trying 10.0.0.1...
Connected to mail.example.jp.
Escape character is '^]'.
220 mail.example.jp ESMTP Postfix
mail from:<>
250 2.1.0 Ok
rcpt to:<ldapuser@example.jp>
550 5.1.1 <ldapuser@example.jp>: Recipient address rejected: User unknown in local recipient table
quit
221 2.0.0 Bye
Connection closed by foreign host.
```

これも宛先アドレス `ldapuser@example.jp` が拒否されましたが、
今度の場合は応答コードが `5XX` なので恒久エラー扱いです。
送信元が MTA であれば、再試行はせずに、即座にバウンスしてしまいます!
このようにネームサービス (LDAP サーバー) の一時的な障害にもかかわらず、
恒久エラーとなってしまう問題が起きてしまいます。

このときのログは次のようになります。

```
Dec 24 00:48:19 mail postfix/smtpd[27862]: NOQUEUE: reject: RCPT from mua.example.jp[10.0.0.4]: 550 5.1.1 <ldapuser@example.jple.jp>: Recipient address rejected: User unknown in local recipient table; from=<> to=<ldapuser@example.jple.jp> proto=SMTP
```

ネームサービスに
SSS (`nss_sss`) や PADL nss-pam-ldapd (`nss_ldap`)
を利用している場合は、その直接のバックエンドである `sssd` や `nslcd`
の障害時にも同様の結果になります。

Postfix のコードを読んでみる
----------------------------------------------------------------------

Postfix がローカルユーザーの存在を確認する際に参照するテーブルは何でしょうか。
それは `local_recipient_maps` パラメーターの値が示しています。
デフォルトなら次のような設定になっています。

```console
# postconf local_recipient_maps
local_recipient_maps = proxy:unix:passwd.byname $alias_maps
```

`proxy` (`proxymap`(8)) を介して `unix` テーブルの `passwd.byname`
でローカルユーザーの確認をしていることがわかります。
そこで Postfix のソースコードから `src/util/dict_unix.c` を参照すると、
以下の部分が該当することがわかります。

```c
static const char *dict_unix_getpwnam(DICT *dict, const char *key)
{
    …省略…
    if ((pwd = getpwnam(key)) == 0) {
        if (sanity_checked == 0) {
            sanity_checked = 1;
            errno = 0;
            if (getpwuid(0) == 0) {
                msg_warn("cannot access UNIX password database: %m");
                dict->error = DICT_ERR_RETRY;
            }
        }
        return (0);
    } else {
        …省略…
    }
    …省略…
```

UNIX ユーザー情報をユーザー名で索く関数 `getpwnam`(3) が失敗 (0 を返す)
したとき、さらに UID 番号 0 で `getpwuid`(3) 関数も試行し、
それも失敗した場合だけ `dict->error = DICT_ERR_RETRY;` するようになっています。

これにより、`/etc/passwd`
のアクセス障害時は両方とも失敗して `/etc/passwd` の障害と認識されるため一時エラーとなり、
そのほかのネームサービスの障害のときは後者は失敗せず、
ユーザーが存在しないと認識されてしまい恒久エラーとなります。

すべてのネームサービス障害を一時エラーにする方法
----------------------------------------------------------------------

### Postfix にネームサービスサーバーを直接参照させる

今回の例のようにネームサービスに LDAP サーバーを利用しているのであれば、
`ldap_table`(5) でローカルユーザーの確認をさせればよいです。
`ldap_table`(5) なら LDAP サーバーが利用できない場合は一時エラーになります。

```cfg
local_recipient_maps =
  ldap:$config_directory/local_recipient.ldap.cf
  $alias_maps
```

参考までに `local_recipient.ldap.cf` の例も載せておきましょう。

```cfg
server_host = ldaps://ldap.example.jp/
version = 3
search_base = ou=users,dc=example,dc=jp
scope = sub
query_filter = (&(objectClass=posixAccount)(uid=%s))
result_attribute = uid
```

### Postfix を改修する

確認はしていませんが、
Postfix のソースコードの `src/util/dict_unix.c` を次のように変更することにより、
すべてのネームサービス障害を一時エラーにできるのではないかと思われます。

```c
static const char *dict_unix_getpwnam(DICT *dict, const char *key)
{
    …省略…
    if ((pwd = getpwnam(key)) == 0) {
        if (sanity_checked == 0) {
            sanity_checked = 1;
            errno = 0;
            getpwnam(":");
            if (errno != 0 && errno != ENOENT) {
                msg_warn("cannot access UNIX password database: %m");
                dict->error = DICT_ERR_RETRY;
            }
        }
        return (0);
    } else {
        …省略…
    }
    …省略…
```

ただし、ネームサービス障害時の `getpwnam`(3) による `errno` 値に標準はなく、
C ライブラリーやネームサービスモジュールの実装に依存している模様です。
この変更では対応できないケースがあるかもしれません。

* * *

{% include wishlist-dec.html %}

