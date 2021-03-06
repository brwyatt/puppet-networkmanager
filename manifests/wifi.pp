# See README.md for details.
define networkmanager::wifi (
  $ssid,
  $user = undef,
  $wpa_psk = undef,
  $eap = undef,
  $phase2_auth = undef,
  $password_raw_flags = undef,
  $uuid                   = regsubst(
    md5($name), '^(.{8})(.{4})(.{4})(.{4})(.{12})$', '\1-\2-\3-\4-\5'),
  $ensure                 = present,
  $mode                   = 'infrastructure',
  $mac_address            = undef,
  $autoconnect            = true,
  $hidden                 = undef,
  $ipv4_method            = 'auto',
  $ipv6_method            = 'auto',
  $ipv6_addr_gen_mode     = 'stable-privacy',
  $security               = 'none',
  $nma_ca_cert_ignore     = false,
  $key_mgmt               = 'wpa-eap',
  $auth_alg               = 'open',
  $directory              = '/usr/share/glib-2.0/schemas',
  $ignore_ca_cert         = false,
  $ignore_phase2_ca_cert  = false,
) {

  Class['networkmanager::install'] -> Networkmanager::Wifi[$title]

  file { "/etc/NetworkManager/system-connections/${name}":
    ensure => $ensure,
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
  }

  if ($eap and $key_mgmt != 'wpa-eap') {
    fail('NON-EAP Key management selected with EAP')
  }

  if ($wpa_psk and $key_mgmt != 'wpa-psk') {
    fail('WPA-PSK Key provided without WPA-PSK Key Management')
  }

  if $ensure == 'present' {
    Ini_setting {
      ensure  => present,
      path    => "/etc/NetworkManager/system-connections/${name}",
      notify  => Exec['reload nm configuration'],
    }

    # section: connection
    ini_setting { "${name}/connection/id":
      section => 'connection',
      setting => 'id',
      value   => $name,
    }

    ini_setting { "${name}/connection/uuid":
      section => 'connection',
      setting => 'uuid',
      value   => $uuid,
    }

    ini_setting { "${name}/connection/type":
      section => 'connection',
      setting => 'type',
      value   => '802-11-wireless',
    }

    if ($user) {
      ini_setting { "${name}/connection/permissions":
        section => 'connection',
        setting => 'permissions',
        value   => "user:${user}:;",
      }
    }

    # section: 802-11-wireless
    ini_setting { "${name}/802-11-wireless/ssid":
      section => '802-11-wireless',
      setting => 'ssid',
      value   => $ssid,
    }

    if $hidden {
      ini_setting { "${name}/802-11-wireless/hidden":
        section => '802-11-wireless',
        setting => 'hidden',
        value   => $hidden,
      }
    }

    ini_setting { "${name}/802-11-wireless/mode":
      section => '802-11-wireless',
      setting => 'mode',
      value   => $mode,
    }

    ini_setting { "${name}/802-11-wireless/security":
      section => '802-11-wireless',
      setting => 'security',
      value   => $security,
    }

    # section: 802-11-wireless-security
    ini_setting { "${name}/802-11-wireless-security/key-mgmt":
      section => '802-11-wireless-security',
      setting => 'key-mgmt',
      value   => $key_mgmt,
    }

    if ($wpa_psk) {
      ini_setting { "${name}/802-11-wireless-security/psk":
        section => '802-11-wireless-security',
        setting => 'psk',
        value   => $wpa_psk,
      }
    }

    ini_setting { "${name}/802-11-wireless-security/auth-alg":
      section => '802-11-wireless-security',
      setting => 'auth-alg',
      value   => $auth_alg,
    }

    # section: ipv4
    ini_setting { "${name}/ipv4/method":
      section => 'ipv4',
      setting => 'method',
      value   => $ipv4_method,
    }

    # section: ipv6
    ini_setting { "${name}/ipv6/method":
      section => 'ipv6',
      setting => 'method',
      value   => $ipv6_method,
    }

    ini_setting { "${name}/ipv6/addr-gen-mode":
      section => 'ipv6',
      setting => 'addr-gen-mode',
      value   => $ipv6_addr_gen_mode,
    }

    # section: 802-1x
    if ($eap) {
      ini_setting { "${name}/802-1x/eap":
        section => '802-1x',
        setting => 'eap',
        value   => "${eap};",
      }

      ini_setting { "${name}/802-1x/identity":
        section => '802-1x',
        setting => 'identity',
        value   => $user,
      }

      ini_setting { "${name}/802-1x/phase2-auth":
        section => '802-1x',
        setting => 'phase2-auth',
        value   => $phase2_auth,
      }

      ini_setting { "${name}/802-1x/password-raw-flags":
        section => '802-1x',
        setting => 'password-raw-flags',
        value   => $password_raw_flags,
      }

      ini_setting { "${name}/802-1x/nma-ca-cert-ignore":
        section => '802-1x',
        setting => 'nma-ca-cert-ignore',
        value   => $nma_ca_cert_ignore,
      }
    }

  }

  if ( $eap and $eap =~ /^tls|^ttls|^peap/ ) {
    file { "${directory}/org.gnome.nm-applet.eap.${uuid}.gschema.xml":
      ensure  => file,
      content => template('networkmanager/org.gnome.nm-applet.eap.gschema.xml.erb'),
    }
    ~> exec { "Compile modifications for ${uuid}":
      command     => "/usr/bin/glib-compile-schemas ${directory}",
      refreshonly => true,
    }

    exec {"sudo -u ${user} DISPLAY=:0 gsettings set org.gnome.nm-applet.eap.${uuid} ignore-ca-cert ${ignore_ca_cert}":
      unless  => "[ $(sudo -u ${user} DISPLAY=:0 gsettings get org.gnome.nm-applet.eap.${uuid} ignore-ca-cert) = ${ignore_ca_cert} ]",
      path    => '/usr/bin/',
      require => File["${directory}/org.gnome.nm-applet.eap.${uuid}.gschema.xml"],
    }

    exec {"sudo -u ${user} DISPLAY=:0 gsettings set org.gnome.nm-applet.eap.${uuid} ignore-phase2-ca-cert ${ignore_phase2_ca_cert}":
      unless  => "[ $(sudo -u ${user} DISPLAY=:0 gsettings get org.gnome.nm-applet.eap.${uuid} ignore-phase2-ca-cert) = ${ignore_phase2_ca_cert} ]",
      path    => '/usr/bin/',
      require => File["${directory}/org.gnome.nm-applet.eap.${uuid}.gschema.xml"],
    }
  }
}
