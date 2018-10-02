require_relative './logger'
require_relative './runner'

module Multiroom
  module Helpers
    class Spotify
      def self.start(user, room, sink, source)
        return if !running(user, room).empty?
        logger.info("Starting Spotify for user #{user} at room #{room}")
        Runner.run("scripts/spotify #{user} #{room} #{sink} #{source} &")
      end

      def self.stop(user = '*', room = '*')
        container_ids = running(user, room)
        if container_ids.empty?
          logger.info("No Spotify instance to be stopped for user #{user} at room #{room}")
          return
        end
        logger.info("Stopping Spotify for user #{user} at room #{room}")
        Runner.run("docker stop #{container_ids.join(' ')} >/dev/null 2>&1")
      end

      def self.running(user = '*', room = '*')
        Runner.run("docker ps | grep \"spotify-#{user}-#{room}\" | awk '{ print $1 }' | tr '\n' ' '").split(' ')
      end

      def self.running?(user, room)
        running(user, room).any?
      end

      private_class_method

      def self.logger
        @@logger ||= Logger.new('spotify')
      end
    end
  end
end
