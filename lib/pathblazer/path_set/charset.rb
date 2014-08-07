module Pathblazer
  class PathSet
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
