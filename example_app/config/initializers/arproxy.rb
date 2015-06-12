class QueryTracer < Arproxy::Base
  def execute(sql, name=nil)
    Rails.logger.debug sql
    # Rails.logger.debug caller(1).join("\n")
    super(sql, name)
  end
end

Arproxy.configure do |config|
  config.adapter = "mysql2" # A DB Apdapter name which is used in your database.yml
  config.use QueryTracer
end
Arproxy.enable!
