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
run Pinify
