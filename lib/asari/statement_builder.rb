class Asari
  class StatementBuilder

    DEFAULT_CONVERSION = lambda do |key, value|
      "#{key}:'#{value.to_s}'"
    end

    CONVERSIONS = {
      Range => lambda do |key, value|
        "#{key}:[#{value.first},#{value.last}]"
      end,
      Integer => lambda do |key, value|
        "#{key}:#{value}"
      end,
      Hash => lambda do |key, value|
        "#{key}:[#{value.first},#{value.last}]"
      end
    }


    attr_reader :key, :value

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
        return func if value.kind_of?(klass)
      end

      # If other class
      DEFAULT_CONVERSION
    end

  end
end
