# frozen_string_literal: true

class UserSettings::Setting
  attr_reader :name, :namespace, :in

  def initialize(name, options = {})
    @name          = name.to_sym
    @default_value = options[:default]
    @namespace     = options[:namespace]
    @in            = options[:in]
  end

  def inverse_of(name)
    @inverse_of = name.to_sym
    self
  end

  def array_inverse_of(name, arr)
    @inverse_of_array = name.to_sym
    @reverse_array = arr
    self
  end

  def value_for(name, original_value)
    value = begin
      if original_value.nil?
        default_value
      else
        original_value
      end
    end

    value = value.compact_blank if value.is_a?(Array)

    if !@inverse_of.nil? && @inverse_of == name.to_sym
      !value
    elsif !@inverse_of_array.nil? && @inverse_of_array == name.to_sym
      reverse_array(value)
    else
      value
    end
  end

  def reverse_array(value)
    @reverse_array.clone.filter { |v| value.exclude?(v) }
  end

  def default_value
    if @default_value.respond_to?(:call)
      @default_value.call
    else
      @default_value
    end
  end

  def array_type?
    default_value.is_a?(Array) || default_value == []
  end

  def type
    return ActiveRecord::Type.lookup(:string, array: true) if array_type?

    case default_value
    when TrueClass, FalseClass
      ActiveModel::Type::Boolean.new
    when Integer
      ActiveModel::Type::Integer.new
    else
      ActiveModel::Type::String.new
    end
  end

  def type_cast(value)
    if type.respond_to?(:cast)
      type.cast(value)
    else
      value
    end
  end

  def to_a
    [key, default_value]
  end

  def key
    if namespace
      :"#{namespace}.#{name}"
    else
      name
    end
  end
end
