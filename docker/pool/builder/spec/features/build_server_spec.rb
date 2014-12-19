require 'spec_helper'

require 'em-websocket'
require 'em-websocket-client'
require 'em-spec/rspec'
require 'em-http'
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
    Docker::Container.all.select{|c| c.info["Command"] =~ /flaskapp/}.each{|c| c.kill}
  end

  after(:all) do
    Docker::Container.all.select{|c| c.info["Command"] =~ /flaskapp/}.each{|c| c.kill}
  end

  it 'building master branch' do
   em do
     start_builder('master')
     EM.add_timer(1) do
       conn =  EM::WebSocketClient.connect("ws://0.0.0.0:8090/")
       conn.errback { fail }
          conn.stream do |msg|
            @logger.info("#{msg.data}")
            if msg.data == "FINISHED"
              conn.close_connection
              done
            end
          end
     end
   end
  end

  it 'building CAPITAL branch' do
   em do
     # Actual branch name is "CAPITAL" but HTTP request only supports lower
     # letter so the specifier is "capital"
     start_builder('capital')
     EM.add_timer(1) do
       conn =  EM::WebSocketClient.connect("ws://0.0.0.0:8090/")
       conn.errback { fail }
          conn.stream do |msg|
            @logger.info("#{msg.data}")
            if msg.data == "FINISHED"
              conn.close_connection
              done
            end
          end
     end
   end
  end

  it 'locking workspace while building image' do
   output = ''
   em do
     start_builder('master')

     EM.add_timer(1) do
       conn =  EM::WebSocketClient.connect("ws://0.0.0.0:8090/")
       conn.errback { fail }
          conn.stream do |msg|
            @logger.info("#{msg.data}")
            if msg.data == "FINISHED"
              conn.close_connection
              done
            end
          end
     end

     EM.add_timer(2) do
       conn =  EM::WebSocketClient.connect("ws://0.0.0.0:8090/")
       conn.errback { fail }
          conn.stream do |msg|
            @logger.info("#{msg.data}")
            output << msg.data
            if msg.data == "FINISHED"
              conn.close_connection
              expect(output).to match(/Locked!/)
              done
            end
          end
     end
   end
  end

  def start_builder(git_specifier)
    EM::WebSocket.run(:host => '0.0.0.0', :port => 8090) do |ws|
      ws.onopen { |handshake|
        puts 'WebSocket connection open'
        target = git_specifier

        Thread.new(ws) do |ws|
          begin
            builder = Builder::Builder.new(ws, target)
            builder.up
          rescue => ex
            puts "#{ex.class}: #{ex.message}; #{ex.backtrace}"
            ws.send "#{ex.class}: #{ex.message}; #{ex.backtrace}"
          end
        end
      }

      ws.onclose { puts 'Connection closed' }
    end
  end

end
