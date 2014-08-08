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

        result = [[]]
        expressions.each_with_index do |expression, index|
          case expression
          when Sequence
            result[-1] += expression.items
          when ExactSequence
            result[-1] << expression
          when PathExpression::Sequence
            if expression.items.size > 0
              result << expression.items
              result << []
            end
          when PathExpression::ExactSequence
            if expression.size > 0
              result << expression
              result << []
            end
          when Repeat, Union, Charset, PathExpression::Repeat, PathExpression::Union
            result[-1] << expression
          else
            if expression == NOTHING
              return NOTHING
            else
              raise ParseError, "Unknown type #{expression.type} passed to concat: #{expression.inspect}"
            end
          end
        end
        if result.size == 1
          build_sequence(result[0])
        else
          result = atomic_sandwich(result)
        end
      end

      def self.build_sequence(array)
        if array.size == 0
          return EMPTY
        end
        if array.size == 1
          return array[0]
        end
        array.all? { |e| e.is_a?(ExactSequence) } ? array.join('') : Sequence.new(array)
      end

      def self.atomic_sandwich(slices)
        result = []
        slices.each do |slice|
          if result.size == 0
            result << slice if slice.size > 0
          else
            result += smoosh(result[-1]||[], slice)
          end
        end
        result = result.map { |r| build_sequence(r) }
        PathExpression.concat(*result)
      end

      # Smoosh two arrays of atomics together, returning head, smooshed, and tail.
      def self.smoosh(a, b)
        if a.size == 0
          if b.size == 0
            []
          else
            [ b[0], b[1..-1]]
          end
        elsif b.size == 0
          [ a[0..-2], a[-1] ]
        else
          [ a[0..-2], concat(a[-1], b[0]), b[1..-1] ]
        end
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
