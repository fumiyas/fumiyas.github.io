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

参考:

  * 続・GitHubクローンのGitLabを５分でインストールした - アルパカDiary
    * http://d.hatena.ne.jp/toritori0318/20140524/1400955383

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
  * Chef
  * そのほか

### 初期ユーザー

  * ユーザー名: `root`
  * パスワード: `5iveL!fe`

パッケージの入手
----------------------------------------------------------------------

GitLab CE のダウンロードページ https://about.gitlab.com/downloads/ を開き、
「I want to install GitLab on」から「Debian 8」
を選択するとパッケージの入手方法と導入手順が表示されるので参照する。

…が、2015年5月現在、手順通りに作業すると最新版の GitLab はインストールされない。

そこで、同ページの下部「Omnibus Packages」の「Download the package」を開き、
さらに「`gitlab-ce_<バージョン>~omnibus-1_amd64.deb` debian/jessie」を開き、
画面右上の「Download」ボタンを押して deb パッケージをダウンロードする。
パッケージファイルのサイズは 300 MB 超あるので注意。

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

`/etc/passwd`、`/etc/group` ファイルではなく LDAP
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
# dpkg -i gitlab_<バージョン>-omnibus-1_amd64.deb
```

GitLab CE Omnibus の基本操作手順
----------------------------------------------------------------------

### `gitlab-ctl` コマンド

`/usr/bin/gitlab-ctl` コマンドで様々な操作が可能。

```console
# gitlab-ctl
…有効なサブコマンドと説明の一覧…
# gitlab-ctl status
run: logrotate: (pid 8984) 1974s; run: log: (pid 24524) 78533s
nginx disabled
run: postgresql: (pid 8987) 1973s; run: log: (pid 18827) 169590s
run: redis: (pid 8995) 1973s; run: log: (pid 18770) 169596s
run: sidekiq: (pid 9000) 1973s; run: log: (pid 18948) 169577s
run: unicorn: (pid 9016) 1972s; run: log: (pid 18924) 169579s
```

### `/etc/gitlab/gitlab.rb` 設定変更の反映手順

`/etc/gitlab/gitlab.rb` を変更したら以下を実行する。
組込みの Chef が実行され構成に反映される。

```console
# gitlab-ctl reconfigure
```

Unicorn (バックエンド Web サーバー) の調整
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

`/etc/gitlab/gitlab.rb` の `unicorn['worker_timeout']`
パラメーターでタイムアウト時間 (秒) を調整して対処する。

```ruby
unicorn['worker_timeout'] = 180
```

メール発信に SMTP サーバーを利用する
----------------------------------------------------------------------

デフォルトは sendmail コマンドを利用してメールを発信する。

SMTP サーバーを利用するには `/etc/gitlab/gitlab.rb` を次のように設定する。

```ruby
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.example.jp"
```

デフォルトでは、SMTP サーバーがクライアントからの `EHLO` コマンドに対して
`STARTTLS` を応答すると、自動的に TLS を利用する点に注意。

SMTP サーバーに localhost を指定した場合、
サーバー証明書に記載のサーバー名と[localhost」が一致しないため、
証明書の検証処理で不正と判断され、メール発信が失敗してしまう。
このようなときは、 `gitlab_rails['smtp_enable_starttls_auto'] = false`
を設定するとよい。

```ruby
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "localhost"
gitlab_rails['smtp_enable_starttls_auto'] = false
```

nginx (フロントエンド Web サーバー) の調整
----------------------------------------------------------------------

### URL、ポート番号の変更

必要であれば HTTP サーバーのサーバー名とポート番号を調整する。

`/etc/gitlab/gitlab.rb` の `external_url` に指定するパラメーターを変更する。

```ruby
external_url 'http://gitlab.example.jp'
```

### nginx の無効化

Omnibus 付属の nginx ではなく別の Web サーバーをフロントエンドに利用したい場合は、
nginx を無効にする。

`/etc/gitlab/gitlab.rb` の `nginx['enable']` パラメーターで nginx を無効化し、
`web_server['external_users']` パラメーターでフロントエンド
Web サーバーの実行ユーザーを指定する。
必要であれば `external_url` に指定するパラメーターも変更する。

```ruby
external_url 'http://gitlab.example.jp'
nginx['enable'] = false
web_server['external_users'] = ['www-data']
```

Apache HTTPD をフロントエンド Web サーバーにする場合の設定例:

```apache
<VirtualHost *:80>
  ServerName gitlab.example.jp
  DocumentRoot /opt/gitlab/embedded/service/gitlab-rails/public

  ## HTTPS を利用する場合:
  ##   * gitlab.rb の external_url を 'https://〜' に変更する。
  ##   * 上記の <VirtualHost *:80> を <VirtualHost *:443> に変更する。
  ##   * 以下のコメント文字を外して SSL を有効にする。
  #SSLEngine On
  #SSLCertificateKeyFile /etc/apache2/private/gitlab.example.jp.key
  #SSLCertificateFile /etc/apache2/certs/gitlab.example.jp.crt
  #RequestHeader set X-Forwarded-Proto 'https'

  AllowEncodedSlashes NoDecode

  ProxyPreserveHost On
  RewriteEngine On
  RewriteCond %{DOCUMENT_ROOT}%{REQUEST_FILENAME} !-f
  RewriteRule .* http://127.0.0.1:8080%{REQUEST_URI} [proxy,qsappend]

  ## GitLab のアイコンとロゴを独自のものに入れ換える場合:
  #Alias /favicon.ico /srv/www/gitlab.example.jp/public/example-favicon.ico
  #AliasMatch ^/assets/favicon-[0-9a-f]+\.ico$ /srv/www/gitlab.example.jp/public/example-favicon.ico
  #AliasMatch ^/assets/logo-[0-9a-f]+\.svg$ /srv/www/gitlab.example.jp/public/example-logo.png
       
  ErrorDocument 404 /404.html
  ErrorDocument 422 /422.html
  ErrorDocument 500 /500.html
  ErrorDocument 503 /deploy.html

  <Location />
    Require all granted
  </Location>
