require 'spec_helper_acceptance'
require 'json'

test_name 'kubernetes using kubeadm'

describe 'kubernetes using kubeadm' do

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
        expect(node).to match(/\sReady\s/)
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

  shared_examples_for 'wait for pods to finish deploying' do
    it 'should not have pods in ContainerCreating or Pending status' do
      sleep 20
      retry_on(controller,
        'env KUBECONFIG="/etc/kubernetes/admin.conf" kubectl get pods --all-namespaces --field-selector=status.phase!=ContainerCreating |& grep "No resources found"',
        desired_exit_codes: 1,
        retry_interval: 10,
        max_retries: 60,
      )
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
      host.install_package('jq')
      on(host, 'systemctl enable haveged --now')
    end
    it 'should set up dnsmasq' do
      host.install_package('dnsmasq')
      on(host, 'systemctl enable dnsmasq --now')
    end
    # it 'should set sysctl' do
    #   on(host, 'sysctl net.bridge.bridge-nf-call-iptables=1')
    # end
    it 'should set hieradata' do
      hiera = {
        'iptables::ignore' => [
          'DOCKER',
          'docker',
          'KUBE-'
        ],
        'iptables::ports' => {
          '22'   => nil,
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
    it 'should not have any other cri network plugins installed' do
      on(host, '[ ! -d /etc/cri ]')
    end
  end

  it 'should use kubeadm to bootstrap cluster' do
    controller_ip = fact_on(controller, 'ipaddress_eth1')
    init_cmd = [
      'kubeadm init',
      '--pod-network-cidr=192.168.0.0/16',
      '--service-cidr=10.96.0.0/12',
      "--apiserver-advertise-address=#{controller_ip}"
    ].join(' ')
    init_log = on(controller, init_cmd)
    $join_cmd = init_log.stdout.split("\n").grep(/kubeadm join/).first

    # init
    on(controller,
      'kubectl taint nodes --all node-role.kubernetes.io/master-',
      environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
    )

    # networking overlay (flannel)
    on(controller,
      'kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml',
      environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
    )
    sleep 60
  end

  workers.each do |host|
    it 'should connect to the master' do
      on(host, $join_cmd)
      sleep 60
    end
  end

  context 'should be healthy' do
    it_behaves_like 'wait for pods to finish deploying'
    it_behaves_like 'a healthy kubernetes cluster'
  end

  context 'use kubernetes' do
    it 'should deploy the dashboard' do
      on(controller,
        'kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml',
        environment: { 'KUBECONFIG' => '/etc/kubernetes/admin.conf' }
      )
    end
  end

  context 'should be healthy' do
    it_behaves_like 'wait for pods to finish deploying'
    it_behaves_like 'a healthy kubernetes cluster'
  end
end
