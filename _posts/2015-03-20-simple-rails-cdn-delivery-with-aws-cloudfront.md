---
id: 87
title: Simple Rails CDN delivery with AWS CloudFront
date: 2015-03-20T08:17:46+00:00
author: simon
layout: post
guid: http://simonnordberg.com/?p=87
permalink: /simple-rails-cdn-delivery-with-aws-cloudfront/
dsq_thread_id:
  - 3760928453
categories:
  - rails
tags:
  - aws
  - cdn
  - cloudfront
  - s3
---
In order to have our application deliver a superb experience to the user every single time, speed is important. There are many areas to consider when it comes to speed and performance. One of these, which provide a quick and effective way to increase the perceived page load time is to use a Content Delivery Network (CDN).

By using a CDN we can make use of existing infrastructure to offload static resources from our application to a location close to the end user, called _edge locations_. This is particularly important if we are using a PaaS such as [Heroku](https://www.heroku.com/) where we want to ensure the web dynos are free to handle dynamic content.

In this post I will outline the steps required to start using the CDN available by [Amazon Web Services (AWS)](http://aws.amazon.com/) called CloudFront. Also, as I am using AWS S3 to store dynamic application assets (e.g. user contributed images, movies etc.) I will offload that to CloudFront as well.

So, our strategy going forward will be to offload all content from our Rails application and our S3 bucket to a common CloudFront distribution that will handle the end user delivery.

Let go!

## AWS CloudFront, say what?

[AWS CloudFront](http://aws.amazon.com/cloudfront/) is a content delivery framework that allows application developers and businesses to easily distribute content to end users with low latency.

CloudFront works from what is called a _distribution_. A distribution will map to a public hostname whose purpose it is to serve the content to our visitors. A distribution in turn is comprised by a number of _origins_, which is basically a source for which data the distribution is acting in place of. The origin may source its data from an external domain name (e.g. our site) or an existing S3 bucket.

An example CloudFront distribution hostname might look like `d36r53qa60invh.cloudfront.net`. By using custom CNAME records we can mask this hostname behind our own application URL, either by using a single hostname, e.g. `static.app.com`, or even multiple hostnames e.g. `static0.app.com, static1.app.com, ...` if we want to utilize web browser download parallelization. More on this in the Rails section below.

By using custom CNAME records it is also possible to us our own SSL certificate to allow encryption. Either a dedicated certificate for the particular hostname, or a wildcard certificate if that is more appropriate.

Whenever a request enters a CloudFront distribution, a list of configured _behaviors_ will be considered based on the requested path pattern. This will determine from which origin the requested object will be returned. Multiple behaviors can be defined and arranged based on precedence. E.g. a origin with the the request pattern `/images/*` can be specified to route the request to a S3 bucket containing user generated and uploaded images, whilst all other requests (`*`) should be routed to our application server at `www.app.com` to handle CSS, Javascript and other application assets.

Once a requested resource has been returned from the origin CloudFront will cache that resource. The next time a request is made for the same resource the cached copy will be returned directly to the end user.

![First request](/assets/cloudfront-first-request.png)

![Subsequent requests](/assets/cloudfront-subsequent-requests.png)

Please refer to the [CloudFront introduction](http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Introduction.html) for the official introduction to CloudFront.

## Configuring CloudFront for S3 assets

Why you ask? Why not deliver that content directly from S3? The thing is, S3 is really a storage service, not a services aimed at delivering static resources to users in real-time.

From the AWS CloudFront FAQ:

> Q. How is Amazon CloudFront different from Amazon S3?
> 
> Amazon CloudFront is a good choice for distribution of frequently accessed static content that benefits from edge delivery—like popular website images, videos, media files or software downloads. 

Configuring CloudFront to deliver cached content from S3 buckets is very straightforward. Before introducing CloudFront we might have accessed an image from this bucket by using an URL targeting your S3 bucket name (`rails-bucket`)

    http://rails-bucket.s3-eu-west-1.amazonaws.com/images/background.jpeg
    

For all intents and purposes, let us assume the we want to have all content with path pattern `/images/*` delivered from the S3 bucket. This will allow us to access these resources with an URL relative to our application domain:

    http://www.app.com/images/background.jpeg
    

Provided that we already have an S3 bucket configured, there are only a small number steps required to configure CloudFront to deliver that content for us.

  1. Go to [AWS CloudFont Management Console](https://console.aws.amazon.com/cloudfront)
  2. Create a distribution. Select _Web distribution_.
  3. **Origin Domain Name**: Select the hostname for the existing S3 bucket we want to enable CDN delivery for.
  4. The defaults are usually sufficient to start off with. However, it is well worth spending a couple of minutes to familiarize yourself with the various settings. There are options here that allow us to specify SSL certificates, alternative domain names (more on this later), logging and much more. 
  5. Press _Create Distribution_, then go grab a cup of coffee and let AWS spend 5-10 minutes to setup our distribution. It is worth highlighting that every change we make to a distribution will take a couple of minutes to publish. The state for an up to date distribution will be _Enabled_, as listed in the overview distribution list.
  6. Inspect the _Behaviours_ tab and note that there is a _Default (*)_ Path Pattern defined that will forward all requests to this newly created origin. As we add additional origins, this will become important as we will be required to add additional behaviors to handle that. More on this in the next section.

# Configuring CloudFront for Rails assets

Now that CloudFront is configured to deliver S3 content, it is time to let the static assets served by the Rails asset pipeline be delivered in the same way. What we want to achieve is to allow S3 to deliver any content with path pattern `/images/*`, and let the application server handle everything else (CSS, Javascript etc.).

This can be accomplished by a number of simple steps:

  1. Open the previously configured distribution (or create a new one).
  2. Create a new origin. Set the _Origin Domain Name_ to our public application hostname (e.g. www.app.com).
  3. (If you access your site via HTTPS, be sure to set _Origin Protocol Policy_ to _Match Viewer_. This will make CloudFront access the origin using HTTPS. The opposite is also true, if the viewer accesses the resource using HTTP, the origin will also be accessed using HTTP.)
  4. Create a new behavior with _Path Pattern_ set to `/images/*` and _Origin_ to our previously created S3 origin.
  5. Once created, make sure this newly created behavior is set with higher precedence than the default. 

Thats it. Every request to the CloudFront distribution hostname with a path pattern of `/images/*` will be handled by S3 whilst all other requests will be handled by our application server.

## Configuring Rails to support CDN delivery

The final step we need to complete before we can celebrate success is to configure Rails to serve the CDN offloaded resources to our site visitors. Luckily this is very simple as most recent versions of Rails allows us to do this with a simple change to `asset_host` in our environment configuration.

    # config/environments/production.rb
    config.action_controller.asset_host = "<distribution-id>.cloudfront.net" # e.g. d36r53qa60invh.cloudfront.net
    

Rails allows us two says to enable multiple CNAME. First off we can use a shorthand by defining `%d` in the hostname, e.g. `static%d.app.com`. With this wildcard present, Rails will distribute requests among four corresponding hosts `static0.app.com, ..., static3.app.com`.

A better solution in my opinion is to use a Proc to generate the URL, as this gives us complete control. This might come in handy if for instance we only want two CDN hosts.

    # config/environments/production.rb
    ActionController::Base.asset_host = Proc.new { |source|
      "static#{Digest::MD5.hexdigest(source).to_i(16) % 2 + 1}.app.com"
    }
    

With this change, all assets requested through the asset pipeline will be prepended with this hostname. See [AssetUrlHelper](http://api.rubyonrails.org/classes/ActionView/Helpers/AssetUrlHelper.html) for more details.

## Testing

Now that we have successfully configured a CloudFront distribution and configured our Rails application to use it, it is a good time to test it out.

There are two things we need to verify, the S3 resources and the resources served by our application. These resources should be available through the CloudFront delivery with the same path as originally provided by the application prior to the configuration changes.

E.g. a javascript file served by the application with the full URL

    http://www.site.com/assets/site-89974af0519bc53c7be4dc959e2ae96a.js
    

should now be served with the CloudFront distribution hostname

    http://d36r53qa60invh.cloudfront.net/assets/site-89974af0519bc53c7be4dc959e2ae96a.js 
    

as well as any configured CNAME for the same distribution

    http://staticN.site.com/assets/site-89974af0519bc53c7be4dc959e2ae96a.js 
    

The same goes with e.g. images served by S3 with the full URL

    http://rails-bucket.s3-eu-west-1.amazonaws.com/images/background.jpeg
    

should now be served with the CloudFront distribution hostname (and CNAME)

    http://staticN.site.com/images/background.jpeg
    

Also remember to verify your response headers to ensure proper operation. This is easily done with `curl`

    simon@mbp ~/: curl -I https://static3.site.com/images/background.jpeg
    HTTP/1.1 200 OK
    Content-Type: image/jpeg
    Content-Length: 113358
    Connection: keep-alive
    Date: Fri, 20 Mar 2015 08:22:53 GMT
    Content-Encoding: 
    Cache-Control: max-age=315576000
    Last-Modified: Thu, 19 Mar 2015 19:43:13 GMT
    ETag: "d8d948ad4432ed38b1fee64b25c71bce"
    Accept-Ranges: bytes
    Server: AmazonS3
    Age: 122
    X-Cache: Hit from cloudfront
    Via: 1.1 d36r53qa60invh.cloudfront.net (CloudFront)
    X-Amz-Cf-Id: lmfHYbVCVZDswOKO6sMgLfkFTgq817ioOaZ8YOvHubl6lYtLGGiOOg==
    

If something is wrong (e.g. you keep receiving `X-Cache: Miss from cloudfront` for a resource that should be cached, or if Cache-Control is missing) you may need to go back to the origin and verify that the headers are correct. Remember, CloudFront will only mirror your upstream headers.

## Conclusion

Enabling CDN delivery with AWS CloudFront is a really pleasant experience with some immediate gains. This is especially noticeable if using a PaaS service such as Heroku for running our application.

Some words of caution. Since CloudFront in its default configuration will honor cache headers from its origins it is important to have those properly configured. For Rails this will require making sure asset pipeline resources have their cache headers (e.g. Cache-Control) defined.

For S3 this will require uploaded resources to also have their cache headers set, either manually for each file or preferably programmatically if using for instance [Fog](https://github.com/fog/fog) to perform the upload.
