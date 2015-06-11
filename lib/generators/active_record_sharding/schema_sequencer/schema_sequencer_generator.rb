module ActiveRecordSharding
  module Generators
    class SchemaSequencerGenerator < Rails::Generators::Base
      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

      desc "Initial schema generate for sequencer database."
      def create_sequencer_schema_for_ridgepole

        raise "Please, set shard_name args[0]." unless args[0]
        raise "Please, set sequencer_name args[1]." unless args[1]

        shard_name = args[0]
        sequencer_name = args[1]

        config = { shard_name: shard_name,
                   sequencer_name: sequencer_name }

        dir_path = "db/ridgepole/#{shard_name}_shard/#{sequencer_name}_sequence"

        template "config.yml.erb",   "#{dir_path}/config.yml", config
        template "Schemafile.erb",   "#{dir_path}/Schemafile", config
        template "table.schema.erb", "#{dir_path}/#{shard_name}_#{sequencer_name}_sequence.schema", config
      end
    end
  end
end
