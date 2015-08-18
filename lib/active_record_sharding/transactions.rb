module ActiveRecordSharding
  module Transactions
    extend ActiveSupport::Concern

    included do
      class << self
      end
    end

    module ClassMethods
      def transaction_next_shard(options = {}, &block)
        if sharding?
          self.sequence_id = current_sequence_id + 1
          connection.transaction options, &block
        else
          transaction options, &block
        end
      end

      def transaction_for_shard(shard_key, options = {}, &block)
        return unless sharding?
        self.sequence_id = shard_key
        connection.transaction(options, &block)
      end
    end
  end
end
