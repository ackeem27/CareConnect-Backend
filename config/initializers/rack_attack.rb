class Rack::Attack
  # Safelist localhost in development to avoid rate-limit lockouts
  safelist('allow-localhost') do |req|
    req.ip == '127.0.0.1' || req.ip == '::1'
  end

  # Rate limit login attempts: 50 requests per IP every 5 minutes
  throttle('logins/ip', limit: 50, period: 5.minutes) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      req.ip
    end
  end

  # Rate limit password resets: 10 requests per IP every 15 minutes
  throttle('password_resets/ip', limit: 10, period: 15.minutes) do |req|
    if req.path == '/api/v1/auth/forgot_password' && req.post?
      req.ip
    end
  end

  # Throttle all requests by IP
  throttle('req/ip', limit: 600, period: 5.minutes) do |req|
    req.ip
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    match_data = env['rack.attack.match_data']
    now = match_data[:epoch_time]

    headers = {
      'RateLimit-Limit' => match_data[:limit].to_s,
      'RateLimit-Remaining' => '0',
      'RateLimit-Reset' => (now + (match_data[:period] - now % match_data[:period])).to_s,
      'Content-Type' => 'application/json'
    }

    [429, headers, [{ error: "Too many requests. Please try again later." }.to_json]]
  end
end
