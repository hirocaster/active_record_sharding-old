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
      @shards ||= { :user => [:user_shard_1, :user_shard_2, :user_shard_3] }
    end

    def self.environment
      if defined?(Rails) && Rails.env
        Rails.env
      else
        if ENV['RACK_ENV']
          ENV['RACK_ENV']
        else
          :development
        end
      end
    end
  end
end
