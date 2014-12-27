require 'docker'
require 'builder/config'

module Builder
  module Docker
    CONTAINER_PORT = 80

    module_function
    #
    # Get container address which corresponds to Git commit id.
    # Returns the address of container.
    #
    # [commit_id]
    #   Git commit id
    #
    def find_container_by_commit_id(commit_id, opts={})
      logger = opts[:logger] || Logger.new(STDOUT)

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

      return "#{matched_container["NetworkSettings"]["IPAddress"]}:#{CONTAINER_PORT}"
    end
  end
end
