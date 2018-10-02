require 'optparse'
require 'ostruct'
require_relative '../helpers/logger'
require_relative '../helpers/spotify'
require_relative '../helpers/config_manager'

module Multiroom
  module Commands
    class Spotify

      ALL_ROOMS = 'Home'

      def self.call
        load_config
        parse_options
        set_logger
        users.each do |user|
          selected_rooms.each do |room|
            perform(user, room)
          end
        end
      end

      private_class_method
      def self.selected_rooms
        return ARGV unless ARGV.empty?
        Multiroom::Helpers::ConfigManager.rooms + [ALL_ROOMS]
      end

      def self.perform(user, room)
        stop(user, room) if stop?
        start(user, room) if start?
        status(user, room) if status?
      end

      def self.start(user, room)
        device = config(room) ? config(room)[:device] : nil
        sink = Multiroom::Helpers::Pulseaudio.sink_name(device)
        source = Multiroom::Helpers::Pulseaudio.source_name(device)
        Multiroom::Helpers::Spotify.start(user, room, sink, source)
      end

      def self.stop(user, room)
        Multiroom::Helpers::Spotify.stop(user, room)
      end

      def self.status(user, room)
        running = Multiroom::Helpers::Spotify.running?(user, room)
        status = running ? 'running' : 'stopped'
        puts "Spotify for #{user} at #{room}: #{status}"
      end

      def self.users
        return Multiroom::Helpers::ConfigManager.users if @@options.user.nil?
        [@@options.user]
      end

      def self.start?
        @@options.start == true
      end

      def self.stop?
        @@options.stop == true
      end

      def self.status?
        @@options.status == true
      end

      def self.config(room)
        Multiroom::Helpers::ConfigManager.config_for_room(room)
      end

      def self.load_config
        Multiroom::Helpers::ConfigManager.load_config
      end

      def self.set_logger
        Multiroom::Helpers::Logger.level = @@options.log_level || 0
      end

      def self.logger
        @@logger ||= Multiroom::Helpers::Logger.new('spotify')
      end

      def self.parse_options
        @@options = OpenStruct.new.tap do |options|
          OptionParser.new do |parser|
            parser.banner = "Usage: multiroom [options]"

            parser.on("-v[LEVEL]", "Run verbosely") do |level|
              options.log_level = level ? level.size : 0
            end
            parser.on("--start", "Start Spotify") do
              options.start = true
              options.stop = false
            end
            parser.on("--stop", "Stop Spotify") do
              options.start = false
              options.stop = true
            end
            parser.on("--restart", "Restart Spotify") do
              options.start = true
              options.stop = true
            end
            parser.on("-u USER", "--user USER", "Select user") do |user|
              options.user = user
            end
            parser.on("-s", "--status", "Spotify status") do
              options.start = false
              options.stop = false
              options.status = true
            end
          end.parse!
        end
      end
    end
  end
end
