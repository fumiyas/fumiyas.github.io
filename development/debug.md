---
title: "デバッグ"
tags: [development,c,gdb]
layout: default
---

C: 特定の関数あるいはファイルのコンパイル最適化を無効化
======================================================================

C コンパイラーの最適化によりデバッグが難しくなるときがある。
調査すべき箇所が限定されているときは、そこだけ最適化せずにコンパイルするとよい。

```c
void __attribute__((optimize("O0"))) foo(unsigned char data) {
  // ここのコードは最適化されない
}

#pragma GCC push_options
#pragma GCC optimize ("O0")

// ここのコードは最適化されない

#pragma GCC pop_options
```

参考:

* How to prevent gcc optimizing some statements in C? - Stack Overflow
    * https://stackoverflow.com/questions/2219829/how-to-prevent-gcc-optimizing-some-statements-in-c
