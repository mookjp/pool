$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'simplecov'

RSpec.configure do |c|
  c.filter_run_excluding :system_test => true
end

SimpleCov.start do
  add_filter '../spec'
  add_filter '../vendor'
end
