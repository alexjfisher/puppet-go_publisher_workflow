require 'spec_helper'

describe 'go_publisher_workflow' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      context "on #{os}" do
        let(:facts) do
          facts
        end
        it { is_expected.to compile }
        it { is_expected.to create_class('go_publisher_workflow') }
      end
    end
  end
end
