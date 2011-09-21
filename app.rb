require 'bundler/setup'
require 'sinatra'
require 'sinatra/synchrony'
require 'sinatra/reloader'
require 'uber-s3'
require 'redis'
require 'redis/connection/synchrony'
require './lib/synchrony-popen'

configure :production do
  S3_BUCKET = 'i.pinify.me'
end

configure :development do
  require 'sinatra/reloader'
  also_reload 'lib/*.rb'
  S3_BUCKET = 'z.pinify.me'
end

configure do
  use Rack::CommonLogger

  S3 = UberS3.new(
    :access_key         => ENV['AWS_ACCESS_KEY'],
    :secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'],
    :bucket             => S3_BUCKET,
    :persistent         => true,
    :adapter            => :em_http_fibered
  )

  redis_uri = URI.parse(ENV['REDISTOGO_URL'] || 'redis://localhost:6379')
  R = Redis.new(:host => redis_uri.host, :port => redis_uri.port, :password => redis_uri.password)
end

get '/' do
  erb :index
end

post '/upload' do
  image = params[:image]
  return 404 unless image
  return 415 unless image[:type] =~ %r{^image/}
  return 413 if image[:tempfile].size > 4_194_304

  result = EM::Synchrony.popen("filter/pinify #{image[:tempfile].path}")
  id = R.incr('last-id').to_s(36)

  if S3.store "#{id}.jpg", result, :content_type => 'image/jpeg'
    redirect "/#{id}"
  else
    return 500
  end
end

get %r{^/([0-9a-z]+)$} do
  @id = params[:captures].first
  return 404 unless R.get('last-id').to_i >= @id.to_i(36)
  erb :show
end

error 413 do
  '<h1>413 ePenis Too Large</h1>'
end

error 415 do
  '<h1>415 Unsupported Media Type</h1>'
end

__END__

@@ index
<title>Pinify</title>
<form method="POST" enctype="multipart/form-data" action="/upload">
  <input name="image" type="file" /><br />
  <input type="submit" />
</form>

@@ show
<img src="http://<%= S3_BUCKET %>/<%= @id %>.jpg" />
