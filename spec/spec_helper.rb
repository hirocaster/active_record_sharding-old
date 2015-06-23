$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_record_sharding'
require "pry"
require "awesome_print"

ENV["RACK_ENV"] ||= "test"

RSpec::Matchers.define :connect_to do |expected|
  database_name = lambda do |model|
    model.connection.pool.spec.config[:database]
  end

  match do |actual|
    database_name.call(actual) == expected
  end

  failure_message do |actual|
    "expected #{actual.name} to connect to #{expected} but connected to #{database_name.call(actual)}"
  end
end
