require 'memoist'

module ActiveRecordSharding
  class Sequencer
    extend Memoist

    def initialize(shard_name, model)
      @shard_name = shard_name
      @model = model
    end

    def next_id
      conn = ActiveRecord::Base.establish_connection("#{@shard_name}_#{@model}_sequence".to_sym).connection
      quoted_table_name = conn.quote_table_name("#{@shard_name}_#{@model}_sequence")

      # for MySQL
      # conn.execute "UPDATE #{quoted_table_name} SET id=LAST_INSERT_ID(id+1)"
      # res = conn.execute("SELECT LAST_INSERT_ID()")
      # new_id = res.first.first.to_i

      # for sqlite
      conn.execute "UPDATE #{quoted_table_name} SET id=id+1"
      res = conn.execute "SELECT id FROM #{quoted_table_name}"
      new_id = res.first.first.second.to_i

      raise SequenceNotFoundError if new_id.zero?
      flush_cache
      new_id
    end

    def current_id
      # conn = ActiveRecord::Base.establish_connection("#{@shard_name}_sequence".to_sym).connection
      # quoted_table_name = conn.quote_table_name("#{@shard_name}_sequence")
      # conn.execute "UPDATE #{quoted_table_name} SET id=LAST_INSERT_ID(id)"
      # res = conn.execute("SELECT LAST_INSERT_ID()")
      # current_id = res.first.first.to_i
      # current_id

      conn = ActiveRecord::Base.establish_connection("#{@shard_name}_#{@model}_sequence".to_sym).connection
      quoted_table_name = conn.quote_table_name("#{@shard_name}_#{@model}_sequence")
      # for sqlite
      res = conn.execute "SELECT id FROM #{quoted_table_name}"
      current_id = res.first.first.second.to_i
      current_id
    end

    memoize :current_id

    def connection
      ActiveRecord::Base.establish_connection("#{@shard_name}_#{@model}_sequence".to_sym).connection
    end

  end
end
