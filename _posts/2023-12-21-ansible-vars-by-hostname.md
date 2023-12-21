---
title: "Ansible の一つの vars ファイルで複数ホスト別の値を定義する - Ansible Advent Calendar 2023"
tags: [sh, shell]
layout: default
---

[Ansible Advent Calendar 2023](https://qiita.com/advent-calendar/2023/ansible)
21 日目の記事です。

Ansible で複数ホストで構成されるサービスの構成管理をしたいとき、
ホストごとに異なる変数はどのように定義すればよいでしょうか?

ホストごとに異なる変数定義が面倒くさい!
----------------------------------------------------------------------

OpenLDAP サーバーホスト 3 台構成で、そのうち 2 台をマルチプロバイダー、
1 台をコンシューマーにする例で考えます。この構成では、
ホストごとに (1) ユニークなサーバー識別番号を割り当て、
(2) どのプロバイダーから LDAP データをレプリケーションするか、
を変える必要があります。この 2 つのパラメーターを Ansible の変数
`openldap_server_id` と `openldap_db_providers` で指示するものとします。

愚直に考えれば、下記のように `host_vars/<ホスト名>/*.yml`
ごとに記述するかと思います。
少し面倒くさかったり、見通しが悪いと思いませんか?

`host_vars/ldap1/openldap.yml`:

```yaml
openldap_server_id: 1
openldap_db_providers:
  - ldaps://ldap2.example.com/
```

`host_vars/ldap2/openldap.yml`:

```yaml
openldap_server_id: 2
openldap_db_providers:
  - ldaps://ldap1.example.com/
```

`host_vars/ldap3/openldap.yml`:

```yaml
openldap_server_id: 3
openldap_db_providers:
  - ldaps://ldap1.example.com/
  - ldaps://ldap2.example.com/
```

この例では `openldap_server_id` はホスト名を元に決めることもできますが、
ホスト名が使えない構成もあるかもしれません。

インベントリーファイル一つにホストごとの変数を記述することもできますが、
ロールやプレイブック向けの変数定義は `*_vars` に書きたいところ。

ホストごとに異なる変数定義を一つの変数ファイルで定義
----------------------------------------------------------------------

私の考えた解は、別途インベントリーのホスト名をキーに値を持つ辞書型変数を定義し、
それを参照する方法です。

これなら先の例と同等の変数定義が一つのファイルで済みます:

`host_vars/all/openldap.yml`:

{% raw %}
```yaml
openldap_server_id: "{{ openldap_server_id_by_hostname.get(inventory_hostname, 0) }}"
openldap_db_provider: "{{ openldap_db_provider_by_hostname.get(inventory_hostname, []) }}"

openldap_server_id_by_hostname:
  ldap1: 1
  ldap2: 2
  ldap3: 3

openldap_db_providers_by_hostname:
  ldap1:
    - ldaps://ldap2.example.com/
  ldap2:
    - ldaps://ldap1.example.com/
  ldap3:
    - ldaps://ldap1.example.com/
    - ldaps://ldap2.example.com/
```
{% endraw %}
