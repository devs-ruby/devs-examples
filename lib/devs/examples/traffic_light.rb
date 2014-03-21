if __FILE__ == $0
  require 'devs'
  require 'devs/models'
  begin
    require 'devs/ext'
  rescue LoadError
  end
end

module DEVS
  module Examples
    module TrafficLight
      class TrafficLightModel < DEVS::AtomicModel
        def initialize
          super()
          add_input_port :interrupt
          add_output_port :observed
          @state = :red
        end

        def external_transition(messages)
          messages.each do |message|
            payload, port = *message
            if port.name == :interrupt
              case payload
              when :to_manual
                @state = :manual if [:red, :green, :orange].include?(@state)
              when :to_autonomous
                @state = :red if @state == :manual
              end
            end
          end
        end

        def internal_transition
          @state = case @state
          when :red then :green
          when :green then :orange
          when :orange then :red
          end
        end

        def output
          observed = case @state
          when :red, :orange then :grey
          when :green then :orange
          end
          post observed, :observed
        end

        def time_advance
          case @state
          when :red then 60
          when :green then 50
          when :orange then 10
          when :manual then DEVS::INFINITY
          end
        end
      end

      class PolicemanModel < DEVS::AtomicModel
        def initialize
          super()
          add_output_port :output
          @state = :idle
        end

        def internal_transition
          @state = case @state
          when :idle then :working
          when :working then :idle
          end
        end

        def output
          mode = case @state
          when :idle then :to_manual
          when :working then :to_autonomous
          end
          post mode, :output
        end

        def time_advance
          case @state
          when :idle then 200
          when :working then 100
          end
        end
      end

      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)
        DEVS.logger.level = Logger::INFO
        DEVS.simulate(formalism) do
          duration 1000

          add_model TrafficLightModel, name: :traffic_light
          add_model PolicemanModel, name: :policeman

          plug 'policeman@output', with: 'traffic_light@interrupt'
        end
      end
      module_function :run
    end
  end
end

if __FILE__ == $0
  DEVS::Examples::TrafficLight.run
end
