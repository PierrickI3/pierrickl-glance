# glance

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with glance](#setup)
    * [What glance affects](#what-glance-affects)
    * [Setup requirements](#setup-requirements)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Limitations - OS compatibility, etc.](#limitations)

## Overview

Installs and configures the integration between CIC and Glance

## Module Description

Tested with CIC 2015R4
IIS and CIC must be installed before deployment

## Setup

### What glance affects

* Copies files under C:/inetpub/wwwroot/glance
* Installs Firefox
* Installs the client add-in required to manage Glance sessions
* Optionally adds a new entry in the hosts file to cope with Glance whitelisting requirements

### Setup Requirements

* CIC 2015R4+
* IIS

## Usage

```puppet
class { 'glance':
  ensure              => installed, # only option supported for now
  clientbuttoninstall => true,      # if true, installs the client button on the local machine
  usedev2000domain    => false,     # if true, changes the hosts file to be able to use Glance without requiring your domain to be whitelisted
  targetchatworkgroup => 'Support', # Workgroup used to queue chat interactions
}
```

## Limitations

Tested with CIC 2015R4 on Windows 2012R2
