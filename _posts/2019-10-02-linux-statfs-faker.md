---
title: XFS? QEMU さん、あなたが見ているのは ext4 ですよ
tags: [linux]
layout: default
---

タイトルの元ネタ:

  * btrfs? Dropboxさん, あなたが見ているのはext4ですよ
      * <http://gentoo.hatenablog.com/entry/2018/09/03/160749>

本 blog のネタ:

  * Bug 1751934 - Fail to install guest when xfs is the host filesystem [NEEDINFO] 
      * <https://bugzilla.redhat.com/show_bug.cgi?id=1751934>

ということで、QEMU を XFS 上で使うと XFS 固有の機能 (`xfsctl()`) を利用するが、
これが RHEL / CentOS 8 のインストールで問題を引き起すようです。私もハマりました。
仮想ストレージの内容が壊れるのかな。

元ネタの blog に `statfs`(2) の返すデータを改竄する Linux カーネルモジュールが
紹介されていますが、root 権限が必要になるなど手軽に利用できないので、
手軽に使える別実装を作ってみました。

  * Preloadable library to fake Linux statfs(2) information
      * <https://github.com/fumiyas/linux-statfs-faker>

これで無事に XFS 上の QEMU で CentOS 8 をインストールできました。

```console
$ statfs-faker --type=0xEF53 packer -only=qemu ...
```

試してないですが、たぶん Dropbox も騙せます。Dropbox の件のときにも
考えていたのですが、気が向かなかったので放置してたのであった。

おしまい。
