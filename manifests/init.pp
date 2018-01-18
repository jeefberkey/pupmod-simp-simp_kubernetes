# Full description of SIMP module 'simp_kubernetes' here.
#
# https://gist.github.com/jgsqware/6595126e17afc6f187666b0296ea0723
#
# @author https://github.com/simp/pupmod-simp-simp_kubernetes/graphs/contributors
#
class simp_kubernetes (
  Boolean $is_master,
  Hash $master_ports,
  Hash $worker_ports,
  Boolean $use_simp_docker,
  Boolean $manage_repo,
  Boolean $repo_enabled,
  Array[String] $packages,
  Boolean $manage_packages,
  String $package_ensure,
  Boolean $manage_service,
  Boolean $service_ensure,
) {
  if $use_simp_docker { include 'simp_docker' }

  if $is_master {
    simp_kubernetes::iptables($master_ports)
  }
  else {
    simp_kubernetes::iptables($worker_ports)
  }

  if $manage_repo and $manage_packages {
    $_enabled = $repo_enabled ? { true => 1, false => 0 }
    yumrepo { 'kubernetes':
      baseurl       => 'https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64',
      descr         => 'The kubernetes repository - from Google',
      enabled       => $_enabled,
      gpgcheck      => '1',
      repo_gpgcheck => '1',
      gpgkey        => 'https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg',
    }
  }

  if $manage_packages {
    $_require = $manage_repo ? { True => Yumrepo['kubernetes'], default => undef }
    package { $packages:
      ensure  => $package_ensure,
      require => $_require,
    }
  }

  if $manage_service {
    service { 'kubelet':
      ensure => $service_ensure,
      enable => true,
    }
  }

}
