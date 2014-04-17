---
title: Dovecot FTS + Apache Solr
tags: [dovecot,solr]
layout: default
---

メモ。必要最低限のパッケージと作業のみを記述。
まだほとんど使用していないので穴があるかもしれない。

FIXME: 自前で Solr コアディレクトリツリーを作成する方法。とりあえず
Solr アーカイブ中の `example/solr/collection1` から作成した
`dovecot-fts` コアを利用するものとする。

Dovecot の Solr スキーマをインストールする。
日本語対応のトークナイザーを使用するフィールド型
`text_cjk` (N-gram。デフォルトは N=2 らしい) を定義し、
メールメッセージのヘッダー `hdr`、本文 `body`、`Subject` ヘッダー `subject`
フィールドに適用する。
(フィールド型 `text_ja` (日本語形態素解析) も定義しているが今回は未使用)

``` console
# cd /var/solr/collection1/conf
# mv schema.xml schema.xml.dist
# wget -q -O schema.xml http://hg.dovecot.org/dovecot-2.2/file/tip/doc/solr-schema.xml
# cp -p schema.xml schema.xml.dovecot.dist
# (
  echo '/<\/types>'	## 「/</types>」を検索
  echo '-'		## 1行前に移動
  echo 'a'		## テキストの追加を開始
  sed -n \
    -e '/<!-- CJK bigram /,/<\/fieldType>/p' \
    -e '/<!-- Japanese /,/<\/fieldType>/p' \
    schema.xml.dist \
  ;
  echo '.'		## テキストの追加を終了
  echo '%s/\(<field name="hdr" type="text\)/\1_cjk/'
  echo '%s/\(<field name="body" type="text\)/\1_cjk/'
  echo '%s/\(<field name="subject" type="text\)/\1_cjk/'
  echo 'w'		## 書き込み
) |ed schema.xml
…
# diff -u schema.xml.dovecot.dist schema.xml
…
```

このコマンドラインは `ed`(1) を利用しており、元の `schema.xml` から
`<fieldType name="text_cjk" 〜>〜</fieldType>` と
`<fieldType name="text_ja" 〜>〜</fieldType>` を抽出して差し込み、
`<field name="hdr" 〜>`、`<field name="body" 〜>`、`<field name="subject" 〜>`
に `type="text_cij"` を適用している。

Dovecot の元の `schema.xml` からの変更前後の差分は以下の通り。

``` diff
--- schema.xml.dovecot.dist	2013-12-05 09:14:53.000000000 +0000
+++ schema.xml	2013-12-05 10:31:34.329703482 +0000
@@ -34,6 +34,69 @@
         <filter class="solr.EnglishMinimalStemFilterFactory"/>
       </analyzer>
     </fieldType>
+    <!-- CJK bigram (see text_ja for a Japanese configuration using morphological analysis) -->
  …省略…
+    </fieldType>
+    <!-- Japanese using morphological analysis (see text_cjk for a configuration using bigramming)
  …省略…
+    -->
+    <fieldType name="text_ja" class="solr.TextField" positionIncrementGap="100" autoGeneratePhraseQueries="false">
  …省略…
+    </fieldType>
  </types>
 
 
@@ -43,14 +95,14 @@
    <field name="box" type="string" indexed="true" stored="true" required="true" />
    <field name="user" type="string" indexed="true" stored="true" required="true" />
 
-   <field name="hdr" type="text" indexed="true" stored="false" />
-   <field name="body" type="text" indexed="true" stored="false" />
+   <field name="hdr" type="text_cjk" indexed="true" stored="false" />
+   <field name="body" type="text_cjk" indexed="true" stored="false" />
 
    <field name="from" type="text" indexed="true" stored="false" />
    <field name="to" type="text" indexed="true" stored="false" />
    <field name="cc" type="text" indexed="true" stored="false" />
    <field name="bcc" type="text" indexed="true" stored="false" />
-   <field name="subject" type="text" indexed="true" stored="false" />
+   <field name="subject" type="text_cjk" indexed="true" stored="false" />

    <!-- Used by Solr internally: -->
    <field name="_version_" type="long" indexed="true" stored="true"/>
```

```
FIXME: <filed>
  sortMissingLast=false			?
  sortMissingFirst=false		?
  omitNorms=false			?
  omitTermFreqAndPositions=false	?
  omitPositions=false			true?
```

`dovecot.conf` の設定。

```
mail_plugins = $mail_plugins fts fts_solr

plugin {
  fts = solr
  fts_solr = url=http://dovecot:password@localhost:8080/solr/dovecot-fts/
  fts_decoder = decode2text
  ## Dovecot 2.2.9+
  #fts_autoindex = yes
}

service decode2text {
  executable = script /usr/libexec/dovecot/decode2text.sh
  user = dovecot
  group = mail
  unix_listener decode2text {
    mode = 0660
  }
}
```
