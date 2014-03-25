module DEVS
  module Examples
    module Sampling
      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)
        DEVS.logger.level = Logger::INFO

        DEVS.simulate(formalism) do
          duration 10

          add_model DEVS::Models::Generators::SinusGenerator, with_args: [0.5, 0.5, 0.0, 100, 2], :name => :generator

          add_model do
            name :sampling

            init do
              add_input_port :input
              add_output_port :output

              @duration = 0.04
              @state = :passive
              @sigma = DEVS::INFINITY
            end

            external_transition do |messages|
              messages.each do |message|
                @sampling = message.payload
              end

              case @state
              when :passive
                @sigma = @duration
                @state = :respond
              when :respond
                @sigma -= self.elapsed
              when :conflict
                @sigma = 0
              end
            end

            internal_transition do
              @sigma = DEVS::INFINITY
              @state = :passive
            end

            confluent_transition do |messages|
              internal_transition
              @state = :conflict
              external_transition(messages)
            end

            output do
              post @sampling, :output
            end

            time_advance do
              case @state
              when :passive
                DEVS::INFINITY
              when :respond
                @sigma
              when :conflict
                0
              end
            end
          end

          add_coupled_model do
            name :collector

            add_model DEVS::Models::Collectors::PlotCollector, with_args: [style: 'data lines', ylabel: 'x'], :name => :plot
            add_model DEVS::Models::Collectors::DatasetCollector, :name => :dataset

            plug_input_port :sinus, with_children: ['dataset@sinus', 'plot@sinus']
            plug_input_port :sampled, with_children: ['dataset@sampled', 'plot@sampled']
          end

          plug 'generator@output', with: 'sampling@input'
          plug 'generator@output', with: 'collector@sinus'
          plug 'sampling@output', with: 'collector@sampled'
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
  DEVS::Examples::Sampling.run
end
