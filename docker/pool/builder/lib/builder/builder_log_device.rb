# LogDevice to write log to a file and send it through EM:WebSocket at once.
module Builder
  class BuilderLogDevice
    @logfile = nil
    @res = nil

    # [res]
    #   EM::DelegatedHttpResponse object
    # [logfile]
    #   File obejct to write log; this parameter is optional
    def initialize(res, logfile = nil)
      raise RuntimeError, 'Output objects are nil' if res.nil?
      @logfile = File.new(logfile, 'a') unless logfile.nil?
      @res  = res
      self.write('BuilderLogDevice is initialized')
    end

    # write and send to client the log message
    def write(message)
      @logfile.write(message) unless @logfile.nil?
      @res.send_event("build_log", strip_control_chars(message))
    end

    # Close file object
    def close
      @res.close_connection_after_writing
      @logfile.close
    end

    def strip_control_chars(message)
      message.gsub(/\x1B\[[0-9;]*[a-zA-Z]/, '')
    end
  end
end
