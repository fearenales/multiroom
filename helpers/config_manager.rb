require 'yaml'
require_relative './logger'
require_relative './runner'

module Multiroom
  module Helpers
    class ConfigManager

      HOME = ENV.fetch('HOME')
      CONFIG_DIR = "#{HOME}/.multiroom"
      CONFIG_FILE = "#{HOME}/.multiroom/config"

      def self.add_room(config)
        self.config[:multiroom] << config
      end

      def self.add_user(user)
        self.config[:users] << user
      end

      def self.dump_config
        Runner.run("mkdir -p #{CONFIG_DIR}") unless File.directory?(CONFIG_DIR)
        File.open(CONFIG_FILE, 'w') do |f|
          f.write(YAML.dump(@@config))
        end
      end

      def self.load_config
        if !File.exists?(CONFIG_FILE)
          logger.warn("Run `multiroom init' to setup")
          exit 1
        end
        @@config = YAML.load_file(CONFIG_FILE)
      end

      def self.config_for_room(room)
        self.config[:multiroom].detect do |cfg|
          cfg[:room] == room
        end
      end

      def self.rooms
        self.config[:multiroom].map do |cfg|
          cfg[:room]
        end
      end

      def self.devices
        self.config[:multiroom].map do |cfg|
          cfg[:device]
        end
      end

      def self.users
        self.config[:users]
      end

      private_class_method

      def self.config
        @@config ||= default_config
      end

      def self.default_config
        { multiroom: [], users: [] }
      end

      def self.logger
        @@logger ||= Logger.new('configmanager')
      end
    end
  end
end
