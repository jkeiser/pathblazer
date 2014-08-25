require 'pathblazer/path_set/formats/bash'

module Pathblazer
  module DSL
    def path(value=nil)
      if value
        path.default_format.from(value)
      else
        @path ||= Pathblazer::DSL::PathDSL.new
      end
    end

    # def root
    #   Pathmap::new
    # end

    class PathDSL
      def initialize
        @default_format = formats.bash
        @shell_format = formats.bash
      end
      attr_accessor :default_format
      attr_accessor :shell_format

      def formats
        @formats ||= PathDSL::Formats.new
      end

      # TODO dynamically initialize formats in this class via init registration
      class Formats
        def bash
          @bash ||= Pathblazer::PathSet::Formats::Bash.new
        end
      end
    end
  end
end
