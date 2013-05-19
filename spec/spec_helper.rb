$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'mongoid'
require 'mongoid_taggable_with_context.rb'

RSpec.configure do |config|
  config.after(:each) do
    Mongoid.purge!
  end
end

Mongoid.configure do |config|
  config.connect_to("mongoid_taggable_with_context_test")
end
