require "active_record_sharding/proxy_repository"
require "active_record_sharding/sequencer_repository"

module ActiveRecordSharding
  module Model

    def self.included(model)
      model.singleton_class.class_eval do
        include ClassMethods
        alias_method_chain :connection, :sharding
        # alias_method_chain :cache, :switch_point
        # alias_method_chain :uncached, :switch_point
      end

      model.class_eval do
        before_create :set_sequence_id_for_primary_key

        private

        def set_sequence_id_for_primary_key
          self.id = self.class.next_sequence_id
        end
      end
    end

    module ClassMethods

      def next_sequence_id
        SequencerRepository.checkout(@shard_name).next_id if @shard_name
      end

      def current_sequence_id
        SequencerRepository.checkout(@shard_name).current_id if @shard_name
      end

      def sharding_proxy
        if @shard_name
          ProxyRepository.checkout(@shard_name, current_sequence_id)
        elsif self == ActiveRecord::Base
          nil
        else
          superclass.sharding_proxy
        end
      end

      def connection_with_sharding
        if sharding_proxy
          sharding_proxy.connection
        else
          connection_without_sharding
        end
      end

      def use_shard(name)
        @shard_name = name
      end

    end
  end
end
