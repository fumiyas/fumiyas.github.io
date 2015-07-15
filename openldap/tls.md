---
title: "OpenLDAP: TLS 関連"
tags: [openldap, tls]
layout: default
---

CRL の参照
----------------------------------------------------------------------

OpenLDAP がリンクしている TLS 実装に依って異なる。

### 参考

  * Checking client certificates against CRLs 
    * http://www.openldap.org/lists/openldap-technical/201404/threads.html#00061

### OpenSSL の場合

CA 証明書と CRL を格納するディレクトリを用意する。

```console
# mkdir -p /path/to/cacerts
```

CA が発行した CRL 情報を含むファイルを先に作成したディレクトリに置く。
CRL ファイルの内容は PEM 形式である必要がある。

以下ではファイル名を `/path/to/cacerts/ca.example.com.pem` とする。

CRL ファイルの情報から CRL のハッシュ値を求める。

```console
# cd /path/to/cacerts
# /opt/osstech/bin/openssl crl -hash -noout -in ca.example.com.pem
<CRLのハッシュ値>
```

CRL ファイルへのシンボリックリンク `<CRLのハッシュ値>.r0` を作成する。

```
# cd /path/to/cacerts
# ln -s ca.example.com.pem <CRLのハッシュ値>.r0
```

CRL ファイルのシンボリックリンク `<CRLのハッシュ値>.r<番号>`
が既に存在する場合は不要。

すでに同名のシンボリックリンクが存在する場合は末尾の数字を
増加した名前にする。 (例: `<CRLのハッシュ値>.r1` など)

OpenLDAP ライブラリー/ツールの設定ファイル
`/opt/osstech/etc/openldap/ldap.conf` に次の設定を記述する。

```
TLS_CRLCHECK all
TLS_CACERTDIR /path/to/cacerts
```

確認。

```
$ /opt/osstech/bin/ldapsearch \
    -xZZ \
    -H ldap://<CRL にない証明書を持つ LDAP サーバー名> \
    <必要であればそのほか適切なオプション>
$ /opt/osstech/bin/ldapsearch \
    -xZZ \
    -H ldap://<CRL にある証明書を持つ LDAP サーバー名> \
    <必要であればそのほか適切なオプション>
```

### Mozilla NSS の場合

未対応?

### GnuTLS の場合

`TLS_CRLCHECK` の代わりに `TLS_CRLFILE` を使用するらしい。未確認。
