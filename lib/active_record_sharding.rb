require "active_support/lazy_load_hooks"
require "active_support/concern"

require "active_record_sharding/version"
require "active_record_sharding/error"

module ActiveRecordSharding
end

ActiveSupport.on_load(:active_record) do
  require "active_record_sharding/model"
  ActiveRecord::Base.send(:include, ActiveRecordSharding::Model)

  require "active_record_sharding/connection"
  ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
    include ActiveRecordSharding::Connection
    ActiveRecordSharding::Connection::DESTRUCTIVE_METHODS.each do |method_name|
      alias_method_chain method_name, :sharding
    end
  end

  require "active_record_sharding/base"
  ActiveRecord::Base.send(:include, ActiveRecordSharding::Base)

  require "active_record_sharding/association"
  ActiveRecord::Associations::Builder::Association.send(:include, ActiveRecordSharding::Association)


  require "active_record_sharding/abstract_adapter"
  ActiveRecord::ConnectionAdapters::AbstractAdapter.send(:include, ActiveRecordSharding::AbstractAdapter)
end

ActiveSupport.on_load(:rails) do
  ActiveRecordSharding::Config.load!

  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "active_record_sharding/tasks/db.rake"
    end
  end
end
