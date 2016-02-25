---
id: 9
title: Creating robust email templates in Action Mailer
date: 2015-03-15T14:38:19+00:00
author: simon
layout: post
guid: http://simonnordberg.com/?p=9
permalink: /creating-robust-email-templates-in-action-mailer/
content_columns:
  - 1
dsq_thread_id:
  - 3761635274
categories:
  - rails
tags:
  - actionmailer
  - premailer
---
Creating and maintaining email templates that will produce consistent results across email clients is hard. Not only should the content be compelling, the email should also be pleasant to read. This can mean many different things of course, but the thing I will focus on in this post is the technical challenges involved in creating a proper HTML (and plain text) email with inline CSS and images.

My goal is to achieve this result without resorting to crazy hacks and [regex](http://stackoverflow.com/questions/1732348/regex-match-open-tags-except-xhtml-self-contained-tags) ninja tricks. I want to be able to keep a maintainable and separate structure for all included parts, HTML, CSS and images.

# TL;DR

  * Setup [premailer-rails](https://github.com/fphilipe/premailer-rails)
  * Create a mailer base class that sets a layout and includes inlines assets
  * Create a mailer layout that references the email stylesheet
  * Reference the inline assets in your custom mailer with `attachments.inline`
  * Update `smtp_settings` in development.rb to reference localhost:1025
  * Test with [MailCatcher](http://mailcatcher.me/)

# Defining the problem

The main issue is really to get these separate parts (HTML, CSS, images) together in a format that can be comprehended by as many email clients as possible. This while at the same time being able to introduce changes and being able to reuse what has been already been implemented.

The way HTML emails need to be structured in order for it to be rendered properly causes this to be somewhat of a problem.

# The problem with CSS

Most developers and designers will be familiar with _external CSS_ which uses a link to load the CSS from a server. While some email clients will allow using external CSS, it is very rare and should not be used in practice.

    <link rel="stylesheet" href="/stylesheet/style.css" />
    

The next option is to use _embedded_ CSS defined in a `<style>` block, most often inside the `<head>` section. This will enable a number of email clients to properly render the email. However, if we are seeking to target individuals using e.g. [Gmail](https://gmail.com) we are out of luck as it will strip any `<style>` and `<link>` blocks.

    <html>
        <head>
            <style type="text/css">
                a { font-weight: bold; }
            </style>
        </head>
    </html>
    

This leaves us with _inline_ CSS, where all of our CSS will be placed directly on the HTML elements by using the `style` attribute.

        <a style="font-weight: bold;">...</a>
    

So in order for an HTML email to be properly rendered in a (best effort) consistent way across our various email clients, CSS should be inline. For a complete breakdown of the CSS support offered by the most popular email clients, check out [The Ultimate Guide to CSS](https://www.campaignmonitor.com/css/) by Campaign Monitor.

This is a huge pain as even the simplest password recovery email or newsletter quickly becomes unmanageable. Luckily there are a number of ingenious options available to us developers in the Ruby ecosystem.

Enter `Premailer`.

[Premailer](https://github.com/premailer/premailer) is a Ruby framework that will inline email CSS and produce a HTML email with a structure that will be compatible with most email clients. Along with the HTML version, a plain text version of the content will also be available. (Another popular framework dealing with inlining CSS in Ruby is [Roadie](https://github.com/Mange/roadie). I have yet to try Roadie out, but will do that shortly and add my findings.)

Premailer in conjunction with the Rails adapter [premailer-rails](https://github.com/fphilipe/premailer-rails) allows a developer to write HTML email and CSS using the [Rails Asset Pipeline](http://guides.rubyonrails.org/asset_pipeline.html). By enabling the use of asset pipeline we will have all the usual tools at our disposal, such as the ability to use [Sass](http://sass-lang.com/).

## Configuring premailer

First of all, we need to include `premailer-rails` in our `Gemfile`, as well as a dependency against an HTML parser. [nokogiri](https://github.com/sparklemotion/nokogiri) and [hpricot](https://github.com/hpricot/hpricot) are both supported. Since hpricot has been discontinued, I will use nokogiri going forward. See [installation instructions](https://github.com/fphilipe/premailer-rails#installation) for additional information.

    # Gemfile
    gem 'premailer-rails'
    gem 'nokogiri' 
    

`premailer` provides a number of [configuration options](https://github.com/fphilipe/premailer-rails#configuration). These options can be forwarded to `premailer` by using a Rails initalizer.

    # config/initializers/premailer_rails.rb
    Premailer::Rails.config.merge!(preserve_styles: true, remove_ids: true)
    

We are good to go! `premailer-rails` will hook `premailer` up with Action Mailer by registering a delivery hook. This will cause all outgoing emails to pass through `premailer`.

# The problem with images

Now that we have inline CSS in place, outgoing emails will behave properly in a large set of email clients. Now imagine we want to include a logo in our email. As with using CSS, referencing images (or other assets) in a HTML email is far from standardized among email clients. To increase the likelihood that images will be rendered as precise as possible we should include them inline as well.

Luckily Action Mailer will do this for us without breaking a sweat. All we need to do is to provide the assets we want referenced prior to rendering and dispatching the email from inside mailer.

    class UserMailer < ActionMailer::Base
        def welcome(recipient)
            attachments.inline['logo.png'] = File.read('/images/logo.png')
            mail(to: recipient, subject: "Welcome!")
        end
    end
    

To reference the image in the email view, we use the `image_tag` passing in the attachment, and calling `url` on the attachment to get the relative content id path for the image. We will use [Slim](http://slim-lang.com/) as template language.

    # views/user_mailer/welcome.html.slim
    = image_tag(attachments['logo.png'].url, class: 'logo')
    

For more information, see [Action Mailer Basics](http://guides.rubyonrails.org/action_mailer_basics.html) and [ActionMailer::Base](http://api.rubyonrails.org/classes/ActionMailer/Base.html).

# The problem with reuse

All outgoing emails will now have inline CSS and images. That is all good, but now let us image we have a handful of different email templates that we need to maintain. They share header and footer (with logos, links etc.), but the body naturally differs depending on the context.

A simple way to achieve this in a maintainable fashion is to create a mailer base class that will perform the common setup such as including assets and defining a [layout](http://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-layouts).

    # mailers/base_mailer.rb
    class BaseMailer < ActionMailer::Base
        before_action :add_inline_attachments!
        layout 'mailer'
    
        def add_inline_attachments!
            attachments.inline['logo.png'] = File.read('/images/logo.png')
        end
    end 
    

Finally we can define our mailer layout that includes the CSS that `premailer` will inline to the email. We must also remember to add this email CSS stylesheet to `config.assets.precompile` so that it will be available during pre-flight.

    # views/layouts/mailer.html.slim
    doctype html
    html
      head
        = stylesheet_link_tag 'email'
    
      body
        = render 'shared/mailer_header'
        = yield
        = render 'shared/mailer_footer
    
    # config/application.rb
    config.assets.precompile += %w(email.css)
    

Now we can subclass `BaseMailer` and not have to worry about the shared stuff. Need to add a new logo? Just update the reference in the `BaseMailer` and any layout changes and it will be reflected onto all emails going forward.

By now we will have assembled an email &#8220;framework&#8221; that we can easily adapt and modify according to our requirements, and still maintain consistency.

# Testing

Now it is time to try this new email out! I prefer using [MailCatcher](http://mailcatcher.me/) as it lets me rapidly iterate over the design. In order to have Rails send the emails to `MailCatcher` in the development environment, the smtp settings need to be updated.

    # config/environments/development.rb
    config.action_mailer.smtp_settings = { :address => "localhost", :port => 1025 }
    

After launching `mailcatcher`, from within a [Rails console](http://guides.rubyonrails.org/command_line.html) (`rails console`) I can manually instantiate and send the email, and the email should hopefully appear in the mailcatcher web interface (default at http://127.0.0.1:1080).

    UserMailer.welcome('test@email.com').deliver
    

# Conclusion

This might not seem like a big deal at first. The result for me however, was that after having this in place, adding a new workflow email to my application was significantly less painful and even made me spontaneously go back to improve the email structure and layout.