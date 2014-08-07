require 'pathblazer/path_set/path_expression'
require 'pathblazer/path_set/char_expression'

module Pathblazer
  class PathSet
    module Formats
      class GlobFormat
        def initialize(name, ch)
          @name = name
          @ch = ch || GlobChars.generic
        end

        attr_reader :name
        attr_reader :ch

        def self.bash
          @bash ||= new('generic', GlobChars.new)
        end

        def escape(str)
          str.gsub(escape_regex, '\\\1')
        end

        def construct_glob(path)
          case path.class
          when PathSet
            construct_glob(path.path)

          when String
            if ch.path_sep && path.include?(ch.path_sep)
              raise PathNotSupportedError(path, "Charsets including the path separator #{ch.path_sep} cannot be turned into globs in format #{name}")
            end
            escape(path)

          when Array
            if ch.path_sep && path.any? { |p| p.include?(ch.path_sep) }
              raise PathNotSupportedError(path, "Charsets including the path separator #{ch.path_sep} cannot be turned into globs in format #{name}")
            end
            escape(path.join(ch.path_sep))

          when Charset
            if path == CharExpression::ANY
              ch.any
            else
              result = ch.charset_start
              path.ranges.each do |min, max|
                if ch.path_sep && min <= ch.path_sep && ch.path_sep <= max
                  raise PathNotSupportedError(path, "Charsets including the path separator #{ch.path_sep} cannot be turned into globs in format #{name}")
                end
                if min == max
                  result << escape(min)
                else
                  result << "#{escape(min)}#{ch.charset_range_sep}#{escape(max)}"
                end
              end
              result << ch.charset_end
              result
            end

          when PathExpression::Sequence
            path.items.map { |item| construct(item) }.join(escape(ch.path_sep))
          when CharExpression::Sequence
            path.items.map { |item| construct(item) }.join('')
          when PathExpression::Union
            "#{ch.union_start}#{path.members.map { |item| construct(item) }.join(ch.union_sep)}#{ch.union_end}"
          when CharExpression::Union
            "#{ch.union_start}#{path.members.map { |item| construct(item) }.join(ch.union_sep)}#{ch.union_start}"
          when PathExpression::Repeat
            if path != PathExpression::GLOBSTAR
              raise UnsupportedPathError.new(path, "Only #{ch.star} and #{ch.globstar} repeats are supported in format #{name}")
            end
            if !ch.globstar
              raise UnsupportedPathError.new(path, "Globstar not supported in format #{name}")
            end
            # We turn path expression: repeat into (A/)*
            ch.globstar
          when CharExpression::Repeat
            if path != PathExpression::ANY
              raise UnsupportedPathError.new(path, "Only #{ch.star} and #{ch.globstar} repeats are supported in format #{name}")
            end
            ch.star
          else
            raise UnsupportedPathError.new(path, "Unrecognized path expression #{path} (class #{path.class})!")
          end
        end
      end

      class GlobChars < Hash
        def initialize(chars)
          super(DEFAULTS.merge(chars))
        end

        # Defaults are bash
        DEFAULTS = {
          :path_sep          => '/',
          :any               => '?',
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

        DEFAULTS.each_key do |key|
          define_method(key) do
            self[key]
          end
        end
      end
    end
  end
end
