---
id: 129
title: Testing Stripe Webhooks against your development environment using a reverse SSH tunnel
date: 2015-04-12T20:14:23+00:00
author: simon
layout: post
guid: http://simonnordberg.com/?p=129
permalink: /testing-stripe-webhooks-against-your-development-environment-using-a-reverse-ssh-tunnel/
dsq_thread_id:
  - 3760895370
categories:
  - tools
tags:
  - ssh
  - stripe
---
Integrating [Stripe](https://stripe.com) payments is generally a pleasant experience. Depending on your programming language of choice, you are sure to find [API Libraries](https://stripe.com/docs/libraries) that will work for you.

Testing the Stripe workflow can be done by using a mock framework for your programming language. For instance [stripe-ruby-mock](https://github.com/rebelidealist/stripe-ruby-mock) offers mocking capabilities for the official Ruby Stripe binding [stripe-ruby](https://github.com/stripe/stripe-ruby). If you need bindings for other languages, make sure to check out the [API Libraries](https://stripe.com/docs/libraries) section in the Stripe documentation.

If however you need to run end-to-end tests of Stripe [Webhooks](https://stripe.com/docs/webhooks) against your development environment you will surely run into problems as that requires your development server to be publicly accessible on the internet, which is usually not the case.

As described in the [Testing](https://stripe.com/docs/testing#how-do-i-test-stripe-webhooks) section of the Stripe documentation, one option is to simply capture the rebhook request for inspection by using a service such as [RequestBin](http://requestb.in/). This will however not enable you to run tests end-to-end.

## Reverse SSH tunneling (remote port forwarding)

The concept of an SSH tunnel is a powerful one. It allows us to channel traffic through an intermediate host accessible via the SSH protocol. SSH tunneling (also referred to as _port forwarding_) can be achieved in two directions. Either by forwarding a local port to a remote host/port, called `local port forwarding`, or by forwarding a remote host/port to a local port, called `remote port forwarding`.

The latter, `remote port forwarding` is what allows us to open up a port on a publicly available machine, e.g. an [Amazon EC2](http://aws.amazon.com/ec2/) instance and forward incoming traffic back to our development machine sitting behind a firewall.

One inherent awesomeness with this approach is that all traffic going through the tunnel is encrypted.

## Establishing a reverse SSH tunnel

Establishing a reverse tunnel is possible by passing the `-R` flag to SSH when connecting to the remote host. Imagine we have a local application responsible for responding to the Stripe webhooks setup on port `3000`. We can make this application available on the internet on port `5000` by issuing the the following command, assuming our SSH enabled and publicly available server can be reached at `server.example.com`.

    $ ssh -R :3000:localhost:5000 user@server.example.com
    

This will log you (`user`) on to the server at `server.example.com` and open up port `5000` (assuming there is no firewall in the way) and forward all incoming requests on that port to our local machine on port `3000`. Pay attention to the initial `:` before the local port. This is the `bind_address`.

## Configuring the SSH daemon (GatewayPorts)

By default, the listening socket on the server will be bound to the loopback interface only. This may be overridden by specifying a `bind_address`. By specifying an empty `bind_address` the remote socket will be bound to all interfaces. It is also possible to specify an IP address here, in which case the socket will only be bound to that interface.

This will however only succeed if the SSH daemon is configured to allow non loopback interfaces to be bound. This is accomplished by editing the `/etc/ssh/sshd_config` file and enabling `GatewayPorts`. Since this option may become a security issue I strongly suggest that you limit this option to a limited set of users on the machine.

    Match User user
        GatewayPorts yes
    

This enables `GatewayPorts` to the local user named `user`.

Now reload SSH

    sudo reload ssh
    

## Testing

Phew, all done! Now you can test the connection by issuing a HTTP request to the external host/port e.g. by using curl

    curl http://server.example.com:5000
    

The request will first be handled by the publicly available server at port `5000` and then forwarded &#8220;backwards&#8221; through the previously established tunnel to your local machine at port `3000`.

If the request does not appear to reach all the way though, pay attention to any error messages in the console. Enabling one or two levels of debug/verbose information will surely be a good help to find anything that is not working properly. This can be done by passing `-v`, `-vv` or `-vvv` to the `ssh` command.

## Caveats and configuration hints

In the [Webhook Settings](https://dashboard.stripe.com/account/webhooks) it is possible to set multiple webhooks for a particular environment (Live/Test). It is also possible to filter selected types of events that will be passed on to a particular endpoint. This is useful if you simply want to tap into an existing stream of events, or if there is a subset of events you want to debug locally.

A word of caution regarding testing from multiple application environments against a single Stripe account. All of your application environment (dev, stage, test, &#8230;) endpoints will receive all events as there is no additional levels of separation, other than Live and Test. It is usually not a big deal but worth pointing out as you will sooner or later start noticing webhook events that do not match your current environment, especially if you are simultaneously testing in multiple environments.

## Final thoughts

SSH is just amazing. Simple as that. If you have not done so already I can really suggest you check out the manual page with `man ssh`, which contains some really useful commands.

To get an idea of what else SSH is capable of, I can recommend a talk called [The Black Magic Of SSH / SSH Can Do That?](https://vimeo.com/54505525) by [Bo Jeanes](https://twitter.com/bjeanes) which highlights some of the cool things you can do with SSH, other than an actual shell.