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
    * バックエンド Web サーバー (Rails 実行環境)
    * デフォルトポート: `127.0.0.1:8080`
  * PostgreSQL
    * デフォルトポート: `/tmp/.s.PGSQL.5432`
  * Redis
    * デフォルトポート: `127.0.0.1:6379`
  * そのほか

### 初期ユーザー

  * ユーザー名: `root`
  * パスワード: `5iveL!fe`

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

バックエンド Web サーバー (Unicorn) の調整
----------------------------------------------------------------------

### タイムアウト時間の変更

GitLab Web UI への初回アクセス時に裏で何やら初期化作業を実行するらしいが、
これに時間がかかり、バックエンド Web サーバー Unicorn がタイムアウトしまうことがある。
結果、初期化作業は完了できず、アクセスの度にタイムアウトの 30秒待たされてしまう。
`/var/log/gitlab/unicorn/unicorn_stderr.log` には次のようなエラーが記録される。

```
E, [2014-10-24T19:08:54.946515 #17264] ERROR -- : worker=1 PID:17302 timeout (31s > 30s), killing
E, [2014-10-24T19:08:54.995434 #17264] ERROR -- : reaped #<Process::Status: pid 17302 SIGKILL (signal 9)> worker=1
```

`/etc/gitlab/girlab.rb` の `unicorn['worker_timeout']`
パラメーターでタイムアウト時間 (秒) を調整して対処する。

```
unicorn['worker_timeout'] = 180
```

`/etc/gitlab/girlab.rb` の変更を反映する。

```console
# gitlab-ctl reconfigure
```

フロントエンド Web サーバー (nginx) の調整
----------------------------------------------------------------------

### URL、ポート番号の変更

必要であれば HTTP サーバーのサーバー名とポート番号を調整する。

`/etc/gitlab/girlab.rb` の `external_url` に指定するパラメーターを変更する。

```
external_url 'http://<サーバー名>:<ポート番号>'
```

`/etc/gitlab/girlab.rb` の変更を反映する。

```console
# gitlab-ctl reconfigure
```

### nginx の無効化

Omnibus 付属の nginx ではなく別の Web サーバーをフロントエンドに利用したい場合は、
nginx を無効にする。

`/etc/gitlab/girlab.rb` の `nginx['enable']` パラメーターを追記する。
必要であれば `external_url` に指定するパラメーターも変更する。

```
external_url 'http://<サーバー名>:<ポート番号>'
nginx['enable'] = false
```

`/etc/gitlab/girlab.rb` の変更を反映する。

```console
# gitlab-ctl reconfigure
```

Apache HTTPD をフロントエンド Web サーバーにする場合の設定例:

```
<VirtualHost *:ポート番号>
  ServerName サーバー名
  DocumentRoot /opt/gitlab/embedded/service/gitlab-rails/public

  ## HTTPS (SSL) を利用する場合
  #SSLEngine On
  #SSLCertificateFile サーバー証明書ファイルへのパス
  #SSLCertificateKeyFile サーバー鍵ファイルへのパス

  AllowEncodedSlashes NoDecode

  ProxyPreserveHost On
  ProxyPassReverse / http://127.0.0.1:8080/

  RewriteEngine On
  RewriteCond %{DOCUMENT_ROOT}%{REQUEST_FILENAME} !-f
  RewriteRule .* http://127.0.0.1:8080%{REQUEST_URI} [proxy,qsappend]

  ErrorDocument 404 /404.html
  ErrorDocument 422 /422.html
  ErrorDocument 500 /500.html
  ErrorDocument 503 /deploy.html

  <Location />
    Allow From All
  </Location>
</VirtualHost>
```
