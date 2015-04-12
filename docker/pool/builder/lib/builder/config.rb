require 'builder/constants'
require 'erb'
require 'yaml'

module Builder
  module Config

    @defaults = {
      :repository_conf  => File.join(WORK_DIR, REPOSITORY_CONF),
      :base_domain_file => File.join(WORK_DIR, 'base_domain'),
      :git_commit_id_cache_expire => File.join(WORK_DIR, 'git_commit_id_cache_expire'),
      :config_yml_path  => File.join(WORK_DIR, '../config', 'config.yml'),
      :id_list_file_path => File.join(WORK_DIR, ID_LIST_FILE_NAME)
    }

    module_function 

    def defaults
      @defaults
    end

    def read_git_commit_id_cache_expire(git_commit_id_cache_expire = @defaults[:git_commit_id_cache_expire]) 
      File.open(git_commit_id_cache_expire).gets.chomp
    end

    def read_base_domain(base_domain_file = @defaults[:base_domain_file]) 
      File.open(base_domain_file).gets.chomp
    end

    def read_repository_url(repository_conf = @defaults[:repository_conf]) 
      File.open(repository_conf).gets.chomp
    end

    def read_config_yaml(config_yml_path = @defaults[:config_yml_path])
      template = ERB.new(File.new(config_yml_path).read)
      YAML.load(template.result(binding))
    end

    def read_ids(id_list_file_path = @defaults[:id_list_file_path])
      ids = File.open(id_list_file_path, "r").readlines.map{|l| l.chomp.split("/")}
      return ids
    end

  end
end
