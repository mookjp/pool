require 'builder/constants'
require 'builder/config'
require 'active_support/cache'

module Builder
  module Git
    class Cache
      include Singleton

      def initialize
        @git_commit_id_cache_expire ||= Config.read_git_commit_id_cache_expire
        @cache  = ActiveSupport::Cache::MemoryStore.new(expires_in: @git_commit_id_cache_expire)
      end

      def fetch(key, &block)
        @cache.fetch(key, &block)
      end
    end
  end
end
