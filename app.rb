require File.join(File.dirname(__FILE__), 'init')

require 'yard'
require 'yard-chefdoc'
require 'sinatra'
require 'json'
require 'fileutils'

require 'extensions'
require 'cookbooks_router'
require 'cookbook_store'

require 'digest/sha2'
require 'rack/etag'
require 'version_sorter'
require 'rufus-scheduler'

class Hash
  alias blank? empty?
end
class NilClass
  def blank?
    true
  end
end

class NoCacheEmptyBody
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = *@app.call(env)
    if headers.key?('Content-Length') && headers['Content-Length'].to_i == 0
      headers['Cache-Control'] = 'max-age=0'
    end
    [status, headers, body]
  end
end

class DocServer < Sinatra::Base
  include YARD::Server

  def self.adapter_options
    # TODO: Caching is broken for the actual cookbook. Fix it!
    #       Seems to be a problem with the context path and Sinatra.
    #       Doesn't work for rubydoc.info too, so...
    {
      libraries: {},
      options: { caching: false, single_library: false },
      server_options: { DocumentRoot: STATIC_PATH }
    }
  end

  def self.load_configuration
    puts ">> Loading #{CONFIG_FILE}"
    $CONFIG.each do |key, value|
      set key, value
    end

    # This global variable is required to allow access to all settings
    # from the YARD Server. See templates/default/layout/footer
    $SETTINGS = settings
  end

  def self.copy_static_files
    # Copy template files
    puts '>> Copying static system files...'
    YARD::Templates::Engine.template(:default, :fulldoc, :html).full_paths.each do |path|
      %w(css js images).each do |ext|
        srcdir = File.join(path, ext)
        dstdir = File.join(settings.public_folder, ext)
        next unless File.directory?(srcdir)
        system "mkdir -p #{dstdir} && cp #{srcdir}/* #{dstdir}/"
      end
    end

    # Copy static stuff to public directory so we can use Docker volumes
    system "mkdir -p #{settings.public_folder} && cp -R static/* #{settings.public_folder}/"
  end

  def self.load_cookbooks_adapter
    opts = adapter_options
    opts[:libraries] = CookbookStore.new(settings)
    opts[:options][:router] = CookbooksRouter
    set :cookbooks_adapter, RackAdapter.new(*opts.values)
  rescue Errno::ENOENT
    log.error 'No remote_cookbooks file to load remote cookbooks from, not serving cookbooks.'
  end

  def self.post_all(*args, &block)
    args.each { |arg| post(arg, &block) }
  end

  use Rack::ConditionalGet
  use Rack::Head
  use NoCacheEmptyBody

  enable :static
  enable :dump_errors
  enable :lock
  enable :logging
  disable :raise_errors

  set :views, TEMPLATES_PATH
  set :public_folder, STATIC_PATH
  set :repos, REPOS_PATH
  set :tmp, TMP_PATH

  configure(:production) do
    # log to file
    file = File.open('log/sinatra.log', 'a')
    STDOUT.reopen(file)
    STDERR.reopen(file)
  end unless ENV['DOCKERIZED']

  configure do
    load_configuration
    load_cookbooks_adapter
    copy_static_files

    scheduler = Rufus::Scheduler.new
    schedule = 5 * 60 + Random.new.rand(-20..20) # 5 Minutes + random 20 second splay
    scheduler.every "#{schedule}s", timeout: '2m', first: :now do
      begin
        settings.cookbooks_adapter.libraries.update_from_universe
      rescue Rufus::Scheduler::TimeoutError
        settings.cookbooks_adapter.libraries.update_state(false)
      end
    end
  end

  helpers do
    include YARD::Templates::Helpers::HtmlHelper

    def cache(output)
      return output if settings.caching != true
      return '' if output.nil? || output.empty?
      path = request.path.gsub(%r{^/|/$}, '')
      path = 'index' if path == ''
      path = File.join(settings.public_folder, path + '.html')
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') { |f| f.write(output) }
      output
    end
  end

  # Filters

  # Always reset safe mode
  before do
    YARD::Config.options[:safe_mode] = true
  end

  # Set Last-Modified on all requests
  after { last_modified Time.now }

  # Main URL handlers
  get %r{^/cookbooks(?:/~([a-z])?|/)?$} do |letter|
    @letter = letter || 'a'
    @adapter = settings.cookbooks_adapter
    @libraries = @adapter.libraries.each_of("#{@letter}*")
    cache erb(:cookbooks_index)
  end

  get %r{^/(?:(?:search|list|static)/)?cookbooks/([^/]+)} do |cookbookname|
    @cookbookname = cookbookname

    result = settings.cookbooks_adapter.call(env)
    return status(404) && erb(:cookbooks_404) if result.first == 404
    result
  end

  # Simple search interfaces

  get %r{^/find/cookbooks} do
    self.class.load_cookbooks_adapter unless defined? settings.cookbooks_adapter
    @search = params[:q] || ''
    @adapter = settings.cookbooks_adapter
    @libraries = @adapter.libraries.each_of("#{@search}*")
    erb(:cookbooks_index)
  end

  # Root URL redirection

  # TODO: Hmm, what do do here? If we only have supermarket cookbooks...
  get '/' do
    @letter = 'a'
    @adapter = settings.cookbooks_adapter
    @libraries = @adapter.libraries.each_of("#{@letter}*")
    cache erb(:home)
  end

  # TODO: Change this completely. On sloppy there might be something
  # to collect logs and evaluate them.
  error do
    @page_title = 'Unknown Error!'
    @error = 'Something quite unexpected just happened.'
    # notify_error
  end
end
