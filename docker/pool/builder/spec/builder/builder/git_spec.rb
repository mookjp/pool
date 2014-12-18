$LOAD_PATH.unshift File.expand_path('../', __FILE__)
require 'spec_helper'

require 'builder'
require 'builder/builder_log_device'
require 'em-websocket'
require 'fileutils'

describe '.resolve_commit_id' do
  before(:each) do
    @base_fixture_dir_path = File.expand_path('../../../fixtures/builder/git/resolve_commit_id', __FILE__)
    @output_dir_path = File.expand_path('../../tmp', __FILE__)
    Dir.mkdir(@output_dir_path) if not FileTest.exist?(@output_dir_path)
  end

  after(:each) do
    FileUtils.rm_rf(@output_dir_path) if FileTest.exist?(@output_dir_path)
  end

  # https://github.com/mookjp/flaskapp has branch named as "CAPITAL"
  it 'can be parse ref when the ref whose name includes capital letter and specifier is small letter' do
    branch_name = 'capital'
    expect { init_builder(branch_name) }.not_to raise_error
  end

  it 'throws error when it got branch-name which does not exist' do
    branch_name = 'There-is-no-such-name'
    expect { init_builder(branch_name) }.to raise_error
  end

  it 'interprets -- as branch name' do
    branch_name = "slash--branch--name"
    expect { init_builder(branch_name) }.not_to raise_error
  end

  it 'interprets -- as branch name when it has some symbols' do
    branch_name = "issue-100--my-fix"
    expect { init_builder(branch_name) }.not_to raise_error
  end
end

def init_builder(commit_specifier)
  # create repository file
  # FIXME: Make it not to use repository on github for consistency of tests
  fixture_repository_file_path =
    File.expand_path('preview_target_repository', @base_fixture_dir_path)
  pp fixture_repository_file_path
  tmp_repository_file_path =
    File.expand_path('preview_target_repository', @output_dir_path)
  pp tmp_repository_file_path
  File.copy_stream(fixture_repository_file_path, tmp_repository_file_path)

  # create base_domain file
  fixture_base_domain_file_path =
    File.expand_path('base_domain', @base_fixture_dir_path)
  tmp_base_domain_file_path =
    File.expand_path('base_domain', @output_dir_path)
  File.copy_stream(fixture_base_domain_file_path,
                   tmp_base_domain_file_path)

  # create WebSocket mock
  mock_ws = Object.new
  allow(mock_ws).to receive(:nil?) {false}

  log_file = File.expand_path('log_file', @output_dir_path)
  logger = Logger.new(Builder::BuilderLogDevice.new(mock_ws, log_file))

  # initialize repository
  Builder::Builder.new(mock_ws, commit_specifier, @output_dir_path)
end
