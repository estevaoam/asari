class Asari
  class StatementBuilder

    attr_reader :key, :value

    DEFAULT_CONVERSION = lambda do |key, value|
      "#{key}:#{convert_value(value)}"
    end

    TYPE_CONVERSION = {
      [Integer, Float] => lambda do |v|
        "#{v}"
      end,
      [Date, Time, DateTime] => lambda do |v|
        "'#{v.strftime("%Y-%m-%dT%H:%M:%SZ")}'"
      end
    }

    CONVERSIONS = {
      [Hash, Range] => lambda do |key, value|
        "#{key}:[#{convert_value(value.first)},#{convert_value(value.last)}]"
      end,
      Array => lambda do |key, value|
        value.inject("") do |memo, v|
          memo + " #{key}:#{convert_value(v)}"
        end
      end
    }

    def initialize(key, value)
      @key, @value = key, value
    end

    def build
      func = convertor(value)

      if func
        func.call(key, value)
      end
    end

    private
    def convertor(value)
      CONVERSIONS.each do |klass, func|
        self.class.convertor_satisfies?(klass, value) and return func
      end

      # If any other kind of value
      DEFAULT_CONVERSION
    end

    # Convert value based on it's class
    def self.convert_value(value)
      f = nil

      TYPE_CONVERSION.each do |klass, func|
        if convertor_satisfies?(klass, value)
          f = func and break
        end
      end

      if f
        f.call(value)
      else
        "'#{value.to_s}'"
      end
    end

    def self.convertor_satisfies?(klass, value)
      if klass.is_a?(Array)
        klass.each do |k|
          return true if value.is_a?(k)
        end
      else
        return value.is_a?(klass)
      end

      return false
    end
  end
end
