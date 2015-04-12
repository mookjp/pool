require 'spec_helper'

require 'builder'
require 'builder/constants'
require 'builder/builder_log_device'
require 'em-spec/rspec'
require 'em-http'
require 'net/http'

describe 'git handler' do
  include EM::SpecHelper
  default_timeout 15

  before(:each) do
    @base_fixture_dir_path = File.expand_path('../../../fixtures', __FILE__)
    @output_dir_path = File.expand_path('../../../tmp', __FILE__)
    Builder::WORK_DIR = @output_dir_path
    Dir.mkdir(@output_dir_path) if not FileTest.exist?(@output_dir_path)
    fixture_dir = File.join(@base_fixture_dir_path, 'app01')

    module Builder
      module Config
        @defaults = {
          :repository_conf  => File.join(WORK_DIR, REPOSITORY_CONF),
          :base_domain_file => File.join(WORK_DIR, 'base_domain'),
          :git_commit_id_cache_expire => File.join(WORK_DIR, 'git_commit_id_cache_expire'),
          :config_yml_path  => File.join(WORK_DIR, '../config', 'config.yml'),
          :id_list_file_path => File.join(WORK_DIR, ID_LIST_FILE_NAME)
        }
      end
    end

    # create repository file
    fixture_repository_file_path =
        File.expand_path('preview_target_repository', fixture_dir)
    tmp_repository_file_path =
        File.expand_path('preview_target_repository', @output_dir_path)
    File.copy_stream(fixture_repository_file_path, tmp_repository_file_path)

    git_commit_id_cache_expire_path = File.join(@output_dir_path, 'git_commit_id_cache_expire')
    File.write(git_commit_id_cache_expire_path, 10)
  end

  after(:each) do
      FileUtils.rm_rf(@output_dir_path) if FileTest.exist?(@output_dir_path)
  end

  it 'init_repo' do
    em {
      EM::start_server("0.0.0.0", 9010, Builder::GitHandler)
      EM.add_timer(1) do 
        request_init_repo
      end
    }
  end

  it 'init_repo called again' do
    em {
      EM::start_server("0.0.0.0", 9010, Builder::GitHandler)
      EM.add_timer(1) do 
        3.times { request_init_repo }
      end
    }
  end

  it 'resolve_commit_id' do
    em {
      EM::start_server("0.0.0.0", 9010, Builder::GitHandler)
      EM.add_timer(1) do 
        http = EM::HttpRequest.new('http://0.0.0.0:9010/init_repo').get :timeout => 10
        http.errback{ fail }
        http.callback do
          EM.add_timer(1) do
            resolve = EM::HttpRequest.new('http://0.0.0.0:9010/resolve_git_commit/master').get :timeout => 10
            resolve.errback{ fail }
            resolve.callback do
              expect(resolve.response.length).to eq(40)
              done
            end
          end
        end
      end
    }
  end

  it 'resolve_commit_id with tag name' do
    em {
      EM::start_server("0.0.0.0", 9010, Builder::GitHandler)
      EM.add_timer(1) do 
        http = EM::HttpRequest.new('http://0.0.0.0:9010/init_repo').get :timeout => 10
        http.errback{ fail }
        http.callback do
          EM.add_timer(1) do
            resolve = EM::HttpRequest.new('http://0.0.0.0:9010/resolve_git_commit/1--0--0').get :timeout => 10
            resolve.errback{ fail }
            resolve.callback do
              expect(resolve.response.length).to eq(40)
              done
            end
          end
        end
      end
    }
  end

  private

  def request_init_repo
    http = EM::HttpRequest.new('http://0.0.0.0:9010/init_repo').get :timeout => 10
    http.errback{ fail }
    http.callback do
      fail unless File.exists?(File.join(Builder::WORK_DIR,
                                         Builder::APP_REPO_DIR_NAME,
                                         'Dockerfile'))
      done
    end
  end
end

