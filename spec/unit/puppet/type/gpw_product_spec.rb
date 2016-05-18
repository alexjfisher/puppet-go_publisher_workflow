require 'spec_helper'

describe Puppet::Type.type(:gpw_product) do
  describe 'when validating attributes' do
    [ :name, :provider, :source ].each do |param|
      it "should have a #{param} parameter" do
        expect(described_class.attrtype(param)).to eq(:param)
      end
    end
    [ :ensure ].each do |prop|
      it "should have a #{prop} property" do
        expect(described_class.attrtype(prop)).to eq(:property)
      end
    end
  end

  describe 'namevar validation' do
    it "should have :name as its namevar" do
      expect(described_class.key_attributes).to eq([:name])
    end
  end

  describe 'when validating attribute values' do
    describe 'ensure' do
      [ :present, :absent ].each do |value|
        it "should support #{value} as a value to ensure" do
          expect { described_class.new( {:name => 'product', :ensure => value})}.to_not raise_error
        end
      end
      it 'should not support other values' do
        expect { described_class.new( {:name => 'product', :ensure => 'foo'})}.to raise_error(Puppet::Error, /Invalid value/)
      end
    end
    describe 'source' do
      it "should support an absolute path as a value to source" do
        expect { described_class.new( {:name => 'product', :source => "/an/absolute/path"})}.to_not raise_error
      end
      it "should raise an error when a relative path is given as a value to source" do
        expect { described_class.new( {:name => 'product', :source => './file'})}.to raise_error(Puppet::Error, /'source' file path must be absolute/)
      end
    end
  end
end
