require 'tty-prompt'
require_relative '../helpers/config_manager'

module Multiroom
  module Commands
    class Init
      def self.call
        init_devices
        init_users
        Multiroom::Helpers::ConfigManager.dump_config
      end

      private_class_method

      def self.init_devices
        loop do
          init_device
          break unless next_device?
        end
      end

      def self.init_users
        loop do
          init_user
          break unless next_user?
        end
      end

      def self.init_device
        controller = prompt.ask('Bluetooth controller address:')
        device = prompt.ask('Device address:')
        room = prompt.ask('Room name:')
        Multiroom::Helpers::ConfigManager.add_room(
          { controller: controller, device: device, room: room }
        )
      end

      def self.init_user
        Multiroom::Helpers::ConfigManager.add_user(
          prompt.ask('What\'s the user name?')
        )
      end

      def self.next_device?
        prompt.yes?('Add a new device?')
      end

      def self.next_user?
        prompt.yes?('Add a new user?')
      end

      def self.prompt
        @prompt ||= TTY::Prompt.new
      end

    end
  end
end
