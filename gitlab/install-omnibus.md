---
title: GitLab CE Omnibus のインストール
tags: [git,gitlab,debian]
layout: default
---

GitLab CE (Community Edition) Omnibus (全部入り)
パッケージのインストールと初期設定の手順。
Debian を対象とする。

公式ドキュメントにほぼ網羅されているので、読む。

  * https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md

構成
----------------------------------------------------------------------

### ディレクトリ構成

  * `/opt/gitlab`
  * `/var/opt/gitlab`
  * `/var/log/gitlab`
  * `/etc/gitlab`

### ソフトウェア構成

  * git
  * Ruby
  * Ruby on Rails
  * runit
    * スーパーデーモン
  * nginx
    * フロントエンド Web サーバー (無効化可能)
    * デフォルトポート: `*:80`
  * Unicorn
    * バックエンド Web サーバー
    * デフォルトポート: `127.0.0.1:8080`
  * PostgreSQL
    * デフォルトポート: `/tmp/.s.PGSQL.5432`
  * Redis
    * デフォルトポート: `127.0.0.1:6379`
  * そのほか

パッケージの入手
----------------------------------------------------------------------

GitLab CE のダウンロードページ https://about.gitlab.com/downloads/ を開き、
「I want to install GitLab on」から「Debian 7」
を選択するとパッケージの入手方法と導入手順が表示されるので参照する。

任意の HTTP クライアントでパッケージをダウンロードする。
パッケージファイルのサイズは 200 GB 弱あるので注意。

```console
# wget https://downloads-packages.s3.amazonaws.com/debian-7.6/gitlab_7.3.2-omnibus-1_amd64.deb
```

MTA と SSH サーバーのインストール
----------------------------------------------------------------------

任意の MTA と SSH サーバーをインストールする。

```console
# apt-get install postfix openssh-server
```

システムユーザーの作成
----------------------------------------------------------------------

`gitlab_<バージョン>-omnibus-<リリース>_amd64.deb`
をインストールすると自動的にシステムユーザーを作成してくれるが、
UID/GID を任意のものを割り当てたい場合はインストール前に自前で作成しておく。

```console
# adduser --system --group --home /var/opt/gitlab --no-create-home --shell /bin/sh git
# adduser --system --group --home /var/opt/gitlab/redis --no-create-home --shell /usr/sbin/nologin gitlab-redis
# adduser --system --group --home /var/opt/gitlab/postgresql --no-create-home --shell /bin/sh gitlab-psql
# adduser --system --group --home /var/opt/gitlab/nginx --no-create-home --shell /usr/sbin/nologin gitlab-www
```

`/etc/passwd`、`/etc/group` ファイル以外の LDAP
サーバーなどにシステムユーザーを登録している場合、
GitLab システム構成変更時に実行される Chef でエラーとなるので、
以下のようにローカルファイルに情報をコピーしておく必要がある。

```console
# getent passwd |egrep '^git(lab-[^:]*)?:' >>/etc/passwd
# getent group |egrep '^git(lab-[^:]*)?:' >>/etc/group
```

GitLab CE Omnibus パッケージのインストール
----------------------------------------------------------------------

```console
# dpkg -i gitlab_7.3.2-omnibus-1_amd64.deb
```

`/usr/bin/gitlab-ctl` コマンドで様々な操作が可能になる。

```console
# gitlab-ctl
…有効なサブコマンドと説明の一覧…
# gitlab-ctl status
run: nginx: (pid 9092) 11s; run: log: (pid 14861) 1366207s
run: postgresql: (pid 9099) 11s; run: log: (pid 14736) 1366226s
run: redis: (pid 9107) 11s; run: log: (pid 14676) 1366232s
run: sidekiq: (pid 9111) 10s; run: log: (pid 14831) 1366213s
run: unicorn: (pid 9116) 10s; run: log: (pid 14807) 1366215s
```

フロントエンド Web サーバーの調整
----------------------------------------------------------------------

### URL、ポート番号の変更

必要であれば HTTP サーバーのサーバー名とポート番号を調整する。

`/etc/gitlab/girlab.rb` の `external_url` パラメーターを変更する。

```
external_url 'http://<サーバー名>:<ポート番号>'
```

`/etc/gitlab/girlab.rb` の変更を反映する。

```console
# gitlab-ctl reconfigure
```

### 無効化

Omnibus 付属の nginx ではなく別の Web サーバーをフロントエンドに利用したい場合は、
nginx を無効にする。

`/etc/gitlab/girlab.rb` の `nginx['enable']` パラメーターを追記する。

```
nginx['enable'] = false
```

`/etc/gitlab/girlab.rb` の変更を反映する。

```console
# gitlab-ctl reconfigure
```
