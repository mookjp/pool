require 'eventmachine'
require 'evma_httpserver'

module Builder
  class GitHandler < EventMachine::Connection
    include EventMachine::HttpServer
    include Builder
   
    def process_http_request
      res = EventMachine::DelegatedHttpResponse.new(self)

      if @http_path_info =~ /^\/resolve_git_commit\/(.*)$/
        res.status = 200
        begin
          res.content = resolve_commit_id($1)
        rescue => e
          res.content = e
        end
      end

      res.status  = 500
      res.send_response
    end
  end
end
