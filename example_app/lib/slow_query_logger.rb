class SlowQueryLogger < Arproxy::Base
  def initialize(slow_ms)
    @slow_ms = slow_ms
  end

  def execute(sql, name=nil)
    result = nil
    ms = Benchmark.ms { result = super(sql, name) }
    if ms >= @slow_ms
      Rails.logger.info "Slow(#{ms.to_i}ms): #{sql}"
    end
    result
  end
end

Arproxy.configure do |config|
  config.use SlowQueryLogger, 1000
end
