module ActiveRecordSharding
  class Config
    include Singleton

    def self.shard_count(name)
      instance.shard_count(name)
    end

    def self.shard_connection_names(name)
      instance.shard_connection_names(name)
    end

    def self.shards
      instance.shards
    end

    def shard_count(name)
      shards[name].count
    end

    def shard_connection_names(name)
      shards[name]
    end

    def shards
      if Config.environment == :test
        @shards ||= { :user => [:user_shard_1_test, :user_shard_2_test, :user_shard_3_test] }
      elsif Config.environment == :development
        @shards ||= { :user => [:user_shard_1_development, :user_shard_2_development, :user_shard_3_development] }
      end
    end

    def self.environment
      if defined?(Rails) && Rails.env
        Rails.env
      else
        if ENV['RACK_ENV']
          ENV['RACK_ENV'].to_sym
        else
          :development
        end
      end
    end
  end
end
