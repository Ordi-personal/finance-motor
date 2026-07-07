Rails.application.configure do
  Rack::MiniProfiler.config.skip_paths = [ "/design-system", "/assets", "/cable", "/manifest", "/favicon.ico", "/hotwire-livereload", "/logo-pwa.png" ]
  Rack::MiniProfiler.config.max_traces_to_show = 50

  # Hide the floating profiler badge when Sure is embedded inside Ordi's
  # iframe (?embedded=true) — it's a dev tool for working on Sure directly,
  # not part of the product UI users should see.
  Rack::MiniProfiler.config.pre_authorize_cb = lambda do |env|
    !Rack::Request.new(env).params["embedded"].to_s.include?("true")
  end
end
