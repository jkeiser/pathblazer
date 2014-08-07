require 'pathname'

module Pathblazer
  class Path
    module Formats
      class Bash
        # TODO path lists, urls ...
        # TODO character sets
        # TODO extended globs? ?() *() +() @() !()
        def initialize(case_sensitive=true,path_separator='/')
          @case_sensitive = case_sensitive
          @path_separator = path_separator
          @top_level_regexp = /(\\.|\*\*|\*|\?|\[([^\]]|\\\])*\]|#{Regexp.escape(path_separator)}|\{)/
          @in_union_regexp =  /(\\.|\*\*|\*|\?|\[([^\]]|\\\])*\]|#{Regexp.escape(path_separator)}|\{|\{|,|\}))/
        end

        attr_reader :case_sensitive
        attr_reader :path_separator

        def from(str)
          if str.is_a?(String) || str.is_a?(Pathname)
            result, token, remaining = parse_matcher(str.to_s, top_level_regexp)
            Path.new(result, case_sensitive)
          elsif str.is_a?(Path)
            Path.new(str.matcher, case_sensitive)
          end
        end

        def to_regexp(path)
          /^#{construct_regexp(path.matcher)}$/
        end

        def to_glob(str)
          construct_glob(path.matcher)
        end

        def to_s(path)
          construct_glob(path.matcher)
        end

        protected

        attr_reader :top_level_regexp
        attr_reader :in_union_regexp

        #
        # A path matcher is:
        # - Array of strings: a series of exact paths
        # - PathSequence, containing path atoms (some of which may have a range > 1)
        # - PathUnion, an array of possible paths
        # - PathRepeat, which repeats a path matcher min to max (or infinity) times.
        # - PathIntersection, containing unresolved or unresolvable intersections between path matchers.
        #
        # A path atom is:
        # - A string (an exact path)
        # - A PathAtomMatcher, a series of character atoms
        # - A Star
        #
        def parse_matcher(remaining, regexp)
          matcher = Matcher::Empty
          while remaining
            str, token, remaining = next_match(remaining, regexp)
            matcher = Matcher.concat_atomic(matcher, str) if str != ''
            case token
            when :star
              matcher = Matcher::concat_atomic(matcher, Matcher::Star)
            when :globstar
              matcher = Matcher::concat_atomic(matcher, Matcher::Globstar)
            when :path_sep
              matcher = Matcher.concat(matcher, matcher)
              matcher = Matcher::Empty
            when :one
              matcher = Matcher::concat_atomic(matcher, Matcher::One)
            when :union_start
              union = Matcher::Nothing
              while remaining
                result, token, remaining = parse_matcher(remaining, IN_UNION)
                union = Matcher.union(union, result)
                break if token == :union_end
              end
              matcher = Matcher.concat_atomic(matcher, union)
            when :union_sep, :union_end
              break
            end
          end
          if remaining != ''
            matcher = Matcher.concat_atomic(matcher, remaining)
          end

          matcher
        end

        def next_match(str, regexp)
          built_string = ''
          while match = .match(str)
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
          return [ string + str, nil, nil ]
        end

        def construct_regexp(matcher)
          if matcher.is_a?(String)
            Regexp.escape(matcher)
          elsif matcher.is_a?(Array)
            matcher.map { |m| construct_regexp(m) }.join('')
          elsif matcher.is_a?(Hash)
            regexps = matcher.inject([]) do |r,key,value|
              key = [key] if !key.is_a?(Array)
              value = [value] if !value.is_a?(Array)
              r << construct_regexp(key + value)
              r
            end
            "(#{regexps.join('|')})"
          else
            case matcher
            when :star
              '[^#{Regexp.escape(path_separator)}]*'
            when :globstar
              '.*'
            when :one
              '[^#{Regexp.escape(path_separator)}]'
            when :path_sep
              Regexp.escape(path_separator)
            else
              raise "Unrecognized path matcher #{matcher} (class #{matcher.class})!"
            end
          end
        end

        def construct_glob(matcher)
          if matcher.is_a?(String)
            matcher.gsub(/[|*?{}[\]\\#{path_separator}]/, '\\\0').
          elsif matcher.is_a?(Array)
            matcher.map { |m| construct_glob(m) }.join('')
          elsif matcher.is_a?(Hash)
            regexps = matcher.inject([]) do |r,key,value|
              key = [key] if !key.is_a?(Array)
              value = [value] if !value.is_a?(Array)
              r << construct_glob(key + value)
              r
            end
            "{#{regexps.join(',')}}"
          else
            case matcher
            when :star
              '*'
            when :globstar
              '**'
            when :one
              '?'
            when :path_sep
              path_separator
            else
              raise "Unrecognized path matcher #{matcher} (class #{matcher.class})!"
            end
          end
        end
      end
    end
  end
end
