$:.unshift '/app/builder'
require 'fileutils'
require 'git'
require 'logger'
require 'builder_log_device'

class Builder

  WORK_DIR = '/app/images'
  LOG_FILE = "#{WORK_DIR}/builder.log"
  ID_FILE = "#{WORK_DIR}/ids"
  REPOSITORY_URL = 'https://github.com/mookjp/flaskapp.git'
  REPOSITORY_NAME = 'flaskapp'
  REPOSITORY_PATH = "#{WORK_DIR}/#{REPOSITORY_NAME}"

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
    @logger = Logger.new(BuilderLogDevice.new(@ws, "#{LOG_FILE}"))
    @logger.info "Initialized. Git commit id: #{@git_commit_id}"

    # Initialize Git repository and set @rgit instance
    init_repo
  end

  # Initialize application Git repository to clone from remote
  # If the repository exists, it fetches the latest
  def init_repo
    log_device = BuilderLogDevice.new(@ws)

    @logger.info "repository url:  #{REPOSITORY_URL}"

    if FileTest.exist?(REPOSITORY_PATH)
      @logger.info "repository path exists: #{REPOSITORY_PATH}"
      @rgit = Git.open(REPOSITORY_PATH, :log => @logger)
      @logger.info @rgit.fetch
    else
      @logger.info "repository path doesn't exist: #{REPOSITORY_PATH}"
      # Create LogDevice to log to websocket message
      @rgit = Git.clone(REPOSITORY_URL, REPOSITORY_NAME,
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
    image_id = build
    run(image_id)
    @logger.info 'FINISHED'
    @ws.send 'FINISHED'
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
    build_command = "docker build -t '#{REPOSITORY_NAME}/#{@git_commit_id}' #{WORK_DIR}/#{REPOSITORY_NAME}"
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
    `docker inspect \
    --format='{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' \
    #{container_id}`.chomp
  end
end
