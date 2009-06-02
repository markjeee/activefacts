#
#       ActiveFacts CQL Parser.
#       The parser turns CQL strings into abstract syntax trees ready for semantic analysis.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
require 'rubygems'
require 'treetop'

# These are Treetop files, which it will compile on the fly if precompiled ones aren't found:
require 'activefacts/cql/LexicalRules'
require 'activefacts/cql/Language/English'
require 'activefacts/cql/Expressions'
require 'activefacts/cql/Concepts'
require 'activefacts/cql/ValueTypes'
require 'activefacts/cql/FactTypes'
require 'activefacts/cql/CQLParser'

module ActiveFacts
  # Extend the generated parser:
  class CQLParser
    include ActiveFacts

    # Repeatedly parse rule_name until all input is consumed,
    # returning an array of syntax trees for each definition.
    def parse_all(input, rule_name = nil, &block)
      self.root = rule_name if rule_name

      @index = 0  # Byte offset to start next parse
      self.consume_all_input = false
      results = []
      begin
        node = parse(input, :index => @index)
        return nil unless node
        node = block.call(node) if block
        results << node if node
      end until self.index == @input_length
      results
    end

    def definition(node)
      name, ast = *node.value
      kind, *value = *ast

      begin
        debug "CQL: Processing definition #{[kind, name].compact*" "}" do
          case kind
          when :vocabulary
            [kind, name]
          when :value_type
            value_type(name, value)
          when :entity_type
            supertypes = value.shift
            entity_type(name, supertypes, value)
          when :fact_type
            f = fact_type(name, value)
          when :constraint
            ast
          end
        end
      end
    rescue => e
      raise "in #{kind.to_s.camelcase(true)} definition, #{e.message}:\n\t#{node.text_value}" +
        (ENV['DEBUG'] =~ /\bexception\b/ ? "\nfrom\t"+e.backtrace*"\n\t" : "")
    end

    def value_type(name, value)
      # REVISIT: Massage/check value type here?
      [:value_type, name, *value]
    end

    def entity_type(name, supertypes, value)
      #print "entity_type parameters for #{name}: "; p value
      identification, mapping_pragmas, clauses = *value
      clauses ||= []

      # raise "Entity type clauses must all be fact types" if clauses.detect{|c| c[0] != :fact_clause }

      [:entity_type, name, supertypes, identification, mapping_pragmas, clauses]
    end

    def fact_type(name, value)
      defined_readings, *clauses = value

      [:fact_type, name, defined_readings, clauses]
    end

  end

  Polyglot.register('cql', CQLParser)
end
