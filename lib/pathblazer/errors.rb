module Pathblazer
  module Errors
    # All Pathblazer errors descend from this.
    class PathblazerError < Error
    end

    # A source-specific error.
    class SourceError < PathblazerError
      def initialize(error, *args)
        @error = error
      end

      # The original error.
      attr_reader :error
    end

    #
    # An error involving a pathset.
    #
    class PathError < PathblazerError
      def initialize(pathset, *args)
        super(*args)
      end

      #
      # The pathset involved in the error.
      #
      attr_reader :pathset
    end

    #
    # The pathset did not match any results.
    #
    class PathMatchesNoResultsError < PathError
    end

    #
    # The pathset already matched results: this error is thrown by set when
    # replacement is not allowed.
    #
    class PathAlreadyMatchesResults < PathError
    end

    #
    # The pathset matched more than one result, and one result per pathset was required.
    #
    class PathMatchesMultipleResultsError < PathError
      def initialize(pathset, results, *args)
        super(pathset, *args)
        @results = results
      end

      #
      # The results, in a pathmap.
      #
      # This may or may not be set; it is pathmap-dependent, a courtesy as long
      # as it is easy to do.
      #
      attr_reader :results
    end

    #
    # Thrown when the pathset you pass is entirely out of range for the target.
    #
    # This exception may not be thrown by all pathmaps: it exists as a convenient
    # way to signal the impossible match.
    #
    class PathOutOfRangeError < PathError
    end

    #
    # You asked to do a pathmap operation with :only_if, and the only_if
    # returned false or unknown.
    #
    class OnlyIfFailedError < PathError
      def initialize(pathset, failed_results, *args)
        super(pathset, *args)
        @failed_results = failed_results
      end

      #
      # The offending results, in a pathmap.
      #
      # This may or may not be set; it is pathmap-dependent, a courtesy as long
      # as it is easy to do.
      #
      attr_reader :failed_results
    end

    #
    # You tried to get an array of an infinite list of paths.  (each is just fine.)
    #
    # I love that this error exists.
    #
    class InfinitePathsError < PathError
    end
  end
end
