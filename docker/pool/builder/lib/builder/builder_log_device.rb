# LogDevice to write log to a file and send it through EM:WebSocket at once.
module Builder
  class BuilderLogDevice

    @logfile = nil
    @ws = nil

    # [ws]
    #   EM::WebSocket object
    # [logfile]
    #   File obejct to write log; this parameter is optional
    def initialize(ws, logfile = nil)
      raise RuntimeError, 'Output objects are nil' if ws.nil?
      @logfile = File.new(logfile, 'a') unless logfile.nil?
      @ws = ws
    end

    # write and send to client the log message
    def write(message)
      @logfile.write(message) unless @logfile.nil?
      @ws.send(message)
    end

    # Close file object
    def close
      @logfile.close
    end
  end
end
