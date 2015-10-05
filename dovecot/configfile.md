---
title: Dovecot 設定ファイルの仕様
tags: [dovecot]
layout: default
---

`dovecot-ldap.conf.ext`
----------------------------------------------------------------------

`pass_attrs = [<LDAP属性名>]=<passdb属性名>[=<属性マッピング文字列>]`
のうち、`<属性マッピング文字列>`の制限を調査した。
`user_attrs` も同様と思われるが未調査。

ソースコードを斜め読みした程度で動作検証はしていない。

  * バイト数制限は 128バイト以内。
  * 文字種制限は以下の通り。
    * 改行、コンマ `,` を含めることはできない。
    * パーセント記号 `%` は `%%` とすることで含めることが可能。
      `%` と解釈される。
    * `pass_attrs = "〜"` のように `pass_attrs` パラメーターの値全体を
      ダブルクォート `"` で括った場合はナンバーサイン `#`、
      シングルクォート `'`、ダブルクォート `"`
      (前にバックスラッシュ `\` を付けエスケープが必要)を含めることができる。
    * `pass_attrs = '〜'` のように `pass_attrs` パラメーターの値全体を
      シングルクォート `'`で括った場合はナンバーサイン `#`、
      ダブルクォート `"`、シングルクォート `'` (前にバックスラッシュ
      `\` を付けエスケープが必要)を含めることができる。
    * シングル/ダブルクォートで括らない場合は、それらを含めることはできない。
    * 実装上は制御コードやマルチバイト文字なども含めることも
      できるが、認証処理の仕様(制限)の影響も受けるため、
      使用しないことを推奨。

該当ソースコード:

  * `src/auth/db-ldap.c`:`db_ldap_init()`
  * `src/lib-settings/settings.c`:`settings_read()`
  * `src/auth/db-ldap.c`:`db_ldap_set_attrs()`
