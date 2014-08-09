module Pathblazer
  class PathSet
    class Charset
      # Ranges must be sorted and not intersecting.
      def initialize(*ranges)
        @ranges = Charset.init_ranges(ranges)
      end

      attr_reader :ranges

      UNICODE_MAX = 0x10FFFF
      UNICODE_MAX_CHAR = "\u10FFFF"

      def ==(other)
        other.is_a?(Charset) && ranges == other.ranges
      end

      def self.any
        Charset.new([0, 0x10FFFF])
      end

      def self.none
        Charset.new
      end

      def to_s
        if ranges == [ [ 0, UNICODE_MAX ] ]
          "."
        else
          "[#{ranges.map { |min,max| min==max ? Charset.from_codepoint(min) : "#{Charset.from_codepoint(min)}-#{Charset.from_codepoint(max)}" }.join(",")}]"
        end
      end

      def first
        ranges[0] ? Charset.from_codepoint(ranges[0][0]) : nil
      end

#      def each
#        ranges.each do |min, max|
#          min.upto(max) do |codepoint|
#            yield Charset.from_codepoint(codepoint)
#          end
#        end
#      end

      def size
        sum = 0
        ranges.each do |min,max|
          sum += max - min + 1
        end
        sum
      end

      def match?(ch)
        if ch.size == 1
          ranges.any? { |min,max| ch.codepoints[0] >= min && ch.codepoints[0] <= max }
        else
          false
        end
      end

      def intersect_pair(a, b)
        min = [ a[0], b[0] ].max
        max = [ a[1], b[1] ].min
        max >= min ? [ [ min, max ] ] : []
      end

      def &(other)
        if other.is_a?(String)
          return match?(other) ? Charset.new(other) : Charset.new
        end

        new_ranges = []
        index = other_index = 0
        while index < ranges.size && other_index < other.ranges.size
          new_ranges += intersect_pair(ranges[index], other.ranges)
          if other.ranges[other_index][0] < ranges[other_index][0]
            other_index += 1
          else
            index += 1
          end
        end
        Charset.new(new_ranges)
      end

      def |(other)
        # deduping will happen on the other side
        Charset.new(new_ranges+other_ranges)
      end

      def -(other)
        self & ~other
      end

      def ~()
        new_ranges = []
        new_min = 0
        ranges.each do |min, max|
          new_ranges << [ new_min, min-1 ] if new_min < min
          new_min = max+1
        end
        if new_min <= UNICODE_MAX
          new_ranges << [ new_min, UNICODE_MAX ]
        end
        Charset.new(*new_ranges)
      end

      def empty?
        ranges.size == 0
      end

      private

      def self.from_codepoint(codepoint)
        x = ''
        x << codepoint
        x
      end

      def self.init_ranges(ranges)
        new_ranges = ranges.map do |min,max|
          if min.is_a?(String)
            if min.size == 3 && min[1] == '-' && !max
              max = min[2]
              min = min[0]
            elsif min.size != 1
              raise "Passed #{min.inspect} to Charset.new!  Pass either a Unicode codepoint or a pair of single-character strings to Charset!"
            end
            min = min.codepoints[0]
          end
          if max.is_a?(String)
            if max.size != 1
              raise "Passed #{max.inspect} to Charset.new!  Pass either a Unicode codepoint or a pair of single-character strings to Charset!"
            end
            max = max.codepoints[0]
          end
          max ||= min
          [ min, max ]
        end

        # Sort by min, then dedup overlapping and consecutive ranges.
        new_ranges = new_ranges.sort_by { |min,max| min }
        new_ranges.each do |min,max|
          if new_ranges.size == 0 || min > new_ranges[-1][0]+1
            new_ranges << [ min, max ]
          else
            new_ranges[-1][1] = max if new_ranges[-1][1] < max
          end
        end
        new_ranges
      end
    end
  end
end
