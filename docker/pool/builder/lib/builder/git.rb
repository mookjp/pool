require 'git'
require 'builder/constants'

module Builder
  module Git

    module_function
    def resolve_commit_id(git_commit_specifier, opts = {})
      git_base = opts[:git_base] || ::Git.open("#{WORK_DIR}/#{APP_REPO_DIR_NAME}")

      begin
        commit_id = git_base.revparse(git_commit_specifier)
      rescue => e
        if e.message =~ /unknown revision or path not in the working tree/
          remote_branches = git_base.branches.remote.reject{|n| n.name =~ /^HEAD/}
          matched_branches = remote_branches.select{|n| n.name =~ /#{git_commit_specifier}/}
          raise e if matched_branches.size == 0
          commit_id = git_base.revparse(matched_branches.first.full)
        else
          raise e
        end
      end
      return commit_id
    end

    # Initialize application Git repository to clone from remote
    # If the repository exists, it fetches the latest
    def init_repo(url, path, logger, opts = {})
      logger.info "repository url: #{url}"

      if FileTest.exist?(path)
        logger.info "repository path exists: #{path}"
        rgit = ::Git.open(path, :log => logger)
        logger.info rgit.fetch unless opts[:no_fetch]
      else
        logger.info "repository path doesn't exist: #{path}"
        # Create LogDevice to log to websocket message
        app_repository_name = path.split('/').last
        logger.info "cloning: #{[url, app_repository_name, File.basename(path)].join(",")}"
        rgit = ::Git.clone(url,
                           app_repository_name,
                           :path => File.dirname(path),
                           :log => logger)
      end
      return rgit
    end
  end
end
