module DEVS
  module Examples
    module X2
      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)
        #DEVS.logger.level = Logger::INFO

        DEVS.simulate(formalism) do
          duration DEVS::INFINITY

          add_model DEVS::Models::Generators::SequenceGenerator, with_args: [1, 20, 1], :name => :sequence

          add_model do
            name 'x^x'
            # reverse_confluent_transition!

            init do
              add_output_port :out_1
              add_input_port :in_1
            end

            when_input_received do |messages|
              messages.each do |message|
                value = message.payload
                @result = value ** value
              end
              @sigma = 0
            end

            output do
              post @result, :out_1
            end

            after_output { @sigma = DEVS::INFINITY }
            # time_advance { @sigma }
          end

          add_coupled_model do
            name :collector

            add_model DEVS::Models::Collectors::PlotCollector, :name => :plot
            add_model DEVS::Models::Collectors::CSVCollector, :name => :csv

            plug_input_port :a, with_children: ['csv@x', 'plot@x']
            plug_input_port :b, with_children: ['csv@x^x', 'plot@x^x']
          end

          plug 'sequence@value', with: 'x^x@in_1'
          plug 'sequence@value', with: 'collector@a'
          plug 'x^x@out_1', with: 'collector@b'
        end
      end
      module_function :run
    end
  end
end

if __FILE__ == $0
  require 'devs'
  require 'devs/models'
  DEVS::Examples::X2.run
end
