require 'bundler/setup'
require 'goliath'
require 'uber-s3'
require 'redis'
require 'redis/connection/synchrony'

S3_BUCKET = ENV['S3_BUCKET'] || 'z.pinify.me'

S3 = UberS3.new(
  :access_key         => ENV['AWS_ACCESS_KEY'],
  :secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'],
  :bucket             => S3_BUCKET,
  :persistent         => true,
  :adapter            => :em_http_fibered
)

REDIS_URI = URI.parse(ENV['REDISTOGO_URL'] || 'redis://localhost:6379')
R = Redis.new(:host => REDIS_URI.host, :port => REDIS_URI.port, :password => REDIS_URI.password)

UPLOAD_TEMPLATE = <<EOS
<title>Pinify</title>
<form method="POST" enctype="multipart/form-data" action="/upload">
  <input name="image" type="file" /><br />
  <input type="submit" />
</form>
EOS

SHOW_TEMPLATE = <<EOS
<img src="http://#{S3_BUCKET}/%{id}.jpg" />
EOS

HTML_CONTENT = { 'Content-Type' => 'text/html' }

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
      process env['params']['image']
    when %r{^/([0-9a-z]+)$}
      show $1
    else
      fourohfour
    end
  end

  def process(image)
    return fourohfour unless image
    return stupid_user unless image[:type] =~ %r{^image/}
    return so_big if image[:tempfile].size > 4_194_304

    result = EM::Synchrony.popen("filter/pinify #{image[:tempfile].path}")
    id = R.incr('last-id').to_s(36)
    S3.store "#{id}.jpg", result, :content_type => 'image/jpeg'
    [302, { 'Location' => "/#{id}" }, '']
  end

  def show(id)
    return fourohfour unless R.get('last-id').to_i >= id.to_i(36)
    render SHOW_TEMPLATE % { :id => id }
  end

  def render(content)
    [200, HTML_CONTENT, content]
  end

  def fourohfour
    [404, HTML_CONTENT, '<h1>404 Not Found</h1>']
  end

  def so_big
    [413, HTML_CONTENT, "<h1>413 ePenis Too Large</h1>"]
  end

  def stupid_user
    [415, HTML_CONTENT, "<h1>415 Unsupported Media Type</h1>"]
  end
end
