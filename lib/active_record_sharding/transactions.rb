module ActiveRecordSharding
  module Transactions
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :transaction, :shard
      end
    end

    module ClassMethods
      def transaction_with_shard(options = {}, &block)
        if sharding?
          self.sequence_id = current_sequence_id + 1
          connection.transaction(options, &block)
        else
          transaction_without_shard options, &block
        end
      end
    end
  end
end
