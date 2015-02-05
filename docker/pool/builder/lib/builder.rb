require 'fileutils'
require 'net/http'
require 'logger'
require 'timeout'

require 'git'
require 'pty'

require 'builder/build_handler'
require 'builder/builder_log_device'
require 'builder/git'
require 'builder/git_handler'
require 'builder/docker'
require 'builder/docker_handler'
require 'builder/constants'
require 'builder/config'
require 'builder/bot'
require 'builder/version'

module Builder
  class BuildLockedError < StandardError; end

  class Builder
    include ::Builder::Git
    #
    # Initialize method
    # [res]
    #   EM::DelegatedHttpResponse object
    # [git_commit_id]
    #   Git commit id
    # [work_dir]
    #   Working directory to save logfile and commit-image id file
    # [log_file]
    #   Build log file
    # [id_file]
    #   File to store the references git-commit-id and docker-image-id
    # [repository_conf]
    #   File to store repository url
    def initialize(res,
                   git_commit_specifier,
                   work_dir = WORK_DIR,
                   app_repo_dir_name = APP_REPO_DIR_NAME,
                   log_file = "#{work_dir}/builder.log",
                   id_file = "#{work_dir}/ids",
                   repository_conf = "#{work_dir}/#{REPOSITORY_CONF}",
                   base_domain_file = "#{work_dir}/base_domain"
                  )

      # Create work directory if it has not been created yet
      [work_dir, File.join(work_dir, WORKSPACE_BASE_DIR)].each do |d|
        FileUtils.mkdir_p(d) unless File.exist?(d)
      end

      @work_dir = work_dir
      @repository = create_repository_config(repository_conf,
                                             work_dir,
                                             app_repo_dir_name)

      @res = res
      @log_device_pool = BuilderLogDevicePool.instance
      logger = Logger.new(BuilderLogDevice.new(res, "#{log_file}"))
      # Initialize Git repository and set @rgit instance
      Docker.logger = logger

      @rgit = init_repo(@repository[:url],
                        @repository[:path],
                        logger)

      @id_file = id_file
      @git_commit_id = resolve_commit_id(git_commit_specifier, :git_base => @rgit)

      @log_device = @log_device_pool.find_or_create_device(@git_commit_id, res, "#{log_file}")
      @logger = Logger.new(@log_device)

      @base_domain = Config.read_base_domain(base_domain_file)
      @logger.info "Initialized. Git commit id: #{@git_commit_id}"
    end
    # Create objects which has infomation of app
    #
    # [repository_conf]
    #   repository_conf file which has repository's URL
    # [work_dir]
    #   Path of working directory
    # [app_repo_dir_name]
    #   The name of directory of application repository; This should be fixed
    #   value as pool only supports one application and it fetches changes
    #   inside repository directory.
    def create_repository_config(repository_conf,
                          work_dir,
                          app_repo_dir_name)
      repository_url = Config.read_repository_url(repository_conf)
      name = repository_url.split("/").last.split(".git").first
      return {
        :url => repository_url,
        :name => name,
        :path => "#{work_dir}/#{app_repo_dir_name}",
        :container_prefix => container_prefix(name),
      }.freeze
    end

    # Build Docker image and run it as a container.
    def up
      begin
        lock = File.open(lockfile, 'w')
        if lock.flock(File::LOCK_EX | File::LOCK_NB )
          image_id = build
          container = run(image_id)
          confirm_running(container)
        else
          @logger.info("Locked! Other environment is under building process")
          @logger.info("Please wait for finishing another building process...")
          raise BuildLockedError
        end
      rescue BuildLockedError
        Timeout::timeout(BUILD_LOCK_TIMEOUT) do
          lock.flock(File::LOCK_EX)
        end
      rescue Timeout::Error
        @logger.error("No response after #{BUILD_LOCK_TIMEOUT}. Please reload the page.")
      rescue => ex
        @logger.error ex
        raise
      ensure
        @logger.close
        @log_device_pool.delete_device(@git_commit_id)
        lock.flock(File::LOCK_UN)
      end
    end

    def lockfile
      return File.join(LOCK_DIR, "pool_#{@git_commit_id}.lock")
    end

    # Confirm container application is ready to get request via HTTP
    # the container is not ready, wait and retry to send request
    #
    # TODO: need to set protocol, port and path by the user
    def confirm_running(container)
      ip = container[:ip]
      port = container[:port]

      tried_count = 1
      begin
        @logger.info "Checking application is ready... trying count:#{tried_count}"
        req = Net::HTTP.new(ip, port)
        res = req.get('/')
        unless res.kind_of?(Net::HTTPSuccess) or res.kind_of?(Net::HTTPRedirection)
          raise "Response status is not ready: #{res.code}"
        end
        @logger.info("Application is ready! forwarding to port #{port}")
        @log_device.notify_finished
      rescue => e
        @logger.info e
        if tried_count <= 30
          sleep 1
          tried_count += 1
          retry
        end
        raise
      end
    end

    #
    # Build Docker image from Git commit id.
    # Docker image will be built by Dockerfile in Git repository which is pointed
    # by Git commit id.
    # This method returns Docker image id.
    #
    def build
      @logger.info "Build for #{@git_commit_id} ..."

      @workspace = init_repo(@repository[:url],
                        @repository[:path],
                        @logger,
                        :workspace_dir => @git_commit_id)

      @logger.info @workspace.checkout(@git_commit_id)

      @logger.info 'Start building docker image...'
      image = Docker.build("#{@repository[:container_prefix]}/#{@git_commit_id}",
                   "#{@workspace.dir.path}"
                  )
      image_id = image.json["Id"]
      write_ids(image_id)
      image_id
    end

    #
    # Run container with Docker image id
    # [image_id]
    #   Docker image id
    #
    def run(image_id)
      @logger.info 'Start running container...'
      env = ["POOL_HOSTNAME=#{pool_hostname}"]
      container = Docker.run(image_id, {'Env' => env})

      return container
    end


    def pool_hostname
      [@git_commit_id, @base_domain].join(".")
    end

    #
    # Write Git commit id and Docker image id to id file.
    # id file is needed for controller to judge to build new image
    #
    # [image_id]
    #   Docker image id
    # [id_file]
    #   Path to id file
    #
    def write_ids(image_id, id_file = @id_file)
      @logger.info "Write image id <#{image_id}> and commit id <#{@git_commit_id}> to #{@id_file}"

      File.open(id_file, "a") do |file|
        file.write("#{@git_commit_id}/#{image_id}\n")
      end
    end

    # As the naming rule for Git repository and Docker image is different,
    # this method would convert it to the name which matches both rules.
    #
    # [name]
    #   The name of Git repository
    def container_prefix(name)
      name << '_' while name.size < 4
      return name.gsub(/-/, '_').downcase
    end
  end

end

