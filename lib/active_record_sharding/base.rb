module ActiveRecordSharding
  module Base
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :find, :shard
        alias_method_chain :find_by, :shard
        alias_method_chain :exists?, :shard
      end

    end

    module ClassMethods
      def exists_with_shard?(conditions = :none)
        return false if !conditions

        if shard_name
          case conditions
          when Array # User.exists?(['name LIKE ?', "%ali%"])
            result = (1..Config.shards[shard_name].count).map do |id|
              self.sequence_id = id
              exists_without_shard?(conditions)
            end
            result.any?
          when Hash
            if conditions.has_key? :id # User.exists?(id: [1, 2])
              results = conditions[:id].map do |id|
                         self.sequence_id = id
                         exists_without_shard?(id)
              end
              results.all?
            else # User.exists?(name: "alice")
              results = (1..Config.shards[shard_name].count).map do |id|
                self.sequence_id = id
                exists_without_shard?(conditions)
              end.flatten
              results.any?
            end
          when Fixnum # User.exists?(1)
            self.sequence_id = conditions
            exists_without_shard?(conditions)
          when String # User.exists?('1')
            self.sequence_id = conditions.to_i
            exists_without_shard?(conditions)
          end
        else
          exists_without_shard?(conditions)
        end
      end

      def find_with_shard(*ids)
        if ids.size == 1 && ids.first.is_a?(Fixnum) # find(1)
          if shard_name
            self.sequence_id = ids.first
          end
          return find_without_shard(*ids)
        end

        if ids.size == 1 && ids.first.is_a?(Array) # find([1, 2, 3])
          find_ids = ids.first
          if find_ids.size == 1 # find([1])
            if shard_name
              self.sequence_id = find_ids.first
              return find_without_shard(find_ids)
            end
          elsif find_ids.size > 1 # find([1, 2, 3])
            if shard_name

              find_ids.sort!

              shard_count = ActiveRecordSharding::Config.shard_count(shard_name)

              find_record = []
              find_ids.each do |find_id|
                find_record[find_id.modulo(shard_count)] = [] unless find_record[find_id.modulo(shard_count)]
                find_record[find_id.modulo(shard_count)] << find_id
              end

              result = []
              find_record.each_with_index do |value, index|
                next unless value
                self.sequence_id = index
                result << find_without_shard(value)
              end
              return result.flatten
            end
          end
        end

        find_without_shard(*ids)
      end

      def find_by_with_shard(*args)
        if args.size == 1 && args.first.is_a?(Fixnum)
          if shard_name
            self.sequence_id = args.first
          end
        end
        find_by_without_shard(*args)
      end

      def all_shard
        if shard_name

          column_name = "#{shard_name.to_s}_id"

          if all.where_values_hash.has_key? column_name
            if all.where_values_hash[column_name].is_a?(Fixnum)
              self.sequence_id = all.where_values_hash[column_name]
              all
            else
              # multi value
            end
          else
            (1..Config.shards[shard_name].count).map do |id|
              self.sequence_id = id
              all.to_a
            end.flatten.sort
          end
        else
          all
        end
      end
    end
  end
end
