require_relative './logger'
require_relative './runner'
require_relative './config_manager'

module Multiroom
  module Helpers
    class Pulseaudio

      COMBINED_SINK_NAME = 'combined'

      def self.has_sink?(device)
        result = Runner.run(
          "pactl list sinks | grep #{sink_name(device)}"
        )
        return false if result == ''
        true
      end

      def self.sink_name(device)
        return COMBINED_SINK_NAME if device.nil?
        "bluez_sink.#{device.gsub(':', '_')}.a2dp_sink"
      end

      def self.card_name(device)
        "bluez_card.#{device.gsub(':', '_')}"
      end

      def self.combined_sink_slaves(devices)
        devices.map do |device|
          sink_name(device)
        end.join(',')
      end

      def self.sync_audio_stream(device)
        Runner.run("pactl set-card-profile #{card_name(device)} a2dp_sink")
        Runner.run("pactl set-card-profile #{card_name(device)} off")
        Runner.run("pactl set-card-profile #{card_name(device)} a2dp_sink")
      end

      def self.source_name(device)
        "#{sink_name(device)}.monitor"
      end

      def self.combined_module_id
        Runner.run("pactl list sinks | " \
                   "grep -A 5 'Name: #{COMBINED_SINK_NAME}' | " \
                   "grep 'Owner Module:' | " \
                   "sed 's/.*\: //'")
      end

      def self.setup(devices)
        create_combined_sink(devices)
        create_loopback_module
        devices.each do |device|
          sync_audio_stream(device)
        end
      end

      def self.unload_combined_module
        logger.info("Unloading pulseaudio combined module")
        Runner.run("pactl unload-module #{combined_module_id}") if combined_module_id != ""
      end

      def self.reset
        logger.info("Restarting pulseaudio")
        Runner.run("pulseaudio -k")
      end

      private_class_method

      def self.create_combined_sink(devices)
        result = Runner.run("pactl load-module module-combine-sink sink_name=combined slaves=#{combined_sink_slaves(devices)} 2>&1")
        abort if result =~ /failed/
      end

      def self.create_loopback_module
        Runner.run("pactl load-module module-loopback " \
                   "source=combined " \
                   "sink=alsa_output.pci-0000_00_1b.0.analog-stereo >/dev/null 2>&1")
      end


      def self.logger
        @@logger ||= Logger.new('pulseaudio')
      end
    end
  end
end
