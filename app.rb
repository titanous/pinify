require 'bundler'
Bundler.require
require './lib/synchrony-popen'
require './lib/base62'
require 'tempfile'
require 'securerandom'

class Pinify < Sinatra::Base
  ONE_YEAR = 31556952
  ONE_DAY  = 86400

  register Sinatra::CompassSupport
  register Sinatra::AssetPack

  use Rack::CommonLogger
  use Rack::Deflater

  configure :production do
    set :s3_bucket, 'i.pinify.me'
  end

  configure :development do
    set :s3_bucket, 'z.pinify.me'
  end

  set :root, File.dirname(__FILE__)
  set :views, 'app/views'
  disable :threaded

  compass = Compass.configuration
  compass.project_path     = root
  compass.images_dir       = 'app/images'
  compass.http_images_path = '/images'
  compass.output_style     = :compressed

  assets {
    serve '/images', :from => '/app/images'
    js :libs, %w(/js/ender.js /js/app.js)
    css :styles, [ '/css/*.css' ]
    js_compression  :uglify
    css_compression :simple
  }

  helpers do
    def redis
      @redis ||= begin
        redis_uri = URI.parse(ENV['REDISTOGO_URL'] || 'redis://localhost:6379')
        Redis.new(:host => redis_uri.host, :port => redis_uri.port, :password => redis_uri.password)
      end
    end

    def s3
      @s3 ||= UberS3.new(
        :access_key         => ENV['AWS_ACCESS_KEY_ID'],
        :secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY'],
        :bucket             => settings.s3_bucket,
        :persistent         => true,
        :adapter            => :em_http_fibered
      )
    end

    def title(t)
      @title = t
    end

    def id
      params[:captures].first
    end

    def s3_url
      "http://#{settings.s3_bucket}/#{id}.png"
    end

    def imgur_hash
      @imgur_hash ||= redis.get("img:#{id}:imgur")
    end

    def imgur_url(hash = imgur_hash)
      @imgur_url ||= begin
        "http://i.imgur.com/#{hash}.png" if imgur_hash
      end
    end
  end

  get '/' do
    erb :index
  end

  post '/upload' do
    return 413 if request.body.respond_to?(:size) && request.body.size > 4_194_304
    return 400 unless env['HTTP_X_FILE_NAME']
    ext = '.' + env['HTTP_X_FILE_NAME'].split('.').last

    begin
      file = Tempfile.new(['img', ext], :encoding => 'binary')
      file.write request.body.read
      file.close
      result = EM::Synchrony.popen("filter/pinify #{file.path}")
    ensure
      file.unlink
    end

    id = SecureRandom.urlsafe_base64(5)

    if s3.store "#{id}.png", result, :content_type => 'image/png', :ttl => ONE_YEAR
      redis.setex("img:#{id}", ONE_DAY, '1')
      content_type :json
      { :id => id }.to_json
    else
      500
    end
  end

  get %r{^/([0-9a-zA-Z\-_]+)$} do
    if redis.exists("img:#{id}")
      erb :show
    elsif imgur_url
      redirect imgur_url, 301
    else
      404
    end
  end

  get %r{^/([0-9a-zA-Z\-_]+)/imgur$} do
    if imgur_hash
      redirect imgur_url
    elsif hash = URI.encode_www_form_component(params[:hash])
      redis.set("img:#{id}:imgur", hash)
      redirect imgur_url(hash)
    else
      404
    end
  end

  error 413 do
    '<h1>413 ePenis Too Large</h1>'
  end
end
