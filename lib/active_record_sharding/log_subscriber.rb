module ActiveRecordSharding
  module LogSubscriber
    extend ActiveSupport::Concern

    included do
      alias_method_chain :sql, :shard
      MAGENTA = "\e[35m"
      CYAN    = "\e[36m"
    end

    def sql_with_shard(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload

      return if ActiveRecord::LogSubscriber::IGNORE_PAYLOAD_NAMES.include?(payload[:name])

      name  = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      sql   = payload[:sql]
      binds = nil
      database = payload[:database]

      unless (payload[:binds] || []).empty?
        binds = "  " + payload[:binds].map { |col,v|
          render_bind(col, v)
        }.inspect
      end

      if odd?
        name = color(name, CYAN, true)
        database = color(database, CYAN, true)
        sql  = color(sql, nil, true)
      else
        name = color(name, MAGENTA, true)
        database = color(database, MAGENTA, true)
      end

      debug "  #{name} #{database}  #{sql}#{binds}"
    end
  end
end
