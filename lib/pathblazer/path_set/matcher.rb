require 'pathblazer/path_set/path_expression/intersect'

module Pathblazer
  class PathSet
    module PathExpression
      #
      # Strings indicate an exact match for one path atom to a string of
      # characters.
      #
      # Expressions may include strings, which are exactly that--exact strings.
      # Strings do not have an expression type associated with them.  They can
      # have any character in them, and always take up exactly one path.
      #
      # This means that / and \ in these expression strings do NOT indicate
      # path boundaries.
      #
      # ab/*/c would be a PathSequence([ 'ab', STAR, 'c'])
      #
      ExactString = String

      # TODO arrays: planning to reserve them for paths where range(path) ==
      # [ array.size, array.size ], so we don't even have to check that. Maybe
      # even reserve them for strings only, but that might be too drastic.

      # An array of items that are split on path boundaries.
      # This does not guarantee that the items themselves take exactly one
      # directory, but with the exception of unions containing /, and globstars,
      # that will generally be the case.
      PathSequence = Struct.new(:items)

      # An array of items which are *not* separated by path boundaries.
      AtomicSequence = Struct.new(:items)

      # A set of path expressions, any of which can match and are part of the
      # pathset.
      Union = Struct.new(:members)

      # Matches all characters but cannot cross path boundaries.
      Star = Struct.new(:was_globstar)

      # Matches all characters but can cross path boundaries.
      Globstar = Struct.new

      # Constant used quite a bit to avoid constructing new Stars
      STAR = Star.new

      # Constant representing a globstar
      GLOBSTAR = Globstar.new
      EMPTY_PATH = PathSequence.new([])
      EMPTY_ATOM = ''
      NOTHING = nil


      # Concatenate two path-bounded path_expressions.  This should only be called
      # when the caller knows that the left side of a and the right side of b
      # are already bounded.
      def self.concat(a, b)
        if a == NOTHING || b == NOTHING
          return NOTHING
        end

        if a == EMPTY_PATH
          return b
        elsif b == EMPTY_PATH
          return a
        end

        if a.is_a?(PathSequence)
          a_items = a.items
        else
          a_items = [ a ]
        end
        if b.is_a?(PathSequence)
          b_items = b.items
        else
          b_items = [ b ]
        end

        sequence = a_items + b_items
        if sequence.size == 0
          EMPTY_PATH
        else
          PathSequence.new(a_items, b_items)
        end
      end

      # Concatenates two Expressions without space between them.
      def self.concat_atomic(a, b)
        if a == NOTHING || b == NOTHING
          return NOTHING
        end

        if a == EMPTY_PATH || a == EMPTY_ATOM
          return b
        elsif b == EMPTY_PATH || b == EMPTY_ATOM
          return a
        end

        # PathSequences, atomically concatenated, concatenate their ends.
        if a.is_a?(PathSequence) || b.is_a?(PathSequence)
          head = a.is_a?(PathSequence) ? a.items : [ a ]
          tail = b.is_a?(PathSequence) ? b.items : [ b ]
          # We know there is at least one item in each sequence, because we
          # already handled EMPTY_PATH above.  Glue the two middle parts
          # together as an atom.
          middle = concat_atomic(head.pop, tail.shift)
          sequence = a_items + middle + b_items
          if sequence.size == 1
            return sequence[0]
          elsif sequence.size == 0
            return EMPTY_PATH
          else
            return PathSequence.new(sequence)
          end
        end
        end

        # Get rid of repeated stars and globstars
        if a.is_a?(Globstar) && (b.is_a?(Star) || b.is_a?(Globstar))
          return a
        elsif a.is_a?(Star)
          if b.is_a?(Star)
            return a.was_globstar ? a : b
          elsif b.is_a?(Globstar)
            return b
          end
        end

        # Smoosh strings together
        if a.is_a?(ExactString) && b.is_a?(ExactString)
          return a + b
        end

        # Build an atomic sequence.
        if a.is_a?(AtomicSequence)
          a_items = a.items
        else
          a_items = [ a ]
        end
        if b.is_a?(AtomicSequence)
          b_items = b.items
        else
          b_items = [ b ]
        end
        AtomicSequence.new(a_items + b_items)
      end

      # Union
      def self.union(a, b)
        if a == NOTHING
          if b == NOTHING
            return NOTHING
          else
            return b
          end
        elsif b == NOTHING
          return a
        end

        if a.is_a?(Union)
          if b.is_a?(Union)
            Union.new(a.members + b.members)
          else
            Union.new(a.members + [ b ])
          end
        elsif b.is_a?(Union)
          Union.new([ a ] + b.members)
        else
          Union.new([ a, b ])
        end
      end

      #
      # Find out the path range of a path_expression.  Returns min, max. max = nil
      # means infinite.
      #
      # range('abc') == [ 1, 1 ]
      # range('*') == [ 1, 1 ]
      # range('**') == [ 1, nil ]
      # range(Union(a/b/c, a/b, a/b/c/d)) == [ 2, 4 ]
      # range(EMPTY_ATOM) == [ 1, 1 ]
      # range(EMPTY_PATH) == [ 0, 0 ]
      # range(NOTHING) == [ 0, 0 ]
      # range(PathSequence([ 'a', '*', 'c'])) == [ 3, 3 ]
      # range(PathSequence([ 'a', '**', 'c']) == [ 3, nil ]
      # range(AtomicSequence([ 'a', '*', 'c'])) == [ 1, 1 ]
      # range(AtomicSequence([ 'a', '**', 'c'])) == [ 2, nil ]
      #
      def self.range(a)
        if a.is_a?(ExactString) || a.is_a?(Star)
          [ 1, 1 ]
        elsif a.is_a?(PathSequence)
          a.items.inject([0,0]) do |(min,max),item|
            item_min, item_max = range(item)
            item_min = 1 if item_min == 0
            item_max = 1 if item_max == 0
            [ min+item_min, max&&item_max ? max+item_max : nil ]
          end
        elsif a.is_a?(AtomicSequence)
          a.items.inject([1,1]) do |(min,max),item|
            item_min, item_max = range(item)
            [ min+item_min-1, max&&item_max ? max+item_max-1 : nil ]
          end
        elsif a.is_a?(Union)
          range = a.members.inject([0,0]) do |(min,max),item|
            r = range(item)
            min = r if r < min
            max = r if !r || (max && r && r > max)
            [ min, max ]
          end
        elsif a.is_a?(Globstar)
          [ 1, nil ]
        elsif a == NOTHING
          [ 0, 0 ]
        else
          raise "Unknown path_expression type #{a}"
        end
      end

      #
      # Go down one directory in the tree.
      #
      # In set language: return a set of [ head, tail ] pairs where
      # union([ head+tail ]*) == a, and where range(head) == [ 1, 1 ].
      #
      # head is also guaranteed to have no Globstars or PathSequences in it.
      #
      def self.descend(a)
        # ExactString:
        # abc == abc => EMPTY_PATH
        #
        # Star:
        # * == * => EMPTY_PATH
        if a.is_a?(ExactString) || a.is_a?(Star)
          { a => EMPTY_PATH }

        # PathSequence:
        # a                   == a   => EMPTY_PATH
        # a/b/c               == a   => b/c
        # a*b/c*/d            == a*b => c*/d
        # a**b/c              == a*b => c,   a* => **b/c
        # EMPTY_PATH           == NOTHING
        elsif a.is_a?(PathSequence)
          min, max = range(a.items[0])
          if max == 1
            { a.items[0] => PathSequence.new(a.items[1..-1]) }
          else
            results = {}
            descend(a.items[0]).each do |head, tail|
              add_descend_results(results, head => concat(tail, PathSequence.new(a.items[1..-1]))
            end
            results
          end

        # Descending into nothing, you will find nothing more.
        elsif a == NOTHING
          NOTHING

        elsif a.is_a?(AtomicSequence)
          descend_atomic_sequence(a)

        elsif a.is_a?(Union)
          results = {}
          a.members.each do |member|
            add_descend_results(results, descend(member))
          end
          results

        elsif a.is_a?(Globstar)
          # Either we are done with the globstar, or we aren't.
          { Star.new(true) => GLOBSTAR, STAR => EMPTY_PATH }

        else
          raise "Unknown path_expression #{a}"
        end
      end

      # Descend a and b in lock step, yielding the intersection of a and b
      # at each point, along with the remaining data. No effort is made to
      # remove duplicates.
      def self.match_step(a, b)
        processing = [ [ EMPTY_PATH, a, b ] ]
        while processing.size > 0
          next_processing = []
          processing.each do |intersection, a, b|
            descended_a = descend(a)
            descended_b = descend(b)
            descended_a.each do |head_a, tail_a|
              descended_b.each do |head_b, tail_b|
                intersection = concat(intersection, intersect_single(head_a, head_b))

                if intersection != NOTHING
                  yield intersection, tail_a, tail_b
                  if tail_a != EMPTY_PATH && tail_b != EMPTY_PATH
                    next_processing << [ intersection, tail_a, tail_b ]
                  end
                end
              end
            end
          end
          processing = next_processing
        end
      end

      # Intersect two path_expressions.
      def self.intersect(a, b)
        results = NOTHING
        match_step(a, b) do |intersection, tail_a, tail_b|
          if tail_a != EMPTY_PATH && tail_b != EMPTY_PATH
            results = union(intersection)
          end
        end
        results
      end

      # Return the result of "a.chdir(b)".
      #
      # Returns:
      # A list of pairs, each of which represents a head (the chdir'd part)
      # and a tail (the tree below that chdir).  Returns an empty list if the
      # path chdir'd to does not exist.  Tail will be EMPTY_PATH if the chdir
      # was exact (chdir('a', 'a'))
      #
      # This is really a partial intersection where a is allowed to have stuff
      # remaining.
      #
      # chdir('a', 'a')                 == [[ 'a', EMPTY_PATH ]]
      # chdir('a/b/c', 'a/b')           == [[ 'a/b', 'c' ]]
      # chdir('a/b', 'a/b/c')           == []
      # chdir('a/{b/x,b/y,c/d}', 'a/b') == [[ 'a/b', '{x,y}' ]]
      # chdir('a/b/c/d/e/f/g', 'a/b')   == [[ 'a/b', 'c/d/e/f/g']]
      # chdir('a/b/c/d/e/f/g', 'a/b/x') == []
      # chdir('a/**.txt', 'a/b')        == [[ 'a/b', '**.txt' ]]
      # chdir('a/**.txt', '*/*')        == [[ 'a/*', '**.txt' ]]
      def self.chdir(a, b)
        results = {}
        match_step(a, b) do |intersection, tail_a, tail_b|
          if tail_b == EMPTY_PATH
            add_descend_results(results, intersection => tail_a)
          end
        end
        results
      end

      private

      def add_descend_results(results, more_results)
        more_results.each do |a, b|
          if results.has_key?(a)
            results[a] = union(results[a], b)
          else
            results[a] = b
          end
        end
      end

      # AtomicSequence is the most complicated one to split up (which is why
      # we do the work first to see if it needs to be).  If you have PathSequences
      # or ** in your AtomicSequence, descending down it means splitting the
      # sequence up into a head and tail.
      #
      # a*b                == a*b    => EMPTY_PATH
      # a{b,c}             == a{b,c} => EMPTY_PATH
      # **                 == *      => EMPTY_PATH,  * => **
      # **b                == *b     => EMPTY_PATH,  * => **b
      # a**b               == a*b    => EMPTY_PATH, a* => **b
      # a{b,b/c,b/d/e,x/y} == ab     => {EMPTY_PATH,c,d/e}
      #
      # Pathological:
      # a**b
      # a**b/d             == a*b    => d,          a* => **b/d
      # a{b/c}{d/e}        == ab     => cd/e
      def descend_atomic_sequence(a)
        # If every single item is <= 1 cardinality (like a*b or a{b,c}), we
        # take the easy way out.
        if !a.items.any? { |item| min, max = range(a.items[0]); !max || max > 1 }
          { a => EMPTY_PATH }
        else
          #
          # Descend all items.  descend(<items>) = <concat item heads> => <concat item tails>
          #

          # To process is the leftovers from the previous iteration (the tails).
          to_process = { EMPTY_ATOM => EMPTY_PATH }

          # Example follows: a**b/d == a*b => d, a* => **b/d

          items.each do |item|
            # item:
            # 1. a
            # 2. **
            # 3. b/d (PathSequence(b, d))

            # The next to_process will be <current head><item head> => <current tail><item tail>
            next_to_process = {}

            results.each do |head, tail|
              #     head        => tail
              # 1.  EMPTY_ATOM => EMPTY_PATH
              # 2.  a           => EMPTY_PATH
              # 3a. a*          => EMPTY_PATH
              # 3b. a*          => **

              # If our result has a tail already, anything left of our sequence just gets
              # atomically appended to it.
              if tail != EMPTY_PATH
                #     tail+item
                # 3b. a*        => **b/d
                add_descend_results(next_to_process, head, concat_atomic(tail, item))
              else
                # For each item, we want to take <head, tail so far> + <item head, item tail>.
                descend(concat_atomic(tail, item)).each do |item_head, item_tail|
                  # descend(tail+item): item_head => item_tail
                  # 1.  descend(a):     a         => EMPTY_PATH
                  # 2.  descend(**):    *         => EMPTY_PATH
                  #                     *         => **
                  # 3a. descend(b/d):   b         => d

                  add_descend_results(next_to_process, concat_atomic(head, item_head) => item_tail))
                  # results: head+item_head => tail+item_tail
                  # 1.       a              => EMPTY_PATH
                  # 2.       a*             => EMPTY_PATH
                  #          a*             => **
                  # 3a.      a*b            => d

                end
              end
              results = next_to_process
            end
          end

          # Answer:
          # a*b => d
          # a*  => **b/d
          results
        end
      end

      #
      # intersect_single returns the possible intersections of a and b, both of
      # which must contain no expressions that cross path boundaries.  It returns
      # results in the format [ [ intersection, remaining_b ] ].  If this hash is
      # empty, there is no intersection.  If any result has "remaining_b", it is
      # a partial result. If a result has remaining_b = EMPTY_ATOM, it is a full
      # result.  Results that do not consume all of a are failed intersections.
      #
      def self.intersect_single(a, b, a_right_bound, b_right_bound)
        # NOTHING
        if a == NOTHING || b == NOTHING
          return NOTHING
        end

        #
        # AtomicSequence:
        #
        # a & b is done by intersecting each item with b, feeding the remaining
        # to the next item, rinse and repeat until failure or success.
        #
        if a.is_a?(AtomicSequence)
          partials = { EMPTY_ATOM => b }
          a.items.each do |item|
            to_process = partials
            partials = []
            to_process.each do |intersection, b|
              add_partials(partials, intersect_single(item, b), intersection)
            end
          end
          return partials
        end

        #
        # PathSequence: intersect_single is not allowed to cross path boundaries,
        # so this is automatically an error.
        #
        if a.is_a?(PathSequence)
          if a.size == 1
            return intersect_single(a[0], b)
          end
          raise "Unexpected PathSequence with #{a.size} entries in intersection: cannot intersect!"
        end

        #
        # Union
        #
        if a.is_a?(Union)
          partials = {}
          a.members.each do |member|
            add_partials(partials, intersect_single(member, b))
          end
          return partials
        end

        #
        # ExactString
        #
        if a.is_a?(ExactString)
          if b.is_a?(ExactString)
            if a == b
              return [ [ a, EMPTY_ATOM ] ]
            elsif b.start_with?(a)
              return [ [ a => b[a.length..] ] ]
            else
              return []
            end


          elsif b.is_a?(Star)
            # In the general case, we need to be able to handle b = *abc, *bc, *c, and *.
            #
            #       abc.../ & *...
            # --------------------
            # abc->    .../ & *...
            #  ab->   c.../ &  ...
            #   a->  bc.../ &  ...
            #       abc.../ &  ...
            [ [ ] ]
          end
        end

        # Star
        # Globstar
        if a.is_a?(AtomicSequence)
          if b.is_a?(Atomic)



        if a.is_a?(ExactString)
          if b.is_a?(ExactString)
            return a == b ? a : NOTHING
          end
        end
      end
    end
  end
end
