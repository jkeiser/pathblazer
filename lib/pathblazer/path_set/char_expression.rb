require 'pathblazer/path_set/regular_expression'
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
      ANY = Charset.new([ [ 0, Integer::MAX ] ])
      STAR = Repeat.new(ANY)

      def self.intersect_exact_string(op)
        results = regular_intersect_exact_string(op)
        return results if results

        if op.b.is_a?(Charset)
          if op.b == ANY || op.b.match?(op.a[0])
            return [ operation.consume_b(op.a[0], op.a[1..])]
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
            return [ operation.consume_a(op.b[0], op.b[1..])]
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

      class Charset
        # Ranges must be sorted and not intersecting.
        def initialize(ranges)
          @ranges = ranges
        end

        attr_reader :ranges

        def match?(ch)
          ranges.any? { |min,max| ch >= min && ch <= max }
        end

        def &(other)
          new_ranges = []
          index = 0
          other_index = 0
          while index < ranges.size && other_index < other.ranges.size
            if other.ranges[other_index].min <= ranges[index].min
              if other.ranges[other_index].max >= ranges[index].min
                new_ranges << [ ranges[index].min,
                                [ other_ranges[index].max, ranges[index].max].min ]
              end
              other_index += 1
            else
              if ranges[index].max >= other.ranges[other_index].min
                new_ranges << [ other.ranges[other_index].min,
                                [ other_ranges[index].max, ranges[index].max].min ]
              end
              index += 1
            end
          end
          Charset.new(new_ranges)
        end

        def |(other)
          new_ranges = []
          index = 0
          other_index = 0
          current_range = nil
          while index < ranges.size && other_index < other.ranges.size
            if ranges[index][0] <= other.ranges[other_index][0]
              range = range[index][0]
              index += 1
            else
              range = other.ranges[other_index][0]
              other_index += 1
            end

            # If there is a gap between the ranges, we have a new range.
            if !current_range || range[0] > current_range[1]+1
              new_ranges << current_range if current_range
              current_range = range[0]
            end
          end
          new_ranges << current_range if current_range
          new_ranges
        end

        def empty?
          ranges.size == 0
        end
      end
    end
  end
end
