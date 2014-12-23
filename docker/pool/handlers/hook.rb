# hook to build and run Docker container
# TODO: Replace back quote; Karnel.` to Process to wait and kill processes

WORK_DIR = "/app/images"
APP_REPO_DIR = "#{WORK_DIR}/app_repo"
REPOSITORY_CONF = "#{WORK_DIR}/preview_target_repository"
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
  return 80
end

def get_addr_of_container(container_id)
  Apache.errlogger Apache::APLOG_NOTICE, \
    "Getting address container<#{container_id}>"
  return `docker inspect --format '{{ .NetworkSettings.IPAddress }}' #{container_id}`.chomp
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

# return build-screen to show Docker's build log
def return_build_screen
  r = Apache::Request.new
  Apache.errlogger Apache::APLOG_NOTICE, \
    "#{r.uri}, #{r.path_info}, #{r.args}, #{r.protocol}, #{r.the_request}"
  
  doc_root = "/app/handlers/resources/build-screen/"

  if r.uri =~ /^\/(styles|scripts|images)\//
    r.filename = doc_root + r.uri 
  else
    r.filename = doc_root + "index.html"
  end

  return Apache::return(Apache::OK)
end

# Forward to container
def forward_to_container(container_id)
  addr = get_addr_of_container(container_id)
  port = get_port_of_container(container_id)
  r = Apache::Request.new()
  r.reverse_proxy "http://#{addr}:#{port}" + r.uri
  return Apache::return(Apache::OK)
end

#`mkdir -p #{APP_REPO_DIR}` unless FileTest.exist?(APP_REPO_DIR)
# Create id-file to log git-commit-id and container-id
File.new(ID_FILE, "w") unless FileTest.exist?(ID_FILE)

# Get target name like git-commit-id or branch name from subdomain
# then use `git rev-parse` to get actual commit id
hin = Apache::Headers_in.new
target = hin["Host"].split(".")[0]

# Move to the repository directory if there is.
# Or clone it by url read from git_repository_conf file.
`curl http://0.0.0.0:9000/init_repo`
return Apache::return(Apache::HTTP_BAD_REQUEST) \
  unless FileTest.exist?(APP_REPO_DIR)

target_commit_id = `curl http://0.0.0.0:9000/resolve_git_commit/#{target}`.chomp
Apache.errlogger Apache::APLOG_NOTICE, \
  "target: #{target}, target_commit_id: #{target_commit_id}"
# There is the target commit in repository or having not been initialized as
# Git repository, return bad request response
Apache::return(Apache::HTTP_BAD_REQUEST) unless `echo $?`.chomp == '0'

container_id = get_container_id(target_commit_id)
if container_id == nil
  return_build_screen
else
  forward_to_container(container_id)
end
