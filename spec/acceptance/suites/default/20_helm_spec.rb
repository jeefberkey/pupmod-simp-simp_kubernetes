require 'spec_helper_acceptance'
require 'json'

test_name 'install helm'

describe 'install helm' do

  masters    = hosts_with_role(hosts,'master')
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

  context 'should be healthy' do
    it_behaves_like 'wait for pods to finish deploying'
    it_behaves_like 'a healthy kubernetes cluster'
  end

  context 'use kubernetes' do
    it 'should install helm' do
      on(controller, 'echo \'export PATH="${PATH}:/usr/local/bin"\' >> .bashrc')
      on(controller, 'curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh')
      on(controller, 'chmod 700 get_helm.sh')
      on(controller, './get_helm.sh')
      on(controller, 'helm init')
    end
  end

  context 'should be healthy' do
    it { sleep 30 }
    it_behaves_like 'wait for pods to finish deploying'
    it_behaves_like 'a healthy kubernetes cluster'
  end
end
