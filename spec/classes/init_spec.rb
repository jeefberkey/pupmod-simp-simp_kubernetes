require 'spec_helper'
require 'json'

describe 'simp_kubernetes' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          facts = os_facts
          facts['fqdn'] = 'etcd01.test'
          facts
        end

        context 'without any parameters' do

        end

        context 'on a node' do

        end

        context 'on a master' do

        end
      end
    end
  end
end
