require "active_support/lazy_load_hooks"

require "active_record_sharding/version"

module ActiveRecordSharding
  # Your code goes here...
end

ActiveSupport.on_load(:active_record) do
  require "active_record_sharding/model"
  require "active_record_sharding/connection"

  # require 'switch_point/query_cache'

  ActiveRecord::Base.send(:include, ActiveRecordSharding::Model)

  ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
    include ActiveRecordSharding::Connection
    ActiveRecordSharding::Connection::DESTRUCTIVE_METHODS.each do |method_name|
      alias_method_chain method_name, :sharding
    end
  end
end
