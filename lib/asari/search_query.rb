class Asari
  class SearchQuery

    attr_reader :search_params, :conditions

    def initialize
      @search_params = ""
    end

    # Alias to and()
    def where(conditions)
      conditions.each do |key, value|
        @search_params =
      end

      self
    end

    def or(conditions)
      self
    end

    def not(conditions)
      self
    end

    private

    def build_statement(key, value)
      builder = Asari::StatementBuilder.new(key, value)
      builder.build
    end

  end
end
