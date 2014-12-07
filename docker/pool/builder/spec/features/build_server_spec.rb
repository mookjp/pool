require 'spec_helper'

require 'em-websocket'
require 'em-spec/rspec'
require 'em-http'

describe 'Builder', :system_test => true do
  include EM::SpecHelper
  it 'test' do
    expect(true).to eq(true)
  end
end

