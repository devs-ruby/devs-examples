module DEVS
  module Examples
    module Soil
      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)

        DEVS.simulate(formalism) do
          duration 100

          add_coupled_model do
            name :generator
            add_model DEVS::Models::Generators::RandomGenerator, with_args: [0, 5], :name => :random
            plug_output_port :output, :with_child => 'random@output'
          end

          add_model do
            name :soil

            init do
              add_output_port :sponging
              add_output_port :overflow
              add_input_port :input

              @sponging = 0
              @cc = 40.0
              @out_flow = 5.0
              @overflow = 0
            end

            when_input_received do |messages|
              messages.each do |message|
                value = message.payload
                @sponging += value unless value.nil?
              end

              @sponging = [@sponging - (@sponging * (@out_flow / 100)), 0].max

              if @sponging > @cc
                @overflow = @sponging - @cc
                @sponging = @cc
              end

              @sigma = 1
            end

            output do
              post @sponging, :sponging
              post @overflow, :overflow
            end

            after_output do
              @overflow = 0
              @sigma = DEVS::INFINITY
            end

            # if_transition_collides do |*messages|
            #   external_transition *messages
            #   internal_transition
            # end

            time_advance { @sigma }
          end

          add_coupled_model do
            name :collector

            add_model DEVS::Models::Collectors::PlotCollector, :name => :plot
            add_model DEVS::Models::Collectors::CSVCollector, :name => :csv

            plug_input_port :sponging, with_children: ['csv@sponging', 'plot@sponging']
            plug_input_port :overflow, with_children: ['csv@overflow', 'plot@overflow']
          end

          plug 'generator@output', with: 'soil@input'
          plug 'soil@sponging', with: 'collector@sponging'
          plug 'soil@overflow', with: 'collector@overflow'
        end
      end
      module_function :run
    end
  end
end

if __FILE__ == $0
  require 'devs'
  require 'devs/models'
  DEVS::Examples::Soil.run
end
