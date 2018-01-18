require 'spec_helper_acceptance'
require 'json'

test_name 'kubernetes using redhat provided packages'

describe 'kubernetes using redhat provided packages' do

  masters = hosts_with_role(hosts,'master')
  workers = hosts_with_role(hosts,'worker')

  manifest = "include 'simp_kubernetes'"

  hosts.each do |host|
    it 'should set a root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo "root:password" | chpasswd --crypt-method SHA256')
    end
  end

  masters.each do |host|
    it "should do master stuff on #{host}" do
      apply_manifest_on(host, manifest, catch_failures: true)
      apply_manifest_on(host, manifest, catch_changes: true)
    end
  end

  context 'check kubernetes health' do
    it 'should get componentstatus with no unhealthy components' do
      status = on(controller, 'kubectl get componentstatus')
      expect(status.stdout).not_to match(/Unhealthy/)
    end
  end

  workers.each do |host|
    it "should do node stuff on #{host}" do
      apply_manifest_on(host, manifest, catch_failures: true)
      apply_manifest_on(host, manifest, catch_changes: true)
    end
  end

  context 'use kubernetes' do
    it 'should deploy a nginx service' do
      scp_to(controller, 'spec/acceptance/suites/one-master/test-nginx_deployment.yaml','/root/test-nginx_deployment.yaml')
      on(controller, 'kubectl create -f /root/test-nginx_deployment.yaml')
    end
    it 'should delete it' do
      sleep 30
      on(controller, 'kubectl delete service nginx-service')
      on(controller, 'kubectl delete deployment nginx-deployment')
    end
  end
end
