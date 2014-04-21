---
title: "Vagrant ネットワーク"
layout: default
tags: [linux, vagrant, virtualbox]
---

VirtualBox: デフォルト NIC が接続する NAT ネットワークの調整
----------------------------------------------------------------------

FIXME: デフォルトの NIC は VirtualBox の NAT (NAT Network ではない)
を利用するのが一般的? NAT Network や Bridged ネットワークも可能?

VirtualBox の NAT ネットワークとそこで稼動している DHCP サーバーは、
デフォルトで次のようなパラメーターになっている:

  * ネットワークアドレス
    * 10.0.2.0/24
  * デフォルトルート
    * 10.0.2.2
    * ネットワークアドレスの最後が「2」になったものが用いられるらしい。
  * DNS キャッシュサーバー
    * 10.0.2.2
    * DNS プロクシーとして動作し、ホスト OS が参照している DNS
      キャッシュサーバーを利用して名前解決される。
    * この DNS プロクシーには欠陥があり、ゲスト OS 上が glibc のとき、
      `/etc/resolv.conf` で `options single-request`
      設定をしないとホスト名の名前解決が失敗する。
      (VirtualBox 4.3.10 で不具合を確認)

これらは VirtualBox の `vboxmanage` コマンドで調整可能だが、
`Vagrantfile` から `vboxmanage` コマンドを間接的に呼ぶこともできる。

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--natnet1", "192.168.255.0/24"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "off"]
  end
end
```

この例ではネットワークと DHCP サーバーは次のように調整される。

  * ネットワークアドレス
    * 192.168.255.0/24
  * デフォルトルート
    * 192.168.255.2
  * DNS キャッシュサーバー
    * ホスト OS に設定されている DNS キャッシュサーバーの IP アドレス

ホスト OS とのブリッジネットワーク接続 NIC の追加
----------------------------------------------------------------------

固定 IP アドレス:

```ruby
Vagrant.configure("2") do |config|
  config.vm.network :public_network, ip: "10.0.103.6", netmask: "255.255.0.0", bridge: "br0"
end
```

