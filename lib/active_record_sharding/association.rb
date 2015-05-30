module ActiveRecordSharding
  module Association
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :define_readers, :shard
      end
    end

    module ClassMethods
      def define_readers_with_shard(mixin, name)
        mixin.class_eval <<-CODE, __FILE__, __LINE__ + 1
          def #{name}(*args)

            if self.class.respond_to? :shard_name
              if self.class.name == self.class.shard_name.to_s.camelize.singularize
                if self.id
                  self.class.sequence_id = self.id
                  if __method__.to_s.classify.constantize.respond_to? :sequence_id
                    __method__.to_s.classify.constantize.sequence_id = self.id
                  end
                end
              end
            end

            association(:#{name}).reader(*args)
          end
        CODE
      end
    end
  end
end
