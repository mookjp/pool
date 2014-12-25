require 'spec_helper'

require 'em-spec/rspec'
require 'em-eventsource'
require 'builder'
require 'docker'

# This spec is for system test.
# This may only works inside build_server docker container.
# If you execute system test with using this spec, please 
# execute the following command:
# /opt/ruby-2.1.2/bin/bundle exec rspec --tag system_test


describe 'Builder', :system_test => true do
  include EM::SpecHelper
  default_timeout 180

  before(:all) do
    @logger = Logger.new(STDOUT)
    @build_handler_addr = "0.0.0.0"
    @build_handler_port = 9002
    @test_addr = "http://#{@build_handler_addr}:#{@build_handler_port}/build"

    Docker::Container.all.select{|c| c.info["Command"] =~ /flaskapp/}.each{|c| c.kill}
  end

  after(:all) do
    Docker::Container.all.select{|c| c.info["Command"] =~ /flaskapp/}.each{|c| c.kill}
  end

  it 'building master branch' do
   em do
     start_builder
     EM.add_timer(1) do
       conn =  init_lisnter('master')
       conn.error { |msg| @logger.info("#{msg}"); fail }
       conn.on("build_finished") do |msg|
         @logger.info("#{msg}")
         if msg == "FINISHED"
           conn.close
           done
         end
       end
       conn.start
     end
   end
  end

  it 'building CAPITAL branch' do
   em do
     # Actual branch name is "CAPITAL" but HTTP request only supports lower
     # letter so the specifier is "capital"
     start_builder
     EM.add_timer(1) do
       conn =  init_lisnter('capital')
       conn.error { |msg| @logger.info("#{msg}"); fail }
       conn.message {|m| @logger.info(m)}
       conn.on("build_finished") do |msg|
         @logger.info("#{msg}")
         if msg == "FINISHED"
           conn.close
           done
         end
       end
       conn.start
     end
   end
  end

  it 'locking workspace while building image' do
   output = ''
   em do
     start_builder

     EM.add_timer(1) do
       conn =  init_lisnter('master')
       conn.error { |msg| @logger.info("#{msg}"); fail }
       conn.message {|m| @logger.info(m)}
       conn.on "build_finished" do |msg|
         @logger.info("#{msg}")
         if msg == "FINISHED"
           conn.close
           done
         end
       end
       conn.start
     end

     EM.add_timer(2) do
       conn =  init_lisnter('master')
       conn.error { |msg| @logger.info("#{msg}"); fail }
       conn.message {|m| @logger.info(m)}
       conn.on "build_finished" do |msg|
         @logger.info("#{msg}")
         output << msg.data
         if msg.data == "FINISHED"
           conn.close
           expect(output).to match(/Locked!/)
           done
         end
       end
     end
   end
  end

  def start_builder
    EM::start_server(@build_handler_addr, @build_handler_port, Builder::BuildHandler)
  end

  def init_lisnter(git_commit_specifier)
    conn =  EM::EventSource.new("#{@test_addr}/#{git_commit_specifier}")
    conn.inactivity_timeout = 120
    return conn
  end
end
