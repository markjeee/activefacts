#
#       ActiveFacts Relational mapping and persistence.
#       Tables; Calculate the relational composition of a given Vocabulary.
#       The composition consists of decisions about which Concepts are tables,
#       and what columns (absorbed roled) those tables will have.
#
# Copyright (c) 2009 Clifford Heath. Read the LICENSE file.
#
# This module has the following known problems:
#
# * When a subtype has no mandatory roles, we should support an optional schema transformation step
#   that introduces a boolean (is_subtype) to indicate it's that subtype.
#

require 'activefacts/persistence/reference'

module ActiveFacts
  module Metamodel

    class ValueType < Concept
      def absorbed_via  #:nodoc:
        # ValueTypes aren't absorbed in the way EntityTypes are
        nil
      end

      # Returns true if this ValueType is a table
      def is_table
        return @is_table if @is_table != nil

        # Always a table if marked so:
        if is_independent
          debug :absorption, "ValueType #{name} is declared independent"
          @tentative = false
          return @is_table = true
        end

        # Only a table if it has references (to another ValueType)
        if !references_from.empty?
          debug :absorption, "#{name} is a table because it has #{references_from.size} references to it"
          @is_table = true
        else
          @is_table = false
        end
        @tentative = false

        @is_table
      end

      # Is this ValueType auto-assigned on first save to the database?
      def is_auto_assigned
        # REVISIT: Find a better way to determine AutoCounters (ValueType unary role?)
        type = self
        type = type.supertype while type.supertype
        type.name =~ /^Auto/
      end
    end

    class EntityType < Concept
      # A Reference from an entity type that fully absorbs this one
      def absorbed_via; @absorbed_via; end
      def absorbed_via=(r) #:nodoc:
        @absorbed_via = r
      end

      def is_auto_assigned  #:nodoc:
        false
      end

      # Returns true if this EntityType is a table
      def is_table
        return @is_table if @is_table != nil  # We already make a guess or decision

        @tentative = false

        # Always a table if marked so
        if is_independent
          debug :absorption, "EntityType #{name} is declared independent"
          return @is_table = true
        end

        # Always a table if nowhere else to go, and has no one-to-ones that might flip:
        if references_to.empty? and
            !references_from.detect{|ref| ref.role_type == :one_one }
          debug :absorption, "EntityType #{name} is independent as it has nowhere to go"
          return @is_table = true
        end

        # Subtypes are not a table unless partitioned or separate
        # REVISIT: Support partitioned subtypes here
        if (!supertypes.empty?)
          return @is_table = all_supertype_inheritance.detect{|ti| ti.assimilation} != nil
        end

        # If the preferred_identifier includes an auto_assigned ValueType
        # and this object is absorbed in more than one place, we need a table
        # to manage the auto-assignment.
        if references_to.size > 1 and
          preferred_identifier.role_sequence.all_role_ref.detect {|rr|
            next false unless rr.role.concept.is_a? ValueType
            rr.role.concept.is_auto_assigned
          }
          debug :absorption, "#{name} has an auto-assigned counter in its ID, so must be a table"
          @tentative = false
          return @is_table = true
        end

        @tentative = true
        @is_table = true
      end
    end # EntityType class

    class Role    #:nodoc:
      def role_type
        # TypeInheritance roles are always 1:1
        if TypeInheritance === fact_type
          return concept == fact_type.supertype ? :supertype : :subtype
        end

        # Always N:1 if unary:
        return :unary if fact_type.all_role.size == 1

        # List the UCs on this fact type:
        all_uniqueness_constraints =
          fact_type.all_role.map do |fact_role|
            fact_role.all_role_ref.map do |rr|
              rr.role_sequence.all_presence_constraint.select do |pc|
                pc.max_frequency == 1
              end
            end
          end.flatten.uniq

        to_1 =
          all_uniqueness_constraints.
            detect do |c|
                (rr = c.role_sequence.all_role_ref.single) and
                rr.role == self
            end

        if fact_type.entity_type
          # This is a role in an objectified fact type
          from_1 = true
        else
          # It's to-1 if a UC exists over roles of this FT that doesn't cover this role:
          from_1 = all_uniqueness_constraints.detect{|uc|
            !uc.role_sequence.all_role_ref.detect{|rr| rr.role == self || rr.role.fact_type != fact_type}
          }
        end

        if from_1
          return to_1 ? :one_one : :one_many
        else
          return to_1 ? :many_one : :many_many
        end
      end

    end

    class Vocabulary
      # return an Array of Concepts that will have their own tables
      def tables
        decide_tables if !@tables
        @tables
      end

      def decide_tables #:nodoc:
        # Strategy:
        # 1) Populate references for all Concepts
        # 2) Decide which Concepts must be and must not be tables
        #  a. Concepts labelled is_independent are tables (See the is_table methods above)
        #  b. Entity types having no references to them must be tables
        #  c. subtypes are not tables unless marked with assimilation = separate or partitioned
        #  d. ValueTypes are never tables unless they can have references (to other ValueTypes)
        #  e. An EntityType having an identifying AutoInc field must be a table unless it has exactly one reference
        #  f. An EntityType whose only reference is through its single preferred_identifier role gets absorbed
        #  g. An EntityType that must has references other than its PI must be a table (unless it has exactly one reference to it)
        #  h. supertypes are elided if all roles are absorbed into subtypes:
        #    - partitioned subtype exhaustion
        #    - subtype extension where supertype has only PI roles and no AutoInc
        # 3) any ValueType that has references from it must become a table if not already

        populate_all_references

        debug :absorption, "Calculating relational composition" do
          # Evaluate the possible independence of each concept, building an array of concepts of indeterminate status:
          undecided =
            all_concept.select do |concept|
              concept.is_table          # Ask it whether it thinks it should be a table
              concept.tentative         # Selection criterion
            end

          if debug :absorption, "Generating tables, #{undecided.size} undecided"
            (all_concept-undecided).each {|concept|
              next if ValueType === concept && !concept.is_table  # Skip unremarkable cases
              debug :absorption do
                debug :absorption, "#{concept.name} is #{concept.is_table ? "" : "not "}a table#{concept.tentative ? ", tentatively" : ""}"
              end
            }
          end

          pass = 0
          begin                         # Loop while we continue to make progress
            pass += 1
            debug :absorption, "Starting composition pass #{pass} with #{undecided.size} undecided tables"
            possible_flips = {}         # A hash by table containing an array of references that can be flipped
            finalised =                 # Make an array of things we finalised during this pass
              undecided.select do |concept|
                debug :absorption, "Considering #{concept.name}:" do
                  debug :absorption, "refs to #{concept.name} are from #{concept.references_to.map{|ref| ref.from.name}*", "}" if concept.references_to.size > 0
                  debug :absorption, "refs from #{concept.name} are to #{concept.references_from.map{|ref| ref.to.name rescue ref.fact_type.default_reading}*", "}" if concept.references_from.size > 0

                  # Always absorb an objectified unary into its role player:
                  if concept.fact_type && concept.fact_type.all_role.size == 1
                    debug :absorption, "Absorb objectified unary #{concept.name} into #{concept.fact_type.entity_type.name}"
                    concept.definitely_not_table
                    next concept
                  end

                  # If the PI contains one role only, played by an entity type that can absorb us, do that.
                  pi_roles = concept.preferred_identifier.role_sequence.all_role_ref.map(&:role)
                  debug :absorption, "pi_roles are played by #{pi_roles.map{|role| role.concept.name}*", "}"
                  first_pi_role = pi_roles[0]
                  pi_ref = nil
                  if pi_roles.size == 1 and
                    concept.references_to.detect{|ref| pi_ref = ref if ref.from_role == first_pi_role && ref.from.is_a?(EntityType)}

                    debug :absorption, "#{concept.name} is fully absorbed along its sole reference path into entity type #{pi_ref.from.name}"
                    concept.definitely_not_table
                    next concept
                  end

                  # If there's more than one absorption path and any functional dependencies that can't absorb us, it's a table
                  non_identifying_refs_from =
                    concept.references_from.reject{|ref|
                      pi_roles.include?(ref.to_role)
                    }
                  debug :absorption, "#{concept.name} has #{non_identifying_refs_from.size} non-identifying functional roles"

                  if concept.references_to.size > 1 and
                      non_identifying_refs_from.size > 0
                    debug :absorption, "#{concept.name} has non-identifying functional dependencies so 3NF requires it be a table"
                    concept.definitely_table
                    next concept
                  end

                  absorption_paths =
                    (
                      non_identifying_refs_from.reject do |ref|
                        !ref.to or ref.to.absorbed_via == ref
                      end+concept.references_to
                    ).reject do |ref|
                      next true if !ref.to.is_table or
                        ![:one_one, :supertype, :subtype].include?(ref.role_type)

                      # Don't absorb an object along a non-mandatory role (otherwise if it doesn't play that role, it can't exist either)
                      from_is_mandatory = !!ref.is_mandatory
                      to_is_mandatory = !ref.to_role || !!ref.to_role.is_mandatory

                      bad = !(ref.from == concept ? from_is_mandatory : to_is_mandatory)
                      debug :absorption, "Not absorbing #{concept.name} through non-mandatory #{ref}" if bad
                      bad
                    end

                  # If this object can be fully absorbed, do that (might require flipping some references)
                  if absorption_paths.size > 0
                    debug :absorption, "#{concept.name} is fully absorbed through #{absorption_paths.inspect}"
                    absorption_paths.each do |ref|
                      debug :absorption, "flip #{ref} so #{concept.name} can be absorbed"
                      ref.flip if concept == ref.from
                    end
                    concept.definitely_not_table
                    next concept
                  end

                  if non_identifying_refs_from.size == 0
