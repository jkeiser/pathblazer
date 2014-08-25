#require 'pathblazer/extensible_dsl'
#require 'pathblazer/pathmap/relative'
#require 'pathblazer/store/ruby_init_registration'
require 'pathblazer/dsl'

module Pathblazer
  class Context
    def self.global
      @global ||= begin
#        @@init_registration ||= Pathblazer::Store::RubyInitRegistration(global_root, '')
        Pathblazer::Context.new
      end
    end

    include Pathblazer::DSL

    # cache, merged sources, extensible dsl, caching, freezing, split.
#    attr_reader :root
  #
  #   protected
  #
  #   def initialize
  #     dsl = ExtensibleDSL.new(Pathmap::Relative.new(root, 'pathblazer/dsl'))
  #     dsl.attach_to(self)
  #   end
  #
  #   def self.init_registration
  #     @@init_registration ||= begin
  #       Pathblazer::Store::RubyInitRegistration.new(dsl_store, 'pathblazer/dsl/init/\1') do ||
  #       end
  #     end
  #   end
  #
  #   def self.pathblazer_dsl_store
  #     # The DSL store is not allowed to set duplicates
  #     @@dsl_store ||= Pathblazer::Filter::SetOptions(
  #       Pathblazer::Store::PathmapStore.new({
  #         'modules/**' =>
  #         'classes/**' =>
  #       }, [ Module, Class, ]),
  #       :set => { :if_already_has_results => :fail })
  #   end
  # end
end
