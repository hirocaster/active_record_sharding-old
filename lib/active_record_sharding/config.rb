require 'singleton'

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
      @config ||= self.load!(self.class.file, self.class.environment)
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

    DEFAULT_PATH = File.dirname(File.dirname(__FILE__))

    def self.file
      @@config_file ||=
        File.join(defined?(::Rails) ?
                    ::Rails.root.to_s : DEFAULT_PATH, 'config/shards.yml')
    end

    def self.file=(filename)
      @@config_file = filename
    end

    def self.load!(config_file = self.file, env = self.environment)
      instance.load!(config_file, env)
    end

    def load!(config_file, env)
      @config = YAML.load(ERB.new(IO.read(config_file)).result).with_indifferent_access[env]
    end
  end
end
