---
layout: default
title: Articles
permalink: /articles/
class: articles
---

<div class="articles-list">
  {% for post in site.posts %}
    <article class="article-item">
      <a href="{{ post.url | relative_url }}">
        <h2>{{ post.title }}</h2>
      </a>
    </article>
  {% endfor %}
</div>
