require 'openssl'
require 'ridley'

# Configuration class to load the config YAML
class Configuration < Hash
  # Define defaults
  def load_defaults
    self[:name] = 'Chefdoc'
    self[:url] = 'http://chefdoc.info'

    self[:caching] = false
    self[:endpoints] = [
      { 'name' => 'chef-supermarket',
        'type' => 'supermarket',
        'url'  => 'https://supermarket.chef.io/',
        'desc' => 'Official chef cookbook supermarket'
      }
    ]
    self[:database] = { host: ENV['REDIS_HOST'],
                        port: ENV['REDIS_PORT'] || 6379,
                        db:   ENV['REDIS_DB'] || 1 }
    self[:endpoint_interval] = (5 * 60) # 5 Minutes
    self[:google_analytics] = ENV['G_ANALYTICS_ID']
  end

  def self.load
    config = Configuration.new
    config.load_defaults

    if File.file?(CONFIG_FILE)
      (YAML.load_file(CONFIG_FILE) || {}).each do |key, value|
        config[key] = value
        define_method(key) { self[key] }
      end
    end

    config
  end

  def method_missing(name, *_args, &_block)
    self[name]
  end
end
