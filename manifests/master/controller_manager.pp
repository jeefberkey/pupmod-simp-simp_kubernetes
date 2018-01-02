# Populate the controller-manager kubernetes configuration
#
class simp_kubernetes::master::controller_manager {
  assert_private()


  if $::simp_kubernetes::kube_api_protocol == 'https' {
    # https://github.com/kubernetes/kubernetes/issues/27442#issuecomment-241894715
    simp_kubernetes::kubeconfig { '/etc/kubernetes/controller-manager.kubeconfig':
      current_context => 'controller-manager-ctx',
      clusters        => [
        {
          'name'    => 'kubernetes',
          'cluster' => {
            'certificate-authority' => $::simp_kubernetes::app_pki_ca,
            'server'                => $::simp_kubernetes::kube_master_urls[0]
          }
        }
      ],
      contexts        => [
        {
          'name'    => 'controller-manager-ctx',
          'context' => {
            'cluster' => 'kubernetes',
            'user'    => 'controller-manager'
          }
        }
      ],
      users           => [
        {
          'name' => 'controller-manager',
          'user' => {
            'client-certificate' => $::simp_kubernetes::app_pki_cert,
            'client-key'         => $::simp_kubernetes::app_pki_key,
          }
        }
      ],
    }
    $pki_params = { 'service-account-private-key-file' => $::simp_kubernetes::app_pki_key }
  }
  else {
    simp_kubernetes::kubeconfig { '/etc/kubernetes/controller-manager.kubeconfig':
      current_context => 'controller-manager-ctx',
      clusters        => [
        {
          'name'    => 'kubernetes',
          'cluster' => {
            'server' => $::simp_kubernetes::kube_master_urls[0]
          }
        }
      ],
      contexts        => [
        {
          'name'    => 'controller-manager-ctx',
          'context' => {
            'cluster' => 'kubernetes',
            'user'    => 'controller-manager'
          }
        }
      ],
      users           => [],
    }
    $pki_params = {}
  }

  # controller-manager uses a kubeconfig just like anything else that talks to the apiserver
  $controller_manager_template = epp('simp_kubernetes/etc/kubernetes/controller-manager.epp', {
      'args' => $pki_params + $::simp_kubernetes::controller_args,
    }
  )

  file { '/etc/kubernetes/controller-manager':
    ensure  => 'file',
    content => $controller_manager_template,
  }

  service { 'kube-controller-manager':
    ensure    => running,
    enable    => true,
    subscribe => [
      File['/etc/kubernetes/controller-manager'],
      File['/etc/kubernetes/config']
    ],
  }

}
