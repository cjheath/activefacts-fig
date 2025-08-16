module ActiveFacts
  module FIG
    module FIG
      module FactType
        def typelist
          ([h]+l.elements.map(&:typename)).map(&:ast)
        end
        def ast
          { type: 'FactType', predicate: predicate.ast, typenames: typelist }
        end
      end

      module AlternatePredicate
        def roleNumbers
          if l.empty?
            [2, 1]
          else
            l.r.elements.map(&:roleNumber).map(&:text_value).map{|s|Integer(s)}
          end
        end
        def ast
          { type: 'AlternatePredicate', p1: p1.ast, p2: p2.ast, roleNumbers: roleNumbers }
        end
      end

      module RoleNaming
        def ast
          { type: 'RoleNaming', role: predicateRole.ast, name: roleName.value }
        end
      end

      module Mandatory
        def ast
          { type: 'Mandatory', typename: typename.ast,
            roles: ([predicateRole]+r.elements.map(&:predicateRole)).map(&:ast)
          }
        end
      end

      module Unique
        def ast
          { type: 'Unique', roles: ([predicateRole] + r.elements.map(&:predicateRole)).map(&:ast) }
        end
      end

      module SimpleIdentification
        def ast
          { type: 'SimpleIdentification', typename: typename.ast, role1: pr1.ast, role2: pr2.ast }
        end
      end

      module ExternalUnique
        def ast
          { type: 'ExternalUnique',
            # typename: typename.ast,
            roles: ([pr0] + r.elements.map(&:pr)).map(&:ast)
          }
        end
      end

      module ExternalIdentification
        def ast
          { type: 'ExternalIdentification', typename: typename.ast,
            roles: ([pr0]+r.elements.map(&:pr)).map(&:ast)
          }
        end
      end

      module Frequency
        def ast
          { type: elements[0].empty? ? 'Frequency' : 'ExternalFrequency',
            roles: ([pr0]+r.elements.map(&:pr)).map(&:ast),
            range: frequencyRanges.ast
          }
        end
      end

      module FrequencyRange1
        def ast
          lo = Integer(l.text_value)
          return lo if g.empty?
          hi = g.h.empty? ? nil : Integer(g.h.text_value)
          lo..hi
        end
      end

      module FrequencyRange2
        def ast
          nil..Integer(h.text_value)
        end
      end

      module FrequencyRanges
        def ast
          [fr0.ast] + frn.elements.map(&:frequencyRange).map(&:ast)
        end
      end

      module Subtypes
        def ast
          if t1.respond_to? :t0
            {
              type: 'Subtypes',
              super: t2.ast,
              subtypes: [t1.t0.ast] + t1.tn.elements.map(&:typename).map(&:ast)
            }
          else
            { type: 'Subtypes', super: t2.ast, subtypes: [t1.ast] }
          end
        end
      end

      module ESubtypes
        def ast
          { type: elements[0].text_value+'Subtypes', super: sup.ast,
            subtypes: ([sub0]+l.elements.map(&:typename)).map(&:ast)
          }
        end
      end

      module Comparison
        def ast
          { type: elements[0].text_value, role1: pr1.ast, role2: pr2.ast }
        end
      end

      module RingConstraint
        def ast
          { type: 'RingConstraint', ringType: elements[0].text_value, role1: pr1.ast, role2: pr2.ast }
        end
      end

      module TypeCardinality
        def ast
          { type: 'TypeCardinality', typename: typename.ast, cardinality: r.ast }
        end
      end

      module RoleCardinality
        def ast
          { type: 'RoleCardinality', role: predicateRole.ast, cardinality: r.ast }
        end
      end

      module CardinalityRange
        def ast
          ival = Integer(i.text_value)
          j.empty? ? ival : ival..(Integer(j.text_value) rescue nil)
        end
      end

      module Objectifies
        def ast
          { type: 'Objectifies', typename: typename.ast, predicate: predicate.ast }
        end
      end

      module SubTypeRule
        def ast
          { type: 'SubTypeRule', semi: elements[0].text_value == 'SubTypeSemiRule',
            typename: typename.ast, path: path.ast
          }
        end
      end

      module FactTypeRule
        def ast
          { type: 'FactTypeRule', semi: elements[0].text_value == 'FactTypeSemiRule',
            predicate: predicate.ast, path: ([path]+p.elements.map(&:path)).map(&:ast)
          }
        end
      end

      module JoinPath
        def ast
          { type: 'JoinPath', predicate: predicate.ast, roles: rolePairs.ast }
        end
      end

      module PathDisjunction
        def ast
          return pathConjunction.ast if f.empty?
          { type: 'PathDisjunction', paths: ([pathConjunction]+f.elements.map(&:pathConjunction)).map(&:ast) }
        end
      end

      module PathConjunction
        def ast
          return pathException.ast if f.empty?
          { type: 'PathConjunction', paths: ([pathException]+f.elements.map(&:pathException)).map(&:ast) }
        end
      end

      module PathException
        def ast
          debugger unless pathSimple.respond_to? :ast
          return pathSimple.ast if f.empty?
          { type: 'PathException', paths: ([pathSimple]+f.elements.map(&:pathSimple)).map(&:ast) }
        end
      end

      module PathSimple
        def ast
          { type: 'PathSimple', content: text_value, REVISIT: "Finish Path ASTs" }
        end
      end

=begin
      module PathSteps
        def ast
          { type: 'PathStep', start: predicateRole.ast,
            steps: p.elements.map{|l| [l.predicateRole.ast, l.path.ast] }
          }
        end
      end
=end

    end
  end
end
