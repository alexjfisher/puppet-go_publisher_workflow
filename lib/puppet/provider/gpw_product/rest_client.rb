require 'json'
require 'rest-client' if Puppet.features.restclient?
require 'rexml/document'
include REXML

Puppet::Type.type(:gpw_product).provide(:rest_client) do
  confine :feature => :restclient
  commands :unzip => 'unzip'

  mk_resource_methods

  def initialize(value={})
    super(value)
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.instances
    urls = get_instance_urls
    urls.collect do |url|
      new get_product_properties(get_product_json(url))
    end
  end

  def self.get_product_json(url)
    response = RestClient.get(url, {:accept => :json} )
    JSON.parse(response)['PublishProduct']
  end

  def self.get_instance_urls
    url = 'http://localhost:7003/go-publisher-workflow-product-admin/products' # TODO MAKE THIS CONFIGURABLE??
    begin
      response = RestClient.get(url, {:accept => :json} )
    rescue Exception => e
      Puppet.debug "RestClient.get #{url} had an error -> #{e.inspect}"
      return []
    end
    JSON.parse(response)['PublishProducts']['publishProduct'].collect do |product|
      product['href']
    end
  end

  def self.get_product_properties(product)
    product_properties = {}
    product_properties[:ensure] = :present
    product_properties[:provider] = :rest_client
    product_properties[:name] = product['name']
    product_properties
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def destroy
    url = "http://localhost:7003/go-publisher-workflow-product-admin/products/#{resource[:name]}"
    RestClient.delete(url)
    @property_hash.clear
  end

  def create
    validate_all
    url = 'http://localhost:7003/go-publisher-workflow-product-admin/products'
    RestClient.post(url, read_source, { :content_type => 'application/zip', :accept => :json }) do |response, request, result, &block|
      case response.code
      when 201
        @property_hash = self.class.get_product_properties({:name => resource[:name]})
      else
        fail "Go Publisher API returned #{response.code} when uploading #{resource[:name]}. #{JSON.parse(response)}"
      end
    end
  end

  def read_source
    file = File.new(resource[:source], 'rb')
    file.read
  end

  def validate_all
    fail "source is required when creating new resource file" unless has_source?
    fail "name does not match gpa:name element in product.xml" unless product_name_matches?
  end

  def has_source?
    return false if resource[:source].nil?
    true
  end

  def product_name_matches?
    product_xml = unzip(['-p',resource[:source], 'product.xml'])
    doc = Document.new(product_xml)
    product_name_in_zip = XPath.first(doc, '//gpa:name')[0]
    resource[:name] == product_name_in_zip.to_s
  end
end
