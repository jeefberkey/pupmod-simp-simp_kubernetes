require 'spec_helper_acceptance'
require 'json'

test_name 'kubernetes using redhat provided packages'

describe 'kubernetes using redhat provided packages' do

  masters    = hosts_with_role(hosts,'master')
  controller = masters.first
  workers    = hosts_with_role(hosts,'worker')

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
    it 'should disabe swap' do
      on(host, 'swapoff -a')
      on(host, "sed -i '/swap/d' /etc/fstab")
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
        'simp_config::trusted_nets' => [
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

  # hosts.each do |host|
  #   on(host, 'systemctl enable kubelet')
  # end

  it 'should use kubeadm to bootstrap cluster' do
    require 'pry';binding.pry
    # @token = 'aaaaaa-aaaabbbbccccdddd'
    @controller_ip = controller.ip
    # init_log = on(controller, "kubeadm init --token #{@token} --pod-network-cidr=192.168.0.0/16")
    init_log = on(controller, "kubeadm init --pod-network-cidr=192.168.55.0/24 --apiserver-advertise-address=#{@controller_ip}")
    net_log  = on(controller, 'kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml')
    @token = init_log.grep(/kubeadm join/)
    p net_log
  end

  workers.each do |host|
    it 'should connect to the master' do
      on(host, @token)
      # on(host, "kubeadm join --token #{@token}")
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
