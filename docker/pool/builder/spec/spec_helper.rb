$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'simplecov'

RSpec.configure do |c|
  c.filter_run_excluding :system_test => true
end

SimpleCov.start do
  add_filter '../spec'
  add_filter '../vendor'
end

class MockHttpResponse
  def send_event(event_id, message)
    return nil
  end
end

def mock_res
  @mock_res ||= MockHttpResponse.new
end
