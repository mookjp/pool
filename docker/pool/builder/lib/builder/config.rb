require 'builder/constants'
require 'erb'
require 'yaml'

module Builder
  module Config

    @defaults = {
      :repository_conf  => File.join(WORK_DIR, REPOSITORY_CONF),
      :base_domain_file => File.join(WORK_DIR, 'base_domain'),
      :config_yml_path  => File.join(WORK_DIR, '../config', 'config.yml'),
    }

    module_function 

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

  end
end
