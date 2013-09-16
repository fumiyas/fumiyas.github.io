---
layout: default
---
Blog、再開しました。

技術情報
----------------------------------------------------------------------

  * [rsync](linux/rsync.html)
  * [Linux オートマウント](linux/autofs.html)
  * Apache HTTPD
    * [mod_allowfileowner](apache/mod-allowfileowner.html)

日記
----------------------------------------------------------------------
<ul>
{% for post in site.posts %}
<li>
  <a href="{{ post.url }}">{{ post.date |date: '%Y-%m-%d' }} : {{ post.title }}</a>
</li>
{% endfor %}
</ul>
