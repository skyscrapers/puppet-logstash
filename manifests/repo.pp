# This class manages package repositories for Logstash.
#
# It is usually used only by the top-level `logstash` class. It's unlikely
# that you will need to declare this class yourself.
#
# @example Include this class to ensure its resources are available.
#   include logstash::repo
#
# @author https://github.com/elastic/puppet-logstash/graphs/contributors
#
class logstash::repo {
  $version = $logstash::repo_version
  $repo_name = "elastic-${version}"
  $url_root = "https://packages.elastic.co/logstash/${version}"
  $gpg_key_url = 'https://packages.elastic.co/GPG-KEY-elasticsearch'
  $gpg_key_id = '46095ACC8548582C1A2699A9D27D666CD88E42B4'

  Exec {
    path      => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd       => '/',
  }
  if versioncmp('5.0', "${version}") >= 0 {
    $url_root = "https://artifacts.elastic.co/packages/${version}"
  }
  else{
    $url_root = "https://packages.elastic.co/logstash/${version}"
  }
  case $::osfamily {
    'Debian': {
      include apt
      if versioncmp('5.0', "${version}") >= 0 {
        $url_root_tot = "$url_root/apt"
      }
      else{
        $url_root_tot = "$url_root/debian"
      }
      apt::source { $repo_name:
        location => "${url_root_tot}",
        release  => 'stable',
        repos    => 'main',
        key      => {
          'id'     => $gpg_key_id,
          'source' => $gpg_key_url,
        },
        include  => {
          'src' => false,
        },
        notify   => [
          Class['apt::update'],
          Exec['apt_update'],
        ],
      }
    }
    'RedHat': {
      if versioncmp('5.0', "${version}") >= 0 {
        $url_root_tot = "$url_root/yum"
      }
      else{
        $url_root_tot = "$url_root/centos"
      }
      yumrepo { $repo_name:
        descr    => 'Logstash Centos Repo',
        baseurl  => "${url_root_tot}",
        gpgcheck => 1,
        gpgkey   => $gpg_key_url,
        enabled  => 1,
      }

      Yumrepo[$repo_name] -> Package<|tag == 'logstash'|>
    }
    'Suse' : {
      if versioncmp('5.0', "${version}") >= 0 {
        $url_root_tot = "$url_root/yum"
      }
      else{
        $url_root_tot = "$url_root/centos"
      }
      zypprepo { $repo_name:
        baseurl     => "${url_root_tot}",
        enabled     => 1,
        autorefresh => 1,
        name        => 'logstash',
        gpgcheck    => 1,
        gpgkey      => $gpg_key_url,
        type        => 'yum',
      }

      # Workaround until zypprepo allows the adding of the keys
      # https://github.com/deadpoint/puppet-zypprepo/issues/4
      exec { 'logstash_suse_import_gpg':
        command => "wget -q -O /tmp/RPM-GPG-KEY-elasticsearch ${gpg_key_url}; \
                    rpm --import /tmp/RPM-GPG-KEY-elasticsearch; \
                    rm /tmp/RPM-GPG-KEY-elasticsearch",
        unless  => "test $(rpm -qa gpg-pubkey | grep -i \"${gpg_key_id}\" | wc -l) -eq 1 ",
      }

      Exec['logstash_suse_import_gpg'] ~> Zypprepo['logstash'] -> Package<|tag == 'logstash'|>
    }
    default: {
      fail("\"${module_name}\" provides no repository information for OSfamily \"${::osfamily}\"")
    }
  }
}
