---
layout: default
---

{% for post in site.posts %}
{% unless post.hidden %}
<article class="card">
  <h2>{{ post.title }}</h2>
  {{ post.excerpt }}
  <a class="card__link" href="{{ post.url }}">Read more</a>
</article>
{% endunless %}
{% endfor %}
