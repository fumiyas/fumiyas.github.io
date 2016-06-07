---
title: Postfix 2.10 の smtpd_relay_restrictions 新設の背景 - Postfix Advent Calendar 2014
tags: [postfix]
layout: default
---

[Postfix Advent Calendar 2014](http://qiita.com/advent-calendar/2014/postfix) の 5日目の記事です。

本日は予定を変更して、Postfix 2.10 で新設された
`smtpd_relay_restrictions` パラメーターの意図を紹介したいと思います。

以下、Postfix 付属のドキュメントファイル
`SMTPD_ACCESS_README` からの抜粋と意訳です。

Dangerous use of `smtpd_recipient_restrictions`  
`smtpd_recipient_restrictions` の危険な用例

By now the reader may wonder why we need smtpd client, helo or sender
restrictions, when their evaluation is postponed until the RCPT TO or ETRN
command. Some people recommend placing **ALL** the access restrictions in the
`smtpd_recipient_restrictions` list. Unfortunately, this can result in too
permissive access. How is this possible?  
ここまでの解説を読んで、何故 `smtpd`
にはクライアント、`HELO`、送信者の制限パラメーター※も必要なのか、
また、それら制限の評価が `RCPT` または `ETRN` コマンドを受け取るまで先延しにするのか、
不思議に思うかもしれません。世の中には、**すべて**のアクセス制限を
`smtpd_recipient_restrictions` に列挙することを推奨する人もいます。
残念なことに、そうしてしまうと、意図しないアクセス許可を与えてしまう可能性があります。

※訳注: `smtpd_recipient_restrictions` 以外の `smtpd_client_restrictions`、
`smtpd_helo_restrictions`、`smtpd_sender_restrictions` のことを
指しているものと思われます。

The purpose of the `smtpd_recipient_restrictions` feature is to control how
Postfix replies to the `RCPT TO` command. If the restriction list evaluates to
`REJECT` or `DEFER`, the recipient address is rejected; no surprises here. If the
result is `PERMIT`, then the recipient address is accepted. And this is where
surprises can happen.  
`smtpd_recipient_restrictions` の本来の目的は、
Postfix が `RCPT TO` コマンドにどう応えるかを制御することです。
そこに列挙された制限のリストにより `REJECT` または `DEFER` と判断されると、
`RCPT TO` の宛先アドレスは拒否されます。この動作に何も違和感はありません。
`PERMIT` と判断されたときは宛先アドレスは受理されますが、
ここで予想外のことが起こることがあります。

The problem is that Postfix versions before 2.10 did not have
`smtpd_relay_restrictions`. They combined the mail relay and spam blocking
policies, under `smtpd_recipient_restrictions`. The result is that a permissive
spam blocking policy could unexpectedly result in a permissive mail relay
policy.  
問題は、Postfix 2.10 より以前のバージョンには `smtpd_relay_restrictions`
がないことにあります。古い Postfix では、メールのリレーと spam 遮断の
ポリシーを混合して `smtpd_recipient_restrictions` に列挙していました。
このため、寛容的な spam 遮断ポリシーが適用されてしまい、その結果、
過剰なメールリレーポリシーとなってしまう可能性があります。

Here is an example that shows when a `PERMIT` result can result in too much
access permission:  
以下に例を示します。この構成では、`PERMIT`
が過剰なアクセス許可を与えるかもしれません:

```
1 /etc/postfix/main.cf:
2     smtpd_recipient_restrictions =
3         permit_mynetworks
4         check_helo_access hash:/etc/postfix/helo_access
5         reject_unknown_helo_hostname
6         reject_unauth_destination
7
8 /etc/postfix/helo_access:
9     localhost.localdomain PERMIT
```
 
Line 5 rejects mail from hosts that don't specify a proper hostname in the `HELO`
command (with Postfix < 2.3, specify `reject_unknown_hostname`). Lines 4 and 9
make an exception to allow mail from some machine that announces itself with
`HELO localhost.localdomain`.  
5行目の記述により、
`HELO` コマンドに正式なホスト名を示さないホストからのメールは拒否されます。
4行目と 9行目により、例外として `HELO localhost.localdomain`
と告げるホストは許可されます。

The problem with this configuration is that `smtpd_recipient_restrictions`
evaluates to `PERMIT` for **EVERY** host that announces itself as
`localhost.localdomain`, making Postfix an open relay for all such hosts.  
この設定の問題点は、`smtpd_recipient_restrictions` が、
自身を `localhost.localdomain` だと告げる**あらゆるホスト**に対して
`PERMIT` の評価を与えてしまう点にあります。

With Postfix before version 2.10 you should place non-recipient restrictions
**AFTER** the `reject_unauth_destination` restriction, not before. In the above
example, the `HELO` based restrictions should be placed **AFTER**
reject_unauth_destination, or better, the `HELO` based restrictions should be
placed under smtpd_helo_restrictions where they can do no harm.  
Postfix 2.9 以前では、**`reject_unauth_destination`
制限よりも後に宛先制限以外の制限を記述すべき**です。
上記の例では、`HELO` に基く制限は **`reject_unauth_destination`
より後**に記述すべきです。もしくは、`HELO` の制限を
`smtpd_helo_restrictions` に記述するようにすれば、
このような問題を避けることができます。

```
1 /etc/postfix/main.cf:
2     smtpd_recipient_restrictions =
3         permit_mynetworks
4         reject_unauth_destination
5         check_helo_access hash:/etc/postfix/helo_access
6         reject_unknown_helo_hostname
7
8 /etc/postfix/helo_access:
9     localhost.localdomain PERMIT
```

The above mistake will not happen with Postfix 2.10 and later, when the relay
policy is specified under `smtpd_relay_restrictions`, and the spam blocking
policy under `smtpd_recipient_restrictions`. Then, a permissive spam blocking
policy will not result in a permissive mail relay policy.  
上記のような失敗は、Postfix 2.10 以降を用い、リレーポリシーを
`smtpd_relay_restrictions` に指定し、spam 遮断ポリシーを
`smtpd_recipient_restrictions` に指定することにより起こらなくなるでしょう。
結果、寛容な spam 遮断ポリシーによって、過剰なメールリレーポリシーと
なってしまうことがなくなります。

* * *

{% include wishlist-dec.html %}

