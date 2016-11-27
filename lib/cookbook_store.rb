# require 'sequel'
require 'base64'
require 'version_sorter'
require 'redis'
require 'time'
require 'openssl'
require 'ridley'
require 'sinatra'
require_relative 'extensions'
require_relative 'cache'

# Communicates with the backend storage to save/cache the list of
# cookbooks and versions
class CookbookStore
  include Enumerable

  attr_accessor :endpoints
  attr_accessor :endpoint_interval
  attr_accessor :redis

  def initialize(settings)
    @endpoints = init_ridley(settings.endpoints)
    @endpoint_interval = settings.endpoint_interval.to_i
    @redis = if settings.database.is_a? Hash
               Redis.new(settings.database)
             else
               settings.database
             end
  end

  def update_from_universe
    return unless update_required?

    start_time = Time.now

    update_state(true)
    update_time(start_time)
    # TODO: Iterating over endpoints currently is not thoroughly tested!
    @endpoints.each do |ep|
      ridley = ep['ridley']
      # TODO: Remove versions and cookbooks from redis that
      #       were removed from supermarket
      #       How to remove when dealing with multiple endpoints?
      updated_cookbooks = []
      ridley.universe.each do |cookbook, versions|
        versions.each do |version, data|
          data['endpoint'] = ep['name']
          updated = @redis.hset("cookbook:#{cookbook}", version, data.to_json)
          updated_cookbooks.push(cookbook) if updated && !updated_cookbooks.include?(cookbook)
        end
      end

      # TODO: This cache flushing is pretty intense on first startups where the database is
      #       empty and everything gets deleted multiple times.
      updated_cookbooks.each { |c| flush_cache(c) }
    end

    update_state(false)
    last_fetch(Time.now)
  end

  def flush_cache(name)
    Cache.invalidate('/cookbooks', "/cookbooks/~#{name[0, 1]}", "/cookbooks/#{name}")
  end

  def update_required?
    # If last_fetch is newer than endpoint_interval no update is required
    required_by_time = (last_fetch + @endpoint_interval) < Time.now
    return false if required_by_time == false # We are up2date, nothing to do

    # Check if any other process is currently fetching
    state = update_state

    return true if state == false # No other process is updating so go for it

    # From here on we are not up2date and some other process is updating
    # If this process started more than 2,5 min ago then the process either died
    # or rufus killed it because of a timeout. In this case update, otherwise don't.
    (update_time + 150) < Time.now
  end

  def update_state(state = nil)
    return (@redis.get('fetch_update_state') == 'true') if state.nil?
    @redis.set('fetch_update_state', state.to_s)
  end

  def update_time(time = nil)
    if time.nil?
      t = @redis.get('fetch_update_time')
      Time.parse(t)
    else
      @redis.set('fetch_update_time', time.to_s)
    end
  end

  def last_fetch(time = nil)
    if time.nil?
      Time.parse(@redis.get('fetch_successful_time') || '1980-01-01')
    else
      @redis.set('fetch_successful_time', time.to_s)
    end
  end

  # Required by yard server for accessing cookbooks
  def [](name)
    config = @redis.hgetall("cookbook:#{name}")
    to_versions(name, config)
  end

  def cookbook?(name)
    @redis.exists("cookbook:#{name}")
  end

  def version?(name, version)
    !@redis.hkeys("cookbook:#{name}").index(version).nil?
  end

  # Retrieves the versions of a cookbook in an unsorted manner...
  def versions(name)
    @redis.hkeys("cookbook:#{name}")
  end

  def cookbooks
    @redis.keys('cookbook:*')
  end

  # Don't know what this is for, but seems handy
  def each_of(search, &_block)
    return enum_for(:each_of, search) unless block_given?

    @redis.keys("cookbook:#{search}").each do |cookbook|
      config = @redis.hgetall(cookbook)
      name = cookbook.gsub(/^cookbook:/, '')
      yield name, to_versions(name, config)
    end
  end

  def each(block)
    each_of('*', block)
  end

  def size
    cookbooks.length
  end

  def empty?
    size.zero?
  end

  def find_by(search)
    @redis.keys("cookbook:#{search}").map { |cb| cb[9, cb.length] }
  end

  alias keys cookbooks

  private

  def init_ridley(endpoints)
    endpoints.each do |config|
      key = config['client_key'] || OpenSSL::PKey::RSA.new(2048).to_pem
      client = config['client_name'] || 'anonymous'
      config['ridley'] = Ridley.new(server_url: config['url'],
                                    client_name: client,
                                    client_key: key)
    end
  end

  def to_versions(name, versions)
    return nil unless versions
    v = versions.map do |ver, c|
      config = JSON.parse(c)
      ep = @endpoints.select { |elem| elem['name'] == config['endpoint'] }.first

      lib = YARD::Server::LibraryVersion.new(name, ver, nil, ep['type'].to_sym)
      lib.download_url = config['download_url']
      lib.ridley = ep['ridley'] if ep['type'] == 'chef_server'
      lib
    end
    v.sort_by { |l| Gem::Version.new(l.version) }
  end
end
