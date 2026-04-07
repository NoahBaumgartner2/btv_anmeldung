class Rack::Attack
  # ── Login-Versuche: max 5 pro Minute pro IP ────────────────────────────────
  throttle("login/ip", limit: 5, period: 1.minute) do |req|
    req.ip if req.path == "/users/sign_in" && req.post?
  end

  # ── Passwort-Reset: max 3 pro Stunde pro IP ───────────────────────────────
  throttle("password_reset/ip", limit: 3, period: 1.hour) do |req|
    req.ip if req.path == "/users/password" && req.post?
  end

  # ── Webhooks: max 100 pro Minute pro IP ───────────────────────────────────
  throttle("webhooks/ip", limit: 100, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/webhooks/") && req.post?
  end

  # ── Antwort bei Throttle: 429 Too Many Requests ───────────────────────────
  self.throttled_responder = lambda do |_req|
    [
      429,
      { "Content-Type" => "text/plain; charset=utf-8" },
      ["Zu viele Anfragen. Bitte warte kurz und versuche es erneut."]
    ]
  end
end
