$LOAD_PATH.unshift File.expand_path('../', __FILE__)
require 'spec_helper'

require 'builder'
require 'builder/builder_log_device'
require 'em-websocket'
require 'fileutils'
require 'pry'

describe '.new' do

    before(:each) do
        @base_fixture_dir_path = File.expand_path('../../fixtures', __FILE__)
        @output_dir_path = File.expand_path('../../tmp', __FILE__)
        Dir.mkdir(@output_dir_path) if not FileTest.exist?(@output_dir_path)
    end

    after(:each) do
        FileUtils.rm_rf(@output_dir_path) if FileTest.exist?(@output_dir_path)
    end

    it 'has a version number' do
        expect(Builder::VERSION).not_to be nil
    end

    it 'initializes builder' do
        fixture_dir = File.join(@base_fixture_dir_path, 'app01')

        # create repository file
        fixture_repository_file_path =
            File.expand_path('preview_target_repository', fixture_dir)
        tmp_repository_file_path =
            File.expand_path('preview_target_repository', @output_dir_path)
        File.copy_stream(fixture_repository_file_path, tmp_repository_file_path)

        # create WebSocket mock
        mock_ws = Object.new
        allow(mock_ws).to receive(:nil?) {false}

        log_file = File.expand_path('log_file', @output_dir_path)
        logger = Logger.new(Builder::BuilderLogDevice.new(mock_ws, log_file))

        # execute
        b = Builder::Builder.new('master', logger, @output_dir_path)

    end
end
