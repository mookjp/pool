# hook to build and run Docker container

WORK_DIR = "/app/images"
APP_REPO_DIR = "#{WORK_DIR}/app_repo"
ID_FILE = "#{WORK_DIR}/ids"

# return build-screen to show Docker's build log
def return_build_screen
  r = Apache::Request.new
  Apache.errlogger Apache::APLOG_NOTICE, \
    "#{r.uri}, #{r.path_info}, #{r.args}, #{r.protocol}, #{r.the_request}"

  doc_root = "/app/handlers/resources/build-screen/"

  if r.uri =~ /^\/(styles|scripts|images)\//
    r.filename = doc_root + r.uri
  elsif r.uri =~ /^\/build/
    r.reverse_proxy "http://localhost:9001" + r.uri
  else
    r.filename = doc_root + "index.html"
  end

  return Apache::return(Apache::OK)
end

# Create id-file to log git-commit-id and container-id
File.new(ID_FILE, "w") unless FileTest.exist?(ID_FILE)

# Get target name like git-commit-id or branch name from subdomain
# then use `git rev-parse` to get actual commit id
hin = Apache::Headers_in.new
target = hin["Host"].split(".")[0]

# To request and control git repository inside pool, init the api client
# Git repository handler(GitHandler) listens on "http://0.0.0.0:9000"
git_api = WebAPI.new("http://0.0.0.0:9000")

# Initialize preview target git repository via githandler api.
# After requesting to initialize git repository via '/init_repo',
# check if repository doesn't exist because of some error or fail,
# Apache returns Bad request.
res = git_api.get("/init_repo")
if res.code != "200"
  Apache.errlogger(Apache::APLOG_WARNING, "git_api /init_repo returned #{result.code}: #{result.body}")
  Apache::return(Apache::HTTP_BAD_REQUEST)
elsif !FileTest.exist?(APP_REPO_DIR)
  Apache.errlogger(Apache::APLOG_WARNING, "#{APP_REPO_DIR} is not created")
  Apache::return(Apache::HTTP_BAD_REQUEST)
else
  # Resolve actual git commit ref by target name got from subdomain via git
  # handler api
  res = git_api.get("/resolve_git_commit/#{target}")
  target_commit_id = res.body
  Apache.errlogger Apache::APLOG_NOTICE, \
    "target: #{target}, target_commit_id: #{target_commit_id}"
  # There is the target commit in repository or having not been initialized as
  # Git repository, return bad request response
  unless res.code == "200"
    Apache::return(Apache::HTTP_BAD_REQUEST)
  else
    docker_api = WebAPI.new("http://0.0.0.0:9002")

    container_addr = docker_api.get("/containers/#{target_commit_id}").body
    matched_container = JSON.parse(container_addr)

    if matched_container["status"] != "success"
      return_build_screen
    else
      # Forward to container
      r = Apache::Request.new
      r.reverse_proxy "http://#{matched_container["addr"]}" + r.uri
      Apache::return(Apache::OK)
    end
  end
end
