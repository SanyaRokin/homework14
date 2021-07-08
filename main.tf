terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.60.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = "b1ge18qajhn4v1vpuu6r"
  folder_id                = "b1gjntugsva73tig95mk"
  zone                     = "ru-central1-a"
}

resource "yandex_compute_instance" "build" {
  name        = "build"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd86qp46m631lci0347o"
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("/home/terraform/variables.txt")}"
  }
   provisioner "remote-exec" {
    connection {
      type = "ssh"
      user = "home"
      agent = false
      host = yandex_compute_instance.build.network_interface.0.nat_ip_address
      private_key = "${file("/home/home/.ssh/id_rsa")}"
    }

    inline = [
      "sudo apt update && sudo apt install git -y && sudo apt install maven -y",
      "sudo git clone https://github.com/boxfuse/boxfuse-sample-java-war-hello.git /tmp/boxfuse-sample-java-war-hello", 
      "cd /tmp/boxfuse-sample-java-war-hello && sudo mvn package",
      "scp /tmp/boxfuse-sample-java-war-hello/target/hello-1.0.war home@178.154.207.146:/tmp -yes"
    ]
  }
}

resource "yandex_compute_instance" "prod" {
  name = "prod"

  resources {
    cores  = 4
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd86qp46m631lci0347o"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("/home/terraform/variables.txt")}"
  }

  provisioner "remote-exec" {
   connection {
     type = "ssh"
     user = "home"
     agent = false
     host = yandex_compute_instance.prod.network_interface.0.nat_ip_address
     private_key = "${file("/home/home/.ssh/id_rsa")}"
   }
   inline = [
     "sudo apt update && sudo apt install default-jdk -y && sudo apt install tomcat9 -y",
     "scp home@178.154.207.146:/tmp/hello-1.0.war -yes /var/lib/tomcat9/webapps/"
   ]
 }
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

output "internal_ip_address_build" {
  value = yandex_compute_instance.build.network_interface.0.ip_address
}

output "internal_ip_address_prod" {
  value = yandex_compute_instance.prod.network_interface.0.ip_address
}

output "external_ip_address_build" {
  value = yandex_compute_instance.build.network_interface.0.nat_ip_address
}

output "external_ip_address_prod" {
  value = yandex_compute_instance.prod.network_interface.0.nat_ip_address
}
