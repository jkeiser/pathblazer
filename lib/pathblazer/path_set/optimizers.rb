module Pathblazer
  class PathSet
    module Optimizers
      #
      # Lets you walk the expression's children, if any.  Does not recurse.
      #
      # Does not walk a string's "children."  Just yields the string.
      #
      def self.walk(expression, type = :pre)
        if expression.is_a?(CharExpression::Sequence) || expression.is_a?(PathExpression::Sequence)
          expression.items.each { |child| yield child }
        elsif expression.is_a?(PathExpression::ExactSequence)
          expression.each { |child| yield child }
        elsif expression.is_a?(CharExpression::Union) || expression.is_a?(PathExpression::Union)
          expression.members.each { |child| yield child }
        elsif expression.is_a?(CharExpression::Repeat) || expression.is_a?(PathExpression::Repeat)
          yield expression.expression
        end
      end

      #
      # Lets you walk (and potentially transform) the expression.
      # Yields each expression in turn, and if you return an
      # expression in your block, replaces the expression in the
      # tree.  It uses concat(), replace() and union() to replace the
      # expression.
      #
      # Does not walk a string's "children."  Just yields the string.
      #
      def self.transform(expression, type = :pre, &block)
        original_expression = expression
        if type == :pre
          new_expression = yield expression
          expression = new_expression if new_expression
        end

        if expression.is_a?(PathExpression::Sequence)
          walk_children(expression.items, type, block) do |new_children|
            expression = PathExpression.concat(new_children)
          end
        elsf expression.is_a?(PathExpression::Sequence)
          walk_children(expression.items, type, block) do |new_children|
            expression = PathExpression.concat(new_children)
          end
        elsif expression.is_a?(CharExpression::ExactSequence))
          walk_children(expression, type, block) do |new_children|
            expression = CharExpression.concat(new_children)
          end
        elsif expression.is_a?(PathExpression::ExactSequence)
          walk_children(expression, type, block) do |new_children|
            expression = PathExpression.concat(new_children)
          end
        elsif expression.is_a?(CharExpression::Union)
          walk_children(expression.members, type, block) do |new_children|
            expression = CharExpression.union(new_children)
          end
        elsif expression.is_a?(PathExpression::Union)
          walk_children(expression.members, type, block) do |new_children|
            expression = PathExpression.union(new_children)
          end
        elsif expression.is_a?(CharExpression::Repeat)
          new_child = walk(expression.expression, type, &block)
          if new_child
            expression = CharExpression.repeat(new_child, expression.min, expression.max)
          end
        elsif expression.is_a?(PathExpression::Repeat)
          new_child = walk(expression.expression, type, &block)
          if new_child
            expression = PathExpression.repeat(new_child, expression.min, expression.max)
          end
        end

        if type == :post
          new_expression = yield expression
          expression = new_expression if new_expression
        end

        # Only return the expression if it was modified
        if !(expression === original_expression)
          expression
        else
          nil
        end
      end

      # Walks a list of elements with the walker, and yields a new set of elements
      # to &block if it changed.
      def self.transform_children(children, type = :pre, walker)
        new_results = nil
        children.each_with_index do |child, index|
          new_child = walker.call(child)
          if new_child && !new_results
            new_results = children[0..index-1]
          end
          if new_results
            new_results << new_child || child
          end
        end
        yield new_results if new_results
      end

      #
      # Unfolds all unions out to the top (exploding the size multiplicatively).
      #
      def self.unfold_unions(original)
        results = Set.new
        if expression.is_a?(CharExpression::Sequence) || expression.is_a?(PathExpression::Sequence)
          # This is where it gets multiplicative if you have a lot of unions
          results << PathExpression::EMPTY
          expression.items.each do |child|
            child_union = unfold_unions(child)
            results = Set.new(
              results.map do |result|
                child_union.map { |union| PathExpression.concat(result, union) }
              end.flatten(1)
            )
          end
        elsif expression.is_a?(CharExpression::Union) || expression.is_a?(PathExpression::Union)
          expression.members.each { |child| results += unfold_unions(child) }
        elsif expression.is_a?(CharExpression::Repeat)
          unfold_unions(expression.expression).each do |e|
            results << CharExpression.repeat(e, expression.min, expression.max)
          end
        elsif expression.is_a?(PathExpression::Repeat)
          unfold_unions(expression.expression).each do |e|
            results << PathExpression.repeat(e, expression.min, expression.max)
          end
        else
          results << expression
        end
        return results
      end

      #
      # Used to unearth path expressions buried under atomic expressions.  This
      # is common for parsers, and we'd like path lookups and operations to be
      # fast.
      #
      def self.surface_paths(expression)
        if expression.is_a?(CharExpression::Sequence)
          expression.items.each_with_index do |item, index|
            surfaced = surface_paths(item)
            if surfaced

              # x{a/b/c}y -> {xa/b/cy}
              left = expression.items[0..index-1]
              right = expression.items[index+1..]
              if surfaced.is_a?(PathExpression::Sequence)
                return atomic_sandwich(expression.items[0..index-1], surfaced.items, expression.items[index+1..])

              # x{a/b/c,d/e/f}y -> {xa/b/cy,xd/e/fy}
              elsif surfaced.is_a?(PathExpression::Union)
                return PathExpression.union(
                  surfaced.members.map { |member| atomic_sandwich(left, [ member ], right) })

              # abc{x/y/z/}*def ->
              # abcX*def -< abcdef, abcXdef, abcX/Xdef, abcX/X/Xdef
              # = head{first, {<middle>, <last>, <first>}*, <middle>, <last>}<tail>
              # = {<head><first>, {<last>, <first>}*, <last><tail>}
              # = <head><tail>
              # {abcdef,abcXdef,abcXX*Xdef}
              elsif surfaced.is_a?(PathExpression::Repeat)
                unions = []
                if surfaced.min == 0
                  unions << CharExpression.concat(left, right)
                end
                if surfaced.min <= 1 && (!surfaced.max || surfaced.max >= 1)
                  unions << atomic_sandwich(left, [ surfaced.expression ], right)
                end
                if !surfaced.max || surfaced.max >= 2
                  left_sandwich = atomic_sandwich(left, [ surfaced.expression ], EMPTY)
                  center = Repeat.new(surfaced.expression, [ surfaced.min-2, 0 ].max, surfaced.max ? surfaced.max-2 : nil)
                  right_sandwich = atomic_sandwich(EMPTY, [ surfaced.expression ], right)
                  unions << PathExpression.concat(left_sandwich, center, right_sandwich)
                end
                return surface_paths(PathExpression.union(*unions))
              end
            end
          end

        elsif expression.is_a?(CharExpression::Repeat)
          # {a/b/c}* = empty, a/b/c, a/b/ca/b/ca/b/c, ...
          # = {<first>, {<middle>, <last><first>}*, <middle>, <last>}?
          # {a/b/ca/b/ca/b/c}
          surfaced = surface_path(expression.expression)
          if surfaced.is_a?(PathExpression::Sequence)
            if surfaced.size <= 1
              return CharExpression::Repeat.new(surfaced[0], expression.min, expression.max)
            else
              first = surfaced[0]
              middle = surfaced[1..-2]
              last = surfaced[-1]
              if !expression.max || expression.max >= 2
                repeat_expr = PathExpression.concat(middle, CharExpression.concat(last, first))
                repeat = PathExpression::Repeat.new(repeat_expr,
                                                    expression.min > 0 ? expression.min-1 : 0,
                                                    expression.max ? expression.max-1 : nil)
                path = PathExpression.concat(first, repeat, middle, last)
              elsif expression.max >= 1
                path = PathExpression.concat(first, middle, last)
              else
                return EMPTY
              end
              if expression.min == 0
                PathExpression::Repeat.new(path, 0, 1)
              end
            end

          elsif surface.is_a?(PathExpression::Union)
            raise "union of paths inside a character repeat not currently supported due to lack of maths"

            # {a/x/b,c/y/d}* = empty, a/x/b, c/y/d, a/x/ba/x/b, a/x/bc/y/d, c/x/dc/y/d,
            #                  a/x/ba/x/ba/x/b, a/x/ba/x/bc/y/d, a/x/bc/y/da/x/b,
            #                  a/x/bc/y/dc/y/d, c/y/dc/y/da/x/b, c/y/dc/y/dc/y/d
            #                  a/x/ba/x/ba/x/ba/x/b, a/x/ba/x/ba/x/bc/y/d,
            #                  a/x/ba/x/bc/y/da/x/b, a/x/ba/x/bc/y/dc/y/d
            #                  a/x/bc/y/da/x/ba/x/b, a/x/bc/y/da/x/bc/y/d,
            #                  a/x/bc/y/dc/y/da/x/b, a/x/bc/y/dc/y/dc/y/d,
            #                  c/y/dc/y/da/x/ba/x/b, c/y/dc/y/da/x/bc/y/d,
            #                  c/y/dc/y/dc/y/da/x/b, c/y/dc/y/dc/y/dc/y/d,
            # {a/{x/ba/}*x/b}
            # {a/{x/bc/}*y/d}
            # {c/{y/da/}*x/b}
            # {c/{y/dc/}*y/d}
            # {c/{y/da/x/ba/}*x/b}
            # {c/{y/dc/y/da/}*x/b}
            # {c/{y/dc/y/dc/}*y/d}
            # {a1/{a2/a3a1/a2/a3a1/}*a2/a3}
            # {a1/a2/a3a1}
            # {a1/a2/a3b1}
            # {a1/a2/a3b2}
          elsif surface.is_a?(PathExpression::Repeat)
            raise "path repeats inside a character repeat not currently supported due to lack of maths"
          end

        elsif expression.is_a?(CharExpression::Union)
          expression.members.each do |member|
            surfaced = surface_paths(member)
            # For union, we just upgrade to PathExpression::Union and let the insides
            # handle themselves.
            if surfaced
              return surface_paths(PathExpression.union(expression.members))
            end
          end

        elsif expression.is_a?(PathExpression::Sequence)
          surfaced_items = []
          expression.items.each_with_index do |expression, i|
            surfaced = surface_paths(expression)
            if surfaced
              surfaced_items << [ [ surfaced, i ] ]
            end
          end
          if surfaced_items.size > 0
            result = expression.items.dup
            result = surfaced_items.map { |item, i| result[i] = item }
            return PathExpression.concat(surfaced_items)
          end

        elsif expression.is_a?(PathExpression::Repeat)
          surfaced = surfaced_paths(expression.expression)
          if surfaced
            return PathExpression::Repeat.new(surfaced, expression.min, expression.max)
          end

        elsif expression.is_a?(PathExpression::Union)
          surfaced_items = []
          expression.members.each_with_index do |expression, i|
            surfaced = surface_paths(expression)
            if surfaced
              surfaced_items << [ [ surfaced, i ] ]
            end
          end
          if surfaced_items.size > 0
            result = expression.items.dup
            result = surfaced_items.map { |item, i| result[i] = item }
            return PathExpression.union(surfaced_items)
          end
        end
      end

      def self.atomic_sandwich(left, path, right)
        if surfaced.is_a?(PathExpression::Sequence)
          left += [ surfaced.items[0] ] if surfaced.items > 0
          right = [ surfaced.items[-1] ] + right_side if surfaced.items > 1
          if surfaced.items.size <= 1
            return surface_paths(CharExpression.concat(*left_side, *right_side))
          else
            return surface_paths(
                     PathExpression.concat(
                       CharExpression.concat(*left_side)),
                       *surfaced.items[1..-2],
                       CharExpression.concat(*right_side)))
          end
      end
    end
  end
end
