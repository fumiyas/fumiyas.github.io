---
title: "Vagrant ネットワーク"
layout: default
tags: [linux, vagrant, virtualbox]
---

デフォルト NIC が接続するネットワークアドレスの変更
----------------------------------------------------------------------

VirtualBox の場合。

デフォルトのネットワークは VirtualBox の NAT (NAT Network ではない)
を利用するのが一般的?
VirtualBox の NAT はデフォルトで 10.0.2.0/24 となっているので、
これを変更する場合、`Vagrantfile` で `vboxmanage` コマンドを間接的に呼ぶ:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :virtualbox do |vb|
      vb.customize ["modifyvm", :id, "--natnet1", "192.168.0.0/16"]
  end
end
```

ホスト OS とのブリッジネットワーク接続 NIC の追加
----------------------------------------------------------------------

固定 IP アドレス:

```ruby
Vagrant.configure("2") do |config|
  config.vm.network :public_network, ip: "10.0.103.6", netmask: "255.255.0.0", bridge: "br0"
end
```

