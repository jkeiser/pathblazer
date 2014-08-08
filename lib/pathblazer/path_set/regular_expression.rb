module Pathblazer
  class PathSet
    #
    # Path expressions and character expressions both work the same way: they
    # allow you to repeat, sequence and union atoms.  The atoms just happen
    # to be characters in one case and path entries in the other.
    #
    # This module has the common logic for both so we don't duplicate.
    #
    module RegularExpression
      #
      # This represents a sequential op on a pair of inputs.  It includes
      # the op itself, the following unfinished ops, and the
      # result to this point.
      #
      # SequentialOperation has the special quality that the op can
      # be "swapped." This means that a and b always stay consistent with the
      # original a and b, but we can reverse the "view" of the op so that
      # a <=> b.  Then we reverse it back when the parent needs it.
      # op.swap does this. op.intersect(a, b) handles spawning the
      # proper op and then matching the results back to their expected
      # value.
      #
      class SequentialOperation
        def initialize(parent, result, a, b, next_a, next_b, swapped)
          @parent = parent
          @result = result
          @a = a
          @b = b
          @next_a = next_a
          @next_b = next_b
          @swapped = swapped
        end

        attr_reader :result
        attr_reader :a
        attr_reader :b
        attr_reader :next_a
        attr_reader :next_b
        attr_reader :swapped

        # Most of our methods are written to work with a.  Instead of forcing
        # them all to do either a or b, we swap a and b.
        def swap
          a, b = b, a
          next_a, next_b = next_b, next_a
          swapped = !swapped
          self
        end

        def match_swap(op)
          if swapped != op.swapped
            swap
          end
        end

        # intersection         -> a & b
        # intersection->result -> next_a & next_b -> empty & empty
        def consume_both(new_result=nil)
          OperationThread.new(
            self, new_result,
            next_a, next_b,
            EMPTY, EMPTY,
            swapped)
        end

        # intersection           -> a & b                -> next_a & next_b
        # intersection->a        -> next_a & remaining_b -> empty & next_b
        def consume_a(remaining_b=nil)
          OperationThread.new(
            self, a,
            next_a, concat(remaining_b || b, next_b),
            EMPTY, EMPTY,
            swapped)
        end

        # intersection           -> a & b                -> next_a & next_b
        # intersection->b        -> remaining_a & next_b -> next_a & empty
        def consume_b(remaining_a=nil)
          OperationThread.new(
            self, new_result,
            concat(remaining_a, next_a), next_b,
            EMPTY, EMPTY,
            swapped)
        end

        # intersection           -> a & b                        -> next_a & next_b
        # intersection           -> new_a & b                    -> tail+next_a & next_b
        #
        # When we generate alternatives, we hook them up to our parent so we don't waste
        # time and space.
        def alternative_a(new_a, tail=EMPTY)
          OperationThread.new(
            parent, result,
            new_a, b,
            concat(tail, next_a), next_b,
            swapped
          )
        end

        # intersection           -> a & b                        -> next_a & next_b
        # intersection           -> new_a & b                    -> tail+next_a & next_b
        #
        # When we generate alternatives, we hook them up to our parent so we don't waste
        # time and space.
        def alternative_both(new_a, new_b)
          OperationThread.new(
            parent, result,
            new_a, new_b,
            next_a, next_b,
            swapped
          )
        end
      end

      #
      # This represents the fact that literally nothing is in the set of paths /
      # characters.  Nothing can be matched.  This is different from EMPTY in
      # that an empty string ('') or empty path ([]) is still a real thing.
      #
      def start_intersect(a, b)
        OperationThread.new(nil, EMPTY, a, b, EMPTY, EMPTY, false)
      end
      alias :regular_start_intersect :start_intersect

      def intersect(a, b)
        intersect_loop([ start_intersect(a, b) ])
      end
      alias :regular_intersect :intersect

      def intersect_loop(ops)
        results = []
        while ops.size > 0
          next_ops = []
          ops.each do |op|
            intersected = advance_intersect(op)
            next_ops += intersected.map { |r| r.next_a != EMPTY && r.next_b != EMPTY }
            results += intersected.map { |r| r.next_a == EMPTY || r.next_b == EMPTY }
          end
          ops = next_ops
        end
        results
      end
      alias :regular_intersect_loop :intersect_loop

      def advance_intersect(op)
        if op.a == op.b
          return [ op.consume_a ]
        end

        if op.a == NOTHING || op.b == NOTHING
          return []
        end

        if op.a == EMPTY
          if op.b == EMPTY
            # This is the one time we can return ourselves instead of advancing.
            return [ op ]
          else
            # No point wasting time intersecting with EMPTY unless we have to.
            if op.next_a != EMPTY
              return [ op.consume_a ]
            end
          end
        elsif op.b == EMPTY
          # No point wasting time intersecting with EMPTY unless we have to.
          if op.next_b != EMPTY
            return [ op.consume_b ]
          end
        end

        if op.a.is_a?(Repeat)
          return intersect_repeat(op)
        elsif op.b.is_a?(Repeat)
          return intersect_repeat(op.swap)
        end

        if op.a.is_a?(Sequence)
          return intersect_sequence(op)
        elsif op.b.is_a?(Sequence)
          return intersect_sequence(op.swap)
        end

        if op.a.is_a?(Union)
          return intersect_union(op)
        elsif op.b.is_a?(Union)
          return intersect_union(op.swap)
        end

        if op.a.is_a?(ExactSequence)
          return intersect_exact_sequence(op)
        elsif op.b.is_a?(ExactSequence)
          return intersect_exact_sequence(op.swap)
        end

        nil
      end

      alias :regular_advance_intersect :advance_intersect

      #
      # Sequence:
      #
      # sequence & b is done by intersecting each item with b, feeding the remaining
      # to the next item, rinse and repeat until failure or success.
      #
      def intersect_sequence(op)
        # Just move forward, one item at a time.
        if op.a.items.size == 0
          return op.alternative_a(EMPTY)
        elsif op.a.items.size == 1
          return op.alternative_a(op.a.items[0])
        else
          return op.alternative_a(op.a.items[0], concat(op.a.items[1..-1]))
        end
      end
      alias :regular_intersect_sequence :intersect_sequence

      #
      # Union:
      #
      # Return all the alternatives for processing.
      #
      def intersect_union(op)
        return op.a.expressions.map { |expr| op.alternative_a(expr) }
      end
      alias :regular_intersect_union :intersect_union

      #
      # Repeat(A,m,n):
      #
      # If max is finite:
      # - Generate A*min, AAAAA, AAAAAA, until A*max.
      # If max is infinite:
      # 1. Consume forward until A*.  (If it's B*, swap.)
      # 2. Generate A*min, AAAAA, AAAAAA, producing results until you hit B*.
      # 3. A1*->A2 & B1*->B2
      #    -----------------
      #    -> A2 & B1*B2 - consume A1* completely with no B1* mixed
      #    -> A1 & B1*B2 - consume B1* completely with no A1* mixed
      #    A1*C*B1* -> A2&B2 - intermixed, with A1 first, where C is special sauce
      #    B1*C*A1* -> A2&B2 - intermixed, with B1 first, where C is special sauce
      #
      #    C is an expression produced by finding an m and n where A{m}&B{n}
      #    produce a match.  It will repeat from there: any sequence of A&B that
      #    terminates, will loop.  Our algorithm is to do A&B over and over,
      #    appending more B if A is partial and appending more A if B is
      #    partial, until it finishes.
      #
      #    TODO There may be a more scientific way to get C that will make
      #    prettier results, but this will get us past the problem for now :)
      #
      # (abc)* & abc
      # ---------------
      # EMPTY -> abc
      # abc -> (abc)*
      #
      # {ab|cdef}* & {abcd|ef}*
      # ---------------
      # EMPTY ->
      #
      # (abc)* & ab
      # ---------------
      # EMPTY -> ab
      # ab -> c(abc)*
      #
      # (abc)* & abca
      # ---------------
      # EMPTY -> abca
      # abc   -> a
      # abca -> bc(abc)*
      #
      # (abc)[2..-1] & ab
      # ---------------
      # ab -> c(abc)[1..-1]*
      #
      # (abc)[2..-1] & abc
      # ----------------
      # abc -> abc[1..-1]
      #
      # (abc)* & (xyz)*
      # ---------------
      # EMPTY -> (abc)*
      # EMPTY -> (xyz)*
      #
      # (abc)* & abca{ab|ca|bc}*
      # -------------------------
      # abcabc          -> (abc)*
      # abcabc(abcabc)* -> EMPTY
      #
      # (abc)* & {ab|ca|bc}*
      # -------------------------
      # EMPTY     -> (abc)*
      # EMPTY     -> {ab|ca|bc}*
      # (abcabc)* -> EMPTY
      #
      def intersect_repeat(op)
        # TODO this doesn't preserve the range--it unrolls abc{3,3} into abcabcabc.

        # If we have a minimum, toss that out there.
        head = EMPTY
        1.upto(op.a.min) do |i|
          head = concat(head, op.a.expression)
        end
        if head != EMPTY
          if !op.a.max
            tail = repeat(operation.a.expression, 0, nil)
          elsif op.a.max > op.a.min
            tail = repeat(operation.a.expression, 0, op.a.max-op.a.min)
          else
            tail = EMPTY
          end
          return [ operation.consume_a(head, EMPTY) ]
        end

        #
        # If we are infinite, first check if the other guy is an infinite repeat.
        #
        if !op.a.max && op.b.is_a?(Repeat) && !op.b.max
          # If the other guy has a quota to fulfill, let him to do that.
          if op.b.min
            return intersect_repeat(op.swap)
          end

          # We are both infinite.  Time to find the loop.
          return intersect_infinite_repeaters(op)
        end

        #
        # We aren't infinite.  Generate two possibilities: that we run out of juice
        # right now, and A->A* (or A->A{max-1})
        #
        if !op.a.max
          tail = op.a
        else
          tail = repeat(op.a.expression, op.a.min, op.a.max - 1)
        end
        return Set.new(
          op.consume_a,
          op.alternative_a(op.a.expression, tail) # A -> A*
        )
      end
      alias :regular_intersect_repeat :intersect_repeat

      def intersect_infinite_repeaters(op)
        # We are trying to
        # find combinations of AAAAA and BBBB that match perfectly.  These
        # are loops.  For example, abc* & {ab|bc|ca}* = abcabc.  AA and BBB
        expr_a = ops.a.expression
        expr_b = ops.b.expression
        ops = [ start_intersect(expr_a, expr_b) ]
        loops = Set.new
        while ops.size > 0
          ops.each do |op|
            intersect_loop(op).each do |next_op|
              next_op.match_swap(op)
              if next_op.next_a == EMPTY && next_op.next_b == EMPTY
                loops << next_op.full_result
              elsif next_op.next_a == EMPTY
                # Load up another a, we're empty.
                ops << next_op.alternative_a(expr_a)
              else
                # Load up another b, we're empty.
                ops << next_op.alternative_a(expr_b)
              end
            end
          end
        end

        # Return the loops as results.  (If we failed to find loops, that means
        # the intersection didn't pan out, and there are no results for A&B.
        result = Set.new
        loops.each do |expr|
          # We have A* and B*.  We have found C.  Here was our chart:
          #
          #    A1*->A2 & B1*->B2
          #    -----------------
          #    -> A2 & B1*B2 - consume A1* completely with no B1* mixed
          #    -> A1 & B1*B2 - consume B1* completely with no A1* mixed
          #    A1*C*B1* -> A2&B2 - intermixed, with A1 first, where C is special sauce
          #    B1*C*A1* -> A2&B2 - intermixed, with B1 first, where C is special sauce
          result << op.consume_a
          result << op.consume_b
          result << op.consume_both(concat(op.a, repeat(expr, 0, nil), op.b))
          result << op.consume_both(concat(op.b, repeat(expr, 0, nil), op.a))
        end
      end
      alias :regular_intersect_infinite_repeaters :intersect_infinite_repeaters

      #
      # Exact sequence: a sequence where we are guaranteed each item is a single
      # atom with exactly one value.  A String fits the bill exactly, and all
      # exact sequences are required to implement [i..j], == and .size.
      # Paths use arrays of strings for this.
      #
      # Using strings as an example:
      #
      # abc & abc = [ abc, EMPTY, EMPTY ]
      # ab  & abc = [ ab,  EMPTY, c     ]
      # abc & ab  = [ ab,  c,     EMPTY ]
      # abc & abx = []
      # abc & xyz = []
      #
      def intersect_exact_sequence(op)
        # If the other is also an exact sequence, we find out if one starts with
        # the other of the other and and return that.
        if op.b.is_a?(ExactSequence)
          if op.a.size < op.b.size
            op.swap
          end
          if op.a[0..op.b.size-1] == op.b
            return [ op.consume_b(op.a[op.b.size..-1]) ]
          end
          return []
        end
      end
      alias :regular_intersect_exact_sequence :intersect_exact_sequence

      def range(path)
        if expression.is_a?(Sequence)
          return expression.items.map { |item| range(item) }.inject([0,0]) do |(min,max),(item_min,item_max)|
            if item_min
              if min
                min += item_min
              else
                min = nil
              end
            end
            if item_max
              max += item_max if max
            else
              max = item_max
            end
          end
        elsif expression.is_a?(ExactSequence)
          return [ expression.size, expression.size ]
        elsif expression.is_a?(Union)
          if expression.members.size == 0
            return 0
          end
          return expression.members.map { |item| range(item) }.inject([nil,0]) do |(min,max),(item_min,item_max)|
            min = item_min if !min || item_min < min
            max = item_max if !item_max || (item_max && item_max < max)
          end
        elsif expression.is_a?(Repeat)
          min, max = range(expression)
          if min
            min = min * expression.min
          end
          if max && expression.max
            max = max * expression.max
          end
          [ min, max ]
        elsif expression == NOTHING
          [ nil, 0 ]
        # Otherwise, it's an atom.
        else
          [ 1, 1 ]
        end
      end
      alias :regular_range :range
    end
  end
end
