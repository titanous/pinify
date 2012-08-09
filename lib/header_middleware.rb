class HeaderMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers['X-UA-Compatible'] ||= 'IE=edge,chrome=1'
    headers['Content-Type'] += '; charset=utf-8' unless headers['Content-Type'] =~ /charset/ || headers['Content-Type'].nil?
    [status, headers, body]
  end
end
