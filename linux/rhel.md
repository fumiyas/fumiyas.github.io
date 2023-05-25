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
# update-crypto-policies --set DEFAULT:TLS1.0
```

logrotate
======================================================================

logrotate の実行時間
----------------------------------------------------------------------

<https://access.redhat.com/documentation/ja-jp/red_hat_enterprise_linux/6/html/deployment_guide/ch-automating_system_tasks/etc/anacrontab:>

```sh
# the maximal random delay added to the base delay of the jobs
RANDOM_DELAY=45
# the jobs will be started during the following hours only
START_HOURS_RANGE=3-22
```

```crontab
#period in days   delay in minutes   job-identifier   command
1       5       cron.daily              nice run-parts /etc/cron.daily
7       25      cron.weekly             nice run-parts /etc/cron.weekly
@monthly 45     cron.monthly            nice run-parts /etc/cron.monthly
```

* システムが連続稼動しているなら `/etc/cron.daily/logrotate` などは毎日 3:11 〜 3:50 の間に実行される。
    * `START_HOURS_RANGE=3-22` なので、この時間帯の中で `period in days` 期間経過したジョブが実行対象になる。
      よって 3:00 が基点になる。
    * 基点の 3:00 から `delay in minutes + (6 〜 RANDOM_DELAY)` の遅延が差し込まれる。
      よって、`cron.daily` は 3:11 〜 3:50 の時間帯に実行される。
* ある日にシステムを 0:00 から停止していた場合、もし 5:30 にシステムを起動
  (`anacron`(8) を毎時起動する `crond` を起動) すると 6:00 が基点となるので
  6:11 〜 6:50 の時間帯に実行される。
