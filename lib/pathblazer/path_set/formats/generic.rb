require 'pathblazer/errors'
require 'pathblazer/path_set/path_expression'
require 'pathblazer/path_set/char_expression'
require 'pathblazer/path_set/glob_format'

module Pathblazer
  class PathSet
    module Formats
      class Generic
        def initialize(path_separator)
          @path_separator = '/'
          @glob_format = GlobFormat.generic
        end

        attr_reader :path_separator
        attr_reader :glob_format

        def construct_glob(path)
          glob_format.construct_glob(path)
        end

        def construct_regexp(path)
          case path.class
          when PathSet
            construct_regexp(path.path)
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
