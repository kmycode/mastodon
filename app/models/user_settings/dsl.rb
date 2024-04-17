# frozen_string_literal: true

module UserSettings::DSL
  module ClassMethods
    def setting(key, options = {})
      @definitions ||= {}

      UserSettings::Setting.new(key, options).tap do |s|
        @definitions[s.key] = s
      end
    end

    def setting_inverse_alias(key, original_key)
      @definitions[key] = @definitions[original_key].inverse_of(key)
    end

    def setting_inverse_array(key, original_key, reverse_array)
      @definitions[key] = @definitions[original_key].array_inverse_of(key, reverse_array)
    end

    def namespace(key, &block)
      @definitions ||= {}

      UserSettings::Namespace.new(key).configure(&block).tap do |n|
        @definitions.merge!(n.definitions)
      end
    end

    def keys
      @definitions.keys
    end

    def definition_for(key)
      @definitions[key.to_sym]
    end

    def definition_for?(key)
      @definitions.key?(key.to_sym)
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end
end
