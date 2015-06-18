require 'singleton'
require 'active_record_sharding/proxy'
require 'active_record_sharding/config'

module ActiveRecordSharding
  class ProxyRepository
    include Singleton

    def self.checkout(name, id)
      instance.checkout(name, id)
    end

    def checkout(name, id)
      id = 0 unless id
      key_id = id.modulo(Config.shard_count(name))
      proxies["#{name}_#{key_id}"] ||= Proxy.new(name, key_id)
    end

    # def self.find(name)
    #   instance.find(name)
    # end

    # def find(name)
    #   proxies.fetch(name)
    # end

    def proxies
      @proxies ||= {}
    end
  end
end
