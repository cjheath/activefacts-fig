require 'treetop'
require 'activefacts/fim/fim'

require 'debug'

module ActiveFacts
  module FIM
    class Parser < ActiveFacts::FIM::FIMParser
      def initialize filename
      end

      def parse_all(text, tag)
        self.consume_all_input = false
        @index = 0
        begin
          result = parse(text, :index => @index)
          if !result
            p self.class.superclass.superclass.instance_methods-0.methods
            debugger
          end
        end until @index == @input_length
        exit
        return true # REVISIT: Should return vocabulary
      end
    end
  end
end
