require 'pathblazer/source'

module Pathblazer
  module Sources
    class File
      # TODO get file to cooperate with authorization and further restrict by
      # actual user/group?
      def initialize(context, root)
        super(context)
        @root = path.new(root)
      end

      def range
        '**'
      end

      def each(path=range, desired_data=Source.DEFAULT_DESIRED_DATA)
        matches = path.glob_matches { |glob| Dir.glob((root + glob).to_s) }
        matches.each { |match| yield construct_result(match, desired_data) }
      end

      def glob_matches
        current = [ self ]
        while matches, glob, next_part = path.next_glob
          matches.each(current) do
          end
        end
      end

      def copy_to(store, options={})

      end
    end
  end
end
