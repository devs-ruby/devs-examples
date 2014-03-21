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
    module Storage
      class Storage < DEVS::AtomicModel
        def initialize(lag = 1.0)
          super()

          add_input_port :input
          add_output_port :output

          @lag = lag
          @state = :passive
          @sigma = DEVS::INFINITY
        end

        def external_transition(messages)
          case @state
          when :passive
            messages.each do |message|
              @storage = message.payload
            end
            @sigma = @lag
            @state = :respond
          when :respond
            @sigma -= self.elapsed
          end
        end

        def internal_transition
          @sigma = @lag
          @state = :passive
        end

        def confluent_transition(messages)
          # ignore external events and executes the internal transition only
          internal_transition
        end

        def output
          post @storage, :output
        end

        def time_advance
          case @state
          when :passive
            DEVS::INFINITY
          when :respond
            @sigma
          end
        end
      end

      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)
        DEVS.logger.level = Logger::INFO
        DEVS.simulate(formalism) do
          duration DEVS::INFINITY

          add_model DEVS::Models::Generators::SequenceGenerator, with_args: [0, 50, 1], name: :generator
          add_model DEVS::Examples::Storage::Storage, with_args: [5 ], name: :storage

          add_coupled_model do
            name :collector

            add_model DEVS::Models::Collectors::PlotCollector, with_args: [style: 'data steps', ylabel: 'x'], :name => :plot
            add_model DEVS::Models::Collectors::CSVCollector, :name => :csv

            plug_input_port :original, with_children: ['csv@original', 'plot@original']
            plug_input_port :jetlagged, with_children: ['csv@jetlagged', 'plot@jetlagged']
          end

          plug 'generator@value', with: 'storage@input'
          plug 'generator@value', with: 'collector@original'
          plug 'storage@output', with: 'collector@jetlagged'
        end
      end
      module_function :run
    end
  end
end

if __FILE__ == $0
  DEVS::Examples::Storage.run
end
