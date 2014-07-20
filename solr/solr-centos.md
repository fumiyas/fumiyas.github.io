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
  * Apache Solr 4.8.1 (Apache Solr サイトから `solr-<バージョン>.tgz` を入手)

ファイル構成:

  * `/etc/tomcat6`
  * `/var/lib/tomcat6/webapps/solr` (Solr サーブレット)
  * `/var/solr` (Solr ホーム。`$SOLR_HOME`)
  * `/var/solr/dovecot-fts` (Solr コア。Dovecot での利用を想定。名前は任意)

そのほか:

  * Tomcat にロール `solr`, `solr-dovecot`、
    ユーザー `admin`, `dovecot` を作成する。
  * Solr コア `dovecot-fts` を作成し、ロール `solr-dovecot`
    にはこのコアだけアクセス許可する。
  * Tomcat 実行ユーザーにはコア内の `data` ディレクトリだけ書き込みを許可する。

インストール
----------------------------------------------------------------------

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

Solr 4.8.1 をダウンロードしてインストールする。
依存 JAR は付属のものを利用する。

``` console
# wget http://ftp.jaist.ac.jp/pub/apache/lucene/solr/4.8.1/solr-4.8.1.tgz
# tar -xzf solr-4.8.1.tgz --no-same-owner
# cd solr-4.8.1
# unzip -d /var/lib/tomcat6/webapps/solr dist/solr-4.8.1.war
# cp -p --no-clobber dist/solrj-lib/* /var/lib/tomcat6/webapps/solr/WEB-INF/lib/
```

Solr Cell と Apache Tika (オプション)
----------------------------------------------------------------------

付属の Solr Cell プラグインと Apache Tika を利用する場合は関連
JAR をインストールする。

``` console
# cp -p --no-clobber dist/solr-cell-* /var/lib/tomcat6/webapps/solr/WEB-INF/lib/
# cp -p --no-clobber contrib/extraction/lib/* /var/lib/tomcat6/webapps/solr/WEB-INF/lib/
```

Solr ログ (オプション)
----------------------------------------------------------------------

``` console
# mkdir -p -m 0755 /var/lib/tomcat6/webapps/solr/WEB-INF/classes
# vi /var/lib/tomcat6/webapps/solr/WEB-INF/classes/log4j.properties
…省略…
```

`log4j.properties` 設定例:

```
log4j.rootLogger=WARN, file
 
log4j.appender.file=org.apache.log4j.DailyRollingFileAppender
log4j.appender.file.File=${catalina.home}/logs/solr.log
log4j.appender.file.MaxBackupIndex=180
 
log4j.appender.file.DatePattern='.'yyyy-MM-dd
log4j.appender.file.layout=org.apache.log4j.PatternLayout
log4j.appender.file.layout.ConversionPattern=%d %p [%c{3}] - [%t] - %X{ip}: %m%n
```

`$SOLR_HOME` ディレクトリの作成
----------------------------------------------------------------------

`$SOLR_HOME` を作成し、その中に Solr コアの例として `dovecot-fts` を作成する。

```
# mkdir -p -m 02750 /var/solr
# cp -rp example/solr/* /var/solr/
# chown -hR root:tomcat /var/solr
# mv /var/solr/collection1 /var/solr/dovecot-fts
# perl -pi -e 's/^(name)=.*/$1=dovecot-fts/' /var/solr/dovecot-fts/core.properties
# mkdir -m 02750 /var/solr/dovecot-fts/data
# chown tomcat: /var/solr/dovecot-fts/data
```

Tomcat の設定
----------------------------------------------------------------------

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

TODO
----------------------------------------------------------------------

  * Solr 設定

