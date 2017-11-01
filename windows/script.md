---
title: Windows スクリプティング
tags: [windows,bat,powershell]
layout: default
---

# イベントログをすべて消す

```
for /f %%n in ('wevtutil enum-logs') do wevtutil clear-log "%%n"
```

# バッチファイルから PowerShell スクリプトを起動

```
powershell -executionpolicy bypass -File foobar.ps1 arg1 arg2
```

# アプリケーションをアンインストール (PowerShell)

```powershell
$app = Get-WmiObject -Class Win32_Product | Where-Object { 
  $_.Name -match "Software Name" 
}
$app.Uninstall()
```

