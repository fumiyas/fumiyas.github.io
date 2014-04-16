---
title: Apache Solr + Tomcat を CentOS にインストール
tags: [solr]
layout: default
---

メモ。必要最低限のパッケージと作業のみを記述。
まだほとんど使用していないので穴があるかもしれない。

ソフトウェア構成：

  * CentOS 6
  * OpenJDK 1.7 (CentOS RPM パッケージ)
  * Tomcat 6 (CentOS RPM パッケージ)
  * Apache Solr 4.7.1 (Apache Solr サイトから `solr-<バージョン>.tgz` を入手)

ファイル構成:

  * `/etc/tomcat6`
  * `/var/lib/tomcat6/webapps/solr` (Solr サーブレット)
  * `/var/solr` (`$SOLR_HOME`)

そのほか:

  * Tomcat にロール `solr`, `solr-dovecot`、
    ユーザー `admin`, `dovecot` を作成する。
  * Solr コア `dovecot-fts` を作成し、ロール `solr-dovecot`
    にはこのコアだけアクセス許可する。

* * *

RHEL の場合は RHEL Server Optional チャンネルを有効にする必要がある。

``` console
# rhn-channel -a -c rhel-`uname -i`-server-optional-`lsb_release -sr |sed 's/\..*//'`
```

OpenJDK 1.7 と Tomcat 6 をインストールする。

``` console
# yum install -y java-1.7.0-openjdk tomcat6
```

`/etc/tomcat6/tomcat-users.xml` が誰でも読めるモードになっているので修正する。

``` console
# chmod o-r /etc/tomcat6/tomcat-users.xml
```

Solr 4.7.1 をダウンロードしてインストールする。
依存 JAR は付属のものを利用する。

``` console
# wget http://ftp.jaist.ac.jp/pub/apache/lucene/solr/4.7.1/solr-4.7.1.tgz
# tar -xzf solr-4.7.1.tgz --no-same-owner
# unzip -d /var/lib/tomcat6/webapps/solr solr-4.7.1/dist/solr-4.7.1.war
# cp -p --no-clobber solr-4.7.1/dist/solrj-lib/* /var/lib/tomcat6/webapps/solr/WEB-INF/lib/
# mkdir -p -m 02750 /var/solr
```

`$SOLR_HOME` を作成し、その中に Solr コアの例として `dovecot-fts` を作成する。

```
# cp -rp solr-4.7.1/example/solr/* /var/solr/
# chown -hR root:tomcat /var/solr
# mv /var/solr/collection1 /var/solr/dovecot-fts
# find dovecot-fts -type f -exec grep -l collection1 /dev/null {} + |xargs perl -pi -e 's/collection1/dovecot-fts/g'
# mkdir -m 02750 /var/solr/dovecot-fts/data
# chown tomcat: /var/solr/dovecot-fts/data
```

`/etc/sysconfig/tomcat6` の最後のほうに
Solr のホームディレクトリの場所を指定する記述を追加する。
(`/etc/tomcat6/tomcat6.conf` でもよいが、
複数の Tomcat インスタンスを起動する場合は避けること。
`/etc/sysconfig/tomcat6` ファイル先頭のコメント参照)

``` sh
SOLR_HOME="/var/solr"
JAVA_OPTS="$JAVA_OPTS -Dsolr.solr.home=${SOLR_HOME}"
```

`/etc/tomcat6/server.xml` の
`<Connector port="8080" 〜 />` に `useBodyEncodingForURI="true"` を追加する。

``` xml
…省略…
    <Connector port="8080" protocol="HTTP/1.1"
               useBodyEncodingForURI="true"
               connectionTimeout="20000"
               redirectPort="8443" />
…省略…
```

`/etc/tomcat6/tomcat-users.xml` に Solr
管理者と Solr コア用のロールとユーザーを追加する。

``` xml
<tomcat-users>
…省略…
  <role rolename="solr" />
  <role rolename="solr-dovecot" />
  <user username="admin" password="パスワード" roles="solr" />
  <user username="dovecot" password="パスワード" roles="solr-dovecot" />
</tomcat-users>
```

`/var/lib/tomcat6/webapps/solr/WEB-INF/web.xml` に Solr
へのアクセスのセキュリティ制約とログインの設定を追加する。

``` xml
<web-app …>
…省略…
  <security-constraint>
    <web-resource-collection>
      <web-resource-name>Solr Admin</web-resource-name>
      <url-pattern>/*</url-pattern>
    </web-resource-collection>
    <auth-constraint>
       <role-name>solr</role-name>
    </auth-constraint>
  </security-constraint>

  <security-constraint>
    <web-resource-collection>
      <web-resource-name>Solr Dovecot FTS</web-resource-name>
      <url-pattern>/dovecot-fts/*</url-pattern>
    </web-resource-collection>
    <auth-constraint>
       <role-name>solr</role-name>
       <role-name>solr-dovecot</role-name>
    </auth-constraint>
  </security-constraint>

  <login-config>
    <auth-method>BASIC</auth-method>
    <realm-name>Solr</realm-name>
  </login-config>
</web-app>
```

ブート時の Tomcat 自動起動を有効化し、Tomcat サービスを起動する。

``` console
# chkconfig tomcat6 on
# service tomcat6 start
```

http://ホスト名:8080/solr/ にアクセス!

TODO:

  * Solr 設定

