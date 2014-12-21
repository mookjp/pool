require 'rspec/json_matcher'
require 'infrataster/rspec'
require 'serverspec'

RSpec.configuration.include RSpec::JsonMatcher

Infrataster::Server.define(
  :pool_proxy,           # name
  '127.0.0.1', 
)

set :backend, :exec
