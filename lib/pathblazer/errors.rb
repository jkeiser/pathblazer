module Pathblazer
  module Errors
    # All Pathblazer errors descend from this.
    class PathblazerError < StandardError
    end

    # A source-specific error.
    class SourceError < PathblazerError
      def initialize(error, *args)
        @error = error
      end

      # The original error.
      attr_reader :error
    end

    class ParseError < PathblazerError
    end

    #
    # An error involving a path.
    #
    class PathError < PathblazerError
      def initialize(path, *args)
        super(*args)
      end

      #
      # The path involved in the error.
      #
      attr_reader :path
    end

    #
    # The path did not match any results.
    #
    class PathMatchesNoResultsError < PathError
    end

    #
    # The path already matched results: this error is thrown by set when
    # replacement is not allowed.
    #
    class PathAlreadyMatchesResults < PathError
    end

    #
    # The path matched more than one result, and one result per path was required.
    #
    class PathMatchesMultipleResultsError < PathError
      def initialize(path, results, *args)
        super(path, *args)
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
    # Thrown when the path you pass is entirely out of range for the target.
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
      def initialize(path, failed_results, *args)
        super(path, *args)
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
