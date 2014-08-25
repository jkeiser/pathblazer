require 'pathblazer/store'
require 'pathblazer/path_map'

module Pathblazer
  module Store
    class File < PathMap
      # TODO get file to cooperate with authorization and further restrict by
      # actual user/group?
      def initialize(context, root)
        super(context)
        @root = root
      end

      include Pathblazer::DSL

      def range
        '**'
      end

      def each(path=range, options={})
        paths = path.match_step(:globstar => path.formats.bash) do |glob, regex|
          Dir.glob(File.join(root, glob).select { |path| path =~ regex }
        end
        paths.each do |path|
          yield path.store_entry(path)
        end
      end
    end
  end
end
