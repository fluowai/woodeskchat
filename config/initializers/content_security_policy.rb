# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy
#
# NOTE: enforced only in production/staging (where a reverse proxy terminates TLS).
# In development the policy is left disabled so hot-reload / inline scripts work.

production_csp = lambda do |policy|
  # Base policy applies to all environments.
  policy.default_src :self, :https, :data
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data, :blob
  policy.object_src  :none
  policy.script_src  :self, :https, :data, :blob, :unsafe_inline
  policy.style_src   :self, :https, :data, :unsafe_inline
  policy.connect_src :self, :https, :wss, :data
  policy.frame_ancestors :self
  policy.base_uri :self
  policy.form_action :self
  policy.frame_src :self, :https
  policy.media_src :self, :https, :blob
  policy.manifest_src :self, :https

  # Allow blob: in test (used by some asset eval flows).
  policy.script_src(*policy.script_src, :blob) if Rails.env.test?
end

Rails.application.config.content_security_policy do |policy|
  if %w[production staging].include?(Rails.env)
    production_csp.call(policy)
  end
end

# Nonce generator so server-rendered templates can use trusted per-request nonces.
Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Set the nonce only to specific directives (script-src).
Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

# Report-only mode is opt-in via env; off by default in production.
Rails.application.config.content_security_policy_report_only =
  ActiveModel::Type::Boolean.new.cast(ENV.fetch('CSP_REPORT_ONLY', false))
