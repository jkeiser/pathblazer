require 'pathname'
require 'pathblazer/errors'
require 'pathblazer/path_set'
require 'pathblazer/path_set/path_expression'
require 'pathblazer/path_set/char_expression'
require 'pathblazer/path_set/glob_format'

module Pathblazer
  class PathSet
    module Formats
      #
      # Differences:
      # 1. In bash, \/ is considered a path separator just as much as /.
      # 2. In bash, /// is the same as /.  We see empty paths.
      #
      class Generic
        def initialize(name, glob_format = {})
          @name = name
          @glob_format = GlobFormat.new(name, DEFAULT_GLOB_CHARS.merge(glob_format), {})
        end

        attr_reader :name

        def from(str)
          if str.is_a?(String) || str.is_a?(Pathname)
            glob_format.parse_glob(str)
          elsif str.is_a?(PathSet)
            PathSet.new(str.expression, str.absolute, str.trailing_separator)
          end
        end

        def to_glob(path)
          glob_format.construct_glob(path)
        end

        def to_regexp(path)
          /^#{construct_regexp(path, glob_format.ch[:path_sep])}$/
        end

        def to_s(path)
          to_glob(path)
        end

        DEFAULT_GLOB_CHARS = {
          :path_sep          => '/',
          :one               => '?',
          :star              => '*',
          :globstar          => '**',
          :escape            => '\\',
          :union_start       => '{',
          :union_end         => '}',
          :union_sep         => ',',
          :charset_start     => '[',
          :charset_end       => ']',
          :charset_invert    => '^',
          :charset_range_sep => '-'
        }

        protected

        attr_reader :glob_format

        def construct_regexp(path)
          case path
          when PathSet
            construct_regexp(path.expression)
          when String
            if path_separator && path.include?(path_separator)
              raise PathNotSupportedError(path, "Charsets including the path separator #{path_separator} cannot be turned into regexes")
            end
            Regexp.escape(path)
          when Array
            if path_separator && path.any? { |p| p.include?(path_separator) }
              raise PathNotSupportedError(path, "Charsets including the path separator #{path_separator} cannot be turned into regexes")
            end
            Regexp.escape(path.join(path_separator))
          when Charset
            if path == CharExpression::ANY
              path_separator ? "[^#{path_separator}]" : '.'
            else
              result = '['
              path.ranges.each do |min, max|
                if path_separator && min <= path_separator && path_separator <= max
                  raise PathNotSupportedError(path, "Charsets including the path separator #{path_separator} cannot be turned into regexes")
                end
                if min == max
                  result << Regexp.escape(min)
                else
                  result << "#{Regexp.escape(min)}-#{Regexp.escape(max)}"
                end
              end
              result << "]"
              result
            end
          when PathExpression::Sequence
            path.items.map { |item| construct_regexp(item) }.join(Regexp.escape('/'))
          when CharExpression::Sequence
            path.items.map { |item| construct_regexp(item) }.join('')
          when PathExpression::Union
            "(#{path.members.map { |item| construct_regexp(item) }.join('|')})"
          when CharExpression::Union
            "(#{path.members.map { |item| construct_regexp(item) }.join('|')})"
          when PathExpression::Repeat
            # We turn path expression: repeat into (A/)*
            "(#{construct_regexp(path.expression)}#{Regexp.escape("/")})#{repeat_modifier(path)}"
          when CharExpression::Repeat
            "(#{construct_regexp(path.expression)}})#{repeat_modifier(path)}"
          else
            raise UnsupportedPathError.new(path, "Unrecognized path expression #{path} (class #{path.class})!")
          end
        end
      end
    end
  end
end
