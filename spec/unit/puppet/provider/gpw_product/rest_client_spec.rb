require 'spec_helper'
require 'fakefs/spec_helpers'
provider_class = Puppet::Type.type(:gpw_product).provider(:rest_client)

describe provider_class do
  describe 'instances' do
    it 'should have an instances method' do
      expect(described_class).to respond_to :instances
    end
    describe 'returns correct instances' do
      context 'when there are no products' do
        before :each do
          stub_request(:get, "http://localhost:7003/go-publisher-workflow-product-admin/products")
            .with(:headers => {'Accept'=>'application/json'})
            .to_return(:status => 200, :body => '{"PublishProducts":{"publishProduct":[]}}')
        end
        it 'should return no resources' do
          expect(described_class.instances.size).to eq(0)
        end
      end
      context 'with 1 product' do
        before :each do
          stub_request(:get, "http://localhost:7003/go-publisher-workflow-product-admin/products")
            .with(:headers => {'Accept'=>'application/json'})
            .to_return(:status => 200, :body => '{"PublishProducts":{"publishProduct":[{"href":"http://localhost:7003/go-publisher-workflow-product-admin/products/test"}]}}')
          stub_request(:get, "http://localhost:7003/go-publisher-workflow-product-admin/products/test")
            .with(:headers => {'Accept'=>'application/json'})
            .to_return(:status => 200, :body => '{
              "PublishProduct":{
                "name":"test",
                "defaultPathPatterns":[
                  {"id":null,"type":"FILE","value":"/{document}_{sequence}.gml"},
                  {"id":null,"type":"FILE","value":"/{document}.gml"},
                  {"id":null,"type":"FILE","value":"/{path}/{chunk}.gml"},
                  {"id":null,"type":"FILE","value":"/{path}/{chunk}_{sequence}.gml"}
                ],
                "publisherJndiDataSource":{"value":"GOPublisherDS"},
                "publisherProject":{"href":"http://localhost:7003/go-publisher-workflow-product-admin/products/test/projects/test.gpp"},
                "compressFiles":false,
                "generateArchive":true,
                "downloadEmptyFiles":true,
                "list":{"href":"http://localhost:7003/go-publisher-workflow-product-admin/products"}
              }}')
        end
        it 'should return 1 resource' do
          expect(described_class.instances.size).to eq(1)
        end
        it 'should return the resource "test"' do
          expect(described_class.instances[0].instance_variable_get("@property_hash")).to eq( {
            :ensure   => :present,
            :name     => 'test',
            :provider => :rest_client,
            :publisher_project_url => "http://localhost:7003/go-publisher-workflow-product-admin/products/test/projects/test.gpp"
          } )
        end
      end
    end
  end
  describe 'prefetch' do
    it 'should have a prefetch method' do
      expect(described_class).to respond_to :prefetch
    end
    describe 'when prefetching' do
      before :each do
        @resource_foo = Puppet::Type.type(:gpw_product).new(:name => "foo")
        @resource_bar = Puppet::Type.type(:gpw_product).new(:name => "bar")
        @resources = { "foo" => @resource_foo, "bar" => @resource_bar}
      end
      context 'when .instances returns some of the resources' do
        before :each do
          @only_provider_found = provider_class.new(@resource_foo)
          provider_class.stubs(:instances).returns([@only_provider_found])
        end
        describe '.prefetch' do
          context 'when provider for resource is found' do
            it 'should set the resource\'s provider' do
              @resource_foo.expects(:provider=).with(@only_provider_found)
              provider_class.prefetch(@resources)
            end
          end
          context 'when provider for resource is not found' do
            it 'should not set the resource\'s provider' do
              @resource_bar.expects(:provider=).never
              provider_class.prefetch(@resources)
            end
          end
        end
      end
    end
  end
  describe 'when an instance' do
    let :resource do
      Puppet::Type.type(:gpw_product).new(:name => "test", :provider => :rest_client)
    end
    let :provider do
      resource.provider
    end
    it 'should indicate when the gpw_product already exists' do
      provider = provider_class.new(:ensure => :present)
      expect(provider.exists?).to be_truthy
    end
    it 'should indicate when the gpw_product does not exist' do
      provider = provider_class.new(:ensure => :absent)
      expect(provider.exists?).to be_falsey
    end
    describe '#read_source' do
      it 'should return data from source file' do
        mock_source_file = '/testfile'
        resource[:source] = mock_source_file
        mock_data = 'DATA'
        FakeFS do
          File.open(mock_source_file,'w') do |f|
            f.write mock_data
          end
          expect(provider.read_source).to eq mock_data
        end
      end
    end
    describe '#project_xml' do
      it 'should return the products project xml string' do
        provider.instance_variable_set(:@property_hash,{:publisher_project_url => 'http://example.com/product.gpp'})
        stub_request(:get, "http://example.com/product.gpp")
          .with(:headers => {'Accept'=>'application/json'})
          .to_return(:status => 200, :body => '{"String" : "the xml string"}')
        expect(provider.project_xml).to eq 'the xml string'
      end
    end
    context 'is being created' do
      it 'should have a create method' do
        expect(provider).to respond_to(:create)
      end
      context 'when source is set' do
        let(:unzip_output) do
          <<-'EOS'
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<!-- Configuration of a GO Publisher Workflow product -->
<gpa:PublishProduct xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:gpa="http://www.snowflakesoftware.com/agent/go-publisher" xmlns:sfa="http://www.snowflakesoftware.com/agent" xmlns:xlink="http://www.w3.org/1999/xlink">
  <gpa:name>test</gpa:name>
</gpa:PublishProduct>
          EOS
        end
        before :each do
          resource[:source] = '/path/to/product.zip'
          provider.stubs(:read_source).returns('DATA')
          described_class.expects(:unzip).with(
            '-p', resource[:source], 'product.xml'
          ).returns unzip_output
        end
        context 'when API call is successful' do
          it 'should create gpw_product' do
            stub_request(:post, "http://localhost:7003/go-publisher-workflow-product-admin/products").
              with(:body => "DATA",
                   :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/zip'}).
              to_return(:status => 201)
            provider.create
          end
        end
        context 'when API call is unsuccessful' do
          it 'should raise error' do
            stub_request(:post, "http://localhost:7003/go-publisher-workflow-product-admin/products").
              with(:body => "DATA",
                   :headers => {'Accept'=>'application/json', 'Content-Type'=>'application/zip'}).
              to_return(:status => 500, :body => '{"ApiErrorMessage":{"cause":"Internal Server Error"}}')
            expect{provider.create}.to raise_error(Puppet::Error, /Go Publisher API returned 500 when uploading test/)
          end
        end
      end
      context 'when source not set' do
        it 'should raise exception' do
          expect { provider.create }.to raise_error(Puppet::Error, /source is required when creating new gpw_product/)
        end
      end
    end
    context 'is being destroyed' do
      before :each do
        stub_request(:delete, "http://localhost:7003/go-publisher-workflow-product-admin/products/test").
          to_return(:status => 200)
      end
      it 'should have @property_hash cleared' do
        provider.destroy
        expect(provider.instance_variable_get("@property_hash")).to be_empty
      end
    end
  end
end
