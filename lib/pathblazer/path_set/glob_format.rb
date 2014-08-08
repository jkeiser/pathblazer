require 'pathblazer/path_set'
require 'pathblazer/path_set/path_expression'
require 'pathblazer/path_set/char_expression'

module Pathblazer
  class PathSet
    class GlobFormat
      def initialize(name, ch)
        @name = name
        @ch = ch
        @tokens = Hash[ch.map(&:reverse)]
        @glob_escape_regexp = /(#{ch.values.map { |v| Regexp.escape(v) }.join('|')})/
        @top_level_regexp = token_regexp(:union_sep, :union_end)
        @in_union_regexp  = token_regexp
      end

      attr_reader :name
      # Map from token symbols to characters
      attr_reader :ch
      # Map from characters to token symbols
      attr_reader :tokens

      def self.generic
        @bash ||= new('generic', GlobChars.new({}))
      end

      def escape(str)
        str.gsub(glob_escape_regex, '\\\1')
      end

      def construct_glob(path)
        case path
        when PathSet
          construct_glob(path.expression)

        when String
          if ch[:path_sep] && path.include?(ch[:path_sep])
            raise PathNotSupportedError(path, "Charsets including the path separator #{ch[:path_sep]} cannot be turned into globs in format #{name}")
          end
          escape(path)

        when Array
          if ch[:path_sep] && path.any? { |p| p.include?(ch[:path_sep]) }
            raise PathNotSupportedError(path, "Charsets including the path separator #{ch[:path_sep]} cannot be turned into globs in format #{name}")
          end
          escape(path.join(ch[:path_sep]))

        when Charset
          if path == CharExpression::ANY
            ch[:any]
          else
            result = ch[:charset_start]
            path.ranges.each do |min, max|
              if ch[:path_sep] && min <= ch[:path_sep] && ch[:path_sep] <= max
                raise PathNotSupportedError(path, "Charsets including the path separator #{ch[:path_sep]} cannot be turned into globs in format #{name}")
              end
              if min == max
                result << escape(min)
              else
                result << "#{escape(min)}#{ch[:charset_range_sep]}#{escape(max)}"
              end
            end
            result << ch[:charset_end]
            result
          end

        when PathExpression::Sequence
          path.items.map { |item| construct(item) }.join(escape(ch[:path_sep]))
        when CharExpression::Sequence
          path.items.map { |item| construct(item) }.join('')
        when PathExpression::Union
          "#{ch[:union_start]}#{path.members.map { |item| construct(item) }.join(ch[:union_sep])}#{ch[:union_end]}"
        when CharExpression::Union
          "#{ch[:union_start]}#{path.members.map { |item| construct(item) }.join(ch[:union_sep])}#{ch[:union_start]}"
        when PathExpression::Repeat
          if path != PathExpression::GLOBSTAR
            raise UnsupportedPathError.new(path, "Only #{ch[:star]} and #{ch[:globstar]} repeats are supported in format #{name}")
          end
          if !ch[:globstar]
            raise UnsupportedPathError.new(path, "Globstar not supported in format #{name}")
          end
          # We turn path expression: repeat into (A/)*
          ch[:globstar]
        when CharExpression::Repeat
          if path != PathExpression::ANY
            raise UnsupportedPathError.new(path, "Only #{ch[:star]} and #{ch[:globstar]} repeats are supported in format #{name}")
          end
          ch[:star]
        else
          raise UnsupportedPathError.new(path, "Unrecognized path expression #{path} (class #{path.class})!")
        end
      end

      def parse_glob(path)
        result, token, remaining = parse_path(path, top_level_regexp)
        PathSet.new(result == CharExpression::EMPTY ? PathExpression::EMPTY : result)
      end

      protected

      def parse_path(remaining, regexp)
        path = CharExpression::EMPTY
        while remaining
          str, token, remaining = next_match(remaining, regexp)
          path = CharExpression.concat(path, str)
          case token
          when :star
            path = CharExpression.concat(path, CharExpression::STAR)
          when :globstar
            path = CharExpression.concat(path, PathExpression::GLOBSTAR)
          when :path_sep
            path = PathExpression.concat(path, CharExpression::EMPTY)
          when :one
            path = CharExpression.concat(path, CharExpression::ANY)
          when :union_start
            union = []
            while remaining
              result, token, remaining = parse_path(remaining, in_union_regexp)
              union << result
              break if token == :union_end
            end
            path = CharExpression.concat(path, CharExpression.union(*union))
          when :union_sep, :union_end
            return path, token, remaining
          end
        end

        # Empty paths are disallowed: when we get an empty path, treat it as
        # "current directory"
        path = PathExpression::EMPTY if path == CharExpression::EMPTY

        [ path, nil, remaining ]
      end

      attr_reader :glob_escape_regexp
      attr_reader :top_level_regexp
      attr_reader :in_union_regexp

      def next_match(str, regexp)
        built_string = ''
        while match = regexp.match(str)
          built_string << match.pre_match
          token = match.captures[0]
          str = match.post_match

          if token[0] == ch[:escape]
            built_string << token[1]
          elsif token[0] == ch[:charset_start]
            raise "charsets not yet supported: #{token}"
          else
            return [ built_string, tokens[token], str ]
          end
        end

        # If we failed to match, return the rest of the string
        return [ built_string + str, nil, nil ]
      end

      def token_regexp(*except)
        matchers = ch.select { |k,v| !except.include?(k) && k != :escape }.sort_by { |k,v| v.length }.reverse.map { |k,v| Regexp.escape(v) }
        if !except.include?(:escape) && ch[:escape]
          matchers.unshift("#{Regexp.escape(ch[:escape])}.")
        end
        /(#{matchers.join('|')})/
      end
    end
  end
end
