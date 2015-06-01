require 'singleton'
require 'active_record_sharding/sequencer'

module ActiveRecordSharding
  class SequencerRepository
    include Singleton

    def self.checkout(name, model)
      instance.checkout(name, model)
    end

    def checkout(name, model)
      sequencers["#{name}_#{model}"] ||= Sequencer.new(name, model)
    end

    # def self.find(name)
    #   instance.find(name)
    # end

    # def find(name)
    #   proxies.fetch(name)
    # end

    def sequencers
      @sequencers ||= {}
    end
  end
end
