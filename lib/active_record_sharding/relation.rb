module ActiveRecordSharding
  module Relation
    extend ActiveSupport::Concern

    included do
      class << self
        # alias_method_chain :where, :shard
      end
    end

    def where(opts = :chain, *rest)
      if shard_name && (opts.class == Hash)
        if shard_belongs
        else
          if opts.has_key?(:id)
            self.sequence_id = opts[:id]
          end
        end
      end

      if opts == :chain
        WhereChain.new(spawn)
      elsif opts.blank?
        self
      else
        spawn.where!(opts, *rest)
      end
    end

    module ClassMethods
    end
  end
end
