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
        @top_level_regexp = token_regexp(TOP_LEVEL_GROUP)
        @in_union_regexp  = token_regexp(UNION_GROUP)
      end

      TOP_LEVEL_GROUP = [ :path_sep, :one, :star, :globstar, :union_start, :charset_start ]
      UNION_GROUP = TOP_LEVEL_GROUP + [ :union_sep, :union_end ]
      CHARSET_GROUP = [ :charset_invert, :charset_range_sep, :charset_end ]

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
            ch[:one]
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
          when :charset_start
            result, token, remaining = parse_charset(remaining)
            path = CharExpression.concat(path, result)
          when nil
            # When no more tokens can be found
          else
            raise "Unsupported token #{token.inspect}!"
          end
        end

        # Empty paths are disallowed: when we get an empty path, treat it as
        # "current directory"
        path = PathExpression::EMPTY if path == CharExpression::EMPTY

        [ path, nil, remaining ]
      end

      def parse_charset(remaining)
        if remaining[0] == ch[:charset_invert]
          invert = true
          index = 1
        else
          index = 0
        end

        ranges = []
        token = nil
        while index < remaining.length
          if remaining[index] == ch[:charset_end]
            index += 1
            token = :charset_end
            break
          end
          if remaining[index] == ch[:escape] && index+1 < remaining.size
            index += 1
          end
          if remaining[index+1] == ch[:charset_range_sep] && remaining[index+2]
            if remaining[index+2] == ch[:escape]
              if remaining[index+3]
                ranges << [ remaining[index], remaining[index+3] ]
                index += 4
              else
                ranges << remaining[index]
                index += 1
              end
            else
              ranges << [ remaining[index], remaining[index+2] ]
              index += 3
            end
          else
            ranges << remaining[index]
            index += 1
          end
        end

        if invert
          charset = CharExpression.inverted_charset(*ranges)
        else
          charset = CharExpression.charset(*ranges)
        end
        remaining = remaining[index..-1]
        remaining = nil if remaining == ''
        return charset, token, remaining
      end

      attr_reader :glob_escape_regexp
      attr_reader :top_level_regexp
      attr_reader :in_union_regexp

      def next_match(str, regexp)
        built_string = ''
        while match = regexp.match(str)
          built_string << match.pre_match
          token_str = match.captures[0]
          str = match.post_match

          if token_str[0] == ch[:escape]
            built_string << token_str[1]
          else
            token = tokens[token_str]
            if !token
              raise "Unsupported token match #{token_str}!"
            end
            return [ built_string, token, str ]
          end
        end

        # If we failed to match, return the rest of the string
        return [ built_string + str, nil, nil ]
      end

      def token_regexp(tokens)
        matchers = tokens.map { |token| ch[token] }.sort_by { |v| v.length }.reverse.map { |v| Regexp.escape(v) }
        if ch[:escape]
          matchers.unshift("#{Regexp.escape(ch[:escape])}.")
        end
        /(#{matchers.join('|')})/
      end
    end
  end
end
