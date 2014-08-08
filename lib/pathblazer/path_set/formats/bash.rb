require 'pathblazer/path_set/formats/generic'

module Pathblazer
  class PathSet
    module Formats
      class Bash < Generic
        # TODO path lists, urls ...
        # TODO character sets
        # TODO extended globs? ?() *() +() @() !()
        def initialize
          super('bash')
        end
      end
    end
  end
end
