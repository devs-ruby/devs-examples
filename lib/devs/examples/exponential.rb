module DEVS
  module Examples
    module Exponential
      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)
        DEVS.logger.level = Logger::INFO

        DEVS.simulate(formalism) do
          duration DEVS::INFINITY

          add_model DEVS::Models::Generators::SequenceGenerator, with_args: [1, 20, 1], :name => :sequence

          add_model do
            name '2^x'
            # reverse_confluent_transition!

            init do
              add_output_port :out_1
              add_input_port :in_1
            end

            when_input_received do |messages|
              messages.each do |message|
                value = message.payload
                @result = 2 ** value
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
            add_model DEVS::Models::Collectors::DatasetCollector, :name => :dataset

            plug_input_port :a, with_children: ['dataset@x', 'plot@x']
            plug_input_port :b, with_children: ['dataset@2^x', 'plot@2^x']
          end

          plug 'sequence@value', with: '2^x@in_1'
          plug 'sequence@value', with: 'collector@a'
          plug '2^x@out_1', with: 'collector@b'
        end
      end
      module_function :run
    end
  end
end

if __FILE__ == $0
  require 'devs'
  require 'devs/models'
  begin
    require 'devs/ext'
  rescue LoadError
  end
  DEVS::Examples::Exponential.run
end
