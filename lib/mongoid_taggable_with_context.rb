module Mongoid::TaggableWithContext
  def self.mongoid2?
    ::Mongoid.const_defined? :Contexts
  end
  def self.mongoid3?
    ::Mongoid.const_defined? :Observer
  end
end

if Mongoid::TaggableWithContext.mongoid2?
  module Mongoid
    module Extensions
      module Module

        # Redefine the method. Will undef the method if it exists or simply
        # just define it.
        #
        # @example Redefine the method.
        #   Object.re_define_method("exists?") do
        #     self
        #   end
        #
        # @param [ String, Symbol ] name The name of the method.
        # @param [ Proc ] block The method body.
        #
        # @return [ Method ] The new method.
        #
        # @since 3.0.0
        def re_define_method(name, &block)
          undef_method(name) if method_defined?(name)
          define_method(name, &block)
        end
      end
    end
  end

  ::Module.__send__(:include, Mongoid::Extensions::Module)
end

require 'active_support/concern'

require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/aggregation_strategy/map_reduce')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/aggregation_strategy/real_time')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/aggregation_strategy/real_time_group_by')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/deprecations')
require File.join(File.dirname(__FILE__), 'mongoid/taggable_with_context/version')