require 'open3'

# Some helper stuff
module Helpers
  module_function

  def sh(command, title = '', write_error = true)
    puts("#{Time.now}: #{title}: #{command}")
    result, out_data, err_data = 0, '', ''
    Open3.popen3(command) do |_, out, err, thr|
      out_data = out.read
      err_data = err.read
      result = thr.value
    end
    puts("#{Time.now}: #{title}, result=#{result.to_i}")
    if write_error && result != 0
      "#{log}\n\nSTDOUT:\n#{out_data}\n\nSTDERR:\n#{err_data}\n\n"
    end
    result
  end
end
