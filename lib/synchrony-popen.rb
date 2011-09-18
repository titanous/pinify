require 'em-synchrony'

class PopenHandler < EM::Connection
  include EM::Deferrable

  def receive_data(data)
    (@data ||= '') << data
  end

  def unbind
    succeed(@data)
  end
end

module EventMachine
  module Synchrony
    def self.popen(cmd, *args)
      df = nil
      EM.popen(cmd, PopenHandler, *args) { |conn| df = conn }
      EM::Synchrony.sync df
    end
  end
end
