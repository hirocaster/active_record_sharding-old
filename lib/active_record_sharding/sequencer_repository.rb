require 'singleton'
require 'active_record_sharding/sequencer'

module ActiveRecordSharding
  class SequencerRepository
    include Singleton

    def self.checkout(name)
      instance.checkout(name)
    end

    def self.find(name)
      instance.find(name)
    end

    def checkout(name)
      proxies[name] ||= Sequencer.new(name)
    end

    def find(name)
      proxies.fetch(name)
    end

    def proxies
      @proxies ||= {}
    end
  end
end
