module ActiveRecordSharding
  class Proxy
    def initialize(name, id)
      @current_name = name
      @id = id
      define_model(name, id)
    end

    def define_model(name, id)
      if model_name
        model = Class.new(ActiveRecord::Base)
        Proxy.const_set(key(model_name, id), model)
        model.establish_connection shard_connection_name(id)
        model
      else
        Class.new(ActiveRecord::Base)
      end
    end

    def key(model_name, id)
      "#{model_name}_#{shard_key(id)}"
    end

    def shard_connection_name(id)
      Config.shard_connection_names(@current_name)[shard_key(id)]
    end

    def shard_key(id)
      id.modulo(shard_count)
    end

    def shard_count
      Config.shard_count(@current_name)
    end

    def model_for_connection
      ProxyRepository.checkout(@current_name, @id)
      if model_name
        Proxy.const_get(key(model_name, @id))
      else
        ActiveRecord::Base
      end
    end

    def model_name
      @current_name.to_s.camelize.singularize
    end

    def models
      @models ||= {}
    end

    def connection
      model_for_connection.connection
    end

    def connected?
      model_for_connection.connected?
    end
  end
end
