# frozen_string_literal: true
# Trust RFC1918 private networks so the TLS-terminating reverse proxy
# (Caddy/nginx, front-ending the Rails containers in Docker) has its
# X-Forwarded-Proto / X-Forwarded-For / X-Real-IP headers honored.
#
# This is required for the expected production topology only: behind a reverse
# proxy on a private network, so `force_ssl` (FORCE_SSL=true) can detect HTTPS,
# set Secure cookies, and report the correct client IP. It is a no-op when
# there is no proxy (single-container / direct exposure).
#
# Reference: https://guides.rubyonrails.org/configuring.html#config-action_dispatch-trusted_proxies
private_proxy_nets = [
  IPAddr.new('10.0.0.0/8'),
  IPAddr.new('172.16.0.0/12'),
  IPAddr.new('192.168.0.0/16')
]
private_proxy_nets.each do |net|
  Rails.application.config.action_dispatch.trusted_proxies << net
end
