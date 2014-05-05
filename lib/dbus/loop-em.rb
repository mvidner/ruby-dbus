require 'eventmachine'

module DBus
  module Loop
    module EventMachine
      class Reader < ::EventMachine::Connection
        def initialize(parent)
          @parent = parent
        end

        def notify_readable
          @parent.dispatch_message_queue
        rescue EOFError
          detach
        end
      end
    end
  end
end