require 'git'
require 'builder/constants'

module Builder
  module Git

    module_function
    def resolve_commit_id(git_commit_specifier, opts = {})
      git_base = opts[:git_base] || ::Git.open("#{WORK_DIR}/#{APP_REPO_DIR_NAME}")

      begin
        git_base.fetch
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

      if opts[:workspace_dir]
        workspace_path = File.join(File.dirname(path), WORKSPACE_BASE_DIR, opts[:workspace_dir])
      else
        workspace_path = path
      end

      if FileTest.exist?(workspace_path)
        logger.info "repository workspace_path exists: #{workspace_path}"
        rgit = ::Git.open(workspace_path, :log => logger)
        logger.info rgit.fetch unless opts[:no_fetch]
      else
        logger.info "repository workspace_path doesn't exist: #{workspace_path}"

        app_repository_name = workspace_path.split('/').last
        logger.info "cloning: #{[url, app_repository_name, File.basename(workspace_path)].join(",")}"
        rgit = ::Git.clone(url,
                           app_repository_name,
                           :path => File.dirname(workspace_path),
                           :log  => logger)
      end
      return rgit
    end
  end
end
