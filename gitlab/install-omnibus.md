---
title: GitLab CE Omnibus のインストール
tags: [git,gitlab,debian]
layout: default
---

GitLab CE (Community Edition) Omnibus (全部入り)
パッケージのインストールと初期設定の手順。
随時更新しているが、現在は GitLab CE 8.8.2, Debian unstable を対象とする。

公式ドキュメントにほぼ網羅されているので、読む。

  * <https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/README.md>

参考:

  * 続・GitHubクローンのGitLabを５分でインストールした - アルパカDiary
      * <http://d.hatena.ne.jp/toritori0318/20140524/1400955383>

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
      * デフォルト TCP ポート: `*:80`
  * Unicorn
      * バックエンド Web サーバー (Rails 実行環境)
      * デフォルト TCP ポート: `127.0.0.1:8080`
      * デフォルト UNIX ドメインポート: `/var/opt/gitlab/gitlab-workhorse/socket`
  * PostgreSQL
      * デフォルトポート: `/tmp/.s.PGSQL.5432`
  * Redis
      * デフォルトポート: `127.0.0.1:6379`
  * Chef
  * そのほか

### 初期ユーザー

  * ユーザー名: `root`
  * パスワード: `5iveL!fe`

MTA と SSH サーバーのインストール
----------------------------------------------------------------------

任意の MTA と SSH サーバーをインストールする。

```console
# apt-get install postfix openssh-server
```

システムユーザーの作成
----------------------------------------------------------------------

***通常はこの節の作業は必要ない。***

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

GitLab CE Omnibus パッケージのリポジトリの設定とインストール
----------------------------------------------------------------------

GitLab のダウンロードページ <https://about.gitlab.com/downloads/> を開き、
「Omnibus package installation (recommended)」から「Debian」
を選択するとパッケージリポジトリの導入手順が表示されるので参照する。

```console
# curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.deb.sh |bash
...省略...
# EXTERNAL_URL="http://gitlab.example.jp" apt-get install gitlab-ce
...省略...
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

### `gitlab-rake` コマンド

```console
# gitlab-rake gitlab:env:info

System information
System:         Debian 10
Current User:   git
Using RVM:      no
Ruby Version:   2.6.5p114
Gem Version:    2.7.10
Bundler Version:1.17.3
Rake Version:   12.3.3
Redis Version:  5.0.7
Git Version:    2.24.1
Sidekiq Version:5.2.7
Go Version:     go1.11.6 linux/amd64

GitLab information
Version:        12.7.6
Revision:       61654d25b20
Directory:      /opt/gitlab/embedded/service/gitlab-rails
DB Adapter:     PostgreSQL
DB Version:     10.9
URL:            https://gitlab.example.jp
HTTP Clone URL: https://gitlab.example.jp/some-group/some-project.git
SSH Clone URL:  git@gitlab.example.jp:some-group/some-project.git
Using LDAP:     yes
Using Omniauth: yes
Omniauth Providers:

GitLab Shell
Version:        11.0.0
Repository storage paths:
- default:      /var/opt/gitlab/git-data/repositories
GitLab Shell path:              /opt/gitlab/embedded/service/gitlab-shell
Git:            /opt/gitlab/embedded/bin/git
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

SMTP サーバーに `localhost` を指定した場合、
サーバー証明書に記載のサーバー名と `localhost` が一致しないため、
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
external_url 'https://gitlab.example.jp'
```

### nginx の無効化

Omnibus 付属の nginx ではなく別の Web サーバーをフロントエンドに利用したい場合は、
nginx を無効にする。

`/etc/gitlab/gitlab.rb` の `nginx['enable']` パラメーターで nginx を無効化し、
`web_server['external_users']` パラメーターでフロントエンド
Web サーバーの実行ユーザーを指定する。
必要であれば `external_url` に指定するパラメーターも変更する。

```ruby
external_url 'https://gitlab.example.jp'
nginx['enable'] = false
web_server['external_users'] = ['www-data']
```

Apache HTTPD 2.4.7+ をフロントエンド Web サーバーにする場合の設定例:

<!--
FIXME: GitHub Pages fails to build a page from this page with "apache" highlighter.

  * Apache Lexer raises NoMethodError error · Issue #385 · jneen/rouge
      * https://github.com/jneen/rouge/issues/385
-->

```conf
<VirtualHost *:443>
  ServerName gitlab.example.jp
  DocumentRoot /opt/gitlab/embedded/service/gitlab-rails/public

  SSLEngine On
  SSLCertificateKeyFile /etc/apache2/private/gitlab.example.jp.key
  SSLCertificateFile /etc/apache2/certs/gitlab.example.jp.crt
  RequestHeader set X-Forwarded-Proto 'https'

  AllowEncodedSlashes NoDecode

  ProxyPreserveHost On
  RewriteEngine On

  RewriteCond %{DOCUMENT_ROOT}%{REQUEST_FILENAME} !-f [ornext]
  RewriteCond %{REQUEST_URI} ^/uploads/
  RewriteRule ^ unix:/var/opt/gitlab/gitlab-workhorse/socket|http://127.0.0.1%{REQUEST_URI} [proxy,qsappend,noescape]

  ## GitLab の Fav アイコンを独自のものに入れ換える場合:
  #Alias /favicon.ico /srv/www/gitlab.example.jp/public/example-favicon.ico
  #AliasMatch ^/assets/favicon-[0-9a-f]{64}\.ico$ /srv/www/gitlab.example.jp/public/example-favicon.ico
  ## GitLab のロゴは HTML 埋め込みの SVG になったため、
  ## URL 書き換えでは変更できなくなった。以下は旧 GitLab 用の設定:
  #AliasMatch ^/assets/logo-[0-9a-f]{64}\.png$ /srv/www/gitlab.example.jp/public/example-logo.png
       
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
  bind_dn: 'cn=gitlab,dc=example,dc=jp'
  password: 'bind password for bind_dn'
  uid: 'uid'        ## ユーザーIDを保持する属性名
  active_directory: false
  allow_username_or_email_login: false
  base: 'ou=Users,dc=example,dc=jp'
  user_filter: '(&(objectclass=posixAccount)(!(gidNumber=10001)))'
