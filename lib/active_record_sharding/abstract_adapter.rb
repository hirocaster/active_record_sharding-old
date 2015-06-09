module ActiveRecordSharding
  module AbstractAdapter
    extend ActiveSupport::Concern

    included do
      class << self
      end

      protected

      def log(sql, name = "SQL", binds = [], statement_name = nil)
        @instrumenter.instrument(
          "sql.active_record",
          :sql            => sql,
          :name           => name,
          :connection_id  => object_id,
          :statement_name => statement_name,
          :binds          => binds,
          :database       => @config[:database]
        ) { yield }
      rescue => e
        raise translate_exception_class(e, sql)
      end
    end

    module ClassMethods
    end
  end
end
