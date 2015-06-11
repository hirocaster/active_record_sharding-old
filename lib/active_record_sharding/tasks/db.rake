namespace :sharding do
  namespace :sequence do
    desc "Create for sequencer databases. ex) create[shard_name, sequence_model_name]"
    task :create, "shard_name", "sequence_model_name"
    task :create do |_task, args|
      valid_args(args)
      db_config = sequence_db_config(args[:shard_name], args[:sequence_model_name])
      ActiveRecord::Tasks::MySQLDatabaseTasks.new(db_config).create
      puts "Success create #{args[:sequence_model_name]} sequence db in #{args[:shard_name]} shard"
    end

    desc "Drop for sequencer databases. ex) drop[shard_name, sequence_model_name]"
    task :drop, "shard_name", "sequence_model_name"
    task :drop do |_task, args|
      valid_args(args)
      db_config = sequence_db_config(args[:shard_name], args[:sequence_model_name])
      ActiveRecord::Tasks::MySQLDatabaseTasks.new(db_config).drop
      puts "Success drop #{args[:sequence_model_name]} sequence db in #{args[:shard_name]} shard"
    end

    def valid_args(args)
      raise "Please, set shard_name args." unless args[:shard_name]
      raise "Please, set sequence_model_name." unless args[:sequence_model_name]
    end

    def sequence_db_config(shard_name, model_name)
      database_configuration = YAML.load_file('config/database.yml')
      db_connection_name = "#{shard_name}_#{model_name}_sequence_#{Rails.env}"

      unless database_configuration[db_connection_name]
        raise "Notfound database config #{db_connection_name} in database.yml"
      end

      database_configuration[db_connection_name]
    end

    desc "Migrate for sequence databases. ex) migrate[shard_name, sequence_model_name]"
    task :migrate, "shard_name", "sequence_model_name"
    task :migrate do |_task, args|
      valid_args(args)

      shard_name = args[:shard_name]
      sequence_model_name = args[:sequence_model_name]
      dir_path = "db/ridgepole/#{shard_name}_shard/#{sequence_model_name}_sequence"

      sh "bundle exec ridgepole -c #{dir_path}/config.yml -f #{dir_path}/Schemafile --apply -E #{Rails.env}"
    end
  end

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
    task :migrate do |_task, args|
      raise "Please, set shard_name args." unless args[:shard_name]

      shard_name = args[:shard_name]
      shard_node_count = ActiveRecordSharding::Config.shard_count shard_name
      (1..shard_node_count).each do |shard_node_number|
        sh "bundle exec ridgepole -c db/ridgepole/#{shard_name}_shard/shards/#{shard_name}_shard_#{shard_node_number}.yml -f db/ridgepole/#{shard_name}_shard/shards/Schemafile --apply -E #{Rails.env}"
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
          sh "bundle exec ridgepole -c db/ridgepole/#{shard_name}_shard/shards/#{shard_name}_shard_#{shard_node_number}.yml -f db/ridgepole/#{shard_name}_shard/shards/Schemafile --apply --dry-run -E #{Rails.env}"
        end
      end
    end
  end
end
