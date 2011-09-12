require 'bundler/setup'
require 'goliath'

TEMPLATE = <<EOS
<title>Pinify</title>
<form method="POST" enctype="multipart/form-data" action="/">
  <input name="image" type="file" /><br />
  <input type="submit" />
</form>
EOS

class PopenHandler < EM::Connection
  include EM::Deferrable

  def receive_data(data)
    (@data ||= '') << data
  end

  def unbind
    succeed(@data)
  end
end

module EventMachine
  module Synchrony
    def self.popen(cmd, *args)
      df = nil
      EM.popen(cmd, PopenHandler, *args) { |conn| df = conn }
      EM::Synchrony.sync df
    end
  end
end


class Pinify < Goliath::API
  use Goliath::Rack::Params

  def response(env)
    return [404, {}, ''] if env['PATH_INFO'] == '/favicon.ico'
    return [200, { 'Content-Type' => 'text/html' }, TEMPLATE] unless image = env['params']['image']

    result = EM::Synchrony.popen("filter/pinify #{image[:tempfile].path}")

    [200, { 'Content-Type' => 'image/jpg' }, result]
  end
end
