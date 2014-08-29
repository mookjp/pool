# hook to build and run Docker container

WORK_DIR = "/app/images"
ID_FILE = "#{WORK_DIR}/ids"

#
# Get port of Docker container by container id
#
# [container_id]
#   Docker container id
#
def get_port_of_container(container_id)
  Apache.errlogger Apache::APLOG_NOTICE, \
    "Getting port id for container<#{container_id}>"
  `docker inspect --format='{{(index (index .NetworkSettings.Ports "80/tcp") 0).HostPort}}' #{container_id}`.chomp
end

#
# Get container id which corresponds to Git commit id.
# Returns Docker container id.
#
# [commit_id]
#   Git commit id
#
def get_container_id(commit_id, id_file = ID_FILE)
  Apache.errlogger Apache::APLOG_NOTICE, \
    "Getting container id for commit id<#{commit_id}>"

  containers = `docker ps -q`.split("\n").map { |container_id|
    `docker inspect --format='{{.Image}} {{.Id}}' #{container_id}`.split(" ")
  }

  Apache.errlogger Apache::APLOG_NOTICE, \
    "Containers: #{containers}"

  ids = File.open(id_file, "r") do |file|
    file.readlines.map do |line|
      line.chomp.split("/")
    end
  end

  return nil if ids.empty?

  ids.each do |id_set|
  Apache.errlogger Apache::APLOG_NOTICE, "id set: #{id_set}"
    file_commit_id = id_set[0]
    file_image_id = id_set[1]
    if commit_id == file_commit_id
      containers.each do |con_ids|
        if file_image_id == con_ids[0] # Container image id
          return con_ids[1]
        end
      end
    end
  end
  return nil
end

`mkdir -p #{WORK_DIR}` unless FileTest.exist?(WORK_DIR)
File.new(ID_FILE, "w") unless FileTest.exist?(ID_FILE)

hin = Apache::Headers_in.new
target_commit_id = hin["Host"].split(".")[0]

container_id = get_container_id(target_commit_id)

if container_id == nil
  r = Apache::Request.new
  r.filename= "/app/handlers/resources/building.html"
  Apache::return(Apache::OK)
else
  port = get_port_of_container(container_id)
  r = Apache::Request.new()
  r.reverse_proxy "http://0.0.0.0:#{port}" + r.unparsed_uri
  Apache::return(Apache::OK)
end
