---
title: Apache Solr 4.6.0 を CentOS 6 にインストール
tags: [solr]
layout: default
---

メモ。必要最低限のパッケージと作業のみを記述。
まだほとんど使用していないので穴があるかもしれない。

Java 7 と Tomcat 6 をインストールする。 (Java 6 と 7 の違いは知らない)

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
# mkdir -p -m 02770 /var/solr
# cp -rp solr-4.6.0/example/solr/* /var/solr/
# chown -hR tomcat:tomcat /var/solr
```

`/etc/sysconfig/tomcat6` の最後のほうに
Solr の作業ディレクトリの場所を指定する記述を追加する。
(`/etc/tomcat6/tomcat6.conf` でもよいが、
複数の Tomcat インスタンスを起動する場合は避けること。
`/etc/sysconfig/tomcat6` ファイル先頭のコメント参照)

``` sh
SOLR_HOME="/var/solr"
JAVA_OPTS="$JAVA_OPTS -Dsolr.solr.home=${SOLR_HOME}"
```

`/etc/tomcat6/server.xml` の `<Connector port="8080" 〜 />` に
`useBodyEncodingForURI="true"` を追加する。

```
    <Connector port="8080" protocol="HTTP/1.1"
               useBodyEncodingForURI="true"
               connectionTimeout="20000"
               redirectPort="8443" />
```

ブート時の Tomcat 自動起動を有効化し、Tomcat サービスを起動する。

``` console
# chkconfig tomcat6 on
# service tomcat6 start
```

http://ホスト名:8080/solr にアクセス!

TODO:

  * Solr 設定
  * アクセス制限

