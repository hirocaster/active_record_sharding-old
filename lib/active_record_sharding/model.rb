require "request_store"

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
          if self.class.sharding? && new_record?
            self.id = self.class.next_sequence_id
            self.class.sequence_id = self.id

            shard_sequence_id = nil
            if self.class.shard_belongs
              shard_sequence_id = self.send(self.class.shard_belongs.to_sym).send("#{self.class.shard_name.to_s}_id")
              unless shard_sequence_id
                raise NotFoundShardKeyError, "Config miss, 'shard_key_object'."
              end
            else
              if self.respond_to? "#{self.class.shard_name.to_s}_id"
                shard_sequence_id = self.send("#{self.class.shard_name.to_s}_id")
                unless shard_sequence_id
                  raise NotFoundShardKeyError, "Please, set #{self.class.shard_name.to_s}_id."
                end
              end
            end

            self.class.sequence_id = shard_sequence_id if shard_sequence_id
          end
        end
      end
    end

    module ClassMethods
      def next_sequence_id
        SequencerRepository.checkout(shard_name, model_name_symbol).next_id if shard_name
      end

      def current_sequence_id
        SequencerRepository.checkout(shard_name, model_name_symbol).current_id if shard_name
      end

      def model_name_symbol
        self.name.downcase.to_sym
      end

      def sharding_proxy
        if self.sharding?
          ProxyRepository.checkout(shard_name, sequence_id)
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
        class_attribute :shard_name
        self.shard_name = name
      end

      def sharding?
        self.try(:shard_name) ? true : false
      end

      def shard_key_object(name)
        @shard_key_object = name
      end

      def shard_belongs
        @shard_key_object
      end

      def sequence_id
        RequestStore.store["#{shard_name}_sequence_id"] || nil
      end

      def sequence_id=(new_record_id)
        RequestStore.store["#{shard_name}_sequence_id"] = new_record_id
      end
    end
  end
end
