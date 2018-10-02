require_relative './logger'
require_relative './runner'

module Multiroom
  module Helpers
    class Bluetooth
      def self.connect(controller, device)
        power(controller, :on) unless powered_on?(controller)
        scan(controller) unless aware?(controller, device)
        pair(controller, device) unless paired?(controller, device)
        do_connect(controller, device) unless connected?(controller, device)
      end

      def self.disconnect(controller, device)
        power(controller, :on) unless powered_on?(controller)
        do_disconnect(controller, device)
      end

      def self.trust(controller, device)
        run("select #{controller}", "trust #{device}")
      end

      def self.restart(controller)
        power(controller, :off)
        power(controller, :on)
      end

      def self.power(controller, state)
        run("select #{controller}", "power #{state}")
        sleep 3
      end

      def self.scan(controller)
        run("select #{controller}", "scan on")
        sleep 20
        run("select #{controller}", "scan off")
      end

      def self.pair(controller, device)
        run("select #{controller}", "pair #{device}")
        sleep 3
      end

      def self.powered_on?(controller)
        check_setting("echo -e 'select #{controller}\nshow' | bluetoothctl | grep Powered | sed 's/.*: //'")
      end

      def self.paired?(controller, device)
        check_setting("echo -e 'select #{controller}\ninfo #{device}' | bluetoothctl | grep Paired | sed 's/.*: //'")
      end

      def self.trusted?(controller, device)
        check_setting("echo -e 'select #{controller}\ninfo #{device}' | bluetoothctl | grep Trusted | sed 's/.*: //'")
      end

      def self.connected?(controller, device)
        check_setting("echo -e 'select #{controller}\ninfo #{device}' | bluetoothctl | grep Connected | sed 's/.*: //'")
      end

      def self.aware?(controller, device)
        result = Runner.run("echo -e 'select #{controller}\ninfo #{device}' | bluetoothctl")
        return false if result =~ /not available/
        true
      end

      def self.reset
        logger.info('Restarting bluetooth service')
        Runner.run("sudo systemctl restart bluetooth")
      end

      private_class_method

      def self.do_connect(controller, device)
        run("select #{controller}", "connect #{device}")
        sleep 5
      end

      def self.do_disconnect(controller, device)
        run("select #{controller}", "disconnect #{device}")
        sleep 5
      end

      def self.check_setting(command)
        return true if Runner.run(command) == 'yes'
        false
      end

      def self.run(*commands)
        Runner.run('rfkill unblock bluetooth')
        command_sequence = command_sequence(commands)
        Runner.run("echo -e \"#{command_sequence}\" | bluetoothctl")
      end

      def self.command_sequence(commands)
        [commands].flatten.join("\n")
      end

      def self.logger
        @@logger ||= Logger.new('bluetooth')
      end
    end
  end
end
