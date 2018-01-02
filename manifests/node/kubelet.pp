# Populate the proxy kubernetes configuration
#
class simp_kubernetes::node::kubelet {
  assert_private()

  if $::simp_kubernetes::kubelet_protocol == 'https' {
    $pki_params = {
      'tls-cert-file'        => $::simp_kubernetes::app_pki_key,
      'tls-private-key-file' => $::simp_kubernetes::app_pki_cert,
      'client-ca-file'       => $::simp_kubernetes::app_pki_ca,
    }
  }
  else {
    $pki_params = {}
  }

  $kubelet_template = epp('simp_kubernetes/etc/kubernetes/kubelet.epp', {
      'address'           => $::simp_kubernetes::kubelet_listen_address,
      'hostname_override' => $::simp_kubernetes::kubelet_hostname,
      'kube_masters'      => $::simp_kubernetes::kube_master_urls,
      'args'              => $pki_params + $::simp_kubernetes::kubelet_args,
    }
  )
  # TODO do that kubeconfig thing

  file { '/etc/kubernetes/kubelet':
    ensure  => 'file',
    content => $kubelet_template,
  }

  service { 'kubelet':
    ensure    => running,
    enable    => true,
    subscribe => [
      File['/etc/kubernetes/kubelet'],
      File['/etc/kubernetes/config']
    ],
  }

}
