module ActiveRecordSharding
  module Migration
    extend ActiveSupport::Concern

    included do
      class << self
        # alias_method_chain :run, :shard
        # alias_method_chain :migrate, :shard
        # alias_method_chain :up, :shard
        # alias_method_chain :down, :shard
      end
    end

    module ClassMethods

      def use_shard(name)
        @shard_name = name
      end

      def to_sequencer(name)
        @sequencer_name = name

        if @sequencer_name
          SequencerRepository.checkout(@shard_name, @sequencer_name).connection
        end
      end

      # def run_with_shard(*migration_classes)
      #   binding.pry
      #   run_without_shard(*migration_classes)
      # end

      # def migrate_with_shard(direction)
      #   binding.pry
      #   migrate_without_shard(direction)
      # end

      # def up_with_shard
      #   binding.pry
      #   up_without_shard
      # end

      # def down_with_shard
      #   binding.pry
      #   down_without_shard
      # end

      def sequencer_table_name
        "#{@shard_name}_#{@sequencer_name}_sequence"
      end
    end
  end

  module Migrator
    extend ActiveSupport::Concern

    included do
      class << self
        alias_method_chain :migrate, :shard
        alias_method_chain :rollback, :shard
        alias_method_chain :record_version_state_after_migrating_with_shard, :shard
        # alias_method_chain :run, :shard
        # alias_method_chain :up, :shard
        # alias_method_chain :down, :shard

        def run_with_shard(*migration_classes)
          # binding.pry
        end

        def record_version_state_after_migrating(version)
          binding.pry
        end

      end
    end

    module ClassMethods
      # def run_with_shard(*migration_classes)
      #   binding.pry
      #   run_without_shard(*migration_classes)
      # end

      def migrate_with_shard(migrations_paths, target_version = nil, &block)
        migrate_without_shard(migrations_paths, target_version = nil, &block)
      end

      def rollback_with_shard(migrations_paths, steps=1)
        binding.pry
        rollback_without_shard(migrations_paths, steps=1)
      end

      def record_version_state_after_migrating_with_shard(version)
        binding.pry
        record_version_state_after_migrating_without_shard(version)
      end

      # def up(migrations_paths, target_version = nil)
      #   binding.pry
      #   up_without_shard
      # end

      # def down(migrations_paths, target_version = nil, &block)
      #   binding.pry
      #   down_without_shard
      # end

    end
  end
end
