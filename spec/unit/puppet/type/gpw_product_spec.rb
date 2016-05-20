require 'spec_helper'

describe Puppet::Type.type(:gpw_product) do
  describe 'when validating attributes' do
    [:name, :provider, :source].each do |param|
      it "should have a #{param} parameter" do
        expect(described_class.attrtype(param)).to eq(:param)
      end
    end
    [:ensure].each do |prop|
      it "should have a #{prop} property" do
        expect(described_class.attrtype(prop)).to eq(:property)
      end
    end
  end

  describe 'namevar validation' do
    it 'should have :name as its namevar' do
      expect(described_class.key_attributes).to eq([:name])
    end
  end

  describe 'when validating attribute values' do
    describe 'ensure' do
      before :each do
        @provider_class = Puppet::Type.type(:gpw_product).provider(:rest_client)
        @provider = stub('provider', :class => @provider_class, :clear => nil)
        @provider_class.stubs(:new).returns(@provider)

        Puppet::Type.type(:gpw_product).stubs(:defaultprovider).returns @provider_class

        @resource = Puppet::Type.type(:gpw_product).new(:title => 'test', :ensure => :present, :source => '/path/to.zip')
        @property = @resource.property(:ensure)
      end
      [:present, :absent].each do |value|
        it "should support #{value} as a value to ensure" do
          expect { described_class.new(:name => 'product', :ensure => value) }.to_not raise_error
        end
      end
      it 'should not support other values' do
        expect { described_class.new(:name => 'product', :ensure => 'foo') }.to raise_error(Puppet::Error, /Invalid value/)
      end
      describe '#sync' do
        context 'should = :present' do
          before :each do
            @property.should = :present
          end
          describe 'when already present' do
            it 'should delete then upload product' do
              @provider.expects(:exists?).returns(true)
              @provider.expects(:destroy)
              @provider.expects(:create)
              @property.sync
            end
          end
          describe 'when currently absent' do
            it 'should upload product' do
              @provider.expects(:exists?).returns(false)
              @provider.expects(:create)
              @property.sync
            end
          end
        end
        context 'should = :absent' do
          before :each do
            @property.should = :absent
          end
          it 'should call provider.destroy' do
            @provider.expects(:destroy)
            @property.sync
          end
        end
      end
      context 'when testing whether `ensure` is in sync' do
        it 'should be insync if ensure is set to :absent and the provider says the product doesn\'t exist' do
          @property.should = :absent
          expect(@property).to be_safe_insync(:absent)
        end
        it 'should be insync if ensure is set to :present and the project file on the server matches' do
          @property.should = :present
          @property.expects(:project_files_match?).returns true
          expect(@property).to be_safe_insync(:present)
        end
        it 'should not be insync if ensure is set to :present but the project file doesn\'t match' do
          @property.should = :present
          @property.expects(:project_files_match?).returns false
          expect(@property).not_to be_safe_insync(:present)
        end
      end
      describe '.project_files_match?' do
        it 'returns true when the project_xml is the same as the provider reports' do
          @provider.expects(:project_xml).returns('<?xml version="1.0" encoding="UTF-8"?>')
          @property.expects(:project_xml).returns('<?xml version="1.0" encoding="UTF-8"?>')
          expect(@property.project_files_match?).to eq true
        end
      end
      describe '.updated?' do
        it 'returns true when both arguments are :present' do
          expect(@property.updated?(:present, :present)).to eq true
        end
      end
      describe '.project_xml' do
        it 'returns the output from the `unzip` command' do
          Puppet::Type::Gpw_product::Ensure
            .any_instance.expects(:`)
            .with('unzip -p /path/to.zip projects/test.gpp')
            .returns('some output')
          expect(@property.project_xml).to eq 'some output'
        end
      end
      describe '.change_to_s' do
        it 'returns `updated` when resource is being updated' do
          expect(@property.change_to_s(:present, :present)).to eq 'updated'
        end
        it 'otherwise, it calls `super`' do
          expect(@property.change_to_s(:absent, :present)).to eq 'created'
        end
      end
    end
    describe 'source' do
      it 'should support an absolute path as a value to source' do
        expect { described_class.new(:name => 'product', :source => '/an/absolute/path') }.to_not raise_error
      end
      it 'should raise an error when a relative path is given as a value to source' do
        expect { described_class.new(:name => 'product', :source => './file') }.to raise_error(Puppet::Error, /'source' file path must be absolute/)
      end
    end
  end
end