</VirtualHost>
```

LDAP サーバーを認証バックエンドに利用する
----------------------------------------------------------------------

`/etc/gitlab/gitlab.rb` で Rails の LDAP 設定をする。

```ruby
gitlab_rails['ldap_enabled'] = true
gitlab_rails['ldap_servers'] = YAML.load <<-EOS
main:
  label: 'LDAP'     ## ログインページに表示するラベル
  host: '127.0.0.1' ## LDAP サーバーホスト名または IPアドレス
  port: 389         ## LDAP サーバーポート番号
  method: 'plain'   ## "tls", "ssl" or "plain"
  bind_dn: 'cn=gitlab,dc=example,dc=co,dc=jp'
  password: 'bind password for bind_dn'
  uid: 'uid'        ## ユーザーIDを保持する属性名
  active_directory: false
  allow_username_or_email_login: false
  base: 'ou=Users,dc=example,dc=co,dc=jp'
  user_filter: '(&(objectclass=posixAccount)(!(gidNumber=10001)))'
EOS
```

LDAP のユーザーが初めてログインすると、ユーザーの LDAP エントリの
`mail`、`email`、`userPrincipalName` 属性のいずれかの値が
E-mail アドレスとして登録される。しかし、いずれの属性も持たない場合は
`temp-email-for-oauth-<ユーザー名>@gitlab.localhost` になってしまう。
また、この情報は管理者しか変更できない。

E-mail に使用する属性がない場合に `<ユーザー名>@example.jp`
にするモンキーパッチの例を示す。
`/opt/gitlab/embedded/service/gitlab-rails/config/initializers/local.rb`
ファイルを以下の内容で作成する。
(既存ファイルと被らなければファイル名は `<任意の名前>.rb` でよい)

```ruby
module OmniAuth
  module Strategies
    class LDAP
      class << self
        alias_method :map_user_orig, :map_user
      end

      def self.map_user(mapper, object)
        object['mail'] += ["#{object['uid'].first}@example.jp"]
        self.map_user_orig(mapper, object)
      end
    end
  end
end
```

そのほか
----------------------------------------------------------------------

### ユーザー情報の直接編集

`/usr/bin/gitlab-rails console production` で GitLab 環境の
Rails コンソールを開くとパスワードなどのユーザー情報を直接編集できて便利。

```console
# /usr/bin/gitlab-rails console production
…省略…
irb(main):001:0> user = User.where(email: "admin@example.com").first
=> #<User id: 1, email: "admin@example.com", encrypted_password: …省略…
…省略…
irb(main):002:0> user.password=user.password_confirmation='HogeHoge'
=> "HogeHoge"
irb(main):003:0> user.save!
=> true
```

### `~git/.ssh/authorized_keys` の再構築

実験で `~git/.ssh/authorized_keys` ファイルを手動で変更したりしたせいか、
GitLab の Web UI で SSH 公開鍵を編集しても反映されなくなってしまった。

再構築するためのコマンライン:

```console
# /usr/bin/gitlab-rake gitlab:shell:setup
…省略…
This will rebuild an authorized_keys file.
You will lose any data stored in authorized_keys file.
Do you want to continue (yes/no)? yes

.........
```

