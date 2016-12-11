$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__)))
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/lib'))

require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'yard'
require 'cookbook_store'

YARD::Server::Adapter.setup
YARD::Templates::Engine.register_template_path(File.dirname(__FILE__) + '/templates')

def __p(*extra)
  file = extra.last == :file
  extra.pop if file
  path = if extra.first.start_with?('/')
           File.join(*extra)
         else
           File.join(File.dirname(__FILE__), *extra)
         end
  FileUtils.mkdir_p(path) unless File.exist?(path) || file
  path
end

# Set global data path to keep data in one Docker volume
DATA_PATH        = ENV['DATA_PATH'].nil? ? '.' : __p(ENV['DATA_PATH'])

CONFIG_PATH      = __p('config')
TMP_PATH         = __p('tmp')
TEMPLATES_PATH   = __p('templates')
CONFIG_FILE      = __p('config', 'config.yaml', :file)
REPOS_PATH       = __p("#{DATA_PATH}/repos")
STATIC_PATH      = __p("#{DATA_PATH}/public")
COOKBOOKS_PATH   = __p("#{REPOS_PATH}/cookbooks")

require_relative 'lib/helpers'
require_relative 'lib/configuration'

$CONFIG = Configuration.load

# For testing an possibly small installations use a single FakeRedis connection.
# Otherwise initialize the redis connections in the worker.
if $CONFIG[:database][:host].nil? || $CONFIG[:database][:host].empty?
  require 'fakeredis'
  $CONFIG[:database] = Redis.new
else
  require 'redis'
end
