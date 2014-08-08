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

      #
      # Concatenate expressions with no path separator between them and produce
      # a single result expression.  Will detect single-element concatenates
      # and handle EMPTY correctly.
      #
      # Paths have
      # porous borders, so that a{b/c}d == ab/cd.  concat will detect path
      # sequences and smoosh the a into the b and the c into the d, so to speak.
      #
      def self.concat(*expressions)
        result_paths = []
        current_path = []
        expressions.each_with_index do |expression, index|
          # Concatenating EMPTY + a = a
          if current_path[-1] == EMPTY
            current_path.pop
          end
          # Concatenating a + EMPTY = a
          next if expression == EMPTY && current_path.size > 0

          case expression
          when Sequence
            current_path += expression.items
          when ExactSequence
            # Smoosh strings together
            if current_path[-1].is_a?(ExactSequence)
              current_path[-1] += expression
            else
              current_path << expression
            end
          when PathExpression::Sequence
            # Paths have porous edges, and we've been told to atomically concatenate
            # this path with the previous one.  We smoosh previous_path.last up
            # against new_path.first, and put the remaining paths into result_paths
            # (the last path will be eligible for further smooshing).
            if expression.items.size >= 1
              current_path << expression.items[0]
              result_paths << build_sequence(current_path)
              if expression.items.size >= 2
                result_paths += expression.items[1..-2]
                current_path = [ expression.items[-1] ]
              end
            end
          when PathExpression::ExactSequence
            if expression.size >= 1
              current_path << expression[0]
              result_paths << build_sequence(current_path)
              if expression.size >= 2
                result_paths += expression[1..-2]
                current_path = [ expression[-1] ]
              end
            end
          when Repeat, Union, Charset, PathExpression::Repeat, PathExpression::Union
            current_path << expression
          when NOTHING
            return NOTHING
          else
            raise ParseError, "Unknown type #{expression.type} passed to concat: #{expression.inspect}"
          end
        end
        result_paths << build_sequence(current_path) if current_path.size > 0
        result = if result_paths.size == 0
          EMPTY
        elsif result_paths.size == 1
          result_paths[0]
        else
          PathExpression.concat(*result_paths)
        end
        result
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
