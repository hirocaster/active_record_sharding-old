module ActiveRecordSharding
  module Generators
    class SchemaSequencerGenerator < Rails::Generators::Base
      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates/sequencer'))

      desc "Initial schema generate for sequencer database."
      def create_sequencer_schema_for_ridgepole

        shard_name = args[0]
        sequencer_name = args[1]

        config = { shard_name: shard_name,
                   sequencer_name: sequencer_name }

        template "config.yml.erb",   "db/ridgepole/#{shard_name}_#{sequencer_name}_sequencer/config.yml", config
        template "Schemafile.erb",   "db/ridgepole/#{shard_name}_#{sequencer_name}_sequencer/Schemafile", config
        template "table.schema.erb", "db/ridgepole/#{shard_name}_#{sequencer_name}_sequencer/#{shard_name}_#{sequencer_name}_sequence.schema", config
      end
    end
  end
end
