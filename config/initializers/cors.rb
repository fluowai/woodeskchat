# config/initializers/cors.rb
# ref: https://github.com/cyu/rack-cors

# Font CORS issue with CDN
# Ref: https://stackoverflow.com/questions/56960709/rails-font-cors-policy
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  # ---------------------------------------------------------------------------
  # Public, unauthenticated resources. These are intentionally reachable from any
  # origin because the Chatwoot widget / inbox configuration is embedded on
  # third-party sites (e.g. /api/v1/widget/*, /public/api/v1/inboxes/*).
  # ---------------------------------------------------------------------------
  allow do
    origins '*'
    resource '/packs/*', headers: :any, methods: [:get, :options]
    resource '/assets/*', headers: :any, methods: [:get, :options]
    resource '/audio/*', headers: :any, methods: [:get, :options]
    resource '/public/api/*', headers: :any, methods: :any
  end

  # ---------------------------------------------------------------------------
  # Authenticated / first-party resources. Restricted to the installation origin
  # (FRONTEND_URL) in production. In development or API-only mode, fall back to
  # permissive access.
  # ---------------------------------------------------------------------------
  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('CW_API_ONLY_SERVER', false)) || Rails.env.development?
    allow do
      origins '*'
      resource '/api/*', headers: :any, methods: :any, expose: %w[access-token client uid expiry]
      resource '/auth/*', headers: :any, methods: :any, expose: %w[access-token client uid expiry]
      resource '/widget/*', headers: :any, methods: :any, expose: %w[access-token client uid expiry]
    end
  else
    allow do
      origins ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
      resource '/api/*', headers: :any, methods: :any, expose: %w[access-token client uid expiry]
      resource '/auth/*', headers: :any, methods: :any, expose: %w[access-token client uid expiry]
      resource '/widget/*', headers: :any, methods: :any, expose: %w[access-token client uid expiry]
    end
  end

  # Opt-in: allow cross-origin authenticated API access from any origin
  # (operators enable via ENABLE_API_CORS=true). Off by default in production.
  if ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_API_CORS', false))
    allow do
      origins '*'
      resource '/api/*', headers: :any, methods: :any, expose: %w[access-token client uid expiry]
    end
  end
end

################################################
######### Action Cable Related Config ##########
################################################

# Mount Action Cable outside main process or domain
# Rails.application.config.action_cable.mount_path = nil
# Rails.application.config.action_cable.url = 'wss://example.com/cable'
# Rails.application.config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

# To Enable connecting to the API channel public APIs
# ref : https://medium.com/@emikaijuin/connecting-to-action-cable-without-rails-d39a8aaa52d5
Rails.application.config.action_cable.disable_request_forgery_protection = true
