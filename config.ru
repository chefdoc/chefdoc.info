$LOAD_PATH.unshift('.')
require 'app'
use Rack::ShowExceptions
run DocServer
