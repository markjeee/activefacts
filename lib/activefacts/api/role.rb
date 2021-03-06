#
#       ActiveFacts API
#       Role class.
#       Each accessor method created on an instance corresponds to a Role object in the instance's class.
#       Binary fact types construct a Role at each end.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
module ActiveFacts
  module API

    # A Role represents the relationship of one object to another (or to a boolean condition).
    # Relationships (or binary fact types) have a Role at each end; one is declared using _has_one_
    # or _one_to_one_, and the other is created on the counterpart class. Each Concept class maintains
    # an array of the roles it plays.
    class Role
      attr_accessor :owner            # The Concept to which this role belongs
      attr_accessor :name             # The name of the role (a Symbol)
      attr_accessor :counterpart_concept  # A Concept Class (may be temporarily a Symbol before the class is defined)
      attr_accessor :counterpart      # All roles except unaries have a binary counterpart
      attr_accessor :unique           # Is this role played by at most one instance, or more?
      attr_accessor :mandatory        # In a valid fact population, is this role required to be played?
      attr_accessor :value_constraint  # Counterpart Instances playing this role must meet this constraint
      attr_reader :is_identifying     # Is this an identifying role for owner?

      def initialize(owner, counterpart_concept, counterpart, name, mandatory = false, unique = true)
        @owner = owner
        @counterpart_concept = counterpart_concept
        @counterpart = counterpart
        @name = name
        @mandatory = mandatory
        @unique = unique
        @is_identifying = @owner.is_entity_type && @owner.identifying_role_names.include?(@name)
      end

      # Is this role a unary (created by maybe)? If so, it has no counterpart
      def unary?
        # N.B. A role with a forward reference looks unary until it is resolved.
        counterpart == nil
      end

      def resolve_counterpart(vocabulary)  #:nodoc:
        return @counterpart_concept if @counterpart_concept.is_a?(Class)   # Done already
        klass = vocabulary.concept(@counterpart_concept)   # Trigger the binding
        raise "Cannot resolve role counterpart_concept #{@counterpart_concept.inspect} for role #{name} in vocabulary #{vocabulary.basename}; still forward-declared?" unless klass
        @counterpart_concept = klass                       # Memoize a successful result
      end

      def adapt(constellation, value) #:nodoc:
        # If the value is a compatible class, use it (if in another constellation, clone it),
        # else create a compatible object using the value as constructor parameters.
        if value.is_a?(@counterpart_concept)  # REVISIT: may be a non-primary subtype of counterpart_concept
          value = value.__getobj__ if RoleProxy === value
          # Check that the value is in a compatible constellation, clone if not:
          if constellation && (vc = value.constellation) && vc != constellation
            value = value.clone   # REVISIT: There's sure to be things we should reset/clone here, like non-identifying roles
          end
          value.constellation = constellation if constellation
        else
          value = [value] unless Array === value
          raise "No parameters were provided to identify an #{@counterpart_concept.basename} instance" if value == []
          if constellation
            value = constellation.send(@counterpart_concept.basename.to_sym, *value)
          else
            value = @counterpart_concept.new(*value)
          end
        end
        value
      end
    end

    # Every Concept has a Role collection
    # REVISIT: You can enumerate the concept's own roles, or inherited roles as well.
    class RoleCollection < Hash #:nodoc:
      def verbalise
        keys.sort_by(&:to_s).inspect
      end
    end
  end
end
