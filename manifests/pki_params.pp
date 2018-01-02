#
# == Class: simp_kubernetes::pki
#
class simp_kubernetes::pki_params {
  assert_private()

  $use_simp_certs       = $::simp_kubernetes::use_simp_certs
  $kubelet_protocol     = $::simp_kubernetes::kubelet_protocol
  $kube_api_protocol    = $::simp_kubernetes::kube_api_protocol
  $etcd_client_protocol = $::simp_kubernetes::etcd_client_protocol
  $etcd_peer_protocol   = $::simp_kubernetes::etcd_peer_protocol

  if $etcd_client_protocol == 'https' and $use_simp_certs {
    $etcd_pki_params = {
      'etcd-certfile' => $::simp_kubernetes::app_pki_key,
      'etcd-keyfile'  => $::simp_kubernetes::app_pki_cert,
      'etcd-cafile'   => $::simp_kubernetes::app_pki_ca,
    }
  }
  else {
    $etcd_pki_params = {}
  }

  if $kube_api_protocol == 'https' and $use_simp_certs {
    $kube_pki_params = {
      'tls-cert-file'            => $::simp_kubernetes::app_pki_key,
      'tls-private-key-file'     => $::simp_kubernetes::app_pki_cert,
      'tls-ca-file'              => $::simp_kubernetes::app_pki_ca,
    }
  }
  else {
    $kube_pki_params = {}
  }

  if $kubelet_protocol == 'https' and $use_simp_certs {
    $kubelet_pki_params = {
      'kubelet-https'                 => true,
      'kubelet-client-certificate'    => $::simp_kubernetes::app_pki_key,
      'kubelet-client-key'            => $::simp_kubernetes::app_pki_cert,
      'kubelet-certificate-authority' => $::simp_kubernetes::app_pki_ca,
    }
  }
  else {
    $kubelet_pki_params = {}
  }

  $common_pki_params = $etcd_pki_params + $kube_pki_params + $kubelet_pki_params


  if $use_simp_certs {
    if $kubelet_protocol == 'https' or $kube_api_protocol == 'https' or $etcd_peer_protocol == 'https' or $etcd_client_protocol == 'https' {
      if $::simp_kubernetes::is_master {
        $etcd_pki_group = 'etcd'
      }
      else {
        $etcd_pki_group = 'kube'
      }
      pki::copy { 'simp_kubernetes':
        source => $::simp_kubernetes::app_pki_external_source,
        pki    => $use_simp_certs,
        group  => 'kube'
      }
      pki::copy { 'simp_kubernetes-etcd':
        source => $::simp_kubernetes::app_pki_external_source,
        pki    => $::simp_kubernetes::use_simp_certs,
        group  => $etcd_pki_group
      }
    }
  }


}
