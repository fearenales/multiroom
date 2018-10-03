require 'optparse'
require 'ostruct'
require_relative '../helpers/logger'
require_relative '../helpers/runner'
require_relative '../helpers/bluetooth'
require_relative '../helpers/config_manager'

module Multiroom
  module Commands
    class Bluetooth

      CONNECTION_RETRIES = 3

      def self.call
        load_config
        parse_options
        set_logger
        reset_services
        selected_rooms.each do |room|
          perform(room)
        end
        start_services
      end

      private_class_method

      def self.perform(room)
        status(room)
        disconnect(room)
        connect(room)
      end

      def self.selected_rooms
        return ARGV unless ARGV.empty?
        Multiroom::Helpers::ConfigManager.rooms
      end

      def self.connected_devices
        Multiroom::Helpers::ConfigManager.config[:multiroom].select do |cfg|
          controller, device = cfg.slice(:controller, :device).values
          Multiroom::Helpers::Bluetooth.connected?(controller, device)
        end.map do |cfg|
          cfg[:device]
        end
      end

      def self.reset_services
        return unless reset?
        Multiroom::Helpers::Bluetooth.reset
        Multiroom::Helpers::Pulseaudio.reset
        sleep 5
      end

      def self.start_services
        return if status?
        Multiroom::Helpers::Pulseaudio.setup(connected_devices)
      end

      def self.connect(room)
        return unless connect?
        Multiroom::Helpers::Pulseaudio.unload_combined_module
        logger.info("Trying to connect room #{room}")
        try_connect(room)
      end

      def self.try_connect(room, retry_count = 0)
        return fail_connect(room) if retry_count == CONNECTION_RETRIES
        logger.info("Trying to connect room #{room}. Retry: #{retry_count}")
        controller, device = config(room).slice(:controller, :device).values
        Multiroom::Helpers::Bluetooth.connect(controller, device)
        if !Multiroom::Helpers::Bluetooth.connected?(controller, device)
          return try_connect(room, retry_count + 1)
        end
        trust(controller, device)
      end

      def self.trust(controller, device)
        return if Multiroom::Helpers::Bluetooth.trusted?(controller, device)
        Multiroom::Helpers::Bluetooth.trust(controller, device)
        sleep 5
      end

      def self.fail_connect(room)
        logger.warn("Failed to connect room #{room}")
        false
      end

      def self.disconnect(room)
        return unless disconnect?
        controller, device = config(room).slice(:controller, :device).values
        Multiroom::Helpers::Pulseaudio.unload_combined_module
        Multiroom::Helpers::Bluetooth.disconnect(controller, device)
      end

      def self.status(room)
        return unless status?
        controller, device = config(room).slice(:controller, :device).values
        connected = Multiroom::Helpers::Bluetooth.connected?(controller, device)
        status = connected ? 'connected' : 'disconnected'
        puts "#{room}: #{status}"
      end

      def self.config(room)
        Multiroom::Helpers::ConfigManager.config_for_room(room)
      end

      def self.reset?
        @@options.reset == true
      end

      def self.connect?
        @@options.connect == true
      end

      def self.disconnect?
        @@options.disconnect == true
      end

      def self.status?
        @@options.status == true
      end

      def self.load_config
        Multiroom::Helpers::ConfigManager.load_config
      end

      def self.set_logger
        Multiroom::Helpers::Logger.level = @@options.log_level || 0
      end

      def self.logger
        @@logger ||= Multiroom::Helpers::Logger.new('bluetooth')
      end

      def self.parse_options
        @@options = OpenStruct.new.tap do |options|
          OptionParser.new do |parser|
            parser.banner = "Usage: multiroom [options]"

            parser.on("-v[LEVEL]", "Run verbosely") do |level|
              options.log_level = level ? level.size : 0
            end
            parser.on("-c", "--connect", "Connect controller to device") do
              options.connect = true
              options.status = false
            end
            parser.on("-d", "--disconnect", "Disconnect controller from device") do
              options.disconnect = true
              options.status = false
            end
            parser.on("-r", "--reconnect", "Reconnect controller to device") do
              options.connect = true
              options.disconnect = true
              options.status = false
            end
            parser.on("--reset", "Reset services") do
              options.reset = true
            end
            parser.on("--resync", "Resync bluetooth audio") do
              options.resync = true
            end
            parser.on("-s", "--status", "Bluetooth status") do
              options.connect = false
              options.disconnect = false
              options.status = true
            end
          end.parse!
        end
      end
    end
  end
end
