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

  shared_examples_for 'a healthy kubernetes cluster' do
    sleep 60
    it 'should get componentstatus with no unhealthy components' do
      status = on(controller,
        'kubectl get componentstatus',
        environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
      )
      expect(status.stdout).not_to match(/Unhealthy/)
    end
    it 'should get nodes with all good statuses' do
      status = on(controller,
        'kubectl get nodes',
        environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
      )
      status.stdout.split("\n")[1..-1].each do |node|
        expect(node).to match(/Ready/)
      end
    end
    it 'should get pods with all good statuses' do
      status = on(controller,
        'kubectl get pods --all-namespaces',
        environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
      )
      status.stdout.split("\n")[1..-1].each do |pod|
        expect(pod).to match(/Running/)
      end
    end
  end

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
          '22' => nil,
          '6666' => nil
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
    # @token = 'aaaaaa-aaaabbbbccccdddd'
    controller_ip = fact_on(controller, 'ipaddress_eth1')
    init_log = on(controller, "kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=#{controller_ip}")
    $join_cmd = init_log.stdout.split("\n").grep(/kubeadm join/).first

    on(controller,
      'kubectl taint nodes --all node-role.kubernetes.io/master-',
      environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
    )

    on(controller,
      'kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml',
      environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
    )
    sleep 60
  end

  workers.each do |host|
    it 'should connect to the master' do
      on(host, $join_cmd)
    end
  end

  it 'waits for bootstrap to finish' do
    masters.each do |host|
      retry_on(host,
        'env KUBECONFIG="/etc/kubernetes/admin.conf" kubectl get pods --all-namespaces | grep -v "(ContainerCreating|Pending)"',
        max_retries: 60,
        retry_interval: 10
      )
    end
  end

  context 'should be healthy' do
    it_behaves_like 'a healthy kubernetes cluster'
  end

  context 'use kubernetes' do
    it 'should deploy a nginx service' do
      on(controller,
        'kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml',
        environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
      )
    end
  end

  context 'should be healthy' do
    it_behaves_like 'a healthy kubernetes cluster'
  end
end
