require 'eventmachine'
require 'evma_httpserver'
require 'builder/constants'
require 'builder'

module EventMachine
  class HttpResponse
    attr_accessor :sse
    def fixup_headers
      if @content && @content.is_a?(String)
        @headers["Content-Length"] = @content.bytesize
      elsif @chunks
        @headers["Transfer-Encoding"] = "chunked"
      elsif @multiparts
        @multipart_boundary = self.class.concoct_multipart_boundary
        @headers["Content-Type"] = "multipart/x-mixed-replace; boundary=\"#{@multipart_boundary}\""
      elsif @sse
        @headers["Content-Type"] = "text/event-stream"
        @headers["Connection"] = "keep-alive"
        @headers["Cache-Control"] = "no-cache"
      else
        @headers["Content-Length"] = 0
      end
    end

    def send_event event_id, msg
      send_data("event: #{event_id}\r\n")
      send_data("data: #{msg}\r\n\n")
    end
  end
end

module Builder
  class BuildHandler < EventMachine::Connection
    include EventMachine::HttpServer

    def initialize(*args)
      super
      STDOUT.sync = true
      @logger ||= Logger.new(STDOUT)
      @logger.info("BuildHandler is initialized.")
    end

    def process_http_request
      res = EventMachine::DelegatedHttpResponse.new(self)
      res.sse = true
      res.send_headers

      if @http_path_info =~ /^\/build\/(.*)$/
        target = $1
        begin
          Thread.new(res) do |r, l|
            begin
              @logger.info "path_info: #{@http_path_info}"
              builder = Builder.new(res, target)
              builder.up
            rescue => ex
              @logger.info "#{ex.class}: #{ex.message}; #{ex.backtrace}"
              res.content = "#{ex.class}: #{ex.message}; #{ex.backtrace}"
              res.status = 500
              return res.send_response
            end
          end
          return nil
        rescue => e
          @logger.info e
          res.content = e
        end
      end

      res.status = 500
      return res.send_response
    end

  end
end

