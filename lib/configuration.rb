require 'openssl'
require 'ridley'

# Configuration class to load the config YAML
class Configuration < Hash
  def self.load
    config = Configuration.new

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
