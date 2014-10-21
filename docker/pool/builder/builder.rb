$:.unshift '/app/builder'
require 'fileutils'
require 'net/http'
require 'logger'

require 'builder_log_device'
require 'git'

class Builder

  WORK_DIR = '/app/images'
  LOG_FILE = "#{WORK_DIR}/builder.log"
  ID_FILE = "#{WORK_DIR}/ids"
  REPOSITORY_CONF = "#{WORK_DIR}/preview_target_repository"

  #
  # Initialize method
  #
  # [ws]
  #   EM::WebSocket object
  # [git_commit_id]
  #   Git commit id
  #
  def initialize(ws, git_commit_id)
    create_dirs

    @ws = ws
    @git_commit_id = git_commit_id
    @repository = read_repository_info
    @logger = Logger.new(BuilderLogDevice.new(@ws, "#{LOG_FILE}"))
    @logger.info "Initialized. Git commit id: #{@git_commit_id}"

    # Initialize Git repository and set @rgit instance
    init_repo
  end

  # load preview target repository info from config file
  def read_repository_info
    repository_url = File.open(REPOSITORY_CONF).gets.chomp
    name = repository_url.split("/").last.split(".").first
    return {
      :url => repository_url,
      :name => name,
      :container_prefix => container_prefix(name),
      :path => "#{WORK_DIR}/#{name}",
    }.freeze
  end

  # Initialize application Git repository to clone from remote
  # If the repository exists, it fetches the latest
  def init_repo
    log_device = BuilderLogDevice.new(@ws)

    @logger.info "repository url:  #{@repository[:url]}"

    if FileTest.exist?(@repository[:path])
      @logger.info "repository path exists: #{@repository[:path]}"
      @rgit = Git.open(@repository[:path], :log => @logger)
      @logger.info @rgit.fetch
    else
      @logger.info "repository path doesn't exist: #{@repository[:path]}"
      # Create LogDevice to log to websocket message
      @rgit = Git.clone(@repository[:url], @repository[:name],
                        :path => WORK_DIR,
                        :log => @logger)
    end
  end

  # Create required directory if it has not been created yet
  def create_dirs
    FileUtils.mkdir_p(WORK_DIR) unless File.exist?(WORK_DIR)
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
    port = get_port_of_container container_id

    tried_count = 1
    begin
      @logger.info "Checking application is ready... trying count:#{tried_count}"
      Net::HTTP.get('0.0.0.0', '/', port)
      @logger.info("Application is ready! forwarding to port #{port}")
      @logger.info 'FINISHED'
      @ws.send 'FINISHED'
    rescue
      if tried_count <= 10
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
                  "Docker build has not finished successfully, see #{LOG_FILE}"\
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
    build_command = "docker build -t '#{@repository[:container_prefix]}/#{@git_commit_id}' #{WORK_DIR}/#{@repository[:name]}"
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
  def write_ids(image_id, id_file = ID_FILE)
    @logger.info "Write image id <#{image_id}> and commit id <#{@git_commit_id}> to #{ID_FILE}"

    File.open(id_file, "a") do |file|
      file.write("#{@git_commit_id}/#{image_id}\n")
    end
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
