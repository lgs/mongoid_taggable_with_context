module Mongoid::TaggableWithContext
  extend ActiveSupport::Concern

  class AggregationStrategyMissing < Exception; end
  class InvalidTagsFormat < Exception; end

  DEFAULT_FIELD = :tags
  DEFAULT_SEPARATOR = ' '

  included do
    class_attribute :taggable_with_context_options
    self.taggable_with_context_options = {}
  end

  def tag_string_for(context)
    self.read_attribute(context).join(self.class.get_tag_separator_for(context)) rescue ""
  end

  def set_tag_string_for(context, value)
    self.write_attribute(context, self.class.format_tags_for(context, value))
  end

  module ClassMethods
    # Macro to declare a document class as taggable, specify field name
    # for tags, and set options for tagging behavior.
    #
    # @example Define a taggable document.
    #
    #   class Article
    #     include Mongoid::Document
    #     include Mongoid::TaggableWithContext
    #     taggable :keywords, separator: ' ', default: ['foobar']
    #   end
    #
    # @param [ Symbol ] field The name of the field for tags. Defaults to :tags if not specified.
    # @param [ Hash ] options Options for taggable behavior.
    #
    # @option options [ String ] :separator
    #   The delimiter used when converting the tags to and from String format. Defaults to ' '
    # @option options [ :Symbol ] :group_by_field
    #   The Mongoid field to group by when RealTimeGroupBy aggregation is used.
    # @option options [ <various> ] :default, :as, :localize, etc.
    #   Options for Mongoid #field method will be automatically passed
    #   to the underlying Array field
    def taggable(*args)
      # init variables
      options = args.extract_options!
      field = args.present? ? args.shift.to_sym : DEFAULT_FIELD
      added = add_taggable(field, options)
      # TODO: test if this is needed
      # descendants.each do |subclass|
      #   subclass.add_taggable(field, options)
      # end
      added
    end

    def tag_contexts
      self.taggable_with_context_options.keys
    end

    def tag_database_fields
      self.taggable_with_context_options.keys.map do |context|
        tag_options_for(context)[:db_field]
      end
    end

    def tag_options_for(context)
      self.taggable_with_context_options[context]
    end

    def tags_for(context, group_by=nil, conditions={})
      raise AggregationStrategyMissing
    end

    def tags_with_weight_for(context, group_by=nil, conditions={})
      raise AggregationStrategyMissing
    end

    def get_tag_separator_for(context)
      self.taggable_with_context_options[context][:separator]
    end

    def get_tag_group_by_field_for(context)
      self.taggable_with_context_options[context][:group_by_field]
    end

    # Find documents tagged with all tags passed as a parameter, given
    # as an Array or a String using the configured separator.
    #
    # @example Find matching all tags in an Array.
    #   Article.tagged_with(['ruby', 'mongodb'])
    # @example Find matching all tags in a String.
    #   Article.tagged_with('ruby, mongodb')
    #
    # @param [ String ] :field The field name of the tag.
    # @param [ Array<String, Symbol>, String ] :tags Tags to match.
    # @return [ Criteria ] A new criteria.
    def tagged_with(context, tags)
      tags = format_tags_for(context, tags)
      field = tag_options_for(context)[:field]
      all_in(field => tags)
    end

    # Helper method to convert a a tag input value of unknown type
    # to a formatted array.
    def format_tags_for(context, value)
      return nil if value.nil?
      # 0) Tags must be an array or a string
      raise InvalidTagsFormat unless value.is_a?(Array) || value.is_a?(String)
      # 1) convert String to Array
      value = value.split(get_tag_separator_for(context)) if value.is_a? String
      # 2) remove all nil values
      # 3) strip all white spaces. Could leave blank strings (e.g. foo, , bar, baz)
      # 4) remove all blank strings
      # 5) remove duplicate
      value.compact.map(&:strip).reject(&:blank?).uniq
    end

    protected

    # Adds a taggable context to the list of contexts, and creates the underlying
    # Mongoid field and alias methods for the context.
    #
    # @param [ Symbol ] field The name of the Mongoid database field to store the taggable.
    # @param [ Hash ] options The taggable options.
    #
    # @since 1.1.1
    def add_taggable(field, options)
      validate_taggable_options(options)

      # db_field: the field name stored in the database
      options[:db_field] = field.to_sym
      # field: the field name used to identify the tags. :field will
      # be identical to :db_field unless the :as option is specified
      options[:field] = options[:as] || field
      context = options[:field]
      options.reverse_merge!(
          separator: DEFAULT_SEPARATOR
      )

      # register / update settings
      self.taggable_with_context_options[options[:field]] = options

      create_taggable_mongoid_field(field, options)
      create_taggable_mongoid_index(context)
      define_taggable_accessors(context)
    end

    # Validates the taggable options and raises errors if invalid options are detected.
    #
    # @param [ Hash ] options The taggable options.
    #
    # @since 1.1.1
    def validate_taggable_options(options)
      if options[:field]
        raise <<-ERR
          taggable :field option has been removed as of version 1.1.1. Please use the
          syntax "taggable <database_name>, as: <tag_name>"
        ERR
      end
      if options[:string_method]
        raise <<-ERR
          taggable :string_method option has been removed as of version 1.1.1. Please
          define an alias to "<tags>_string" in your Model
        ERR
      end
    end

    # Creates the underlying Mongoid field for the tag context.
    #
    # @param [ Symbol ] name The name of the Mongoid field.
    # @param [ Hash ] options Options for the Mongoid field.
    #
    # @since 1.1.1
    def create_taggable_mongoid_field(name, options)
      field name, mongoid_field_options(options)
    end

    # Prepares valid Mongoid option keys from the taggable options. Slices
    # the taggable options to include only valid options for the Mongoid #field
    # method, and coerces :type to Array.
    #
    # @param [ Hash ] :options The taggable options hash.
    # @return [ Hash ] A options hash for the Mongoid #field method.
    #
    # @since 1.1.1
    def mongoid_field_options(options = {})
      if Mongoid::TaggableWithContext.mongoid2?
        options.merge!(type: Array) # Skip validation for mongoid2
      else
        options.slice(*::Mongoid::Fields::Validators::Macro::OPTIONS).merge!(type: Array)
      end
    end

    # Creates an index for the underlying Mongoid field.
    #
    # @param [ Symbol ] name The name or alias name of Mongoid field.
    #
    # @since 1.1.1
    def create_taggable_mongoid_index(name)
      if Mongoid::TaggableWithContext.mongoid2?
        index :name, background: true
      else
        index({ name => 1 }, { background: true })
      end
    end

    # Defines all accessor methods for the taggable context at both
    # the instance and class level.
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_taggable_accessors(context)
      define_class_tags_getter(context)
      define_class_weighted_tags_getter(context)
      define_class_separator_getter(context)
      define_class_tagged_with_getter(context)
      define_class_group_by_getter(context)
      define_instance_tag_string_getter(context)
      define_instance_tag_setter(context)
    end

    # Create the singleton getter method to retrieve all tags
    # of a given context for all instances of the model.
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_class_tags_getter(context)
      # retrieve all tags ever created for the model
      self.class.class_eval do
        define_method context do |group_by = nil|
          tags_for(context, group_by)
        end
      end
    end

    # Create the singleton getter method to retrieve a weighted
    # array of tags of a given context for all instances of the model.
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_class_weighted_tags_getter(context)
      self.class.class_eval do
        define_method :"#{context}_with_weight" do |group_by = nil|
          tags_with_weight_for(context, group_by)
        end
      end
    end

    # Create the singleton getter method to retrieve the tag separator
    # for a given context for all instances of the model.
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_class_separator_getter(context)
      self.class.class_eval do
        define_method :"#{context}_separator" do
          get_tag_separator_for(context)
        end
      end
    end

    # Create the singleton getter method to retrieve the all
    # instances of the model which contain the tag/tags for a given context.
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_class_tagged_with_getter(context)
      self.class.class_eval do
        define_method :"#{context}_tagged_with" do |tags|
          tagged_with(context, tags)
        end
      end
    end

    # Create the singleton getter method to retrieve the
    # group_by field
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_class_group_by_getter(context)
      self.class.class_eval do
        define_method :"#{context}_group_by_field" do
          get_tag_group_by_field_for(context)
        end
      end
    end

    # Create the setter method for the provided taggable, using an
    # alias method chain to the underlying field method.
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_instance_tag_setter(context)
      generated_methods.module_eval do
        re_define_method("#{context}_with_taggable=") do |value|
          value = self.class.format_tags_for(context, value)
          self.send("#{context}_without_taggable=", value)
        end
        alias_method_chain "#{context}=", :taggable
      end
    end

    # Create the getter method for the joined tags string.
    #
    # @param [ Symbol ] context The name of the tag context.
    #
    # @since 1.1.1
    def define_instance_tag_string_getter(context)
      generated_methods.module_eval do
        re_define_method("#{context}_string") do
          tag_string_for(context)
        end

        re_define_method("#{context}_string=") do |value|
          set_tag_string_for(context, value)
        end
      end
    end
  end
end
