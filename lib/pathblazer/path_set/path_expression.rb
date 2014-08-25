require 'pathblazer/path_set/regular_expression'
require 'pathblazer/path_set/char_expression'

module Pathblazer
  class PathSet
    #
    # Path expressions are expressions that match paths.  Each PathSet is a
    # single path expression.
    #
    # The simplest path expression is an exact one: [ 'a', 'b', 'c'] = a/b/c.
    # More complex path expressions, with union, repeat, and sequence, can be
    # constructed.
    #
    # Path expressions are operating-system agnostic, and designed to be easily
    # parseable into the common format without losing information about ordering
    # (preserving what the user typed is important for later printing).
    #
    # === Non-"file like" Empty Paths, Names, and Path Sets
    #
    # Due to its interfacing with many systems (many of which are not filesystems--
    # databases come to mind), Pathblazer allows for some paths that are not
    # traditionally allowed in a file system.  The file system parsers are aware
    # of this and do not construct such paths.
    #
    # Paths are 8-bit clean (path entries can have any characters in them,
    # including \0, / and \) and any path separator (or none) can be used to
    # build them.  It is left to the parser or the file system being talked to
    # to decide their path separator.
    #
    # Paths can be empty (empty array []), which corresponds to the root of a
    # path system: if your current directory is [], and you ask for 'x.txt', you
    # will get [ 'x.txt' ].
    #
    # Path expressions also allow for empty path names (the empty string ''): If
    # your current directory is [ 'a', 'b' ] (/a/b), and you ask for the file
    # named '', you will get [ 'a', 'b', '' ].
    #
    # == Representations
    #
    # Path expressions operate at two levels:
    #
    # - The path level (the top level), where we consider only path boundary
    #   separation to be important and all atoms are assumed to be surrounded
    #   by path boundaries.  Having a layer for this enables fast matching of
    #   paths, simple path walking and functions like chdir.
    # - The character level, where we walk character by character and
    #   string by string.  This level can be thought of as a regex that does not
    #   cross path boundaries, and indeed a regex can be constructed for any
    #   character expression.  We have our own internal representation to make
    #   parsing a bit easier and due to the fact that Ruby regexes cannot be
    #   manipulated in some of the ways we need, such as intersection.
    #
    # For ease of use in typical path operations, and to make it easy to interface
    # with multiple actual storage systems, the path expressions run at two
    # levels: the path expressions themselves, which always match on entire
    # directory names, and the character expresisons, which can match the
    # directory names character by character.  Character expressions are not
    # allowed to cross path boundaries.
    #
    # PathExpressions implement == and hash codes, so can be used as keys in
    # hashtables or sets.
    #
    # == Available Expressions
    #
    # Pathblazer splits paths into two levels of matcher: path matchers, and
    # character matchers.  Character matchers are like a regex.  Path matchers
    # are a level up: they always match whole directory names.
    #
    # Available path expressions include:
    # - [ 'a', 'b', 'c' ] - the path a/b/c.  Only strings are allowed in the
    #   array.  This form is used for efficiency, since these strings are common.
    # - ANY - matches any single path.  Equivalent to CharExpression.STAR.
    # - GLOBSTAR - matches from 0 to n paths (used for recursive digging).
    # - PathExpression.Sequence: a sequence of paths, with path separators in
    #   between them.
    #   Sequence{items = [ 'a', ANY, 'b' ]} = a/*/b.  Paths in the sequence may
    #   be any expression (and do not have to be a single path):
    #   Sequence{items = [ GLOBSTAR, 'bin' ]} = **/bin.
    # - PathExpression.Repeat: a repeat of a path expression, from m to n (or
    #   infinite), with path separators in between.  Repeat(a/*, 0, 10) will
    #   match empty, a/*, a/*/a/*, a/*/a/*/a/*, ...
    # - PathExpression.Union: a union of paths. Union(a, b/*, d)
    #
    # The next layer down are character expressions--they generally don't need
    # to be invoked, but some path globs need them.  If you are using a*b, **.txt,
    # [A-za-z], or other similar combinations, you are invoking a character
    # expression.
    #
    # == Implementing Parsers
    #
    # Different OS's have different standards for their path and path match
    # expressions:
    # - http://en.wikipedia.org/wiki/Path_(computing)#Representations_of_paths_by_operating_system_and_shell
    # - http://en.wikipedia.org/wiki/Glob_(programming)#Syntax
    #
    # Pathblazer implements the "generic" parser that will try as hard as it can
    # to read all of these, but OS- and shell-specific format parsers will
    # always be needed.
    #
    # PathExpression tries to make it easy to construct new parsers, to preserve
    # user input for later printing, and to create correct and efficient
    # expressions.  Generally parsers will read their input and call methods in
    # PathExpression and CharExpression like concat, union, and repeat.
    #
    # When implementing a parser that creates PathExpressions, you should
    # generally take advantage of PathExpression/CharExpression.concat//union/repeat,
    # instead of trying to construct them yourself, as they provide useful
    # optimizations.  They also take care not to lose the actual shape of the
    # parsed path, so that when it is written back out, it looks like what the
    # user entered in the first place.
    #
    # The bash parser does things a bit like this:
    # A/B (e.g. docs/*.txt): PathExpression.concat(A, B)
    # AB (e.g. *.txt): CharExpression.concat(A, B)
    # {A,B,C}: CharExpression.union(A,B,C)
    # *: CharExpression.STAR
    # **: PathExpression.GLOBSTAR
    # [A-Za-z_-]: CharExpression.union(...)
    #   A-Z: CharExpression.charset('A', 'Z')
    #   a-z: CharExpression.charset('a', 'z')
    #   _: '_'
    #   -: '-'
    #
    # == Available Functions
    #
    # The available construction functions in PathExpression:
    # - concat(a, b, ...) - concatenate expressions together with path separators
    #   assumed between them. a + b = a/b.  Will create string arrays for exact
    #   paths, deal with empty and single sequences, and generally behave well.
    # - union(a, b, ...) - union xpressions, such that either expression is part
    #   of the path set.
    # - repeat(expression, m, n) - repeat path from m to n
    # - intersect(a, b) - intersect two paths, yielding a path that matches only
    #   the paths in both of them.
    # - cd(a, b) - "cd b" relative to a.  Returns a list of expressions that
    #   represent the current directory, along with what remains of a.
    #   cd(a/b/c, a) == [ [ a, b/c ] ]
    #   cd({a/b/c,x/y/*/z,**.txt},*}, a) == [ [ a, b/c ], [ x, y/*/z ], [ *, **.txt ] ]
    #
    # These methods are smart enough to look inside and construct sane and
    # efficient expressions: concat('a', concat('b', 'c')) yields [ 'a', 'b', 'c' ],
    # not [ 'a', [ 'b', 'c' ] ].
    #
    # CharExpression construction functions are also needed:
    #

    module PathExpression
      include RegularExpression

      NOTHING = :nothing
      EMPTY = []
      Union = Struct.new(:members) do
        def to_s
          "Path(#{members.map { |m| m.to_s }.join(" | ")})"
        end
      end
      Sequence = Struct.new(:items) do
        def to_s
          "Path(#{items.map { |m| m.to_s }.join(", ")})"
        end
      end
      Repeat = Struct.new(:expression, :min, :max) do
        def to_s
          if min == 0 && !max
            if expression == ANY
              '**'
            else
              "Path(#{expression})*"
            end
          else
            "Path(#{expression}){#{min},#{max}}"
          end
        end
      end
      ExactSequence = Array
      ANY = CharExpression::STAR
      GLOBSTAR = Repeat.new(ANY, 0, nil)
      # TODO dot and dotdot

      # Concatenate paths with path separators between them
      def self.concat(*paths)
        result = []
        paths.each do |path|
          case path
          when Sequence
            result += path.items
          when ExactSequence
            result += path
          when Repeat, Union, CharExpression::Sequence, CharExpression::ExactSequence, CharExpression::Repeat, CharExpression::Union, Charset
            result << path
          when NOTHING
            return NOTHING
          else
            raise "Unknown type #{path.type} passed to concat: #{path.inspect}"
          end
        end
        if result.size == 0
          return EMPTY
        elsif result.size == 1
          return result[0]
        end
        result = result.all? { |m| m.is_a?(String) } ? result : Sequence.new(result)
        result
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
        else
          Repeat.new(expression, min, max)
        end
      end

      def self.descend(expression)
        case expression
        when PathExpression::Sequence
          result = EMPTY
          expression.items.each_with_index do |item, index|
            head, tail = descend(item)
            result = concat(result, head)
            if range(head)[0] > 0
              return [ head, concat(expression.items[index+1..-1]) ]
            end
          end
          return [ result, EMPTY ]

        when PathExpression::ExactSequence
          [ expression[0], expression[1..-1] ]

        when PathExpression::Union
          heads = Set.new
          tails = Set.new
          expression.members.each do |child|
            head, tail = descend(child)
            heads << head
            tails << tail
          end
          [ union(heads), union(tails) ]

        when PathExpression::Repeat
          if expression.max && expression.max == 1
            [ expression, EMPTY ]
          else
            [ repeat(expression.expression, ) ]
          end
        end
      end

      def self.ascend(expression)
      end
    end
  end
end
