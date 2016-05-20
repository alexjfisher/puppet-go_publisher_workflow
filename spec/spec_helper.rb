require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'
require 'webmock/rspec'

include RspecPuppetFacts

require 'simplecov'
require 'simplecov-console'

SimpleCov.start do
  add_filter '/spec'
  add_filter '/vendor'
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console
    ]
  )
end

RSpec.configure do |config|
  config.hiera_config = File.expand_path(File.join(__FILE__, '../fixtures/hiera.yaml'))
  config.mock_with :mocha
end
