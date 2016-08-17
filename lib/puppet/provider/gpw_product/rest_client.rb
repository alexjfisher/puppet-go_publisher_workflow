require 'json'
require 'rest-client' if Puppet.features.restclient?
require 'rexml/document'
include REXML

Puppet::Type.type(:gpw_product).provide(:rest_client) do
  confine :feature => :restclient
  commands :unzip => 'unzip'

  mk_resource_methods

  def initialize(value = {})
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
    response = RestClient.get(url, :accept => :json)
    JSON.parse(response)['PublishProduct']
  end

  def self.get_instance_urls
    url = 'http://localhost:7003/go-publisher-workflow-product-admin/products' # TODO: MAKE THIS CONFIGURABLE??
    response = RestClient.get(url, :accept => :json)
    JSON.parse(response)['PublishProducts']['publishProduct'].collect do |product|
      product['href']
    end
  end

  def self.get_product_properties(product)
    product_properties = {}
    product_properties[:ensure] = :present
    product_properties[:provider] = :rest_client
    product_properties[:name] = product['name']
    product_properties[:publisher_project_url] = product['publisherProject']['href'] unless product['publisherProject'].nil?
    product_properties
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def destroy
    delete_all_product_jobs
    delete_product
    @property_hash.clear
  end

  def delete_all_product_jobs
    all_job_urls.each do |url|
      if product_associated_with_job(url) == resource[:name]
        Puppet.debug "#{resource[:name]} has job at #{url}. Deleting."
        delete_job(url)
      else
        Puppet.debug "#{url} is not associated with #{resource[:name]}. Not deleting"
      end
    end
  end

  def all_job_urls
    url = 'http://localhost:7003/go-publisher-workflow/api/jobs'
    response = RestClient.get(url, :accept => :json)
    JSON.parse(response)['PublishJobs']['publishJob'].collect do |job|
      job['href']
    end
  end

  def product_associated_with_job(url)
    response = RestClient.get(url, :accept => :json)
    JSON.parse(response)['PublishJob']['product']['ref']
  end

  def delete_job(url)
    Puppet.debug "Deleting job at #{url}"
    RestClient.delete(url)
  end

  def delete_product
    Puppet.debug "Deleting product #{resource[:name]}"
    RestClient.delete("http://localhost:7003/go-publisher-workflow-product-admin/products/#{resource[:name]}")
  end

  def create
    validate_all
    url = 'http://localhost:7003/go-publisher-workflow-product-admin/products'
    RestClient.post(url, read_source, :content_type => 'application/zip', :accept => :json) do |response, request, result, &block|
      case response.code
      when 201
        @property_hash = self.class.get_product_properties(:name => resource[:name])
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
    fail 'source is required when creating new gpw_product'    unless has_source?
    fail 'name does not match gpa:name element in product.xml' unless product_name_matches?
  end

  def has_source?
    return false if resource[:source].nil?
    true
  end

  def product_name_matches?
    product_xml = unzip('-p', resource[:source], 'product.xml')
    doc = Document.new(product_xml)
    product_name_in_zip = XPath.first(doc, '//gpa:name')[0]
    resource[:name] == product_name_in_zip.to_s
  end

  def project_xml
    url = @property_hash[:publisher_project_url]
    response = RestClient.get(url, :accept => :json)
    JSON.parse(response)['String']
  end
end
