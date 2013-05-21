---
title: "Linux オートマウント"
layout: default
tags: [linux, autofs, home]
---
Linux オートマウント
======================================================================

概要
----------------------------------------------------------------------

あとで書く。いつか書く。

`autofs`(8), `automount`(8), `auto.master`(5)

インストール
----------------------------------------------------------------------

Debian / Ubuntu の場合:

``` console
# apt-get install autofs
```

RHEL の場合:

``` console
# yum install autofs
# chkconfig autofs on
```

ホームディレクトリの自動作成
----------------------------------------------------------------------

ユーザーの作成と同時にホームディレクトリも作成できればよいですが、
LDAP サーバーでユーザー情報を管理している場合など、
ユーザー作成と連携するのが困難な場合があります。
そのような場合はオートマウントの実行プログラムマップ機能を利用し、
ホームディレクトリにアクセスされたときに自動的に作成する方法が便利です。

次の条件とします。

  * ホームディレクトリにアクセスが発生したとき、ディレクトリがなければ自動的に作成し、
    自動的にマウントする。
  * ホームディレクトリの実体は `/export/home/ユーザー名` に作成する。
  * マウント先は `/home/ユーザー名` とする。

`/etc/auto.master` ファイルに、ホームディレクトリのマウント場所と、
ホームディレクトリの自動作成とマップ情報を提供する実行プログラムを指定
する設定を記述します。

``` console
/home   program:/etc/auto.home
```

`/etc/auto.home` ファイルを作成し、内容を次のような動作をするシェルスクリプトにします。

  1. オートマウンター `automount` プロセスから第1引数に渡されたユーザー名
     (アクセスされたマウント先 `/home` 下の名前) を受け取る。
  2. ユーザーの存在を確認する。
  3. ユーザーのホームディレクトリが不在なら作成する。
  4. 「`localhost:<マウント元ディレクトリ>`」を出力する。
     オートマウンターがマップ情報として受け取り、結果、自動マウントされる。
     (オプションも渡したい場合は「`-<オプション>[,...] localhost:<マウント元ディレクトリ>`」を出力する)

``` sh
#!/bin/sh

set -u
set -e

home_root="/export/home"
home_umask="0755"

user_name="$1"; shift

id "$user_name" >/dev/null

user_home="$home_root/$user_name"

if [ ! -d "$user_home" ]; then
  mkdir -p -m "$home_umask" "$user_home"
  cp -a /etc/skel/. "$user_home/"
  chown -hR "$user_name:" "$user_home"
fi

echo "- localhost:$user_home"

exit 0
```

`/etc/auto.home` に実行権限を与えておきます。

``` console
# chmod u+x /etc/auto.home
```

autofs サービスを再起動して `/etc/auto.master` の設定変更を反映します。

``` console
# service autofs restart
```

ユーザーのホームディレクトリにアクセスし、自動的にディレクトリが作成・マウントされることを確認します。

``` console
# ls -la /home/ユーザー名
...
# ls -la /export/home/ユーザー名
...
# mount |grep ユーザー名
...
```
