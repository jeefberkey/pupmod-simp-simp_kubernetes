require 'spec_helper_acceptance'
require 'json'

test_name 'bootstrap using kubeadm'

describe 'bootstrap using kubeadm' do

  masters    = hosts_with_role(hosts,'master')
  workers    = hosts_with_role(hosts,'worker')
  controller = masters.first

  shared_examples_for 'a healthy kubernetes cluster' do
    sleep 60
    it 'should get componentstatus with no unhealthy components' do
      status = on(controller, 'kubectl get componentstatus' )
      expect(status.stdout).not_to match(/Unhealthy/)
    end
    it 'should get nodes with all good statuses' do
      status = on(controller, 'kubectl get nodes' )
      status.stdout.split("\n")[1..-1].each do |node|
        expect(node).to match(/\sReady\s/)
      end
    end
    it 'should get pods with all good statuses' do
      status = on(controller, 'kubectl get pods --all-namespaces' )
      status.stdout.split("\n")[1..-1].each do |pod|
        expect(pod).to match(/Running/)
      end
    end
  end

  shared_examples_for 'wait for pods to finish deploying' do
    it 'should not have pods in ContainerCreating or Pending status' do
      sleep 20
      retry_on(controller,
        'kubectl get pods --all-namespaces --field-selector=status.phase!=ContainerCreating |& grep "No resources found"',
        desired_exit_codes: 1,
        retry_interval: 10,
        max_retries: 60,
      )
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

    # copy over the kubeconfig
    on(controller, 'mkdir -p /root/.kube')
    on(controller, 'cp -i /etc/kubernetes/admin.conf /root/.kube/config')

    # init
    on(controller, 'kubectl taint nodes --all node-role.kubernetes.io/master-' )

    # networking overlay (canal)
    # this yaml file had to be modified to tell flannel to run over eth1 instead of eth0
    scp_to(controller, 'spec/acceptance/suites/default/manifests/', '/root/manifests/')
    on(controller, 'kubectl apply -f /root/manifests/canal' )
    sleep 60
  end

  workers.each do |host|
    it 'should connect to the master' do
      on(host, $join_cmd)
      sleep 60
    end
  end

  context 'should be healthy' do
    it { sleep 30 }
    it_behaves_like 'wait for pods to finish deploying'
    it_behaves_like 'a healthy kubernetes cluster'
  end

  context 'use kubernetes' do
    it 'should deploy the dashboard' do
      on(controller, 'kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml' )
    end
  end

  context 'should be healthy' do
    it { sleep 30 }
    it_behaves_like 'wait for pods to finish deploying'
    it_behaves_like 'a healthy kubernetes cluster'
  end
end
