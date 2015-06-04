module ActiveRecordSharding
  module Generators
    class SchemaShardsGenerator < Rails::Generators::Base
      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates/shards'))

      desc "Initial schema generate for shards databases."
      def create_shard_schema_for_ridgepole

        shard_name = args[0]
        shard_node_count = args[1].to_i

        config = { shard_name: shard_name }

        (1..shard_node_count).each do |shard_node_number|
          config.merge!({ shard_node_number: shard_node_number })
          template "config.yml.erb", "db/ridgepole/#{shard_name}_shard/#{shard_name}_shard_#{shard_node_number}.yml", config
        end

        template "Schemafile.erb", "db/ridgepole/#{shard_name}_shard/Schemafile", config
        template "table.schema.erb", "db/ridgepole/#{shard_name}_shard/#{shard_name.pluralize}.schema", config
      end
    end
  end
end
