require 'eventmachine'
require 'evma_httpserver'
require 'builder/constants'

module Builder
  class GitHandler < EventMachine::Connection
    include EventMachine::HttpServer
    include Builder::Git
    
    def initialize(*args)
      super
      @logger = Logger.new(STDOUT)
      @logger.info("GitHandler logger is initialized.")
      @logger.info([WORK_DIR, APP_REPO_DIR_NAME].join(","))
      @repo_config = {
        :path => File.join(WORK_DIR, APP_REPO_DIR_NAME),
        :url =>  File.open(File.join(WORK_DIR, REPOSITORY_CONF)).gets.chomp
      }
      @logger.info("@repo_config is initialized: #{@repo_config}")
    end
  
    def process_http_request
      res = EventMachine::DelegatedHttpResponse.new(self)

      if @http_path_info =~ /^\/resolve_git_commit\/(.*)$/
        res.status = 200
        begin
          res.content = resolve_commit_id($1)
          return res.send_response
        rescue => e
          res.content = e
        end
      end

      if @http_path_info =~ /^\/init_repo/
        res.status = 200
        begin
          @logger.info "init_repo is hooked"
          res.content = init_repo(@repo_config[:url], @repo_config[:path], @logger)
          return res.send_response
        rescue => e
          res.content = e
        end
      end

      res.status = 500
      return res.send_response
    end
  end
end
