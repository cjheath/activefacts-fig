#
#       ActiveFacts FIM Generator
#
# Copyright (c) 2024 Clifford Heath. Read the LICENSE file.
#
require 'digest/sha1'
require 'activefacts/metamodel'
require 'activefacts/compositions'
require 'activefacts/generator'
require 'activefacts/cql/verbaliser'

module ActiveFacts
  module Generators
    # Options are comma or space separated:
    class FIM
      def self.options
        {
          # comments: ['Boolean', "Preceed each role definition with a comment that describes it"]
        }
      end

      def initialize composition, options = {}
        super
      end

      def generate
        vocabulary_start      +
      # all_units             +
      # all_value_types       +
      # entity_types_dump     +
      # fact_types_dump       +
      # constraints_dump      +
      # vocabulary_end        +
        ''
      end

      def vocabulary_start
        build_indices
        "schema #{@vocabulary.name};\n\n"
      end

      def all_units
        units_cql = ''
        units = @vocabulary.all_unit.to_a.sort_by{|u| u.name.gsub(/ /,'')}
        while units.size > 0
          i = 0
          while i < units.size
            unit = units[i]
            i += 1

            # Skip this one if the precursors haven't yet been dumped:
            next if unit.all_derivation_as_derived_unit.detect{|d| units.include?(d.base_unit) }

            # Even if we skip, we're done with this unit
            units.delete(unit)
            i -= 1

            # Skip value-type derived units
            next if unit.name =~ /\^/

            #!!! units_cql << "/*\n * Units\n */" if units_cql.empty?
            #!!! units_cql << unit.as_cql
          end
        end

        units_cql << "\n" unless units_cql.empty?
        units_cql
      end

      def all_value_types
        value_types_cql = ''
        @vocabulary.
        all_object_type.
        sort_by{|o| o.name.gsub(/ /,'')}.
        map do |o|
          next nil unless o.is_a?(ActiveFacts::Metamodel::ValueType)

          value_types_cql << "/*\n * Value Types\n */" if value_types_cql.empty?

          #!!! value_type_chain_dump(o)
          o.ordered_dumped!
        end.
        compact*''
        value_types_cql << "\n" unless value_types_cql.empty?
        value_types_cql
      end

      # Ensure that supertype gets dumped first
      def value_type_chain_dump(o)
        return if o.ordered_dumped
        value_type_chain_dump(o.supertype) if (o.supertype && !o.supertype.ordered_dumped)
        #!!! value_type_fork(o)
        o.ordered_dumped!
      end

      def value_type_fork(o)
        if o.name == "_ImplicitBooleanValueType"
          # do nothing
        elsif
            !o.supertype                      # No supertype, i.e. a base type
            o.all_role.size == 0 &&           # No roles
            !o.is_independent &&              # not independent
            !o.value_constraint &&            # No value constraints
            o.concept.all_context_note_as_relevant_concept.size == 0 &&       # No context notes
            o.all_instance.size == 0          # No instances
          data_type_dump(o)
        else
          super_type_name = o.supertype ? o.supertype.name : o.name
          length = (l = o.length) && l > 0 ? "#{l}" : nil
          scale = (s = o.scale) && s > 0 ? "#{s}" : nil
          facets = { :length => length, :scale => scale }
          value_type_dump(o, super_type_name, facets)
        end
      end

      # Try to dump entity types in order of name, but we need
      # to dump ETs before they're referenced in preferred ids
      # if possible (it's not always, there may be loops!)
      def entity_types_dump
        # Build hash tables of precursors and followers to use:
        @precursors, @followers = *build_entity_dependencies

        done_banner = false
        sorted = @vocabulary.all_object_type.select{|o|
          o.is_a?(ActiveFacts::Metamodel::EntityType) # and !o.fact_type
        }.sort_by{|o| o.name.gsub(/ /,'')}
        panic = nil
        while true do
          count_this_pass = 0
          skipped_this_pass = 0
          sorted.each{|o|
              next if o.ordered_dumped            # Already done

              trace :ordered, "Panicing to dump #{panic.name}" if panic
              # Can we do this yet?
              remaining_precursors = Array(@precursors[o])-[o]
              if (o != panic and                  # We don't *have* to do it (panic mode)
                  remaining_precursors.size > 0)  # precursors - still blocked
                trace :ordered, "Can't dump #{o.name} despite panic for #{panic.name}, it still needs #{remaining_precursors.map(&:name)*', '}" if panic
                skipped_this_pass += 1
                next
              end
              trace :ordered, "Dumping #{o.name} in panic mode, even though it still needs #{remaining_precursors.map(&:name)*', '}" if panic

              entity_type_banner unless done_banner
              done_banner = true

              # We're going to emit o - remove it from precursors of others:
              (@followers[o]||[]).each{|f|
                  @precursors[f] -= [o]
                }
              count_this_pass += 1
              panic = nil

=begin
              if (o.fact_type)
                fact_type_dump_with_dependents(o.fact_type)
                released_fact_types_dump(o)
              else
                entity_type_dump(o)
                released_fact_types_dump(o)
              end
=end

              entity_type_group_end
            }

            # Check that we made progress if there's any to make:
            if count_this_pass == 0 && skipped_this_pass > 0
              # Find the object that has the most followers and no fwd-ref'd supertypes:
              # This selection might be better if we allow PI roles to be fwd-ref'd...
              panic = sorted.
                select{|o| !o.ordered_dumped }.
                sort_by{|o|
                    f = (@followers[o] || []) - [o];
                    o.supertypes.detect{|s| !s.ordered_dumped } ? 0 : -f.size
                  }[0]
              trace :ordered, "Panic mode, selected #{panic.name} next"
            end

            break if skipped_this_pass == 0       # All done.

        end
      end

      def identified_by(o, pi)
        # Different adjectives might be used for different readings.
        # Here, we must find the role_ref containing the adjectives that we need for each identifier,
        # which will be attached to the uniqueness constraint on this object in the binary FT that
        # attaches that identifying role.
        identifying_role_refs =
          (o.fact_type && o.fact_type.all_role.size == 1 ? o.fact_type.preferred_reading : pi).
            role_sequence.all_role_ref_in_order

        # We need to get the adjectives for the roles from the identifying fact's preferred readings:
        identifying_facts = ([o.fact_type]+identifying_role_refs.map{|rr| rr.role.fact_type }).compact.uniq

        identification = identified_by_roles_and_facts(o, identifying_role_refs, identifying_facts)

        identification
      end

      def describe_fact_type(fact_type, highlight = nil)
        (fact_type.entity_type ? fact_type.entity_type.name : "")+
        describe_roles(fact_type.all_role, highlight)
      end

      def describe_roles(roles, highlight = nil)
        "("+
        roles.map{|role| role.object_type.name + (role == highlight ? "*" : "")}*", "+
        ")"
      end

      def describe_role_sequence(role_sequence)
        "("+
        role_sequence.all_role_ref.map{|role_ref| role_ref.role.object_type.name }*", "+
        ")"
      end

      # This returns an array of two hash tables each keyed by an EntityType.
      # The values of each hash entry are the precursors and followers (respectively) of that entity.
      def build_entity_dependencies
        @vocabulary.all_object_type.inject([{},{}]) { |a, o|
            if o.is_a?(ActiveFacts::Metamodel::EntityType)
              precursor = a[0]
              follower = a[1]
              blocked = false
              pi = o.preferred_identifier
              if pi
                pi.role_sequence.all_role_ref.each{|rr|
                    role = rr.role
                    player = role.object_type
                    # REVISIT: If we decide to emit value types on demand, need to remove this:
                    next unless player.is_a?(ActiveFacts::Metamodel::EntityType)
                    # player is a precursor of o
                    (precursor[o] ||= []) << player if (player != o)
                    (follower[player] ||= []) << o if (player != o)
                  }
              end
              if o.fact_type
                o.fact_type.all_role.each do |role|
                  next unless role.object_type.is_a?(ActiveFacts::Metamodel::EntityType)
                  (precursor[o] ||= []) << role.object_type
                  (follower[role.object_type] ||= []) << o
                end
              end

              # Supertypes are precursors too:
              subtyping = o.all_type_inheritance_as_supertype
              next a if subtyping.size == 0
              subtyping.each{|ti|
                  # debug ti.class.roles.verbalise; trace "all_type_inheritance_as_supertype"; exit
                  s = ti.subtype
                  (precursor[s] ||= []) << o
                  (follower[o] ||= []) << s
                }
            end
            a
          }
      end

      # Dump all fact types for which all precursors (of which "o" is one) have been emitted:
      def released_fact_types_dump(o)
        roles = o.all_role
        begin
          progress = false
          roles.map(&:fact_type).uniq.select{|fact_type|
              # The fact type hasn't already been dumped but all its role players have
              !fact_type.ordered_dumped &&
                !fact_type.is_a?(ActiveFacts::Metamodel::LinkFactType) &&
                !fact_type.all_role.detect{|r| !r.object_type.ordered_dumped } &&
                !fact_type.entity_type &&
                derivation_precursors_complete(fact_type)
              # REVISIT: A derived fact type must not be dumped before its dependent fact types have
            }.sort_by{|fact_type|
              fact_type_key(fact_type)
            }.each{|fact_type|
              fact_type_dump_with_dependents(fact_type)
              # Objectified Fact Types may release additional fact types
              roles += fact_type.entity_type.all_role.sort_by{|role| role.ordinal} if fact_type.entity_type
              progress = true
            }
        end while progress
      end

      def derivation_precursors_complete(fact_type)
        pr = fact_type.preferred_reading
        return true unless jr = pr.role_sequence.all_role_ref.to_a[0].play
        query = jr.variable.query
        return false if query.all_step.detect{|js| !js.fact_type.ordered_dumped }
        return false if query.all_variable.detect{|jn| !jn.object_type.ordered_dumped }
        true
      end

      def skip_fact_type(f)
        return true if f.is_a?(ActiveFacts::Metamodel::TypeInheritance)
        return false if f.entity_type && !f.entity_type.ordered_dumped

        # REVISIT: There might be constraints we have to merge into the nested entity or subtype. 
        # These will come up as un-handled constraints:
        # Dump this fact type only if it contains a presence constraint we've missed:
        pcs = @presence_constraints_by_fact[f]
        pcs && pcs.size > 0 && !pcs.detect{|c| !c.ordered_dumped }
      end

      # Dump one fact type.
      # Include as many as possible internal constraints in the fact type readings.
      def fact_type_dump_with_dependents(fact_type)
        fact_type.ordered_dumped!
        return if skip_fact_type(fact_type)

        if (et = fact_type.entity_type) &&
            fact_type.all_role.size > 1 &&
            (pi = et.preferred_identifier) &&
            pi.role_sequence.all_role_ref.detect{|rr| rr.role.fact_type != fact_type }
          # trace "Dumping objectified FT #{et.name} as an entity, non-fact PI"
          entity_type_dump(et)
          released_fact_types_dump(et)
          return
        end

        # trace "#{fact_type.name} has readings:\n\t#{fact_type.readings.map(&:name)*"\n\t"}"
        # trace "Dumping #{fact_type.concept.guid} as a fact type"

        # Fact types that aren't nested have no names
        name = fact_type.entity_type && fact_type.entity_type.name

        fact_type_dump(fact_type, name)

        # REVISIT: Go through the residual constraints and re-process appropriate readings to show them

