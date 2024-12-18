#
#       ActiveFacts Schema Input.
#       Read a FIM file into an ActiveFacts vocabulary
#
# FIM files are in the syntax defined in the ORM Syntax and Semantics glossary,
# https://gitlab.com/orm-syntax-and-semantics/orm-syntax-and-semantics-docs/
#
# Copyright (c) 2024 Clifford Heath. Read the LICENSE file.
#
require 'activefacts/metamodel'
require 'activefacts/fim/parser'

module ActiveFacts
  module Input
    # Compile a FIM (.fim) file to an ActiveFacts vocabulary.
    # Invoke as
    #   afgen --<generator> <file>.fim
    class FIM
      def self.readfile(filename)
        if File.basename(filename, 'fim') == "-"
          read(STDIN, "<standard input>")
        else
          File.open(filename) {|file|
            read(file, filename)
          }
        end
      rescue => e
        # Augment the exception message, but preserve the backtrace
        ne = StandardError.new("In #{filename} #{e.message.strip}")
        ne.set_backtrace(e.backtrace)
        raise ne
      end

      # Read the specified input stream
      def self.read(file, filename = "stdin")
        readstring(file.read, filename)
      end 

      # Read the specified input string
      def self.readstring(str, filename = "string")
        parser = ActiveFacts::FIM::Parser.new(filename)
        parser.compile(str, :definition)
      end 

    end 
  end
end
