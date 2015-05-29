module ActiveRecordSharding
  module Core
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :find, :shard
        alias_method_chain :find_by, :shard
      end

    end

    module ClassMethods
      def find_with_shard(*ids)
        if ids.size == 1 && ids.first.is_a?(Fixnum)
          if @shard_name
            self.sequence_id = ids.first
          end
        end
        find_without_shard(*ids)
      end

      def find_by_with_shard(*args)
        if args.size == 1 && args.first.is_a?(Fixnum)
          if @shard_name
            self.sequence_id = args.first
          end
        end
        find_by_without_shard(*ids)
      end
    end
  end
end
