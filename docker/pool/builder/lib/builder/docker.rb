require 'docker'
require 'builder/config'

module Builder
  module Docker
    CONTAINER_PORT = 80
    ::Docker.options[:read_timeout] = 15 * 60 # 15 minutes

    attr_accessor :logger
    module_function :logger, :logger=
    module_function

    #
    # Get container address which corresponds to Git commit id.
    # Returns the hash which includes ip address and port of container.
    #
    # [commit_id]
    #   Git commit id
    #
    def find_container_by_commit_id(commit_id, opts={})
      logger = opts[:logger] || logger || Logger.new(STDOUT)

      logger.info("Getting container id for commit id<#{commit_id}>")
      
      containers = ::Docker::Container.all.map{|c| c.json}

      logger.info("Now number of running containers: #{containers.size}")

      ids = Config.read_ids

      if ids.empty?
        logger.info("No ids in id file")
        return nil
      end

      matched_images = ids.select{|i| i[0] == commit_id}.map{|i| i[1]}
      return nil if matched_images.empty?

      matched_container =  containers.select{|c| matched_images.include?(c["Image"])}.first
      return nil unless matched_container

      return format_container_data(matched_container)
    end

    def format_container_data(container)
      return {
        :ip => container["NetworkSettings"]["IPAddress"],
        :port => CONTAINER_PORT,
        :raw_json => container
      }
    end

    def build(tag, dir, opts = {})
      docker_opts = {"t" => tag}
      ::Docker::Image.build_from_dir(dir, docker_opts){ |output|
        data = JSON.parse(output)
        logger.info("#{data["status"]}: #{data["progressDetail"]}") if data["status"]
        logger.info(data["stream"]) if data["stream"]
        logger.error(data["errorDetail"]["message"]) if data["errorDetail"]
      }
    end

    def run(image_id, opts = {})
      container_opts = {
        'Image' => image_id,
        'PublishAllPorts' => true,
      }.merge(opts)

      container = ::Docker::Container.create(container_opts)
      container.start!

      return format_container_data(container.json)
    end
  end
end
