#
#       ActiveFacts Schema Input.
#       Read a FIM file into an ActiveFacts vocabulary
#
# FIM files are in the syntax defined in the ORM Syntax and Semantics glossary,
# https://gitlab.com/orm-syntax-and-semantics/orm-syntax-and-semantics-docs/-/blob/master/ORM%20syntax%20and%20semantics%20glossary%20-%20Public%20BETA%202.pdf
#
# Copyright (c) 2024 Clifford Heath. Read the LICENSE file.
#
require 'activefacts/metamodel'

module ActiveFacts
  module Input
    # Compile a FIM (.fim) file to an ActiveFacts vocabulary.
    # Invoke as
    #   afgen --<generator> <file>.fim
    class FIM

      RESERVED_WORDS = %w{
        and but each each either false if maybe no none not one or some that true where
      }

    private
      def self.readfile(filename, *options)
        if File.basename(filename, '.orm') == "-"
          self.read(STDIN, "<standard input>", options)
        else
          File.open(filename) {|file|
            self.read(file, filename, *options)
          }
        end
      end

      def self.read(file, filename = "stdin", *options)
        FIM.new(file, filename, *options).read
      end 

      def initialize(file, filename = "stdin", *options)
        @file = file
        @filename = filename
        @options = options
      end

    public
      def read          #:nodoc:
        begin
          @document = nil #!!! Nokogiri::XML(@file)
        rescue => e
          puts "Failed to parse FIM in #{@filename}: #{e.inspect}"
        end

      end

    private
    end
  end
end
