module ActiveRecordSharding
  module ActiveRecord
    module Core
      extend ActiveSupport::Concern

      included do
        class << self
          alias_method_chain :find, :shard
        end

      end

      module ClassMethods
        def find_with_shard(*ids)
          if ids.size == 1 && ids.first.is_a?(Fixnum)
            if @shard_name
              ProxyRepository.checkout(@shard_name, ids.first)
            end
          end
          find_without_shard(*ids)
          # binding.pry
          # return all.find(ids.first) if ids.size == 1 && ids.first.is_a?(Fixnum)
          # find_without_shard(*ids)
        end
      end
    end
  end
end
