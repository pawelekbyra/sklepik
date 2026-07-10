# frozen_string_literal: true

require 'rack/attack'

Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

# Store API: login throttle (5 attempts per IP per hour)
Rack::Attack.throttle('store/auth/login/ip', limit: 5, period: 1.hour) do |req|
  if req.post? && req.path == '/api/v3/store/auth/login'
    req.ip
  end
end

# Store API: login throttle per email (10 attempts per email per hour)
Rack::Attack.throttle('store/auth/login/email', limit: 10, period: 1.hour) do |req|
  if req.post? && req.path == '/api/v3/store/auth/login'
    # Extract email from request body if present
    begin
      body = req.body.read
      req.body.rewind
      data = JSON.parse(body) rescue {}
      email = data['email']
      "#{email}" if email.present?
    rescue
      nil
    end
  end
end

# Store API: password reset create throttle (3 attempts per IP per hour)
Rack::Attack.throttle('store/password_reset/create/ip', limit: 3, period: 1.hour) do |req|
  if req.post? && req.path == '/api/v3/store/password_resets'
    req.ip
  end
end

# Store API: password reset create throttle per email (3 attempts per email per hour)
Rack::Attack.throttle('store/password_reset/create/email', limit: 3, period: 1.hour) do |req|
  if req.post? && req.path == '/api/v3/store/password_resets'
    begin
      body = req.body.read
      req.body.rewind
      data = JSON.parse(body) rescue {}
      email = data['email']
      "#{email}" if email.present?
    rescue
      nil
    end
  end
end

# Store API: newsletter subscribe throttle (10 attempts per IP per day)
Rack::Attack.throttle('store/newsletter/subscribe/ip', limit: 10, period: 1.day) do |req|
  if req.post? && req.path == '/api/v3/store/newsletter_subscribers'
    req.ip
  end
end

# Store API: newsletter subscribe throttle per email (2 attempts per email per day)
Rack::Attack.throttle('store/newsletter/subscribe/email', limit: 2, period: 1.day) do |req|
  if req.post? && req.path == '/api/v3/store/newsletter_subscribers'
    begin
      body = req.body.read
      req.body.rewind
      data = JSON.parse(body) rescue {}
      email = data['email']
      "#{email}" if email.present?
    rescue
      nil
    end
  end
end

# Admin API: login throttle (10 attempts per IP per hour)
Rack::Attack.throttle('admin/auth/login/ip', limit: 10, period: 1.hour) do |req|
  if req.post? && req.path == '/api/v3/admin/auth/login'
    req.ip
  end
end

# Admin API: customer create throttle (5 attempts per IP per hour - spam prevention)
Rack::Attack.throttle('store/customers/create/ip', limit: 5, period: 1.hour) do |req|
  if req.post? && req.path == '/api/v3/store/customers'
    req.ip
  end
end

# Respond to throttled requests with 429 Too Many Requests
Rack::Attack.throttled_responder = lambda do |env|
  match_data = env['rack.attack.match_data']
  now = Time.current

  headers = {
    'Content-Type' => 'application/json',
    'Retry-After' => match_data[:period].to_s
  }

  [429, headers, [{ error: 'Too many requests. Please try again later.' }.to_json]]
end
