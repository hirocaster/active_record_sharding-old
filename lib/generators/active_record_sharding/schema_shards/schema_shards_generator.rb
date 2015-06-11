module ActiveRecordSharding
  module Generators
    class SchemaShardsGenerator < Rails::Generators::Base
      source_root File.expand_path(File.join(File.dirname(__FILE__), 'templates'))

      desc "Initial schema generate for shards databases."
      def create_shard_schema_for_ridgepole

        shard_name = args[0]
        shard_node_count = args[1].to_i

        config = { shard_name: shard_name }

        dir_path = "db/ridgepole/#{shard_name}_shard/shards"

        (1..shard_node_count).each do |shard_node_number|
          config.merge!({ shard_node_number: shard_node_number })
          template "config.yml.erb", "#{dir_path}/#{shard_name}_shard_#{shard_node_number}.yml", config
        end

        template "Schemafile.erb", "#{dir_path}/Schemafile", config
        template "table.schema.erb", "#{dir_path}/#{shard_name.pluralize}.schema", config
      end
    end
  end
end
