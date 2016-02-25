Puppet::Type.newtype(:gpw_product) do
  desc "Puppet type that manages Go Publisher Workflow products"

  ensurable

  newparam(:name, :namevar => true) do
    desc "Name of the product"
  end

  newparam(:source) do
    desc "The file to upload.  Must be the absolute path to a file."
    validate do |value|
      fail "'source' file path must be absolute, not '#{value}'" unless Puppet::Util.absolute_path?(value)
    end
  end
end
