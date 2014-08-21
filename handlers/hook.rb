# hook to build and run Docker container

WORK_DIR = "/app/images"
ID_FILE = "#{WORK_DIR}/ids"
REPOSITORY_URL = "https://github.com/mookjp/flaskapp.git"

#
# Returns image ids of running containers
#
def get_running_image_ids
  `docker ps -q`.split("\n").map { |containerId|
    `docker inspect --format='{{.Image}}' #{containerId}`.chomp
  }.uniq
end

#
# Returns true if the container which built with Dockerfile on the commit id
# is runnning.
#
# [commit_id]
#   Git commit id
#
def is_running(commit_id)
  running_image_ids = get_running_image_ids

  File.open(ID_FILE) do |file|
    file.each_line do |line|
      id_file_commit_id = line.split("/")[0]
      id_file_image_id = line.split("/")[1]

      if commit_id == id_file_commit_id
        running_image_ids.each do |image_id|
          if image_id == id_file_image_id
            return true
          end
        end
      end
    end
  end
  return false
end

#
# Build Docker image from Git commit id.
# Docker image will be built by Dockerfile in Git repository which is pointed
# by Git commit id.
# This method returns Dcoker image id.
#
# [commit_id]
#   Git commit id
#
def build(commit_id)
  Apache.errlogger Apache::APLOG_NOTICE, "Build for #{commit_id}"

  repository_url = REPOSITORY_URL
  Apache.errlogger Apache::APLOG_NOTICE, "repository url:  #{repository_url}"
  repository_name = repository_url.split('/')[-1].split('.')[0]

  repository_path = "#{WORK_DIR}/#{repository_name}"
  if FileTest.exist?(repository_path)
    `cd #{repository_path} && git fetch origin && git checkout #{commit_id}`
  else
    `git clone -n #{repository_url} #{WORK_DIR}/#{repository_name}`
    `cd #{repository_path} && git checkout #{commit_id}`
  end


  Apache.errlogger Apache::APLOG_NOTICE, "Start building docker image..."
  image_id = \
  `docker build -t '#{repository_name}/#{commit_id}' #{WORK_DIR}/#{repository_name}`\
    .split("\n")[-1]\
    .split(" ")[-1]
  image_full_id = \
  `docker inspect --format='{{.Id}}' #{image_id}`.chomp
  write_ids(commit_id, image_full_id)
  return image_full_id
end

def run(image_id)
  Apache.errlogger Apache::APLOG_NOTICE, "Start running container..."
  `docker run -P -d #{image_id}`.chomp
end

#
# Write Git commit id and Docker image id to id file.
# id file is needed for controller to judge to build new image
#
# [commit_id]
#   Git commit id
# [image_id]
#   Docker image id
# [id_file]
#   Path to id file
#
def write_ids(commit_id, image_id, id_file = ID_FILE)
  Apache.errlogger Apache::APLOG_NOTICE, "Write image id<#{image_id}> and \
  commit id<#{commit_id}> to #{ID_FILE}"

  File.open(id_file, "a") do |file|
    file.write("#{commit_id}/#{image_id}\n")
  end
end

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

  ids = File.open(id_file, "r") do |file|
    file.readlines.map do |line|
      line.chomp.split("/")
    end
  end

  return nil if ids.empty?

  ids.each do |id_set|
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
  image_id = build(target_commit_id)
  container_id = run(image_id)
  port = get_port_of_container(container_id)
else
  port = get_port_of_container(container_id)
end

Apache.errlogger Apache::APLOG_NOTICE, "commit_id=#{target_commit_id} port=#{port} containerid=#{container_id} image_id=#{image_id}"
r = Apache::Request.new()
r.handler  = "proxy-server"
r.proxyreq = Apache::PROXYREQ_REVERSE
r.filename = "proxy:" + "http://0.0.0.0:#{port}" + r.unparsed_uri
Apache::return(Apache::OK)
