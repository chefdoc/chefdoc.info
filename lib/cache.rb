require 'uri'
require 'net/http/persistent'
require_relative 'helpers'

class PurgeRequest < Net::HTTPRequest
  METHOD = 'PURGE'.freeze
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = true
end

module Cache
  module_function

  def invalidate(*paths)
    # TODO: We don't cache by default. Find a way to use the settings.caching option here.
    files = []
    paths.each do |f|
      f = '/index' if f == '/'
      if f[-1, 1] == '/'
        files << File.join(STATIC_PATH, f)
        f = f[0...-1]
      end
      files << File.join(STATIC_PATH, f + '.html')
    end

    rm_cmd = "rm -rf #{files.join(' ')}"
    Helpers.sh(rm_cmd, 'Flushing cache', false)
  end
end
