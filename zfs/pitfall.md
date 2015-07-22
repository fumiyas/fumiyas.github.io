---
title: ZFS の落し穴
tags: [zfs]
layout: default
---

メインプールのストライブセットを構成するデバイスは取り外しできない
----------------------------------------------------------------------

`zfs create` で単純にデバイスを列挙してメインプールを作成したり、
`zfs add` で単純にデバイスを追加すると、
デバイスはメインプールのストライブセットとして組込まれるが、
ストライブセット中のデバイスを取り外す方法は用意されていない。

```console
# zpool status
  pool: zpool0
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        ztank1      ONLINE       0     0     0
          sda1      ONLINE       0     0     0

errors: No known data errors
# zpool add zpool0 sdb1
# zpool status
  pool: zpool0
 state: ONLINE
  scan: none requested
config:

        NAME        STATE     READ WRITE CKSUM
        ztank1      ONLINE       0     0     0
          sda1      ONLINE       0     0     0
          sdb1      ONLINE       0     0     0

errors: No known data errors
# zpool remove zpool0 sdb1
cannot remove sdb1: only inactive hot spares, cache, top-level, or log devices can be removed
```

`zpool create` なら作ったばかりのプールを削除して作り直せばよいが、
ある程度使用したプールに対しての `zpool add` でミスると痛いので注意。

メインプールの空きがなくなるとファイルを削除できなくなる
----------------------------------------------------------------------

CoW のせいらしい。どうにかして空きを作れば削除できるようになる。

不要なファイルシステムあるいはスナップショットを削除する方法。

```console
# zfs lit -t snapshot
…
# zfs destroy <ファイルシステム名>@<スナップショット日時>
```

既存ファイルを縮める方法。

```console
# cp /dev/null /zpool0/largefile
```

  * 領域が不足した場合の動作 - Oracle Solaris ZFS 管理ガイド
    * http://docs.oracle.com/cd/E19253-01/819-6260/gayra/index.html
  * Bug #412: Cannot delete file(s) on root zfs filesystem if disk is full - illumos gate - illumos.org
    * https://www.illumos.org/issues/412

