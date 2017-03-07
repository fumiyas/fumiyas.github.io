---
title: グループへのアクセス権付与 - OpenLDAP と仲間たち Advent Calendar 2015
tags: [openldap, ldap]
layout: default
---

[OpenLDAP と仲間たち Advent Calendar 2015](http://qiita.com/advent-calendar/2015/openldap) の 12日目の記事です。

OpenLDAP `slapd.conf`(5) の `access` パラメーターは、
`slapd`(8) が持つ LDAP DIT へのアクセス権を設定できます。
今回はグループへのアクセス権の付与の方法を解説します。

LDAP のグループエントリ
----------------------------------------------------------------------

RFC 2256 にグループ用のオブジェクトクラスとして `groupOfNames` と
`groupOfUniqueNames` が定義されています。以下は `groupOfNames`
のエントリの例ですが、これは `member` 属性でグループメンバーとなるエントリの
DN を保持します。`groupOfUniqueNames` の場合は `uniqueMember` 属性である
以外は、ほぼ同じです。

```
dn: cn=managers,ou=Groups,dc=example,dc=jp
objectClass: groupOfNames
cn: managers
member: uid=alice,ou=Users,dc=example,dc=jp
member: uid=bob,ou=Users,dc=example,dc=jp
member: uid=carol,ou=Users,dc=example,dc=jp
```

このほかにも、RFC 2307 では UNIX グループ用のオブジェクトクラス
`posixGroup` が定義されています。これは `memberUid`
属性にメンバーを保持しますが、その形式は DN でなく、
RDN の値となるのが特徴です。

```
dn: cn=managers,ou=Groups,dc=example,dc=jp
objectClass: groupOfNames
cn: managers
gidNumber: 1000
memberUid: alice
memberUid: bob
memberUid: carol
```

`access` パラメーターの構文
----------------------------------------------------------------------

`access` パラメーターの解説はオンラインマニュアル `slapd.access`(5) に
記載されています。ここで簡単に紹介しておきましょう。構文は次の通りです。

```
access to <what> [ by <who> [ <access> ] [ <control> ] ]+
```

LDAP DIT 内の `<what>` へのアクセスにおいて、
LDAP アクセス元 `<who>` に対してアクセス権 `<access>` を与える、
という形式です。

`<what>` には LDAP DIT 中の特定のエントリを差す DN のほか、
エントリ下のサブツリー、特定のオブジェクトクラスや属性を
指定することもできます。

`<who>` には LDAP バインド時で示されたアクセス元の DN (=ユーザー)を指定できます。
それ以外に、アクセス元やアクセス先の IP アドレスとポート番号、
TLS 接続時のセキュリティ強度係数などを指定することもできます。

`access` には `read`、`write` (`read` 権も含む)、`manage` (`write` 権も含む)
などのアクセスレベルのほか、`=wx` (書き込み権 (`w`) と認証権 (`x`) のみ。
読み込みなどほかの操作は不可)
のように各種の操作を個別にアクセス許可・拒否することができます。

以下の例は、任意のエントリと属性へのアクセスにおいて、
`uid=root` に `manage` 権限を、`uid=alice`, `uid=bob`, `uid=carol` に
`write` 権限を与えるアクセス権付与の設定になります。

```
access to *
	by dn="uid=root,ou=Users,dc=example,dc=jp" manage
	by dn="uid=alice,ou=Users,dc=example,dc=jp" write
	by dn="uid=bob,ou=Users,dc=example,dc=jp" write
	by dn="uid=carol,ou=Users,dc=example,dc=jp" write
```

`groupOfNames` / `groupOfUniqueNames` 形式グループへのアクセス権付与
----------------------------------------------------------------------

`access` パラメーターの `<who>` 節には、グループエントリを指定するための
構文 `group=<グループの DN>` が用意されています。これで指定のグループに所属する
ユーザー群に対してアクセス権を付与することができます。

グループに対するアクセス権付与の設定例を示します。この例は、
オブジェクトクラス `groupOfNames`、DN `cn=managers,ou=Groups,dc=example,dc=jp`
であるグループエントリが持つ `member` 属性の値が示す DN のユーザーが
アクセス権付与の対象になります。

```
## cn=managers (groupOfNames) の member にアクセス権付与
access to *
	by group="cn=managers,ou=Groups,dc=example,dc=jp" write
```

上記例はいくつかのデフォルト値が隠されていますが、明示的に記述すると、
次のようになります。

```
## cn=managers (groupOfNames) の member にアクセス権付与
## (明示的にオブジェクトクラスと属性を指定)
access to *
	by group/groupOfNames/member="cn=managers,ou=Groups,dc=example,dc=jp" write
```

グループエントリがオブジェクトクラス `groupOfUniqueNames` の場合は
メンバー情報は `uniqueMember` 属性が持つので、同等の設定は次のようになります。

```
## cn=managers (groupOfUniqueNames) の uniqueMember にアクセス権付与
access to *
	by group/groupOfUniqueNames/uniqueMember="cn=managers,ou=Groups,dc=example,dc=jp" write
```

グループエントリのオブジェクトクラスが `posixGroup` の場合はどうでしょうか?
例えば次のように設定したとします。

```
## cn=managers (posixGroup) の uidMember にアクセス権付与しているつもり
## (注意: これは期待通りの結果にはならない誤った設定例です!)
access to *
	by group/posixGroup/memberUid="cn=managers,ou=Groups,dc=example,dc=jp" write
```

しかし、この設定ではアクセス権は付与できません。何故なら、`memberUid`
属性が持つのは DN ではなく、RDN の値にすぎないからです。LDAP 的には、
RDN の値だけではユーザーエントリを識別することができません。
`group=〜` で指定するグループエントリのメンバーを差す属性は、
ユーザーエントリを一意に差す DN である必要があります。

`set=<集合>` 構文
----------------------------------------------------------------------

`slapd.access`(5) をよく読んでも `memberUid` のような DN
でない属性値を元にアクセス権を付与する方法はないように見えますが、
実は用意されています。それが `set=<集合>` 構文です。
オンラインマニュアルには「The statement set=<pattern> is undocumented yet」
としか記載されていませんが、OpenLDAP の FAQ に詳しい解説があります。

* OpenLDAP Faq-O-Matic: Sets in Access Controls
  * <http://www.openldap.org/faq/data/cache/1133.html>

「sets」とは「集合」のことです。「集合」とは高校の数学で習うあの
「集合」のことです。

* 集合 - Wikipedia
  * <https://ja.wikipedia.org/wiki/%E9%9B%86%E5%90%88>

`slapd.access`(5) の `set=<集合>` 構文は、
各種の集合とその組合せ(集合の和や積)を指定し、その結果、
該当する要素が存在した場合にアクセス権を付与します。

集合の要素はアクセス対象やアクセス元ユーザーをもとに構成
することができますが、LDAP DIT 中の任意のエントリやツリーをもとに
構成することもできます。

`posixGroup` + `memberUid` 形式グループへのアクセス権付与
----------------------------------------------------------------------

`<集合>` を指定する構文のうち、LDAP DIT 中の任意のエントリの属性値を
集合とするには `[<エントリの DN>]/<属性名>` という形式で記述します。
よって、グループエントリ `cn=managers,ou=Groups,dc=example,dc=jp` の
`memberUid` 属性値の集合は `[cn=managers,ou=Groups,dc=example,dc=jp]/memberUid`
という記述になります。

アクセス元ユーザーは `user` と記述することでその DN を一つ含む集合を表します。
さらにユーザーエントリの `uid` 属性値を得るには `user/uid` と記述します。

これら 2つの集合の積を取り、その結果として該当する要素が存在すれば、
アクセス元ユーザーはグループに所属していることになります。
積集合を表わすには集合を表す記述同士を `&` で繋げ、
`[cn=managers,ou=Groups,dc=example,dc=jp]/memberUid & user/uid` のように記述します。

結果、`access` パラメーターは次のようになります。

```
access to *
	by set="[cn=managers,ou=Groups,dc=example,dc=jp]/memberUid & user/uid" write
```

`set=<集合>` 構文の注意点
----------------------------------------------------------------------

`set=<集合>` の利用にはいくつか注意点があります。

先に紹介した FAQ には「Sets are considered experimental」、つまり `set=<集合>`
は試験的な実装であると紹介されています。将来は仕様が変更されたり、
機能そのものがなくなる可能性があります。 仕様変更は過去にいくつかあったので、
バージョンアップの際には注意が必要です。実装は OpenLDAP 2.2 から存在して歴史は長く、
メーリングリストで話題に挙がることもよくあるので、機能がなくなる心配はなさそうです。

メーリングリストや blog などで `set=<集合>` が紹介される際によく言われるのが
パフォーマンスの問題です。ほかの構文に比べて多くの処理が必要であることが
要因と考えられますが、どうやら実装の問題もあるようです。`access` とそれに
含まれる `<who>` 節は `slapd.conf`(5) の記述順に評価されるため、
できるだけ後のほうに `set=<集合>` を記述するか、可能であれば使用を避けるべきです。
どうしても使用する際はどの程度の影響があるか、パフォーマンス測定することを推奨します。

* * *

{% include wishlist-dec.html %}