#                    and (!concept.is_a?(EntityType) ||
#                      # REVISIT: The roles may be collectively but not individually mandatory.
#                      concept.references_to.detect { |ref| !ref.from_role || ref.from_role.is_mandatory })
                    debug :absorption, "#{concept.name} is fully absorbed in #{concept.references_to.size} places: #{concept.references_to.map{|ref| ref.from.name}*", "}"
                    concept.definitely_not_table
                    next concept
                  end

                  false   # Failed to decide about this entity_type this time around
                end
              end

            undecided -= finalised
            debug :absorption, "Finalised #{finalised.size} this pass: #{finalised.map{|f| f.name}*", "}"
          end while !finalised.empty?

          # A ValueType that isn't explicitly a table and isn't needed anywhere doesn't matter,
          # unless it should absorb something else (another ValueType is all it could be):
          all_concept.each do |concept|
            if (!concept.is_table and concept.references_to.size == 0 and concept.references_from.size > 0)
              debug :absorption, "Making #{concept.name} a table; it has nowhere else to go and needs to absorb things"
              concept.probably_table
            end
          end

          # Now, evaluate all possibilities of the tentative assignments
          # Incomplete. Apparently unnecessary as well... so far. We'll see.
          if debug :absorption
            undecided.each do |concept|
              debug :absorption, "Unable to decide independence of #{concept.name}, going with #{concept.show_tabular}"
            end
          end
        end

        populate_all_columns
        populate_all_indices

        @tables =
          all_concept.
          select { |f| f.is_table }.
          sort_by { |table| table.name }
      end
    end

  end
end
