Puppet::Type.newtype(:gpw_product) do
  desc "Puppet type that manages Go Publisher Workflow products"

  ensurable do
    defaultvalues  
    newvalue(:present) do
      provider.destroy if provider.exists?
      provider.create
    end

    def insync?(is)
      return false if is == :present and !project_files_match?
      super
    end

    def change_to_s(currentvalue, newvalue)
      return "updated" if updated?(currentvalue, newvalue)
      super
    end

    def updated?(currentvalue, newvalue)
      currentvalue == :present and newvalue == :present
    end

    def project_files_match?
      project_xml == provider.project_xml
    end

    def project_xml
      unzip_command = "unzip -p #{resource[:source]} projects/#{resource[:name]}.gpp"
      Puppet.debug("project_xml: running #{unzip_command}")
      `#{unzip_command}`
    end
  end

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
