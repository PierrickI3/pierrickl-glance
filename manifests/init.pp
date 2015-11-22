# == Class: glance
#
# Installs and configures ININ's Vidyo integration server
#
# Requirements:
#   CIC Server 2015R4+
#   .Net 4.5.2
#   Interaction Desktop
#   Glance account
#
# === Parameters
#
# [*ensure*]
#   Only installed is supported at this time
#
# [*clientbuttoninstall*]
#   Set to true to install the Glance client button
#
# [*usedev2000domain*]
#   Set to true if you do not own a domain that can be whitelisted by Glance. This will add an entry to the hosts file that point tim-cic4su5.dev2000.com to your machine.
#
# [*targetchatworkgroup*]
#   Specify the workgroup that will receive the chat interactions. Default value: glance
#
# [*targetcallbackworkgroup*]
#   Specify the workgroup that will receive the callback interactions. Default value: glance
#
# === Examples
#
#  class { 'glance':
#    ensure                  => installed,
#    clientbuttoninstall     => true,
#    usedev2000domain        => false,
#    targetchatworkgroup     => 'Support',
#    targetcallbackworkgroup => 'Support',
#  }
#
# === Authors
#
# Pierrick Lozach <pierrick.lozach@inin.com>
#
# === Copyright
#
# Copyright 2015 Interactive Intelligence, Inc.
#
class glance (
    $ensure = installed,
    $clientbuttoninstall = false,
    $usedev2000domain = true,
    $targetchatworkgroup = 'glance',
    $targetcallbackworkgroup = 'glance',
)
{

  $clientbuttoninstallerfinallocation = 'C:/I3/IC/Utilities/' # Where the client button msi is copied to
  $net452downloadurl                  = 'https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
  $clientbuttoninstallerdownloadurl   = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5975&authkey=!AEYOvBaxJirAmNg&ithint=file%2cmsi'
  $glancewebsitedownloadurl           = 'https://onedrive.live.com/download?resid=181212A4EB2683F0!5974&authkey=!AGsyI62g8WzK_k0&ithint=file%2czip'

  if ($::operatingsystem != 'Windows')
  {
    err('This module works on Windows only!')
    fail('Unsupported OS')
  } else {
    File { source_permissions => ignore } # Required for windows
  }

  $cache_dir = hiera('core::cache_dir', 'c:/users/vagrant/appdata/local/temp') # If I use c:/windows/temp then a circular dependency occurs when used with SQL
  if (!defined(File[$cache_dir]))
  {
    file {$cache_dir:
      ensure   => directory,
      provider => windows,
    }
  }

  # Install firefox
  package {'firefox':
    ensure   => present,
    provider => chocolatey,
  }

  # Install .Net 4.5.2 if it's not present
  exec {'Download .Net 4.5.2':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${net452downloadurl}','${cache_dir}/NDP452-KB2901907-x86-x64-AllOS-ENU.exe')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  #################
  # Client Button #
  #################

  # Download and copy client button installer
  exec {'Download Client Button installer':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${clientbuttoninstallerdownloadurl}','${cache_dir}/GlanceClientButtonInstaller.msi')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  # Copy it to make it available for all users
  file {"${clientbuttoninstallerfinallocation}/GlanceClientButtonInstaller.msi":
    ensure  => present,
    source  => "${cache_dir}/GlanceClientButtonInstaller.msi",
    require => Exec['Download Client Button installer'],
  }

  # Install client button
  if ($clientbuttoninstall) {
    package {'Install Glance Client Button':
      ensure => installed,
      source => "${clientbuttoninstallerfinallocation}/GlanceClientButtonInstaller.msi",
      install_options => [
        '/l*v',
        'C:\\windows\\logs\\GlanceClientButtonInstall.log',
        { 'INSTALLFOLDER' => 'C:\\I3\\IC\\SERVER\\Addins'},
      ],
      require => File["${clientbuttoninstallerfinallocation}/GlanceClientButtonInstaller.msi"],
    }
  }

  ###################
  # Glance Web Site #
  ###################

  # Download and copy sample web site to C:\inetpub\wwwroot\glance
  exec {'Download glance web site':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('${glancewebsitedownloadurl}','${cache_dir}/glanceweb.zip')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  unzip {"${cache_dir}/glanceweb.zip":
    destination => 'C:/inetpub/wwwroot/glance',
    creates     => 'C:/inetpub/wwwroot/glance/index.html',
    require     => Exec['Download glance web site'],
  }

  # Give Write privileges to IUSR account. Permissions are inherited downstream to subfolders.
  acl {'C:/inetpub/wwwroot':
    permissions => [
      {identity => 'IIS_IUSRS', rights => ['read']},
      {identity => 'IUSR',      rights => ['write']},
    ],
    require     => Unzip["${cache_dir}/glanceweb.zip"],
  }

  file_line {'Configure Domain':
    path     => 'C:/inetpub/wwwroot/glance/scripts/config.js',
    line     => "var glanceScreenDomain = 'http://tim-cic4su5.dev2000.com'",
    match    => '.*glanceScreenDomain.*',
    multiple => false,
    require  => Unzip["${cache_dir}/glanceweb.zip"],
  }

  file_line {'Configure Demo1 URL':
    path     => 'C:/inetpub/wwwroot/glance/scripts/config.js',
    line     => "\"url\": \"http://${hostname}/glance/demo1.html\"",
    match    => '.*demo1\.html.*',
    multiple => false,
    require  => Unzip["${cache_dir}/glanceweb.zip"],
  }

  file_line {'Configure Demo2 URL':
    path     => 'C:/inetpub/wwwroot/glance/scripts/config.js',
    line     => "\"url\": \"http://${hostname}/glance/demo2.html\"",
    match    => '.*demo2\.html.*',
    multiple => false,
    require  => Unzip["${cache_dir}/glanceweb.zip"],
  }

  file_line {'Configure index.html postMessage':
    path     => 'C:/inetpub/wwwroot/glance/index.html',
    line     => "wnd.postMessage(message, 'https://tim-cic4su5.dev2000.com');",
    match    => '.*wnd.postMessage.*',
    multiple => false,
    require  => Unzip["${cache_dir}/glanceweb.zip"],
  }

  file_line {'Configure index.html window.open':
    path     => 'C:/inetpub/wwwroot/glance/index.html',
    line     => "window.open('http://${hostname}/glance/chathost.html?chatUsername=Vincent%20Adultman', '_blank', 'location=no,menubar=0,titlebar=0,status=0,toolbar=0,height=550,width=920,top=10,left=10,scrollbars=1,resizable=1');",
    match    => '.*window\.open.*chathost.*',
    multiple => false,
    require  => Unzip["${cache_dir}/glanceweb.zip"],
  }

  file {'C:/inetpub/wwwroot/glance/chat/BypassLoginForm/js/config.js':
    ensure  => present,
    content => template('glance/chatconfig.js.erb'),
    require => Unzip["${cache_dir}/glanceweb.zip"],
  }

  ################
  # Trick Glance #
  ################

  # Glance requires us to whitelist domains we are demoing from. So, instead, we all use the same domain
  if ($usedev2000domain) {
    host {'dev2000':
      ensure => 'present',
      name   => 'tim-cic4su5.dev2000.com',
      ip     => '127.0.0.1',
    }
  }

  # Add shortcut to desktop. Should probably move this to a template.
  file {'Add Desktop Shortcut Script':
    ensure   => present,
    path     => "${cache_dir}\\createglanceshortcut.ps1",
    content  => "
      function CreateShortcut(\$AppLocation, \$description){
        \$WshShell = New-Object -ComObject WScript.Shell
        \$Shortcut = \$WshShell.CreateShortcut(\"\$env:USERPROFILE\\Desktop\\\$description.url\")
        \$Shortcut.TargetPath = \$AppLocation
        #\$Shortcut.Description = \$description
        \$Shortcut.Save()
      }
      CreateShortcut \"http://${hostname}/glance\" \"Glance\"
      ",
      require => Unzip["${cache_dir}/glanceweb.zip"],
  }

  exec {'Add Desktop Shortcut':
    command  => "${cache_dir}\\createglanceshortcut.ps1",
    path     => $::path,
    cwd      => $::system32,
    provider => powershell,
    require  => File['Add Desktop Shortcut Script'],
  }

}
