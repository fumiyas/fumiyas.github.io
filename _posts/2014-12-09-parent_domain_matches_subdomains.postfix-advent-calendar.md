---
title: parent_domain_matches_subdomains - Postfix Advent Calendar 2014
tags: [postfix]
layout: default
---

[Postfix Advent Calendar 2014]
(http://qiita.com/advent-calendar/2014/postfix) の 9日目の記事です。
書いている時点の日付は 11日目になろうとしています。遅れてごめんなさい。

今日は `parent_domain_matches_subdomains` パラメーターを紹介します。

## `parent_domain_matches_subdomains` 設定してますか?

ふつうの設定例や解説ではお目にかかることのない
`parent_domain_matches_subdomains` パラメーター、あなたは設定していますか?
ググってみると、トラブったときに存在を認識されている例が多いようです。

私の推奨設定は以下です。値は書き忘れではありません。空(から)に設定しています。

```cfg
parent_domain_matches_subdomains =
```

推奨されたからと安易に既存の `main.cf` に設定しないでください。
トラブっても知りません。何を意味するのか把握してからにしましょう。
移行や既存の環境でなく、新規に Postfix を立てるのであれば、是非、設定しましょう
(恐らく安全)。

デフォルト値は次のようになっています。
(見易いように `sed` で加工してます)

```console
$ postconf -d parent_domain_matches_subdomains |sed 's/= /=\n /;s/,/\n /g'
parent_domain_matches_subdomains =
 debug_peer_list
 fast_flush_domains
 mynetworks
 permit_mx_backup_networks
 qmqpd_authorized_clients
 relay_domains
 smtpd_access_maps
```

## `parent_domain_matches_subdomains` って何?

パラメーター名で自明のように思えますが、簡単に紹介しましょう。
まず `postconf`(5) より抜粋:

> `parent_domain_matches_subdomains` (default: see `postconf -d` output)
> 
> What Postfix features match subdomains of `domain.tld` automatically,
> instead of requiring an explicit `.domain.tld`
> pattern. This is planned backwards compatibility: eventually,
> all Postfix features are expected to require explicit
> `.domain.tld` style patterns when you really want to match
> subdomains.

意訳してみました:

> `parent_domain_matches_subdomains` (デフォルト: `postconf -d` の出力を参照)
> 
> このパラメーターに指定した Postfix の機能(パラメーター)は、
> 明示的に `.domain.tld` 形式のパターンを指定せずとも `domain.tld`
> の指定だけで自動的にサブドメインにもマッチします。
> このパラメーターは、将来、後方互換性に影響する変更を計画しています。
> ゆくゆくは、すべての Postfix の機能において、
> サブドメインにマッチさせたいときは明示的に `.domain.tld`
> 形式のパターンを指定することを必須にする予定です。

たとえば、`parent_domain_matches_subdomains` のデフォルト値には
`relay_domains` が含まれていますが、次のような設定をすると、
`example.jp` だけでなく、`任意のあらゆるサブドメイン.example.jp`
のリレーも許可されます。これはあなたの予想あるいは意図した挙動と一致するでしょうか?

```cfg
relay_domains = example.jp
```

たとえそれが望む動作だとしても、
私のように自明でない予想外の仕様・挙動が嫌いな方であれば、
次のように設定を好むと思います。

```cfg
parent_domain_matches_subdomains =
relay_domains = example.jp .example.jp
```

* * *

自明でない予想外の仕様・挙動はトラブルの元になります。
方策があるなら活用し、できるだけ避ける努力をすべきです。

というわけで、`parent_domain_matches_subdomains` パラメーターは、
空(から)に設定することを強く推奨します。
サブドメインをマッチ対象にしたいときにだけ、
明示的に `.domain.tld` 形式を指定しましょう。
将来の Postfix バージョンではデフォルト値が空になる可能性があるため、
それに備える意味でも有用です。

* * *

{% include wishlist-dec.html %}

