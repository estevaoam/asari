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
      end,
      Array => lambda do |key, value|
        value.inject("") do |memo, v|
          if v.is_a?(Integer) || v.is_a?(Float)
            memo + " #{key}:#{v}"
          else
            memo + " #{key}:'#{v.to_s}'"
          end
        end
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

      # If any other kind of value
      DEFAULT_CONVERSION
    end

  end
end
