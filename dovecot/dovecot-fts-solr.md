---
title: Dovecot FTS + Apache Solr
tags: [dovecot,solr]
layout: default
---

設定
----------------------------------------------------------------------

メモ。必要最低限のパッケージと作業のみを記述。
まだほとんど使用していないので穴があるかもしれない。

Dovecot の Solr スキーマをインストールする。
日本語対応のトークナイザーを使用するフィールド型
`text_cjk` (N-gram。デフォルトは N=2 らしい) を定義し、
メールメッセージのヘッダー `hdr`、本文 `body`、`Subject` ヘッダー `subject`
フィールドに適用する。
(フィールド型 `text_ja` (日本語形態素解析) も定義しているが今回は未使用)

``` console
# cd /var/solr/dovecot-fts/conf
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

このコマンドラインは `ed`(1) を利用しており、Solr の元の `schema.xml` から
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

`dovecot.conf` の設定例。

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
  user = nobody
  unix_listener decode2text {
    mode = 0660
    group = mail
  }
}
```

`decode2text`
サービスの実行ユーザーとソケットの所有権とモードは適宜調整する必要がある。
上記例では、デコードスクリプトを `nobody` で実行し、
全メールユーザーを仮想ドメイン用の `mail`
グループでサービスすることを想定している。

保守
----------------------------------------------------------------------

### ユーザー削除時の対応

ユーザーのメールボックスを削除するだけでなく、
Apache Solr の該当データも削除する必要があることに注意。

`doveadm-expunge`(1)
でメールを削除すれば同時にインデックスのデータも削除されるが、
このときユーザーは存在している必要があるため、新着メールが届いてしまう。
これを抑制するためにメールボックスに書き込めないようにする細工も必要。

新着メールの抑制は、メールボックスがホームディレクトリ内の maildir
の場合は次のようにするとよいだろう。

```
# chmod -w ~user
# mv ~user/Maildir{,~}
# ls -ld ~user ~user/Maildir*
dr-x------  5 user group  512 Jun 17 15:05 /home/user
drwx------  5 user group  512 Jun 17 15:05 /home/user/Maildir~
```

ユーザーの削除 (もしくは無効化)
と同時にメールボックスを削除したくない運用の場合も、この状態にするのがよい。
「間違ったユーザーを削除してしまったので、メールボックスを復活して欲しい」
なんてことになっても復活が簡単。

メールとインデックスの削除は次のとおり。
この際は maildir 用のインデックスの更新は不要なので、
`INDEX=MEMORY` も指定することで負荷を減らしている。

```
# doveadm -o 'mail_location=maildir:~/Maildir~:INDEX=MEMORY' expunge -u user ALL MAILBOX \*
# rm -rf ~user
```

