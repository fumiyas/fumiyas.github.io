---
title: "Red Hat Enterprise Linux"
---
<!-- markdownlint-configure-file
{
  "single-h1": false,
  "heading-style": {
    "style": "setext_with_atx"
  },
  "no-duplicate-heading": {
    "siblings_only": true
  },
  "ul-indent": {
    "indent": 4
  },
  "code-block-style": {
    "style": "fenced"
  }
}
-->

暗号化ポリシー
======================================================================

`crypto-policies`(7) を参照。

Perfect Forward Secrecy (PFS) 対応
----------------------------------------------------------------------

2023 年現在の `DEFAULT` ポリシーは RSA と PSK が有効化されている。

* How to customize crypto policies in RHEL 8.2
    * <https://www.redhat.com/ja/blog/how-customize-crypto-policies-rhel-82>

暗号化ポリシーモジュール `PFS-KEX` (名前は任意) を作成する。
`/etc/crypto-policies/policies/modules/PFS-KEX.pmod` (新規作成):

```ini
key_exchange = -RSA -PSK
```

暗号化ポリシー設定にモジュールを追加する:

```console
# update-crypto-policies --set DEFAULT:PFS-KEX
```

TLS 1.0, 1.1 対応
----------------------------------------------------------------------

2023 年現在の DEFAULT ポリシーは TLS 1.1 以下が無効化されている。
**注意: いずれも脆弱性が知られているので、よほどの理由がないなら有効化すべきではない。**

暗号化ポリシーモジュール `TLS1.0` (名前は任意) を作成する。
`/etc/crypto-policies/policies/modules/TLS1.0.pmod` (新規作成):

```ini
protocol@TLS = +TLS1.1 +TLS1.0
```

暗号化ポリシー設定にモジュールを追加する:

```console
# update-crypto-policies  --set DEFAULT:TLS1.0
```
