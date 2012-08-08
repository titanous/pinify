require 'base64'
require 'json'
require 'uri'

module Mixpanel
  class Tracker
    attr_reader :distinct_id, :ip, :token

    def initialize(token, distinct_id, ip)
      @token = token
      @distinct_id = distinct_id
      @ip = ip
    end

    def track(event, properties = {})
      return unless distinct_id

      params = { event: event, properties: { token: token, distinct_id: distinct_id, ip: ip }.merge(properties) }
      data = Base64.strict_encode64(JSON.generate(params))
      request = "http://api.mixpanel.com/track/?data=#{data}"

      `curl -s '#{request}' &`
    end
  end

  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      load_mixpanel(env)
      @app.call(env)
    end

    private

    def load_mixpanel(env)
      request = Rack::Request.new(env)
      cookie = request.cookies.find { |k,v| k =~ /^mp_.+|.+_mixpanel$/ }
      id = JSON.parse(URI.decode(cookie[1]))['distinct_id'] if cookie
    ensure
      env['mixpanel'] = Tracker.new(ENV['MIXPANEL_TOKEN'], id, request.ip)
    end
  end
end
