module DEVS
  module Examples
    module Storage
      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)
        DEVS.simulate(formalism) do
          duration DEVS::INFINITY

          add_model DEVS::Models::Generators::SequenceGenerator, with_args: [1, 50, 1], :name => :sequence

          add_model do
            name :storage

            init do
              add_input_port :input
              add_output_port :output

              @lag = 5
              @state = :passive
              @sigma = DEVS::INFINITY
            end

            external_transition do |messages|
              case @state
              when :passive
                messages.each do |message|
                  @storage = message.payload
                end
                @sigma = @lag
                @state = :respond
              when :respond
                @sigma = @sigma - self.elapsed
              end
            end

            internal_transition do
              @sigma = @lag
              @state = :passive
            end

            confluent_transition do |messages|
              # ignore external events and executes the internal transition only
              internal_transition
            end

            output do
              post @storage, :output
            end

            time_advance do
              case @state
              when :passive
                DEVS::INFINITY
              when :respond
                @sigma
              end
            end
          end

          add_coupled_model do
            name :collector

            add_model DEVS::Models::Collectors::PlotCollector, with_args: [style: 'data steps', ylabel: 'x'], :name => :plot
            add_model DEVS::Models::Collectors::CSVCollector, :name => :csv

            plug_input_port :original, with_children: ['csv@original', 'plot@original']
            plug_input_port :jetlagged, with_children: ['csv@jetlagged', 'plot@jetlagged']
          end

          plug 'sequence@value', with: 'storage@input'
          plug 'sequence@value', with: 'collector@original'
          plug 'storage@output', with: 'collector@jetlagged'
        end
      end
      module_function :run
    end
  end
end

if __FILE__ == $0
  require 'devs'
  require 'devs/models'
  DEVS::Examples::Storage.run
end
