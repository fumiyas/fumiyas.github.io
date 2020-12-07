---
title: "include_vars を group_vars, host_vars より低優先度にする - Ansible Advent Calendar 2020"
tags: [ansible]
layout: default
---

[Ansible Advent Calendar 2020](https://qiita.com/advent-calendar/2020/ansible_01)
の 8 日目の記事です。

この記事は Ansible 2.9 あたりで動作確認しています。

`include_vars` は `group_vars`, `host_vars` より高優先度
======================================================================

あるロールに「構成管理対象の環境に則した変数定義を読み込むタスク」
を作成して利用していました。そのタスクは次のような内容です。

{% raw %}
```yaml
## 環境依存の変数の読み込み
- name: "Include environment-specific variables"
  with_first_found:
    - files:
      - "vars/{{ansible_distribution}}-{{ansible_distribution_version}}.yml"
      - "vars/{{ansible_distribution}}-{{ansible_distribution_major_version}}.yml"
      - "vars/{{ansible_distribution}}.yml"
      - "vars/{{ansible_os_family}}-{{ansible_distribution_version}}.yml"
      - "vars/{{ansible_os_family}}-{{ansible_distribution_major_version}}.yml"
      - "vars/{{ansible_os_family}}.yml"
  include_vars: "{{item}}"
```
{% endraw %}

その後、「`group_vars` や `host_vars` で一部の変数を上書きしたい」
という要件が出てきました。さて、上記のタスクで読み込まれる変数定義と同名の変数を
`group_vars` (あるいは `host_vars`) でも定義するとどうなるでしょうか?
はい、[Ansible では残念(?)ながら `include_vars` の変数が優先度がとても高く](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#understanding-variable-precedence)、要件は叶いません。

`include_vars` を `group_vars`, `host_vars` より低優先度にする (ように見せる)
======================================================================

`include_vars` より高優先度な変数定義は少ないですが、`set_facts`
が使えそうです。さらに `include_vars` には読み込み先の辞書変数を指定可能なので、
一時的な辞書変数に読み込んだ後にその内容のうち未定義のものを `set_facts`
で設定すればよさそうです。

要件を満たすタスクは次のような内容になりました。

{% raw %}
```yaml
## 環境依存の変数の読み込み

## include_vars は group_vars, host_vars などより優先度が高く
## それらを上書きしてしまうため、まずは一時的な辞書変数に読み込む
- name: "Temporarily Include environment-specific variables"
  with_first_found:
    - files:
      - "vars/{{ansible_distribution}}-{{ansible_distribution_version}}.yml"
      - "vars/{{ansible_distribution}}-{{ansible_distribution_major_version}}.yml"
      - "vars/{{ansible_distribution}}.yml"
      - "vars/{{ansible_os_family}}-{{ansible_distribution_version}}.yml"
      - "vars/{{ansible_os_family}}-{{ansible_distribution_major_version}}.yml"
      - "vars/{{ansible_os_family}}.yml"
  include_vars:
    file: "{{item}}"
    name: env_specific_vars_tmp

## include_vars 以外で設定済みでない変数のみを設定
- name: "Set environment-specific variables if not already set"
  loop: "{{env_specific_vars_tmp |dict2items}}"
  when: "item.key not in hostvars[inventory_hostname]"
  set_fact:
    "{{item.key}}": "{{item.value}}"
```
{% endraw %}

いかがでしょうか?
いまのところうまく利用できていますが、もし落とし穴などがあったら教えてください!

* * *

{% include wishlist-dec.html %}
