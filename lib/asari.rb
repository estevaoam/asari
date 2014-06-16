require "asari/version"

require "asari/collection"
require "asari/exceptions"
require "asari/geography"
require "asari/statement_builder"

require "httparty"

require "ostruct"
require "json"
require "cgi"

class Asari
  def self.mode
    @@mode
  end

  def self.mode=(mode)
    @@mode = mode
  end

  attr_writer :api_version
  attr_writer :search_domain
  attr_writer :aws_region

  def initialize(search_domain=nil, aws_region=nil)
    @search_domain = search_domain
    @aws_region = aws_region
  end

  # Public: returns the current search_domain, or raises a
  # MissingSearchDomainException.
  #
  def search_domain
    @search_domain || raise(MissingSearchDomainException.new)
  end

  # Public: returns the current api_version, or the sensible default of
  # "2013-01-01" (at the time of writing, the current version of the
  # CloudSearch API).
  #
  def api_version
    @api_version || "2013-01-01"
  end

  # Public: returns the current aws_region, or the sensible default of
  # "us-east-1."
  def aws_region
    @aws_region || "us-east-1"
  end

  # Public: Search for the specified term.
  #
  # Examples:
  #
  #     @asari.search("fritters") #=> ["13","28"]
  #     @asari.search(filter: { and: { type: 'donuts' }}) #=> ["13,"28","35","50"]
  #     @asari.search("fritters", filter: { and: { type: 'donuts' }}) #=> ["13"]
  #
  # Returns: An Asari::Collection containing all document IDs in the system that match the
  #   specified search term. If no results are found, an empty Asari::Collection is
  #   returned.
  #
  # Raises: SearchException if there's an issue communicating the request to
  #   the server.
  def search(term, options = {})
    return Asari::Collection.sandbox_fake if self.class.mode == :sandbox

    term, options = "", term if term.is_a?(Hash) && options.empty?

    bq = boolean_query(options[:filter]) if options[:filter]
    page_size = options[:page_size].nil? ? 10 : options[:page_size].to_i

    url = "http://search-#{search_domain}.#{aws_region}.cloudsearch.amazonaws.com/#{api_version}/search"
    url += "?q=#{CGI.escape(term)}"
    url += "&fq=#{CGI.escape(bq)}" if options[:filter] && options[:filter].any?
    url += "&q.parser=structured" if options[:filter] || term == 'matchall'
    url += "&size=#{page_size}"
    url += "&return=#{options[:return_fields].join ','}" if options[:return_fields]

    if options[:page]
      start = (options[:page].to_i - 1) * page_size
      url << "&start=#{start}"
    end

    if options[:rank]
      rank = normalize_rank(options[:rank])
      url << "&rank=#{rank}"
    end

    begin
      response = HTTParty.get(url)
    rescue Exception => e
      ae = Asari::SearchException.new("#{e.class}: #{e.message} (#{url})")
      ae.set_backtrace e.backtrace
      raise ae
    end

    unless response.response.code == "200"
      raise Asari::SearchException.new("#{response.response.code}: #{response.response.msg} (#{url})")
    end

    Asari::Collection.new(response, page_size)
  end

  # Public: Compound search.
  #
  # Examples:
  #
  #     @asari.compound_search(query: { and: { email: 'test@mailinator.com' }, or: { type: 'person' } }) #=> ["13","28"]
  #
  # Returns: An Asari::Collection containing all document IDs in the system that match the
  #   specified search term. If no results are found, an empty Asari::Collection is
  #   returned.
  #
  # Raises: SearchException if there's an issue communicating the request to
  #   the server.
  def compound_search(options = {})
    return Asari::Collection.sandbox_fake if self.class.mode == :sandbox

    query = options.delete(:query)
    return [] unless query

    query = boolean_query(query)
    page_size = options[:page_size].nil? ? 10 : options[:page_size].to_i

    url = "http://search-#{search_domain}.#{aws_region}.cloudsearch.amazonaws.com/#{api_version}/search"
    url += "?q=#{CGI.escape(query)}"
    url += "&q.parser=structured"
    url += "&size=#{page_size}"
    url += "&return=#{options[:return_fields].join ','}" if options[:return_fields]


    if options[:page]
      start = (options[:page].to_i - 1) * page_size
      url << "&start=#{start}"
    end

    if options[:rank]
      rank = normalize_rank(options[:rank])
      url << "&rank=#{rank}"
    end

    begin
      response = HTTParty.get(url)
    rescue Exception => e
      ae = Asari::SearchException.new("#{e.class}: #{e.message} (#{url})")
      ae.set_backtrace e.backtrace
      raise ae
    end

    unless response.response.code == "200"
      raise Asari::SearchException.new("#{response.response.code}: #{response.response.msg} (#{url})")
    end

    Asari::Collection.new(response, page_size)
  end


  # Public: Add an item to the index with the given ID.
  #
  #     id - the ID to associate with this document
  #     fields - a hash of the data to associate with this document. This
  #       needs to match the search fields defined in your CloudSearch domain.
  #
  # Examples:
  #
  #     @asari.update_item("4", { :name => "Party Pooper", :email => ..., ... }) #=> nil
  #
  # Returns: nil if the request is successful.
  #
  # Raises: DocumentUpdateException if there's an issue communicating the
  #   request to the server.
  #
  def add_item(id, fields)
    return nil if self.class.mode == :sandbox
    query = { "type" => "add", "id" => id.to_s }

    fields = normalize_field_data(fields)

    query["fields"] = fields
    doc_request(query)
  end

  # Public: Add multiple items.
  #
  #     documents - a hash of the data to associate with this document. This
  #       needs to match the search fields defined in your CloudSearch domain.
  #
  # Examples:
  #
  #     @asari.add_items({ :id => "4", :fields => { :name => "Party Pooper", :email => ..., ... } }) #=> nil
  #
  # Returns: nil if the request is successful.
  #
  # Raises: DocumentUpdateException if there's an issue communicating the
  #   request to the server.
  #
  def add_items(documents)
    return nil if self.class.mode == :sandbox

    if documents.any?
      query = []

      documents.each do |document|
        hash = { "type" => "add", "id" => document[:id].to_s }

        fields = normalize_field_data(document[:fields])

        hash["fields"] = fields
        query << hash
      end

      doc_request(query)
    end
  end

  # Public: Update an item in the index based on its document ID.
  #   Note: As of right now, this is the same method call in CloudSearch
  #   that's utilized for adding items. This method is here to provide a
  #   consistent interface in case that changes.
  #
  # Examples:
  #
  #     @asari.update_item("4", { :name => "Party Pooper", :email => ..., ... }) #=> nil
  #
  # Returns: nil if the request is successful.
  #
  # Raises: DocumentUpdateException if there's an issue communicating the
  #   request to the server.
  #
  def update_item(id, fields)
    add_item(id, fields)
  end

  # Public: Remove an item from the index based on its document ID.
  #
  # Examples:
  #
  #     @asari.search("fritters") #=> ["13","28"]
  #     @asari.remove_item("13") #=> nil
  #     @asari.search("fritters") #=> ["28"]
  #     @asari.remove_item("13") #=> nil
  #
  # Returns: nil if the request is successful (note that asking the index to
  #   delete an item that's not present in the index is still a successful
  #   request).
  # Raises: DocumentUpdateException if there's an issue communicating the
  #   request to the server.
  def remove_item(id)
    return nil if self.class.mode == :sandbox

    query = { "type" => "delete", "id" => id.to_s }
    doc_request query
  end

  # Internal: helper method: common logic for queries against the doc endpoint.
  #
  def doc_request(query)
    endpoint = "http://doc-#{search_domain}.#{aws_region}.cloudsearch.amazonaws.com/#{api_version}/documents/batch"

    query = [query] unless query.is_a?(Array)
    options = { :body => query.to_json, :headers => { "Content-Type" => "application/json"} }

    begin
      response = HTTParty.post(endpoint, options)
    rescue Exception => e
      ae = Asari::DocumentUpdateException.new("#{e.class}: #{e.message}")
      ae.set_backtrace e.backtrace
      raise ae
    end

    unless response.response.code == "200"
      e = Asari::DocumentUpdateException.new(
        "#{response.response.code}: #{response.response.msg} (#{response.inspect})"
      )

      raise e
    end

    nil
  end

  protected

  # Private: Builds the query from a passed hash
  #
  #     terms - a hash of the search query. %w(and or not) are reserved hash keys
  #             that build the logic of the query
  def boolean_query(terms = {}, options = {})
    # First, let's enclose all root not's
    # in an 'and'

    if terms[:not]
      terms[:and] ||= {}
      terms[:and].merge({ not: terms.delete(:not) })
    end

    reduce = lambda do |hash|
      hash.reduce("") do |memo, (key, value)|
        if %w(and or not).include?(key.to_s) && value.is_a?(Hash)
          sub_query = reduce.call(value)
          memo += "(#{key}#{sub_query})" unless sub_query.empty?
        else
          if value.is_a?(Array)
            memo += " (or #{build_statement(key, value)})"
          else
            memo += " #{build_statement(key, value)}"
          end
        end

        memo
      end
    end

    reduce.call(terms)
  end

  def build_statement(key, value)
    builder = Asari::StatementBuilder.new(key, value)
    builder.build
  end

  def normalize_field_data(fields)
    fields.each do |k,v|
      if v.is_a?(Array)
        fields[k] = v.map { |item| convert_date_or_time(item) }
      else
        fields[k] = convert_date_or_time(v)
      end

      fields[k] = "" if v.nil?
    end

    fields
  end

  def normalize_rank(rank)
    rank = Array(rank)
    rank << :asc if rank.size < 2
    rank[1] == :desc ? "-#{rank[0]}" : rank[0]
  end

  def convert_date_or_time(obj)
    if obj.kind_of?(Time) || obj.kind_of?(Date) || obj.kind_of?(DateTime)
      if obj.respond_to?(:strftime)
        return obj.strftime("%Y-%m-%dT%H:%M:%SZ")
      end
    end

    obj
  end
end

Asari.mode = :sandbox # default to sandbox
