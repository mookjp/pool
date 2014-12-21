require 'octokit'
require 'faraday-http-cache'

module Builder
  module Bot
    class GitHubBot
      INTERVAL = 60

      def initialize(args = {})
        @config = Config.read_config_yaml

        @opts = {
          :base_domain => Config.read_base_domain,
          :access_token => @config['GITHUB_ACCESS_TOKEN'] || ENV['GITHUB_ACCESS_TOKEN'],
        }
        
        @opts.merge!(args)

        init_caching

        @last_updated = Time.now
        @client = @opts[:github_client] || Octokit::Client.new(:access_token => @opts[:access_token])
        @repository = get_repo_name
        @logger = @opts[:logger] || Logger.new(STDOUT)
        @pool_base_domain = @opts[:base_domain]
      end

      def get_repo_name
        repository_url = Config.read_repository_url
        /^.*github\.com(?::|\/)(.*).git/.match(repository_url)[1]
      end

      def start
        loop do
          fetch_new_pulls do |pull|
            post_preview_ready(pull)
          end
          sleep INTERVAL
        end
      end

      def post_preview_ready pull
        encoded_ref = encode_ref(pull[:head][:ref])
        sha = pull[:head][:sha]
        message = "Preview environment is staged! watch now:\nhttp://#{encoded_ref}.#{@pool_base_domain}\n(commit-ref ver. http://#{sha}.#{@pool_base_domain})"

        @logger.info("posting to #{@repository}: #{pull[:number].to_i},#{message}")
        @client.add_comment(@repository, pull[:number].to_i, message)
      rescue => e
        @logger.info(e)
      end

      def fetch_new_pulls(&block)
        @logger.info("fetch new pulls...")
        issues = @client.pulls(@repository)
        updated = issues.select{|s| s[:state] == "open" and s[:created_at] >= @last_updated}
        @last_updated = Time.now
        if updated.size > 0
          @logger.info("fetched #{updated.size} updated pulls") 
          @logger.info(updated) 
          updated.each do |issue|
            block.call(issue)
          end
        else
          @logger.info("there are no updates..") 
        end
        return updated
      end

      def encode_ref(ref)
        ref.gsub(/(\.|_)/, '--')
      end

      def init_caching
        stack = Faraday::RackBuilder.new do |builder|
          builder.use Faraday::HttpCache
          builder.use Octokit::Response::RaiseError
          builder.adapter Faraday.default_adapter
        end
        Octokit.middleware = stack
      end
    end
  end
end
