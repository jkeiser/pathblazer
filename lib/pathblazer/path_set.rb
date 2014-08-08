require 'pathblazer/errors'
require 'pathblazer/path_set/path_expression'
require 'pathblazer/path_set/optimizers'

module Pathblazer
  #
  # A PathSet is a path or matcher describing a set of paths.
  #
  # They are designed to:
  # - Work with different OS- or shell-specific user input
  # - Be useable with any system that supports named hierarchies (file system
  #   globs, database custom translation, in-memory regexes)
  # - Allow multi-dimensional namespaces (like a directory tree with metadata
  #   trees sprouting off each directory)
  # - Support file description
  # - be intelligible and easy to look at, debug and print for the user
  #
  # Some examples:
  # A PathSet is a set of paths.  It is generally used for matching.
  #
  # It could be a single path, a list of actual paths, or a regular expression
  # or glob that matches paths, or something different altogether.
  #
  class PathSet
    def initialize(path)
      if expression.is_a?(PathSet)
        @path = path.expression
      else
        @path = expression
      end
    end

    attr_reader :expression

    def ==(other)
      other.is_a?(PathSet) && expression == other.expression
    end

    #
    # Returns true if this PathSet matches no paths.
    #
    def empty?
      PathExpression.range(expression)[0].nil?
    end

    #
    # Returns true if this PathSet includes the root path.
    #
    def include_root?
    end

    #
    # Returns true if this PathSet is exact (exact_path will work).
    #
    def exact?
      expression.is_a?(Array) || expression.is_a?(String)
    end

    #
    # Return the array of strings for this expression.
    #
    # Exceptions:
    # InfinitePathSetException - if you run this on a path that has * in it.
    #
    # Example:
    #
    #     if exact?
    #       puts expression.exact_expression.join('/')
    #     end
    #
    def exact_path
      if expression.is_a?(Array)
        return path
      elsif expression.is_a?(String)
        return [ path ]
      else
        raise InfinitePathSetException.new(self, "Getting :exact_path")
      end
    end

    #
    # Returns the depth of the longest path in the set.  Returns nil if infinite.
    #
    def depth
      PathExpression.range(path)[1]
    end

    #
    # Returns the depth of the smallest path in the set.  nil if there are no paths.
    #
    def min_depth
      PathExpression.range(path)[0]
    end

    #
    # Iterate over the list of paths.
    #
    # Block: |path|
    #
    # Each result is a PathSet and will be as close to a single exact path as it
    # can (unions will be removed).  If there are * repeats or [a-z] character
    # sets, they will be returned verbatim.
    #
    # Call exact? to find out if a path is exact.
    #
    def each
      Optimizers.unfold_unions(path).each
    end

    #
    # Descend downward into the pathset, one directory at a time.  Each result
    # is a PathSet.
    #
    # Exceptions:
    # InfinitePathSetException - if you run this on a path that has * in it.
    #
    # This can descend infinitely if there are constructs like **.  Test the
    # path for depth == nil before committing to this.
    #
    # Block: |path|
    #
    def descend
      next_descend = path
      while next_descend != PathExpression.EMPTY
        dir, next_descend = Optimizers.descend(path)
        yield dir
      end
    end

    #
    # Descend downward into the pathset, yielding each filename.
    #
    # This can descend infinitely if there are constructs like **.  You have
    # been warned.
    #
    # Block: |path|
    #
    def each_filename
      next_descend = path
      while next_descend != PathExpression.EMPTY
        dir, next_descend = PathExpression.descend(path)
        yield dir
      end
    end

    # Pathname methods:
    # ascend
    # each_filename
    # +
    # ==
    # <=>
    # absolute?
    # basename
    # join
    # parent
    # root? (probably only for uri paths)
    # absolute?
    # relative?
    # relative_path_from
    # cleanpath

    #
    # Delete a subset of the pathset.
    #
    def delete(pathset)
      raise ActionNotSupportedError.new(:delete, self)
    end

    alias :- :delete

    #
    # Create a pathset containing only paths in both this and the other pathset.
    #
    def filter(pathset)
      raise ActionNotSupportedError.new(:filter, self)
    end

    alias :intersection :filter
    alias :& :filter

    #
    # Create a pathset containing all paths in both pathsets.
    #
    def union(pathset)
      raise ActionNotSupportedError.new(:union, self)
    end

    alias :| :union

    #
    # Create a new pathset matching each path in a followed by each path in b.
    #
    # a.join(b) == a/b
    # {a,b}.join({c,d}) == {a,b}/{c,d}
    #
    def join(*pathset)
      raise ActionNotSupportedError.new(:join, self)
    end

    alias :+ :join

    #
    # Split the pathset by path separator.
    #
    # Equivalent to repeating chdir('*') over and over.
    #
    # Arguments:
    # - n - the number of paths to split by--n=1 means return a head and a long tail.
    #
    # Example:
    # parts = expression.split
    # head, remainder = expression.split(1)
    def split_top(n=nil)
      results = []
      tail = self
      while true
        head, new_tail = tail.chdir('*')
        results << head
        if new_tail.empty?
          return results
        end
        if tail == new_tail
          raise InfinitePathSetError.new(self)
        end
        tail = new_tail
      end
      results
    end

    #
    # Descend into the given expression.
    #
    # Returns a PathMap where the range is an intersected A&B
    #
    # More formally, return a pair of pathsets [a,b] such that a.join(b) == self&(pathset.join('**'))
    #
    # (It looks a lot like a partial intersection, don't it?)
    #
    # If pathset is an exact path, a == pathset and b == remainder of self
    #
    def chdir(pathset)
      raise ActionNotSupportedError.new(:each, self)
    end

    #
    # A list of pathsets without unions in them that represent this pathset.
    # (Repeats like * and ** are allowed.)
    #
    def without_unions
      raise ActionNotSupportedError.new(:each, self)
    end

    #
    # Expand .. and . along the path, to the extent possible. If a path is
    # passed as an argument, expands relative to that path and creates an
    # absolute URL if .. goes off the top of the expression.
    #
    # 'x/y/.././z'.expand_path -> 'x/z'
    # '../x/./y/z'.expand_path('/a/b/c') -> /a/b/c/x/y/z
    #
    def expand_path(pathset=nil)
      raise ActionNotSupportedError.new(:each, self)
    end

    #
    # Tell whether this path is absolute.
    #
    def absolute?
      # TODO implement absolute paths, . and ..
      false
    end

    private

    NOT_SET = Object.new
  end
end
