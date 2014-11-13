require 'fileutils'
require 'net/http'
require 'logger'

require 'git'

require 'builder/builder_log_device'

module Builder
  class Builder

    #
    # Initialize method
    # [ws]
    #   EM::WebSocket
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
    def initialize(ws,
                   git_commit_id,
                   work_dir = '/app/images',
                   log_file = "#{work_dir}/builder.log",
                   id_file = "#{work_dir}/ids",
                   repository_conf = "#{work_dir}/preview_target_repository")

      @work_dir = work_dir
      create_dirs

      @id_file = id_file
      @repository_conf = repository_conf
      @git_commit_id = git_commit_id
      @repository = read_repository_info

      @ws = ws
      @logger = Logger.new(BuilderLogDevice.new(ws, "#{log_file}"))
      @logger.info "Initialized. Git commit id: #{@git_commit_id}"

      # Initialize Git repository and set @rgit instance
      init_repo
    end

    # load preview target repository info from config file
    def read_repository_info
      repository_url = File.open(@repository_conf).gets.chomp
      name = repository_url.split("/").last.split(".").first
      return {
        :url => repository_url,
        :name => name,
        :container_prefix => container_prefix(name),
        :path => "#{@work_dir}/#{name}",
      }.freeze
    end

    # Initialize application Git repository to clone from remote
    # If the repository exists, it fetches the latest
    def init_repo
      @logger.info "repository url:  #{@repository[:url]}"

      if FileTest.exist?(@repository[:path])
        @logger.info "repository path exists: #{@repository[:path]}"
        @rgit = Git.open(@repository[:path], :log => @logger)
        @logger.info @rgit.fetch
      else
        @logger.info "repository path doesn't exist: #{@repository[:path]}"
        # Create LogDevice to log to websocket message
        @rgit = Git.clone(@repository[:url], @repository[:name],
                          :path => @work_dir,
                          :log => @logger)
      end
    end

    # Create required directory if it has not been created yet
    def create_dirs
      FileUtils.mkdir_p(@work_dir) unless File.exist?(@work_dir)
    end

    # Build Docker image and run it as a container.
    def up
      begin
        image_id = build
        container_id = run image_id
        confirm_running container_id
      rescue => ex
        @logger.error ex
        raise
      ensure
        @logger.close
      end
    end

    # Confirm container application is ready to get request via HTTP
    # the container is not ready, wait and retry to send request
    #
    # TODO: need to set protocol, port and path by the user
    def confirm_running(container_id)
      ip = get_ip_of_container container_id
      port = get_port_of_container container_id

      tried_count = 1
      begin
        @logger.info "Checking application is ready... trying count:#{tried_count}"
        req = Net::HTTP.new(ip, port)
        res = req.get('/')
        unless res.kind_of?(Net::HTTPSuccess) or res.kind_of?(Net::HTTPRedirection)
          raise "Response status is not ready: #{res.code}"
        end
        @logger.info("Application is ready! forwarding to port #{port}")
        @logger.info 'FINISHED'
        @ws.send 'FINISHED'
      rescue
        if tried_count <= 30
          sleep 1
          tried_count += 1
          retry
        end
        raise
      end
    end

    # Wrap command with pty spawn to get output
    #
    # [command]
    #   command to execute
    #
    def ptywrap(command)
      last_line = ''

      PTY.spawn(command) do |r, w, pid|
        begin
          r.each do |line|
            @logger.info line
            last_line = line

            status = PTY.check pid
            unless status.nil?
              raise RuntimeError,
                "Docker build has not finished successfully, see #{@log_file}"\
                unless status.exitstatus.eql? 0
              end
            end
          rescue Errno::EIO
          end
        end

        last_line
      end

      #
      # Build Docker image from Git commit id.
      # Docker image will be built by Dockerfile in Git repository which is pointed
      # by Git commit id.
      # This method returns Docker image id.
      #
      def build
        @logger.info "Build for #{@git_commit_id} ..."

        @logger.info @rgit.checkout(@git_commit_id)

        @logger.info 'Start building docker image...'
        build_command = "docker build -t '#{@repository[:name]}/#{@git_commit_id}' #{@work_dir}/#{@repository[:name]}"
        last_line = ptywrap(build_command)
        image_id = last_line.split(" ")[-1]
        @logger.info "image_id is #{image_id}"

        image_full_id = \
          `docker inspect --format='{{.Id}}' #{image_id}`.chomp
        write_ids(image_full_id)
        image_full_id
      end

      #
      # Run container with Docker image id
      # [image_id]
      #   Docker image id
      #
      def run(image_id)
        @logger.info 'Start running container...'
        container_id = `docker run -P -d #{image_id}`.chomp

        is_running = `docker inspect --format='{{.State.Running}}' #{container_id}`
        raise RuntimeError, 'Could not start running container.' if is_running.eql? 'false'

        container_id
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

      #
      # Get ip address of Docker container by docker inspect command
      #
      # [container_id]
      #   Docker container id
      #
      def get_ip_of_container(container_id)
        `docker inspect --format '{{ .NetworkSettings.IPAddress }}' #{container_id}`.chomp
      end

      #
      # Get port of Docker container by docker inspect command
      #
      # [container_id]
      #   Docker container id
      #
      def get_port_of_container(container_id)
        @logger.info "Getting port id for container <#{container_id}> ..."
        port = container_port
        @logger.info "port for container #{container_id} is : #{port}"

        return port
      end

      def container_port
        #TODO: change to use user-defined value
        return 80
      end

      def container_prefix name
        return name.gsub(/-/, '_')
      end
    end
  end
