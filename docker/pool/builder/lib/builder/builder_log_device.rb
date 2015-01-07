require 'singleton'
# LogDevice to write log to a file and send it through EM:WebSocket at once.
module Builder
  class BuilderLogDevicePool
    include Singleton

    def initialize
      @devices = {}
      @m = Mutex.new
    end

    def find_or_create_device(git_commit_id, res, log_file)
      @m.synchronize do 
        if @devices[git_commit_id]
          @devices[git_commit_id].add_device(res)
        else
          @devices[git_commit_id] = BuilderLogDevice.new(res, "#{log_file}")
        end
        return @devices[git_commit_id]
      end
    end

    def delete_device(git_commit_id)
      @devices.reject!{|k| k == git_commit_id}
    end
  end

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
      @responses = [res]
      @m = Mutex.new
      self.write('BuilderLogDevice is initialized')
    end

    # write and send to client the log message
    def write(message)
      @m.synchronize do
        @logfile.write(message) unless @logfile.nil?
        @responses.each{|res| res.send_event("build_log", strip_control_chars(message)) }
      end
    end

    def notify_finished
      @m.synchronize do
        @responses.each{|res| res.send_event('build_finished', 'FINISHED') }
      end
    end

    def add_device(res)
      @m.synchronize do
        @responses << res
      end
    end

    # Close file object
    def close
      @m.synchronize do
        @responses.each{|res| res.close_connection_after_writing }
        @logfile.close
      end
    end

    def strip_control_chars(message)
      message.gsub(/\x1B\[[0-9;]*[a-zA-Z]/, '')
    end
  end
end
