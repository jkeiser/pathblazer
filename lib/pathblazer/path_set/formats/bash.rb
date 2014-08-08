require 'pathname'
require 'pathblazer/path_set'
require 'pathblazer/path_set/formats/generic'
require 'pathblazer/path_set/path_expression'
require 'pathblazer/path_set/char_expression'

module Pathblazer
  class PathSet
    module Formats
      class Bash < Generic
        # TODO path lists, urls ...
        # TODO character sets
        # TODO extended globs? ?() *() +() @() !()
        def initialize
          super('/')
          @top_level_regexp = /(\\.|\*\*|\*|\?|\[([^\]]|\\\])*\]|#{Regexp.escape(path_separator)}|\{)/
          @in_union_regexp =  /(\\.|\*\*|\*|\?|\[([^\]]|\\\])*\]|#{Regexp.escape(path_separator)}|\{|\{|,|\})/
        end

        def from(str)
          if str.is_a?(String) || str.is_a?(Pathname)
            result, token, remaining = parse_path(str.to_s, top_level_regexp)
            PathSet.new(result)
          elsif str.is_a?(Path)
            PathSet.new(str.expression)
          end
        end

        def to_regexp(path)
          PathExpression.to_regexp(path.expression, path_separator)
        end

        def to_glob(str)
          construct_glob(path.expression)
        end

        def to_s(path)
          construct_glob(path.expression)
        end

        protected

        attr_reader :top_level_regexp
        attr_reader :in_union_regexp

        def parse_path(remaining, regexp)
          path = PathExpression::EMPTY
          while remaining
            str, token, remaining = next_match(remaining, regexp)
            path = CharExpression.concat(path, str) if str != ''
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
                result, token, remaining = parse_path(remaining, IN_UNION)
                union << result
                break if token == :union_end
              end
              path = CharExpression.union(union)
            when :union_sep, :union_end
              break
            end
          end
          if remaining
            path = PathExpression.concat(path, remaining)
          end

          path
        end

        def next_match(str, regexp)
          built_string = ''
          while match = regexp.match(str)
            built_string << match.pre_match
            token = match.captures[0]
            str = match.post_match

            if token[0] == '\\'
              built_string << token[1]
            elsif token[0] == '['
              raise "charsets not yet supported: #{token}"
            else
              token = case token
                when '*'
                  :star
                when '**'
                  :globstar
                when '?'
                  :one
                when '/'
                  :path_sep
                when '{'
                  :union_start
                when ','
                  :union_sep
                when '}'
                  :union_end
                end
              return [ built_string, token, str ]
            end
          end

          # If we failed to match, return the rest of the string
          return [ built_string + str, nil, nil ]
        end
      end
    end
  end
end
