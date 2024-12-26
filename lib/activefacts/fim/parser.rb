require 'treetop'
require 'activefacts/fim/fim'

require 'debug'

module ActiveFacts
  module FIM
    class Parser < ActiveFacts::FIM::FIMParser
      def initialize filename
      end

      def parse_all(input, &block)
        self.consume_all_input = false
        self.root = :definition
        @asts = []
        @index = 0
        begin
          tree = parse(input, :index => @index)
          unless tree
            # debugger
            raise failure_reason || "not all input was understood" unless @index == input.size
            return @asts
          end
          ast = (tree.respond_to? :ast) ? tree.ast : tree
          if block
            block.call(ast, tree)
          else
            @asts << ast
          end
        end until self.index == @input_length
        @asts
      end

      def compile(text, tag)
        asts = parse_all(text) do |ast, tree|
          pp ast
          trace :parse, "Parsed '#{tree.text_value.gsub(/\s+/,' ').strip}'"
        end
        p asts
        exit
        return true # REVISIT: Should return vocabulary
      end
    end
  end
end
