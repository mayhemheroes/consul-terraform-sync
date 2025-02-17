log_level = "ERR"
port = 8502
working_dir = "working"
id = "cts-123"

syslog {
  enabled = true
  name = "syslog"
}

buffer_period {
  min = "20s"
  max = "60s"
}

tls {
  enabled = true
  cert = "../testutils/certs/consul_cert.pem"
  key = "../testutils/certs/consul_key.pem"
  verify_incoming = true
  ca_cert = "../testutils/certs/consul_cert.pem"
}

consul {
  address = "consul-example.com"
  auth {
    enabled = true
    username = "username"
    password = "password"
  }
  kv_path = "kv_path"
  tls {
    ca_cert = "ca_cert"
    ca_path = "ca_path"
    enabled = true
    key = "key"
    server_name = "server_name"
    verify = false
  }
  token = "token"
  transport {
    dial_keep_alive = "5s"
    dial_timeout = "10s"
    disable_keep_alives = false
    idle_conn_timeout = "1m"
    max_idle_conns_per_host = 100
    tls_handshake_timeout = "10s"
  }
  service_registration {
    enabled = true
    service_name = "test-service"
    address = "10.2.3.4"
    namespace = "test-ns"
    default_check {
      enabled = true
      address = "http://cts"
    }
  }
}

driver "terraform" {
  log = true
  path = "path"
  backend "consul" {
    address = "consul-example.com"
    path = "kv-path/terraform"
    gzip = true
  }
  required_providers {
    pName1 = "v0.0.0"
    pName2 = {
      version = "v0.0.1",
      source = "namespace/pName2"
    }
  }
}

service {
  name = "serviceA"
  description = "descriptionA"
}

service {
  name = "serviceB"
  namespace = "teamB"
  description = "descriptionB"
}

terraform_provider "X" {}

task {
  name = "task"
  description = "automate services for X to do Y"
  services = ["serviceA", "serviceB", "serviceC"]
  providers = ["X"]
  module = "Y"
  condition "catalog-services" {
    regexp = ".*"
    use_as_module_input = true
    namespace = "ns2"
    datacenter = "dc2"
    node_meta {
      "key1" = "value1"
      "key2" = "value2"
    }
  }
  module_input "consul-kv" {
    path = "key-path"
    recurse = true
    datacenter = "dc2"
    namespace = "ns2"
  }
}
