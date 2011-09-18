require 'bundler/setup'
require 'goliath'

UPLOAD_TEMPLATE = <<EOS
<title>Pinify</title>
<form method="POST" enctype="multipart/form-data" action="/upload">
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
    case env['PATH_INFO']
    when '/'
      render UPLOAD_TEMPLATE
    when '/upload'
      process_image env['params']['image']
    when %r{^/([0-9a-z]+)$}
    when %r{^/([0-9a-z]+)\.jpg$}
    else
      fourohfour
    end
  end

  def process_image(image)
    return fourohfour unless image
    result = EM::Synchrony.popen("filter/pinify #{image[:tempfile].path}")
    [200, { 'Content-Type' => 'image/jpg' }, result]
  end

  def render(content)
    [200, { 'Content-Type' => 'text/html' }, content]
  end

  def fourohfour
    [404, { 'Content-Type' => 'text/html' }, '<h1>404 Not Found</h1>']
  end
end
