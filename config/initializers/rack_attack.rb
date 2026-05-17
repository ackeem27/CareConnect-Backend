class Rack::Attack
  # Rate limit login attempts: 5 requests per IP every 5 minutes
  throttle('logins/ip', limit: 5, period: 5.minutes) do |req|
    if req.path == '/api/v1/auth/login' && req.post?
      req.ip
    end
  end

  # Rate limit password resets: 3 requests per IP every 15 minutes
  throttle('password_resets/ip', limit: 3, period: 15.minutes) do |req|
    if req.path == '/api/v1/auth/forgot_password' && req.post?
      req.ip
    end
  end

  # Throttle all requests by IP (60 rpm)
  throttle('req/ip', limit: 300, period: 5.minutes) do |req|
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