EOS
```

設定の確認:

```console
# gitlab-rake gitlab:ldap:check
Checking LDAP ...

Server: ldapmain
LDAP authentication... Success
LDAP users with access to your GitLab server (only showing the first 100 results)
        DN: uid=alice,ou=Users,dc=example,dc=jp  uid: alice
        ...

Checking LDAP ... Finished
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

GitLab 環境の Rails コンソールを開くとパスワードなどのユーザー情報を直接編集できて便利。

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

### PostgreSQL `psql` でデータベースへ接続

```console
# gitlab-psql -d gitlabhq_production
```

`psql` コマンド、SQL の実行例:

```
gitlabhq_production=# \d
…テーブル一覧…
gitlabhq_production=# \d users
… users テーブルスキーマ表示…
gitlabhq_production=# SELECT row_to_json(users,TRUE) FROM users;
… users テーブルの全レコードを pretty-print な JSON 形式で表示…
```

### LDAP のユーザーエントリの DN を変更したい

LDAP で認証・登録されたユーザーは、
GitLab のデータベースで GitLab ユーザーと LDAP ユーザーエントリの
DN と関連付けされる。このため、LDAP ユーザーエントリの DN を
変更すると、登録されている GitLab ユーザー情報と切り離されてしまう。

LDAP の DN と GitLab ユーザーはデータベースで次のように関連付けされている。

```console
gitlabhq_production=# SELECT id,username FROM users WHERE username='fumiyas';
 id | username
----+----------
 15 | fumiyas
(1 row)

gitlabhq_production=# SELECT user_id,extern_uid FROM identities WHERE user_id=15;
 user_id |                 extern_uid
---------+---------------------------------------------
      15 | uid=fumiyas,ou=Users,dc=example,dc=jp
(1 row)
```

例として、一括して DN を変更するための SQL を載せておく。

```sql
UPDATE identities
  SET extern_uid = concat('uid=', u.username, ',ou=Users,dc=example,dc=jp')
  FROM (SELECT id,username FROM users) u
  WHERE identities.user_id = u.id
;
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

### プロジェクトを公開せずに Git リポジトリだけ特定ネットワークに公開

GitLab 上のプロジェクトの Git リポジトリにアクセスするには、
プロジェクトを公開設定 (public) にしてユーザー認証なしで Git over HTTP でアクセス、
もしくは GitLab ユーザー認証ありで Git over HTTP または Git over SSH でアクセスする必要がある。

プロジェクトを公開設定にすると、リポジトリ以外も公開されて誰でもアクセスできるようになってしまうので、
それでは嬉しくないこともある。
そこで、プロジェクトは非公開 (Internal または Private) に設定し、
特定ネットワークに対してのみユーザー認証なしでリポジトリアクセス可能にする設定例を示す。
(フロントエンドに Apache を利用する場合)

最初に Apache の実行ユーザー `www-data` が GitLab 配下の Git
リポジトリのファイル群にアクセスできるようにする。しかし、
`/var/opt/gitlab/git-data` のモードが `drwx------` になっており、
手動で変更しても `gitlab-ctl reconfigure` で戻ってしまう。
グループのアクセス権がないため、もしここに ACL を設定しても、効果がない。
そこで、代わりに
`/var/opt/gitlab/git-data/repositories` (`drwxrwx---`) を
`/var/opt/gitlab/git-data-repositories` にバインドマウントして利用する。

```console
# mkdir -m 0755 /var/opt/gitlab/git-data-repositories
# echo '/var/opt/gitlab/git-data/repositories /var/opt/gitlab/git-data-repositories none bind 0 2' >>/etc/fstab
# mount /var/opt/gitlab/git-data-repositories
# setfacl -m user:www-data:r-x /var/opt/gitlab/git-data-repositories
```

グループ名 `groupname` のプロジェクト `projectname` を公開するための
ACL を設定する。

```console
# setfacl -m user:www-data:r-x /var/opt/gitlab/git-data-repositories/groupname
# find /var/opt/gitlab/git-data-repositories/groupname/projectname.git \
  -type d -exec setfacl -m user:www-data:r-x,default:user:www-data:r-x {} + \
  -o \
  -type f -exec setfacl -m user:www-data:r-- {} + \
;
```

Apache の GitLab 向け `<VirtualHost>` ブロックに以下のように設定を追加する。

```conf
  ## ほかの RewriteRule より前に追加
  RewriteRule ^/projectname/projectname\.git(/.*)?$ - [last]

  ## 適当な場所に追加
  ScriptAlias /projectname/projectname.git /usr/lib/git-core/git-http-backend/projectname/projectname.git
  SetEnv GIT_PROJECT_ROOT /var/opt/gitlab/git-data-repositories
  SetEnv GIT_HTTP_EXPORT_ALL

  ## <Location /> ブロックの後に追加
  <Location /projectname/projectname.git>
    Require ip 192.168.0.0/24
  </Location>
```
