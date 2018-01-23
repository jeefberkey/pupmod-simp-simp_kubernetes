require 'spec_helper_acceptance'
require 'json'

test_name 'kubernetes using redhat provided packages'

describe 'kubernetes using redhat provided packages' do

  masters    = hosts_with_role(hosts,'master')
  workers    = hosts_with_role(hosts,'worker')
  controller = masters.first

  worker_manifest = <<-EOF
    include 'iptables'
    class { 'simp_kubernetes':
      manage_service => false,
    }
  EOF
  master_manifest = <<-EOF
    include 'iptables'
    class { 'simp_kubernetes':
      manage_service => false,
      is_master      => true,
    }
  EOF

  hosts.each do |host|
    it 'should set a root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo "root:password" | chpasswd --crypt-method SHA256')
    end
    it 'should disable swap' do
      on(host, 'swapoff -a')
      on(host, "sed -i '/swap/d' /etc/fstab")
    end
    it 'should disable selinux :(' do
      on(host, 'setenforce 0')
      on(host, "sed -i 's/enforcing/disabled/g' /etc/selinux/config /etc/selinux/config")
    end
    it 'should set up haveged' do
      host.install_package('epel-release')
      host.install_package('haveged')
      on(host, 'systemctl enable haveged --now')
    end
    it 'should set hieradata' do
      hiera = {
        'iptables::ignore' => [
          'DOCKER',
          'docker',
          'KUBE-'
        ],
        'iptables::ports' => {
          '22' => nil
        },
        'simp_options::trusted_nets' => [
          '192.168.0.0/16',
          '10.0.0.0/8'
        ]
      }
      set_hieradata_on(host, hiera)
    end
  end

  masters.each do |host|
    it "should do master stuff on #{host}" do
      apply_manifest_on(host, master_manifest, catch_failures: true)
      apply_manifest_on(host, master_manifest, catch_failures: true)
      apply_manifest_on(host, master_manifest, catch_changes: true)
    end
  end

  workers.each do |host|
    it "should do node stuff on #{host}" do
      apply_manifest_on(host, worker_manifest, catch_failures: true)
      apply_manifest_on(host, worker_manifest, catch_failures: true)
      apply_manifest_on(host, worker_manifest, catch_changes: true)
    end
  end

  hosts.each do |host|
    # on(host, 'systemctl enable kubelet')
    it 'should not use cri networking' do
      on(host, "sed -i '/network-plugin=cni/d' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf")
      on(host, 'systemctl daemon-reload')
      on(host, 'systemctl restart kubelet.service')
    end
  end

  it 'should use kubeadm to bootstrap cluster' do
    # export KUBECONFIG=/etc/kubernetes/admin.conf
    # @token = 'aaaaaa-aaaabbbbccccdddd'
    # init_log = on(controller, "kubeadm init --token #{@token} --pod-network-cidr=192.168.0.0/16")
    controller_ip = fact_on(controller, 'ipaddress_eth1')
    require 'pry';binding.pry
    init_log = on(controller, "kubeadm init --pod-network-cidr=192.168.55.0/24 --apiserver-advertise-address=#{controller_ip}")
    @join_cmd = init_log.grep(/kubeadm join/)

    on(controller, 'kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml')
  end

  workers.each do |host|
    it 'should connect to the master' do
      # on(host, "kubeadm join --token #{@join_cmd}")
      on(host, @join_cmd)
    end
  end

  # context 'check kubernetes health' do
  #   it 'should get componentstatus with no unhealthy components' do
  #     status = on(controller, 'kubectl get componentstatus')
  #     expect(status.stdout).not_to match(/Unhealthy/)
  #   end
  # end

  # context 'use kubernetes' do
  #   it 'should deploy a nginx service' do
  #     scp_to(controller, 'spec/acceptance/suites/one-master/test-nginx_deployment.yaml','/root/test-nginx_deployment.yaml')
  #     on(controller, 'kubectl create -f /root/test-nginx_deployment.yaml')
  #   end
  #   it 'should delete it' do
  #     sleep 30
  #     on(controller, 'kubectl delete service nginx-service')
  #     on(controller, 'kubectl delete deployment nginx-deployment')
  #   end
  # end
end
