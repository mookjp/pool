require 'eventmachine'
require 'evma_httpserver'
require 'builder/constants'
require 'builder/docker'
require 'json'

module Builder
  class DockerHandler < EventMachine::Connection
    include EventMachine::HttpServer
    
    def initialize(*args)
      super
      @logger ||= Logger.new(STDOUT)
      @logger.info("DockerHandler logger is initialized.")
    end
  
    def process_http_request
      res = EventMachine::DelegatedHttpResponse.new(self)

      if @http_path_info =~ /^\/containers\/(.*)$/
        commit_id = $1
        begin
          res.status = 200
          container = Docker.find_container_by_commit_id(commit_id)
          if container
            addr = "#{container[:ip]}:#{container[:port]}"
            res.content = JSON.generate({:status => 'success',
                                         :addr => addr})
            @logger.info "found container_id: #{res.content}"
            return res.send_response
          end
        rescue => e
          @logger.info e
        end
      end

      res.status = 500
      res.content = JSON.generate({:status => 'error'})
      return res.send_response
    end
  end
end
