require 'spec_helper'

describe 'simp_kubernetes' do
  context 'supported operating systems' do
    on_supported_os.each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts
        end

        context 'default settings' do
          shared_examples_for 'all nodes' do
            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_class('simp_docker') }
            it { is_expected.to contain_yumrepo('google-kubernetes').with(
              baseurl: 'https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64',
              enabled: '1',
              gpgkey:  'https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg',
              gpgcheck: '1',
              repo_gpgcheck: '1'
            ) }
            it { is_expected.to contain_package('kubelet').with_ensure('installed') }
            it { is_expected.to contain_package('kubeadm').with_ensure('installed') }
            it { is_expected.to contain_package('kubectl').with_ensure('installed') }
            it { is_expected.to contain_service('kubelet').with_ensure('running') }
          end

          context 'on a worker' do
            it_behaves_like 'all nodes'
            it { is_expected.to contain_iptables__ports('kubernetes worker') }
          end

          context 'on a master' do
            let(:params) {{ is_master: true }}

            it_behaves_like 'all nodes'
            it { is_expected.to contain_iptables__ports('kubernetes master') }
          end
        end

        context 'without managing the repo' do
          let(:params) {{ manage_repo: false }}

          shared_examples_for 'all nodes' do
            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_class('simp_docker') }
            it { is_expected.not_to contain_yumrepo('google-kubernetes') }
            it { is_expected.to contain_package('kubelet').with_ensure('installed') }
            it { is_expected.to contain_package('kubeadm').with_ensure('installed') }
            it { is_expected.to contain_package('kubectl').with_ensure('installed') }
            it { is_expected.to contain_service('kubelet').with_ensure('running') }
          end

          context 'on a worker' do
            it_behaves_like 'all nodes'
            it { is_expected.to contain_iptables__ports('kubernetes worker') }
          end

          context 'on a master' do
            let(:params) {{
              manage_repo: false,
              is_master: true
            }}

            it_behaves_like 'all nodes'
            it { is_expected.to contain_iptables__ports('kubernetes master') }
          end
        end

        context 'without managing the packages or the repo' do
          let(:params) {{
            manage_packages: false,
            manage_repo: false,
          }}

          shared_examples_for 'all nodes' do
            it { is_expected.to compile.with_all_deps }
            it { is_expected.to contain_class('simp_docker') }
            it { is_expected.not_to contain_yumrepo('google-kubernetes') }
            it { is_expected.not_to contain_package('kubelet') }
            it { is_expected.not_to contain_package('kubeadm') }
            it { is_expected.not_to contain_package('kubectl') }
            it { is_expected.to contain_service('kubelet').with_ensure('running') }
          end

          context 'on a worker' do
            it_behaves_like 'all nodes'
            it { is_expected.to contain_iptables__ports('kubernetes worker') }
          end

          context 'on a master' do
            let(:params) {{
              manage_packages: false,
              manage_repo: false,
              is_master: true
            }}

            it_behaves_like 'all nodes'
            it { is_expected.to contain_iptables__ports('kubernetes master') }
          end
        end

      end
    end
  end
end