#CJH: Necessary?
        fact_type.ordered_dumped!
        fact_type.entity_type.ordered_dumped! if fact_type.entity_type
      end

      # Dump fact types.
      def fact_types_dump
        # REVISIT: Uniqueness on the LHS of a binary can be coded using "distinct"

        # The only fact types that can be remaining are those involving only value types,
        # since we dumped every fact type as soon as all relevant entities were dumped.
        # Iterate over all fact types of all value types, looking for these strays.

        done_banner = false
        fact_collection = @vocabulary.constellation.FactType
        fact_collection.keys.select{|fact_id|
                fact_type = fact_collection[fact_id] and
                !fact_type.is_a?(ActiveFacts::Metamodel::TypeInheritance) and
                !fact_type.is_a?(ActiveFacts::Metamodel::LinkFactType) and
                !fact_type.ordered_dumped and
                !skip_fact_type(fact_type) and
                !fact_type.all_role.detect{|r| r.object_type.is_a?(ActiveFacts::Metamodel::EntityType) }
            }.sort_by{|fact_id|
                fact_type = fact_collection[fact_id]
                fact_type_key(fact_type)
            }.each{|fact_id|
                fact_type = fact_collection[fact_id]

                fact_type_banner unless done_banner
                done_banner = true
                fact_type_dump_with_dependents(fact_type)
          }

        # REVISIT: Find out why some fact types are missed during entity dumping:
        @vocabulary.constellation.FactType.values.select{|fact_type|
            !fact_type.is_a?(ActiveFacts::Metamodel::TypeInheritance) &&
              !fact_type.is_a?(ActiveFacts::Metamodel::LinkFactType)
          }.sort_by{|fact_type|
            fact_type_key(fact_type)
          }.each{|fact_type|
            next if fact_type.ordered_dumped
            # trace "Not dumped #{fact_type.verbalise}(#{fact_type.all_role.map{|r| r.object_type.name}*", "})"
            fact_type_banner unless done_banner
            done_banner = true
            fact_type_dump_with_dependents(fact_type)
          }

        fact_type_end if done_banner
      end

      def fact_instances_dump
        @vocabulary.fact_types.each{|f|
            # Dump the instances:
            f.facts.each{|i|
              raise "REVISIT: Not dumping fact instances"
              trace "\t\t"+i.to_s
            }
        }
      end

      # Arrange for objectified fact types to appear in order of name, after other fact types.
      # Facts are ordered alphabetically by the names of their role players,
      # then by preferred_reading (subtyping fact types have no preferred_reading).
      def fact_type_key(fact_type)
        role_names =
          if (pr = fact_type.preferred_reading)
            role_refs = pr.role_sequence.all_role_ref.sort_by{|role_ref| role_ref.ordinal}
            role_refs.
              map{|role_ref| [ role_ref.leading_adjective, role_ref.role.object_type.name, role_ref.trailing_adjective ].compact*"-" } +
              [pr.text] +
              role_refs.map{|role_ref| [role_ref.role.is_mandatory ? 0 : 1] }
          else
            fact_type.all_role.map{|role| role.object_type.name }
          end

        (fact_type.entity_type ? [fact_type.entity_type.name] : [""]) + role_names
      end

      def role_ref_key(role_ref)
        [ role_ref.leading_adjective, role_ref.role.object_type.name, role_ref.trailing_adjective ].compact*"-" +
        " in " +
        role_ref.role.fact_type.preferred_reading.expand
      end

      def constraint_sort_key(c)
        case c
        when ActiveFacts::Metamodel::RingConstraint
          [ 1,
            c.ring_type,
            c.role.object_type.name,
            c.other_role.object_type.name,
            c.name||""
          ]
        when ActiveFacts::Metamodel::SetExclusionConstraint
          [ 2+(c.is_mandatory ? 0 : 1),
            c.all_set_comparison_roles.map{|scrs|
              scrs.role_sequence.all_role_ref.map{|rr|
                role_ref_key(rr)
              }
            },
            c.name||""
          ]
        when ActiveFacts::Metamodel::SetEqualityConstraint
          [ 4,
            c.all_set_comparison_roles.map{|scrs|
              scrs.role_sequence.all_role_ref.map{|rr|
                role_ref_key(rr)
              }
            },
            c.name||""
          ]
        when ActiveFacts::Metamodel::SubsetConstraint
          [ 5,
            [c.superset_role_sequence, c.subset_role_sequence].map{|rs|
              rs.all_role_ref.map{|rr|
                role_ref_key(rr)
              }
            },
            c.name||""
          ]
        when ActiveFacts::Metamodel::PresenceConstraint
          [ 6,
            c.role_sequence.all_role_ref.map{|rr|
              role_ref_key(rr)
            },
            c.name||""
          ]
        end
      end

      def constraints_dump
        heading = false
        @vocabulary.
            all_constraint.
            reject{|c| c.ordered_dumped}.
            sort_by{ |c| constraint_sort_key(c) }.
            each do |c|
          # Skip some PresenceConstraints:
          if c.is_a?(ActiveFacts::Metamodel::PresenceConstraint)
            # Skip uniqueness constraints that cover all roles of a fact type, they're implicit
            fact_types = c.role_sequence.all_role_ref.map{|rr| rr.role.fact_type}.uniq
            if fact_types.size == 1 &&
              !c.role_sequence.all_role_ref.detect{|rr| rr.play } &&
              c.max_frequency == 1 &&         # Uniqueness
              fact_types[0].all_role.size == c.role_sequence.all_role_ref.size
              next
            end

            # Skip internal PresenceConstraints over TypeInheritances:
            next if c.role_sequence.all_role_ref.size == 1 &&
              fact_types[0].is_a?(ActiveFacts::Metamodel::TypeInheritance)
          end

          constraint_banner unless heading
          heading = true

          # Skip presence constraints on value types:
          # next if ActiveFacts::PresenceConstraint === c &&
          #     ActiveFacts::ValueType === c.object_type
          constraint_dump(c)
        end
        constraint_end if heading
      end

      def vocabulary_end
      end

      def data_type_dump(o)
        value_type_dump(o, o.name, {}) if o.all_role.size > 0
      end

      def value_type_dump(o, super_type_name, facets)
        # No need to dump it if the only thing it does is be a supertype; it'll be created automatically
        # return if o.all_value_type_as_supertype.size == 0

        # REVISIT: A ValueType that is only used as a reference mode need not be emitted here.

        puts o.as_cql
      end

      def entity_type_dump(o)
        o.ordered_dumped!
        pi = o.preferred_identifier

        supers = o.supertypes
        if (supers.size > 0)
          # Ignore identification by a supertype:
          pi = nil if pi && pi.role_sequence.all_role_ref.detect{|rr| rr.role.fact_type.is_a?(ActiveFacts::Metamodel::TypeInheritance) }
          subtype_dump(o, supers, pi)
        else
          non_subtype_dump(o, pi)
        end
        pi.ordered_dumped! if pi
      end

      def append_ring_to_reading(reading, ring)
        reading << " [#{(ring.ring_type.scan(/StronglyIntransitive|[A-Z][a-z]*/)*", ").downcase}]"
      end

      def mapping_pragma(entity_type, ignore_independence = false)
        ti = entity_type.all_type_inheritance_as_subtype
        assimilation = ti.map{|t| t.assimilation }.compact[0]
        return "" unless (entity_type.is_independent && !ignore_independence) || assimilation
        " [" +
          [
            entity_type.is_independent && !ignore_independence ? "independent" : nil,
            assimilation || nil
          ].compact*", " +
        "]"
      end

      # If this entity_type is identified by a single value, return four relevant objects:
      def value_role_identification(entity_type, identifying_facts)
        external_identifying_facts = identifying_facts - [entity_type.fact_type]
        fact_type = external_identifying_facts[0]
        ftr = fact_type && fact_type.all_role.sort_by{|role| role.ordinal}
        if external_identifying_facts.size == 1 and
            entity_role = ftr[n = (ftr[0].object_type == entity_type ? 0 : 1)] and
            value_role = ftr[1-n] and
            value_player = value_role.object_type and
            value_player.is_a?(ActiveFacts::Metamodel::ValueType) and
            value_name = value_player.name and
            value_residual = value_name.sub(%r{^#{entity_role.object_type.name} ?},'') and
            value_residual != '' and
            value_residual != value_name
          [fact_type, entity_role, value_role, value_residual]
        else
          []
        end
      end

      # This entity is identified by a single value, so find whether standard refmode readings were used
      def detect_standard_refmode_readings fact_type, entity_role, value_role
        forward_reading = reverse_reading = nil
        fact_type.all_reading.each do |reading|
          if reading.text =~ /^\{(\d)\} has \{\d\}$/
            if reading.role_sequence.all_role_ref.detect{|rr| rr.ordinal == $1.to_i}.role == entity_role
              forward_reading = reading
            else
              reverse_reading = reading
            end
          elsif reading.text =~ /^\{(\d)\} is of \{\d\}$/
            if reading.role_sequence.all_role_ref.detect{|rr| rr.ordinal == $1.to_i}.role == value_role
              reverse_reading = reading
            else
              forward_reading = reading
            end
          end
        end
        trace :mode, "Didn't find standard forward reading" unless forward_reading
        trace :mode, "Didn't find standard reverse reading" unless reverse_reading
        [forward_reading, reverse_reading]
      end

      # If this entity_type is identified by a reference mode, return the verbalisation
      def identified_by_ref_mode(entity_type, identifying_facts)
        fact_type, entity_role, value_role, value_residual =
          *value_role_identification(entity_type, identifying_facts)
        return nil unless fact_type

        # This EntityType is identified by its association with a single ValueType
        # whose name is an extension (the value_residual) of the EntityType's name.
        # If we have at least one of the standard refmode readings, dump it that way,
        # else exit and use the long-hand verbalisation instead.

        forward_reading, reverse_reading =
          *detect_standard_refmode_readings(fact_type, entity_role, value_role)
        return nil unless (forward_reading || reverse_reading)

        # We can't subscript reference modes.
        # If an objectified fact type has a role played by its identifying player, go long-hand.
        return nil if entity_type.fact_type and
          entity_type.fact_type.all_role.detect{|role| role.object_type == value_role.object_type }

        fact_type.ordered_dumped!  # We've covered this fact type

        # Elide the constraints that would have been emitted on the standard readings.
        # If there is a UC that's not in the standard form for a reference mode,
        # we have to emit the standard reading anyhow.
        fact_constraints = @presence_constraints_by_fact[fact_type]
        fact_constraints.each do |pc|
          if (pc.role_sequence.all_role_ref.size == 1 and pc.max_frequency == 1)
            # It's a uniqueness constraint, and will be regenerated
            pc.ordered_dumped!
          end
        end

        # Figure out which non-standard readings exist, if any:
        nonstandard_readings = fact_type.all_reading - [forward_reading, reverse_reading]
        trace :mode, "--- nonstandard_readings.size now = #{nonstandard_readings.size}" if nonstandard_readings.size > 0

        verbaliser = ActiveFacts::CQL::Verbaliser.new

        # The verbaliser needs to have a Player for the roles of entity_type, so it doesn't get subscripted.
        entity_roles =
          nonstandard_readings.map{|r| r.role_sequence.all_role_ref.detect{|rr| rr.role.object_type == entity_type}}.compact
        verbaliser.role_refs_have_same_player entity_roles

        verbaliser.alternate_readings nonstandard_readings
        if entity_type.fact_type
          verbaliser.alternate_readings entity_type.fact_type.all_reading
        end

        verbaliser.create_subscripts(:rolenames)      # Ok, the Verbaliser is ready to fly

        fact_readings =
          nonstandard_readings.map { |reading| expanded_reading(verbaliser, reading, fact_constraints, true) }
        fact_readings +=
          fact_readings_with_constraints(verbaliser, entity_type.fact_type) if entity_type.fact_type

        # If we emitted a reading for the refmode, it'll include any role_value_constraint already
        if nonstandard_readings.size == 0 and c = value_role.role_value_constraint
          constraint_text = " "+c.as_cql
        end
        (entity_type.is_independent ? ' independent' : '') +
          " identified by its #{value_residual}#{constraint_text}#{mapping_pragma(entity_type, true)}" +
          entity_type.concept.all_context_note_as_relevant_concept.map do |cn|
            cn.verbalise
          end.join("\n") +
          (fact_readings.size > 0 ? " where\n\t" : "") +
          fact_readings*",\n\t"
      end

      def identified_by_roles_and_facts(entity_type, identifying_role_refs, identifying_facts)
        # Detect standard reference-mode scenarios:
        if srm = identified_by_ref_mode(entity_type, identifying_facts)
          return srm
        end

        verbaliser = ActiveFacts::CQL::Verbaliser.new

        # Announce all the identifying fact roles to the verbaliser so it can decide on any necessary subscripting.
        # The verbaliser needs to have a Player for the roles of entity_type, so it doesn't get subscripted.
        entity_roles =
          identifying_facts.map{|ft| ft.preferred_reading.role_sequence.all_role_ref.detect{|rr| rr.role.object_type == entity_type}}.compact
        verbaliser.role_refs_have_same_player entity_roles
        identifying_facts.each do |fact_type|
          # The RoleRefs for corresponding roles across all readings are for the same player.
          verbaliser.alternate_readings fact_type.all_reading
          fact_type.ordered_dumped! unless fact_type.entity_type # Must dump objectification still!
        end
        verbaliser.create_subscripts(:rolenames)

        irn = verbaliser.identifying_role_names identifying_role_refs

        identifying_fact_text = 
            identifying_facts.map{|f|
                fact_readings_with_constraints(verbaliser, f)
            }.flatten*",\n\t"

        (entity_type.is_independent ? ' independent' : '') +
          " identified by #{ irn*" and " }" +
          mapping_pragma(entity_type, true) +
          entity_type.concept.all_context_note_as_relevant_concept.map do |cn|
            cn.verbalise
          end.join("\n") +
          " where\n\t"+identifying_fact_text
      end

      def entity_type_banner
        puts "/*\n * Entity Types\n */"
      end

      def entity_type_group_end
        puts "\n"
      end

      def subtype_dump(o, supertypes, pi)
        print "#{o.name} is a kind of #{
            o.is_independent ? 'independent ' : ''
          }#{ o.supertypes.map(&:name)*", " }"
        if pi
          puts identified_by(o, pi)+';'
          return
        end

        print mapping_pragma(o, true)

        if o.fact_type
          verbaliser = ActiveFacts::CQL::Verbaliser.new
          # Announce all the objectified fact roles to the verbaliser so it can decide on any necessary subscripting.
          # The RoleRefs for corresponding roles across all readings are for the same player.
          verbaliser.alternate_readings o.fact_type.all_reading
          verbaliser.create_subscripts(:rolenames)

          print " where\n\t" + fact_readings_with_constraints(verbaliser, o.fact_type)*",\n\t"
        end
        puts ";\n"
      end

      def non_subtype_dump(o, pi)
        puts "#{o.name} is" + identified_by(o, pi) + ';'
      end

      def naiive_expand(reading)
        role_refs = reading.role_sequence.all_role_ref_in_order
        reading.text.gsub(/\{(\d+)\}/) do
          role_refs[$1.to_i].role.object_type.name
        end
      end

      def fact_type_dump(fact_type, name)

        if (o = fact_type.entity_type)
          print "#{o.name} is"
          supertypes = o.supertypes
          if supertypes.empty?
            print ' independent' if o.is_independent
          else
            print " a kind of#{
                o.is_independent ? ' independent' : ''
              } #{ supertypes.map(&:name)*', ' }"
          end

          # Alternate identification of objectified fact type?
          primary_supertype = supertypes[0]
          if fact_type.all_role.size > 1 and
              pi = fact_type.entity_type.preferred_identifier and
              primary_supertype && primary_supertype.preferred_identifier != pi
            puts identified_by(o, pi) + ';'
            return
          end
          print " where\n\t"
        end

        # Check whether this fact type has readings which could be confused for a previously-dumped one:
        reading_texts = fact_type.all_reading.map{|r| naiive_expand(r)}
        if reading_texts.size > 1
          ambiguity =
            fact_type.all_role.to_a[0].object_type.all_role.map{|r| r.fact_type}.
              select{|f| f != fact_type && f.ordered_dumped }.
              detect do |dft|
                ambiguous_readings =
                  reading_texts & dft.all_reading.map{|r| naiive_expand(r)}
                ambiguous_readings.size > 0
              end
          if ambiguity
            puts fact_type.default_reading([], true)+';  // Avoid ambiguity; this is a new fact type'
          end
        end

        # There can be no roles of the objectified fact type in the readings, so no need to tell the Verbaliser anything special
        verbaliser = ActiveFacts::CQL::Verbaliser.new
        verbaliser.alternate_readings fact_type.all_reading
        pr = fact_type.preferred_reading
        if (pr.role_sequence.all_role_ref.to_a[0].play)
          verbaliser.prepare_role_sequence pr.role_sequence
        end
        verbaliser.create_subscripts(:rolenames)

        print(fact_readings_with_constraints(verbaliser, fact_type)*",\n\t")
        if (pr.role_sequence.all_role_ref.to_a[0].play)
          print " where\n\t"+verbaliser.verbalise_over_role_sequence(pr.role_sequence)
        end
        puts(';')
      end

      def fact_type_banner
        puts "/*\n * Fact Types\n */"
      end

      def fact_type_end
        puts "\n"
      end

      def constraint_banner
        puts "/*\n * Constraints:"
        puts " */"
      end

      def constraint_end
      end

      # Of the players of a set of roles, return the one that's a subclass of (or same as) all others, else nil
      def roleplayer_subclass(roles)
        roles[1..-1].inject(roles[0].object_type){|subclass, role|
          next nil unless subclass and EntityType === role.object_type
          role.object_type.supertypes_transitive.include?(subclass) ? role.object_type : nil
        }
      end

      def dump_presence_constraint(c)
        # Loose binding in PresenceConstraints is limited to explicit role players (in an occurs list)
        # having no exact match, but having instead exactly one role of the same player in the readings.

        verbaliser = ActiveFacts::CQL::Verbaliser.new
        # For a mandatory constraint (min_frequency == 1, max == nil or 1) any subtyping step is over the proximate role player
        # For all other presence constraints any subtyping step is over the counterpart player
        role_proximity = c.min_frequency == 1 && [nil, 1].include?(c.max_frequency) ? :proximate : :counterpart
        if role_proximity == :proximate
          verbaliser.role_refs_have_subtype_steps(c.role_sequence)
        else
          roles = c.role_sequence.all_role_ref.map{|rr|rr.role}
          join_over, joined_roles = ActiveFacts::Metamodel.plays_over(roles, role_proximity)
          verbaliser.roles_have_same_player(joined_roles) if join_over
        end

        verbaliser.prepare_role_sequence(c.role_sequence, join_over)
        # REVISIT: Need to discount role_adjuncts in here, since this constraint uses loose binding:
        verbaliser.create_subscripts :loose

        expanded_readings = verbaliser.verbalise_over_role_sequence(c.role_sequence, nil, role_proximity)
        if c.min_frequency == 1 && c.max_frequency == nil and c.role_sequence.all_role_ref.size == 2
          puts "either #{expanded_readings*' or '};"
        else
          roles = c.role_sequence.all_role_ref.map{|rr| rr.role }
          players = c.role_sequence.all_role_ref.map{|rr| verbaliser.subscripted_player(rr) }
          players.uniq! if role_proximity == :proximate
          min, max = c.min_frequency, c.max_frequency
          pl = (min&&min>1)||(max&&max>1) ? 's' : ''
          puts \
            "each #{players.size > 1 ? "combination " : ""}#{players*", "} occurs #{c.frequency} time#{pl} in\n\t"+
            "#{Array(expanded_readings)*",\n\t"};"
        end
      end

      def dump_set_comparison_constraint(c)
        scrs = c.all_set_comparison_roles.sort_by{|scr| scr.ordinal}
        role_sequences = scrs.map{|scr|scr.role_sequence}
        transposed_role_refs = scrs.map{|scr| scr.role_sequence.all_role_ref_in_order.to_a}.transpose
        verbaliser = ActiveFacts::CQL::Verbaliser.new

        # Tell the verbaliser all we know, so it can figure out which players to subscript:
        players = []
        trace :subscript, "Preparing query across projected roles in set comparison constraint" do
          transposed_role_refs.each do |role_refs|
            verbaliser.role_refs_have_subtype_steps role_refs
            join_over, = ActiveFacts::Metamodel.plays_over(role_refs.map{|rr| rr.role})
            players << join_over
          end
        end
        trace :subscript, "Preparing query between roles in set comparison constraint" do
          role_sequences.each do |role_sequence|
            trace :subscript, "role sequence is #{role_sequence.describe}" do
              verbaliser.prepare_role_sequence role_sequence
            end
          end
        end
        verbaliser.create_subscripts :normal

        if role_sequences.detect{|scr| scr.all_role_ref.detect{|rr| rr.play}}
          # This set constraint has an explicit query. Verbalise it.

          readings_list = role_sequences.
            map do |rs|
              verbaliser.verbalise_over_role_sequence(rs) 
            end
          if c.is_a?(ActiveFacts::Metamodel::SetEqualityConstraint)
            puts readings_list.join("\n\tif and only if\n\t") + ';'
            return
          end
          if readings_list.size == 2 && c.is_mandatory  # XOR constraint
            puts "either " + readings_list.join(" or ") + " but not both;"
            return
          end

          # Internal check: We must have located the players here
          if i = players.index(nil)
            rrs = transposed_role_refs[i]
            raise "Internal error detecting constrained object types in query involving #{rrs.map{|rr| rr.role.fact_type.default_reading}.uniq*', '}"
          end

          # Loose binding will apply only to the constrained roles, not to all roles. Not handled here.
          mode = c.is_mandatory ? "exactly one" : "at most one"
          puts "for each #{players.map{|p| p.name}*", "} #{mode} of these holds:\n\t" +
            readings_list.join(",\n\t") +
            ';'
          return
        end

        if c.is_a?(ActiveFacts::Metamodel::SetEqualityConstraint)
          puts \
            scrs.map{|scr|
              verbaliser.verbalise_over_role_sequence(scr.role_sequence)
            } * "\n\tif and only if\n\t" + ";"
          return
        end

        # A constrained role may involve a subtyping step. We substitute the name of the supertype for all occurrences.
        players = transposed_role_refs.map{|role_refs| common_supertype(role_refs.map{|rr| rr.role.object_type})}
        raise "Constraint must cover matching roles" if players.compact.size < players.size

        readings_expanded = scrs.
          map do |scr|
            # verbaliser.verbalise_over_role_sequence(scr.role_sequence)
            # REVISIT: verbalise_over_role_sequence cannot do what we need here, because of the
            # possibility of subtyping steps in the constrained roles across the different scr's
            # The following code uses "players" and "constrained_roles" to create substitutions.
            # These should instead be passed to the verbaliser (one variable per index, role_refs for each).
            fact_types_processed = {}
            constrained_roles = scr.role_sequence.all_role_ref_in_order.map{|rr| rr.role}
            join_over, joined_roles = *Metamodel.plays_over(constrained_roles)
            constrained_roles.map do |constrained_role|
              fact_type = constrained_role.fact_type
              next nil if fact_types_processed[fact_type] # Don't emit the same fact type twice (in case of objectification step)
              fact_types_processed[fact_type] = true
              reading = fact_type.reading_preferably_starting_with_role(constrained_role)
              expand_constrained(verbaliser, reading, constrained_roles, players)
            end.compact * " and "
          end

        if scrs.size == 2 && c.is_mandatory
          puts "either " + readings_expanded*" or " + " but not both;"
        else
          mode = c.is_mandatory ? "exactly one" : "at most one"
          puts "for each #{players.map{|p| p.name}*", "} #{mode} of these holds:\n\t" +
            readings_expanded*",\n\t" + ';'
        end
      end

      def dump_subset_constraint(c)
        # If the role players are identical and not duplicated, we can simply say "reading1 only if reading2"
        subset_roles, subset_fact_types =
          c.subset_role_sequence.all_role_ref_in_order.map{|rr| [rr.role, rr.role.fact_type]}.transpose
        superset_roles, superset_fact_types =
          c.superset_role_sequence.all_role_ref_in_order.map{|rr| [rr.role, rr.role.fact_type]}.transpose
        transposed_role_refs = [c.subset_role_sequence, c.superset_role_sequence].map{|rs| rs.all_role_ref_in_order.to_a}.transpose

        verbaliser = ActiveFacts::CQL::Verbaliser.new
        transposed_role_refs.each { |role_refs| verbaliser.role_refs_have_subtype_steps role_refs }
        verbaliser.prepare_role_sequence c.subset_role_sequence
        verbaliser.prepare_role_sequence c.superset_role_sequence
        verbaliser.create_subscripts :normal

        puts \
          verbaliser.verbalise_over_role_sequence(c.subset_role_sequence) +
          "\n\tonly if " +
          verbaliser.verbalise_over_role_sequence(c.superset_role_sequence) +
          ";"
      end

      def dump_ring_constraint(c)
        # At present, no ring constraint can be missed to be handled in this pass
        puts "// #{c.ring_type} ring over #{c.role.fact_type.default_reading}"
      end

      def constraint_dump(c)
        case c
        when ActiveFacts::Metamodel::PresenceConstraint
          dump_presence_constraint(c)
        when ActiveFacts::Metamodel::RingConstraint
          dump_ring_constraint(c)
        when ActiveFacts::Metamodel::SetComparisonConstraint # includes SetExclusionConstraint, SetEqualityConstraint
          dump_set_comparison_constraint(c)
        when ActiveFacts::Metamodel::SubsetConstraint
          dump_subset_constraint(c)
        else
          "#{c.class.basename} #{c.name}: unhandled constraint type"
        end
      end

      # Find the common supertype of these object_types.
      def common_supertype(object_types)
        common = object_types[0].supertypes_transitive
        object_types[1..-1].each do |object_type|
          common &= object_type.supertypes_transitive
        end
        common[0]
      end

      #============================================================
      # Verbalisation functions for fact type and entity type definitions
      #============================================================

      def fact_readings_with_constraints(verbaliser, fact_type)
        fact_constraints = @presence_constraints_by_fact[fact_type]
        readings = []
        define_role_names = true
        fact_type.all_reading_by_ordinal.each do |reading|
          readings << expanded_reading(verbaliser, reading, fact_constraints, define_role_names)
          define_role_names = false     # No need to define role names in subsequent readings
        end
        readings
      end

      def expanded_reading(verbaliser, reading, fact_constraints, define_role_names)
        # Arrange the roles in order they occur in this reading:
        role_refs = reading.role_sequence.all_role_ref_in_order
        role_numbers = reading.text.scan(/\{(\d)\}/).flatten.map{|m| Integer(m) }
        roles = role_numbers.map{|m| role_refs[m].role }

        # Find the constraints that constrain frequency over each role we can verbalise:
        frequency_constraints = []
        value_constraints = []
        roles.each do |role|
          value_constraints <<
            if vc = role.role_value_constraint and !vc.ordered_dumped
              vc.ordered_dumped!
              vc.describe
            else
              nil
            end

          frequency_constraints <<
            if (role == roles.last)   # On the last role of the reading, emit any presence constraint
              constraint = fact_constraints.
                detect do |c|  # Find a UC that spans all other Roles
                  c.is_a?(ActiveFacts::Metamodel::PresenceConstraint) &&
                    !c.ordered_dumped &&  # Already verbalised
                    roles-c.role_sequence.all_role_ref.map(&:role) == [role]
                end
              constraint.ordered_dumped! if constraint
              constraint && constraint.frequency
            else
              nil
            end
        end

        expanded = verbaliser.expand_reading(reading, frequency_constraints, define_role_names, value_constraints)
        expanded = "it is not the case that "+expanded if (reading.is_negative)

        if (ft_rings = @ring_constraints_by_fact[reading.fact_type]) &&
           (ring = ft_rings.detect{|rc| !rc.ordered_dumped})
          ring.ordered_dumped!
          append_ring_to_reading(expanded, ring)
        end
        expanded
      end

      # Expand this reading, substituting players[i].name for the each role in the i'th position in constrained_roles
      def expand_constrained(verbaliser, reading, constrained_roles, players)
        # Make sure that we refer to the constrained players by their common supertype (as passed in)
        frequency_constraints = reading.role_sequence.all_role_ref.
          map do |role_ref|
            player = role_ref.role.object_type
            i = constrained_roles.index(role_ref.role)
            player = players[i] if i
            [ nil, player.name ]
          end
        frequency_constraints = [] unless frequency_constraints.detect{|fc| fc[0] != "some" }

        expanded = verbaliser.expand_reading(reading, frequency_constraints)
        expanded = "it is not the case that "+expanded if (reading.is_negative)
        expanded
      end

      def build_indices
        @presence_constraints_by_fact = Hash.new{ |h, k| h[k] = [] }
        @ring_constraints_by_fact = Hash.new{ |h, k| h[k] = [] }

        @vocabulary.all_constraint.each { |c|
            case c
            when ActiveFacts::Metamodel::PresenceConstraint
              fact_types = c.role_sequence.all_role_ref.map{|rr| rr.role.fact_type}.uniq  # All fact types spanned by this constraint
              if fact_types.size == 1     # There's only one, save it:
                # trace "Single-fact constraint on #{fact_types[0].concept.guid}: #{c.name}"
                (@presence_constraints_by_fact[fact_types[0]] ||= []) << c
              end
            when ActiveFacts::Metamodel::RingConstraint
              (@ring_constraints_by_fact[c.role.fact_type] ||= []) << c
            else
              # trace "Found unhandled constraint #{c.class} #{c.name}"
            end
          }
      end

    end
    publish_generator CQL, "Emit CQL, the Constellation Query Language"
  end

  module Metamodel
    class ValueType
      def as_cql
        parameters =
          [ length != 0 || scale != 0 ? length : nil,
            scale != 0 ? scale : nil
          ].compact
        parameters = parameters.length > 0 ? "("+parameters.join(",")+")" : ""

        "#{name
          } #{
            (is_independent ? '[independent] ' : '')
          }is written as #{
            (supertype || self).name
          }#{
            parameters
          }#{
            unit && " "+unit.name
          }#{
            transaction_phase && " auto-assigned at "+transaction_phase
          }#{
            concept.all_context_note_as_relevant_concept.map do |cn|
              cn.verbalise
            end.join("\n")
          }#{
            value_constraint && " "+value_constraint.describe
          };"
      end
    end

    class Unit
      def as_cql
        if !ephemera_url
          if coefficient
            # REVISIT: Use a smarter algorithm to switch to exponential form when there'd be lots of zeroes.
            coefficient.numerator.to_s('F') +

            if d = coefficient.denominator and d != 1
              "/#{d}"
            else
              ''
            end +

            ' '
          else
            '1 '
          end
        else
          ''
        end +

        all_derivation_as_derived_unit.
          sort_by{|d| d.base_unit.name}.
          # REVISIT: Sort base units
          # REVISIT: convert negative powers to division?
          map do |der|
            base = der.base_unit
            "#{base.name}#{der.exponent and der.exponent != 1 ? "^#{der.exponent}" : ''} "
          end*'' +

        if o = offset and o != 0
          "+ #{o.to_s('F')} "
        else
          ''
        end +

        "converts to #{name}#{plural_name ? '/'+plural_name : ''}" +

        (coefficient && !coefficient.is_precise ?  ' approximately' : '') +

        (ephemera_url ? " ephemera #{ephemera_url}" : '') +

        ';'
      end
    end

  end   # Metamodel

end
