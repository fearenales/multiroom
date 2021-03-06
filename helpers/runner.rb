require_relative './logger'

module Multiroom
  module Helpers
    class Runner
      def self.run(command)
        logger.debug(command)
        result = `#{command}`.chomp
        logger.debug("#=> #{result}")
        result
      end

      def self.spawn(command)
        logger.debug(command)
        Process.spawn(command)
      end

      private_class_method

      def self.logger
        @@logger ||= Logger.new('runner')
      end
    end
  end
end
