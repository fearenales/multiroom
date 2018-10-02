module Multiroom
  module Helpers
    class Logger
      LEVELS = { warn: 0, info: 1, debug: 2 }

      @@level = :info

      def self.level
        @@level
      end

      def self.level=(level)
        level = LEVELS.keys[level] if level.is_a?(Integer)
        @@level = level.to_sym
      end

      def initialize(tag = "")
        @tag = tag
      end

      LEVELS.keys.each do |level|
        define_method(level) do |message|
          log(message) if LEVELS[self.class.level] >= LEVELS[level]
        end
      end

      def tag
        @tag.upcase
      end

      def log(message)
        puts("[#{tag}] #{message}")
      end
    end
  end
end
