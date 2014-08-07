require 'pathblazer/path_set/regular_expression'
require 'pathblazer/path_set/charset'
require 'set'

module Pathblazer
  class PathSet
    module CharExpression
      include RegularExpression

      NOTHING = :nothing
      EMPTY = ''
      Union = Struct.new(:members)
      Sequence = Struct.new(:items)
      Repeat = Struct.new(:expression, :min, :max)
      ExactSequence = String
      ANY = Charset.new([ [ '\0', '\u10FFFF' ] ]) # 10FFFF is the biggest unicode char
      STAR = Repeat.new(ANY)

      def self.intersect_exact_string(op)
        results = regular_intersect_exact_string(op)
        return results if results

        if op.b.is_a?(Charset)
          if op.b == ANY || op.b.match?(op.a[0])
            return [ operation.consume_b(op.a[0], op.a[1..-1])]
          end
        end

        raise "No character intersector written for #{op.a.class} and #{op.a.class}"
      end

      def self.intersect_charset(op)
        if op.b.is_a?(Charset)
          intersected = Charset.new(op.a & op.b)
          if intersected.empty?
            return [ ]
          else
            return [ operation.consume_both(intersected) ]
          end
        end

        if op.b.is_a?(ExactString)
          if op.a == ANY || op.a.match?(op.b[0])
            return [ operation.consume_a(op.b[0], op.b[1..-1])]
          end
        end

        raise "No character intersector written for #{op.a.class} and #{op.a.class}"
      end

      # Our atoms are characters.  But we generally deal in strings.
      def self.advance_intersect(op)
        results = regular_advance_intersect(op)
        return results if results

        if op.a.is_a?(Charset)
          return intersect_charset(op)
        elsif op.b.is_a?(Charset)
          return intersect_charset(op.swap)
        end

        raise "No character intersector written for #{op.a.class} and #{op.a.class}"
      end

      def self.concat(*expressions)
        if expressions.size == 0
          return EMPTY
        end

        result = []
        expressions.each do |expression|
          if expression.is_a?(Sequence)
            result += expression.items
          elsif expression.is_a?(ExactSequence)
            result += expression
          elsif expression == NOTHING
            return NOTHING
          else
            result << expression
          end
        end
        if result.size == 0
          return EMPTY
        end
        result.all? { |m| m.is_a?(ExactSequence) } ? result.join('') : Sequence.new(result, dirty)
      end

      def self.union(*path)
        result = []
        paths.each do |path|
          if path.is_a?(Union)
            result += path.members
          else
            result << path
          end
        end
        if result.size == 0
          return NOTHING
        elsif result.size == 1
          return result[0]
        end
        Union.new(result)
      end

      def self.repeat(expression, min, max)
        if min == 1 && max == 1
          expression
        elsif max == 0
          EMPTY
        elsif max && min > max || expression == NOTHING
          NOTHING
        else
          Repeat.new(expression, min, max)
        end
      end
    end
  end
end
