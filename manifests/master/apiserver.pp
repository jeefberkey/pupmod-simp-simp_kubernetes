# Populate the apiserver kubernetes configuration
#
class simp_kubernetes::master::apiserver {
  assert_private()

  $api_listen_address = $::simp_kubernetes::kube_api_listen_address
  $api_protocol       = $::simp_kubernetes::kube_api_protocol
  $api_port           = $::simp_kubernetes::kube_api_port
  $insecure_listen    = $::simp_kubernetes::insecure_on_localhost

  if $api_protocol == 'https' {
    if $insecure_listen {
      $address = "--insecure-bind-address=127.0.0.1 --bind-address=${$api_listen_address}"
      $port    = "--insecure-port=8080 --secure-port=${$api_port}"
    }
    else {
      $address = "--bind-address=${api_listen_address}"
      $port    = "--secure-port=${$api_port}"
    }
    $pki_params = { 'service-account-key-file' => $::simp_kubernetes::app_pki_key }
  }
  else {
    $address    = "--insecure-bind-address=${api_listen_address}"
    $port       = "--insecure-port=${api_port}"
    $pki_params = {}
  }

  $apiserver_template = epp('simp_kubernetes/etc/kubernetes/apiserver.epp', {
      'address'           => $address,
      'port'              => $port,
      'etcd_servers'      => $::simp_kubernetes::etcd_advertise_client_urls,
      'service_addresses' => $::simp_kubernetes::service_addresses,
      'api_args'          => $::simp_kubernetes::every_node_api_args + $pki_params + $::simp_kubernetes::master_api_args,
    }
  )

  file { '/etc/kubernetes/apiserver':
    ensure  => 'file',
    content => $apiserver_template,
  }

  service { 'kube-apiserver':
    ensure    => running,
    enable    => true,
    subscribe => [
      File['/etc/kubernetes/apiserver'],
      File['/etc/kubernetes/config']
    ],
  }

}
