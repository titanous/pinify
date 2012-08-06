require 'bundler'
Bundler.require
require './lib/synchrony-popen'
require 'tempfile'
require 'securerandom'

class Pinify < Sinatra::Base
  ONE_DAY  = 86400

  register Sinatra::CompassSupport
  register Sinatra::AssetPack

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
        redis_uri = URI.parse(ENV['REDISTOGO_URL'] || ENV['REDIS_URL'] || 'redis://localhost:6379')
        Redis.new(host: redis_uri.host, port: redis_uri.port, password: redis_uri.password)
      end
    end

    def s3
      @s3 ||= UberS3.new(
        access_key: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        bucket: settings.s3_bucket,
        persistent: true,
        adapter: :em_http_fibered
      )
    end

    def title(t)
      @title = t
    end

    def id
      @id || params[:captures].first
    end

    def s3_store(id, base, comped)
      s3.store "#{id}.png", base, content_type: 'image/png', ttl: ONE_DAY
      s3.store "#{id}c.jpg", comped, content_type: 'image/jpeg', ttl: ONE_DAY
    end

    def s3_url(comped = false)
      "http://#{settings.s3_bucket}/#{id}#{comped ? 'c.jpg' : '.png'}"
    end

    def imgur_hash
      @imgur_hash ||= redis.get("img:#{id}:imgur")
    end

    def imgur_url(hash = imgur_hash)
      @imgur_url ||= begin
        "http://i.imgur.com/#{hash}.png" if imgur_hash
      end
    end

    # From http://guides.rubyonrails.org/security.html#file-uploads
    def sanitize_filename(filename)
      filename.strip.sub(/\A.*(\\|\/)/, '').gsub(/[^\w\.\-]/, '_')
    end
  end

  get '/favicon.ico' do
    send_file 'app/images/favicon.ico'
  end

  get '/type/:file' do
    send_file 'app/type/' + sanitize_filename(params[:file])
  end

  get '/' do
    erb :index
  end

  post '/upload' do
    return 413 if request.body.respond_to?(:size) && request.body.size > 4_194_304
    return 400 unless env['HTTP_X_FILE_NAME']
    ext = '.' + env['HTTP_X_FILE_NAME'].split('.').last

    begin
      file = Tempfile.new(['img', ext], encoding: 'binary')
      file.write request.body.read
      file.close
      base, comped = EM::Synchrony.popen("filter/pinify #{file.path}").split("\n----------\n")
    ensure
      file.unlink
    end

    @id = SecureRandom.urlsafe_base64(3)

    if s3_store(id, base, comped)
      redis.setex("img:#{id}", ONE_DAY, '1')
      content_type :json
      { id: id, content: erb(:show, layout: false) }.to_json
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
end
