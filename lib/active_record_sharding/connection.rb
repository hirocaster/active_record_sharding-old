module ActiveRecordSharding
  module Connection

    DESTRUCTIVE_METHODS = [:insert, :update, :delete]

    DESTRUCTIVE_METHODS.each do |method_name|
      define_method(:"#{method_name}_with_sharding") do |*args, &block|
        # self.establish_connection(:shard_1)
        parent_method = :"#{method_name}_without_sharding"
        Connection.handle_generated_connection(self, parent_method, method_name, *args, &block)
      end
    end

    def self.handle_generated_connection(conn, parent_method, method_name, *args, &block)
      # ここでconnection切り替え

      conn.send(parent_method, *args, &block)
    end
  end
end
