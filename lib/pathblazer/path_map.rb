require 'pathblazer/errors'

module Pathblazer
  #
  # A PathMap is a mapping from paths to values.
  #
  # You can query a path map for a path or range of paths, and it will return
  # paths that match.  These paths are not guaranteed to be unique (one path
  # can have multiple results).
  #
  # A dictionary is a very simple example of a pathmap: you can query it for
  # exact paths and get back values.
  #
  # PathMap implementors must implement at least range, each, set, and delete.
  #
  class PathMap
    #
    # Return the range of paths this data store can handle.  ** means it can
    # hold any path.
    #
    # Restricting this will enable users of the pathmap to be more efficient.
    #
    def range
      raise ActionNotSupportedError.new(:range, self)
    end

    #
    # Iterate over results.
    #
    # Produces pairs, [ path, result ].  Not guaranteed to be unique.
    #
    # Options:
    # - TODO: only_if to narrow results?
    #
    def each(pathset=range, options={})
      raise ActionNotSupportedError.new(:each, self)
    end

    #
    # Iterate over the range.
    #
    # Returns a series of paths, each of which may have * and **, and the results
    # they map to.
    #
    def each_result_range
      raise ActionNotSupportedError.new(:each, self)
    end

    #
    # Set a result.
    #
    # Options:
    # - if_has_no_results - :create, :fail.  Default: create.
    # - if_already_has_results - :overwrite, :append, :fail.  Default: ovewrite.
    # - only_if: (atomically) run the given function against the result before
    #   deleting it.
    #
    # Exceptions:
    # - PathHasNoResultsError - if the path has no results and fail is specified.
    # - PathAlreadyMatchesResultsError - if the path already has results and fail is specified.
    # - PathNotSupportedError - if the given path is unsupported.  Many providers
    #   will not let you set('/path/with/*/or/**', value).
    # - PathOutOfRangeError: the path does not even partly match .range.
    # - OnlyIfFailed - the only-if failed.
    #
    def set(path, value, options={})
      raise ActionNotSupportedError.new(:set, self)
    end

    #
    # Move results from path to path.
    #
    # Takes a pathmap saying what paths to move.
    #
    # Options:
    # - only_if: (atomically) run the given function against the result before
    #   moving it.
    # - purge: if true, deletes the range of pathmap when moving the results in.
    #   Defaults to false.
    #
    # Exceptions:
    # - PathNotFoundError: the path matches no results.
    # - PathOutOfRangeError: the path does not even partly match .range.
    # - OnlyIfFailed: the only-if failed.
    #
    def move(pathmap, options={})
      raise ActionNotSupportedError.new(:set, self)
    end

    #
    # Delete results.
    #
    # Options:
    # - only_if: (atomically) run the given function against the result before
    #   deleting it.
    #
    # Exceptions:
    # - PathNotFoundError: the path matches no results.
    # - PathOutOfRangeError: the path does not even partly match .range.
    # - OnlyIfFailed: the only-if failed.
    #
    def delete(pathset, options={})
      move(EmptyPathMap.new(pathset), :purge => true)
    end

    #
    # Say whether this will match any paths.
    #
    def empty?
      begin
        each { return false }
      rescue InfinitePathsException
        return false
      end
      true
    end

    #
    # Get a result.
    #
    # Options:
    # - all: true returns an array with all matches (in case of duplicates).
    #   In case of no results, the array will be empty.
    #
    # Exceptions:
    # - PathHasMultipleResultsError: the path matched more than one result (can happen
    #   even if the path is exact, due to duplicates being supported).
    # - PathHasNoResultsError: the path matches no results.
    # - PathOutOfRangeError: the path is not even partly inside .range.
    #
    def get(pathset, options={})
      if options[:all]
        result = []
        each(pathset) do |value|
          result << value
        end
        result
      else
        result = NOT_SET
        each(pathset) do |value|
          if result == NOT_SET
            result = value
          else
            raise PathDuplicatedError.new(path)
          end
        end
        if result == NOT_SET
          raise PathNotFoundError.new(path)
        end
        result
      end
    end

    #
    # Set the path to the given value.  Existing values at the path will be
    # removed.  This is equivalent to set(path, value)
    #
    def []=(pathset, value)
      set(pathset, value)
    end

    #
    # Get the value at the given path.  Equivalent to get(path)
    #
    def [](pathset)
      get(pathset)
    end

    #
    # Merge the data from another pathmap into this one, using the given pathset
    # as a range.
    #
    # Options:
    # - if_has_no_results - if the other store has a path, and ours has no results, either :create or :fail.  Default: create.
    # - if_already_has_results - if a path has no results, either :overwrite or :fail.  Default: ovewrite.
    # - purge - if this option is on, all our paths in the given range will be purged.
    # - only_if: (atomically) run the given function against a value before deleting it.
    #
    # Exceptions:
    # - PathHasNoResultsError - if the path has no results and fail is specified.
    # - PathAlreadyMatchesResultsError - if the path already has results and fail is specified.
    # - PathNotSupportedError - if the given path is unsupported.
    # - PathOutOfRangeError: the path does not even partly match .range.
    # - OnlyIfFailed - the only-if failed.
    #
    def merge(pathmap, pathset = nil, options = {})
      pathset ||= pathmap.range
    end

    #
    # Returns a new pathset whose current directory is set to the path.  Absolute
    # URLs will resolve to the top, and relative URLs will resolve to the current
    # position.
    #
    def chdir(pathset)
      RelativePathMap.new(self, range.chdir(pathset))
    end

    #
    # Reroot at the given pathset.  This is like chdir(pathset), except that
    # absolute URLs will resolve to the top of the pathset and cwd will be /.
    #
    def reroot(pathset)
      RootedPathMap.new(self, range.chdir(pathset))
    end

    #
    # Returns the current working directory of this pathmap.  Relative paths
    # will be resolved relative to this.
    #
    def cwd
      raise "TODO implement absolute paths"
    end

    private

    NOT_SET = Object.new
  end
end
