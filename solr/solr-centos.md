---
title: Apache Solr + Tomcat を CentOS にインストール
tags: [solr]
layout: default
---

メモ。必要最低限のパッケージと作業のみを記述。
まだほとんど使用していないので穴があるかもしれない。

ソフトウェア構成：

  * CentOS 6
  * Tomcat 6 (CentOS RPM パッケージ)
  * OpenJDK 1.7 (CentOS RPM パッケージ)
  * Apache Solr 4.6.0 (Apache Solr サイトから `solr-<バージョン>.tgz` を入手)

ファイル構成:

  * `/etc/tomcat6`
  * `/var/lib/tomcat6/webapps/solr` (Solr サーブレット)
  * `/var/solr` (Solr ホームディレクトリ)

* * *

RHEL の場合は RHEL Server Optional チャンネルを有効にする必要がある。

``` console
# rhn-channel -a -c rhel-`uname -i`-server-optional-`lsb_release -sr |sed 's/\..*//'`
```

OpenJDK 1.7 と Tomcat 6 をインストールする。

``` console
# yum install -y java-1.7.0-openjdk tomcat6
```

Solr 4.6.0 をダウンロードしてインストールする。
依存 JAR は付属のものを利用する。

``` console
# wget -q http://apache.claz.org/lucene/solr/4.6.0/solr-4.6.0.tgz
# tar xzf solr-4.6.0.tgz
# unzip -d /var/lib/tomcat6/webapps/solr solr-4.6.0/dist/solr-4.6.0.war
# cp -p --no-clobber solr-4.6.0/dist/solrj-lib/* /var/lib/tomcat6/webapps/solr/WEB-INF/lib/
# mkdir -p -m 02750 /var/solr
# cp -rp solr-4.6.0/example/solr/* /var/solr/
# chown -hR root:tomcat /var/solr
# chown -hR tomcat /var/solr/collection1/data
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
管理者とクライアント用のロールとユーザーを追加する。
(FIXME: 管理用とクライアント用のロールを個別に用意する)

``` xml
<tomcat-users>
…省略…
  <role rolename="solr-admin" />
  <user username="solr-admin" password="パスワード" roles="solr-admin" />
  <user username="dovecot" password="パスワード" roles="solr-admin" />
</tomcat-users>
```

`/var/lib/tomcat6/webapps/solr/WEB-INF/web.xml` に Solr
へのアクセスのセキュリティ制約とログインの設定を追加する。
(FIXME: 管理用とクライアント用のロール別に許可する URL を分ける)

``` xml
<web-app>
…省略…
  <security-constraint>
    <web-resource-collection>
      <web-resource-name>Solr Admin</web-resource-name>
      <url-pattern>/*</url-pattern>
    </web-resource-collection>
    <auth-constraint>
       <role-name>solr-admin</role-name>
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

