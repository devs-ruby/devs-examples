module DEVS
  module Examples
    module Curves
      def run(formalism=:pdevs)
        DEVS.logger = Logger.new(STDOUT)
        DEVS.logger.level = Logger::INFO

        DEVS.simulate(formalism) do
          duration DEVS::INFINITY

          add_model DEVS::Models::Generators::SequenceGenerator, with_args: [1, 20, 1], :name => :sequence

          add_model do
            name 'curves'
            # reverse_confluent_transition!

            init do
              add_output_port :logarithmic, :linear, :linearithmic, :quadratic, :cubic, :exponential
              add_input_port :input
            end

            when_input_received do |messages|
              messages.each do |message|
                value = message.payload
                unless value.nil?
                  @x = value
                  @sigma = 0
                end
              end
            end

            output do
              x = @x

              if x
                post Math.log2(x), :logarithmic
                post x, :linear
                post x * Math.log2(x), :linearithmic
                post x ** 2, :quadratic
                post x ** 3, :cubic
                post 2 ** x, :exponential
              end
            end

            after_output { @sigma = DEVS::INFINITY }
          end

          add_coupled_model do
            name :collector

            add_model DEVS::Models::Collectors::PlotCollector, :name => :plot, with_args: [ylabel: 'f(x)']
            add_model DEVS::Models::Collectors::DatasetCollector, :name => :dataset, with_args: [interleaved: false]

            plug_input_port :a, with_children: ['dataset@logarithmic', 'plot@logarithmic']
            plug_input_port :b, with_children: ['dataset@linear', 'plot@linear']
            plug_input_port :c, with_children: ['dataset@linearithmic', 'plot@linearithmic']
            plug_input_port :d, with_children: ['dataset@quadratic', 'plot@quadratic']
            plug_input_port :e, with_children: ['dataset@cubic', 'plot@cubic']
            plug_input_port :f, with_children: ['dataset@exponential', 'plot@exponential']
          end

          plug 'sequence@value', with: 'curves@input'

          plug 'curves@logarithmic', with: 'collector@a'
          plug 'curves@linear', with: 'collector@b'
          plug 'curves@linearithmic', with: 'collector@c'
          plug 'curves@quadratic', with: 'collector@d'
          plug 'curves@cubic', with: 'collector@e'
          plug 'curves@exponential', with: 'collector@f'
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
  DEVS::Examples::Curves.run(:pdevs)
end
