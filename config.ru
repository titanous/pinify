require './app'

# stolen from sinatra-synchrony
exception_handler = Proc.new do |env, e|
  if settings.show_exceptions?
    request = Sinatra::Request.new(env)
    printer = Sinatra::ShowExceptions.new(proc{ raise e })
    s, h, b = printer.call(env)
    [s, h, b]
  else
    [500, {}, ""]
  end
end

use Rack::FiberPool, { :rescue_exception => exception_handler }
use Rack::CommonLogger
use Rack::Rewrite do
  r301 /.*/, 'http://pinify.me$&', if: lambda { |env|
    ENV['RACK_ENV'] == 'production' && !['pinify.me', 'direct.pinify.me'].include?(env['SERVER_NAME'])
  }
end
use HeaderMiddleware
use Rack::Deflater
run Pinify
