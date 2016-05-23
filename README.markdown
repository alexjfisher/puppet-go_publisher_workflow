[![Build Status](https://img.shields.io/travis/OrdnanceSurvey/puppet-go_publisher_workflow.svg)](https://travis-ci.org/OrdnanceSurvey/puppet-go_publisher_workflow)
[![Coverage Status](https://img.shields.io/coveralls/OrdnanceSurvey/puppet-go_publisher_workflow.svg)](https://coveralls.io/github/OrdnanceSurvey/puppet-go_publisher_workflow)

#### Table of Contents

1. [Overview](#overview)
2. [Usage - Configuration options and additional functionality](#usage)
3. [Limitations](#limitations)

## Overview

A very simple module that so far doesn't do anything other than provider a type/provider for uploading Go Publisher Workflow products via the REST API.

## Usage

To upload a product zip...
```
gpw_product {'MyProduct':
  ensure => present,
  source => '/path/to/MyProduct.zip',
}
```

To delete a product zip...
```
gpw_product {'MyProduct':
  ensure => absent,
}
```

## Limitations

* `unzip` must be installed.
* `rest-client` gem must be available to your puppet agent.
* The type only connects to localhost port 7003 and this isn't currently configurable.
* It doesn't install Go Publisher Workflow!
* Only tested on OEL 6.
