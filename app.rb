require 'bundler/setup'
require 'sinatra'
require 'sinatra/synchrony'
require 'sinatra/reloader'
require 'uber-s3'
require 'redis'
require 'redis/connection/synchrony'
require './lib/synchrony-popen'
require './lib/base62'

configure :production do
  set :s3_bucket, 'i.pinify.me'
end

configure :development do
  require 'sinatra/reloader'
  also_reload 'lib/*.rb'
  set :s3_bucket, 'z.pinify.me'
end

configure do
  use Rack::CommonLogger
end

helpers do
  def redis
    @redis ||= begin
      redis_uri = URI.parse(ENV['REDISTOGO_URL'] || 'redis://localhost:6379')
      Redis.new(:host => redis_uri.host, :port => redis_uri.port, :password => redis_uri.password)
    end
  end

  def s3
    @s3 ||= UberS3.new(
      :access_key         => ENV['AWS_ACCESS_KEY'],
      :secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'],
      :bucket             => settings.s3_bucket,
      :persistent         => true,
      :adapter            => :em_http_fibered
    )
  end

  def title(t)
    @title = t
  end
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
  id = Base62.encode redis.incr('last-id')

  if s3.store "#{id}.jpg", result, :content_type => 'image/jpeg'
    redirect "/#{id}"
  else
    return 500
  end
end

get '/channel.html' do
  etag 'facebook'
  cache_control :public, :max_age => 86400
  erb :facebook_channel, :layout => false
end

get %r{^/([0-9a-zA-Z]+)$} do
  @id = params[:captures].first
  return 404 unless redis.get('last-id').to_i >= Base62.decode(@id).to_i
  erb :show
end

error 413 do
  '<h1>413 ePenis Too Large</h1>'
end

error 415 do
  '<h1>415 Unsupported Media Type</h1>'
end
