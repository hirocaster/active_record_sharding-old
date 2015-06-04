namespace :sharding do
  namespace :db do
    desc "Create sharding databases."
    task :create do
      database_configuration = YAML.load_file('config/database.yml')
      ActiveRecordSharding::Config.shards.each do |shard_set|
        shard_set[1].each do |shard_db_name|
          ActiveRecord::Tasks::MySQLDatabaseTasks.new(database_configuration[shard_db_name]).create
        end
      end
    end
    desc "Drop sharding databases."
    task :drop do
      database_configuration = YAML.load_file('config/database.yml')
      ActiveRecordSharding::Config.shards.each do |shard_set|
        shard_set[1].each do |shard_db_name|
          ActiveRecord::Tasks::MySQLDatabaseTasks.new(database_configuration[shard_db_name]).drop
        end
      end
    end

    desc "Migrate for sharding databases. ex) migrate[shard_name]"
    task :migrate, "shard_name"
    task :migrate do |task, args|

      raise "Please, set shard_name args." unless args[:shard_name]

      shard_name = args[:shard_name]
      shard_node_count = ActiveRecordSharding::Config.shard_count shard_name
      (1..shard_node_count).each do |shard_node_number|
        sh "bundle exec ridgepole -c db/ridgepole/#{shard_name}_shard/#{shard_name}_shard_#{shard_node_number}.yml -f db/ridgepole/#{shard_name}_shard/Schemafile --apply -E #{Rails.env}"
      end
    end

    namespace :migrate do
      desc "Migrate dry-run for sharding databases. ex) dry_run[shard_name]"
      task :dry_run, "shard_name"
      task :dry_run do |task, args|

        raise "Please, set shard_name args." unless args[:shard_name]

        shard_name = args[:shard_name]
        shard_node_count = ActiveRecordSharding::Config.shard_count shard_name
        (1..shard_node_count).each do |shard_node_number|
          sh "bundle exec ridgepole -c db/ridgepole/#{shard_name}_shard/#{shard_name}_shard_#{shard_node_number}.yml -f db/ridgepole/#{shard_name}_shard/Schemafile --apply --dry-run -E #{Rails.env}"
        end
      end
    end
  end
end
