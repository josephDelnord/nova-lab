# -*- mode: ruby -*-
# vi: set ft=ruby :

# TP0: Configuration des 3 VM pour nova-lab
# - ctrl: Machine de contrôle (Ansible, Helm, kubectl)
# - preprod: Noeud Kubernetes pour l'environnement de préproduction
# - prod: Noeud Kubernetes pour l'environnement de production

Vagrant.configure("2") do |config|
  # Configuration commune à toutes les VM
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_version = "202403.15.0"
  config.ssh.insert_key = false
  config.ssh.forward_agent = true

  # Configuration réseau
  config.vm.network "private_network", ip: "192.168.56.100", netmask: "255.255.255.0"

  # ============================================
  # VM CTRL (Machine de contrôle)
  # ============================================
  config.vm.define "ctrl" do |ctrl|
    ctrl.vm.hostname = "ctrl.novalab.local"
    ctrl.vm.network "private_network", ip: "192.168.56.10"
    
    # Port forwarding pour SSH
    ctrl.vm.network "forwarded_port", guest: 22, host: 2222, id: "ssh-ctrl"
    
    # Provisionnement
    ctrl.vm.provision "shell", path: "scripts/provision-ctrl.sh", run: "once"
    
    # Montage des répertoires partagés
    ctrl.vm.synced_folder ".", "/vagrant", disabled: true
    ctrl.vm.synced_folder "./ansible", "/home/vagrant/ansible", owner: "vagrant", group: "vagrant"
    ctrl.vm.synced_folder "./charts", "/home/vagrant/charts", owner: "vagrant", group: "vagrant"
    ctrl.vm.synced_folder "./scripts", "/home/vagrant/scripts", owner: "vagrant", group: "vagrant"
    
    # Ressources
    ctrl.vm.provider "virtualbox" do |vb|
      vb.name = "nova-lab-ctrl"
      vb.memory = "4096"
      vb.cpus = 2
    end
  end

  # ============================================
  # VM PREPROD (Noeud Kubernetes - Préproduction)
  # ============================================
  config.vm.define "preprod" do |preprod|
    preprod.vm.hostname = "preprod.novalab.local"
    preprod.vm.network "private_network", ip: "192.168.56.20"
    
    # Port forwarding pour SSH et Kubernetes API
    preprod.vm.network "forwarded_port", guest: 22, host: 2223, id: "ssh-preprod"
    preprod.vm.network "forwarded_port", guest: 6443, host: 6443, id: "k8s-api-preprod"
    preprod.vm.network "forwarded_port", guest: 80, host: 8080, id: "http-preprod"
    preprod.vm.network "forwarded_port", guest: 443, host: 8443, id: "https-preprod"
    
    # Provisionnement
    preprod.vm.provision "shell", path: "scripts/provision-node.sh", run: "once", args: ["preprod"]
    
    # Ressources
    preprod.vm.provider "virtualbox" do |vb|
      vb.name = "nova-lab-preprod"
      vb.memory = "4096"
      vb.cpus = 2
    end
  end

  # ============================================
  # VM PROD (Noeud Kubernetes - Production)
  # ============================================
  config.vm.define "prod" do |prod|
    prod.vm.hostname = "prod.novalab.local"
    prod.vm.network "private_network", ip: "192.168.56.30"
    
    # Port forwarding pour SSH et Kubernetes API
    prod.vm.network "forwarded_port", guest: 22, host: 2224, id: "ssh-prod"
    prod.vm.network "forwarded_port", guest: 6443, host: 6444, id: "k8s-api-prod"
    prod.vm.network "forwarded_port", guest: 80, host: 8081, id: "http-prod"
    prod.vm.network "forwarded_port", guest: 443, host: 8444, id: "https-prod"
    
    # Provisionnement
    prod.vm.provision "shell", path: "scripts/provision-node.sh", run: "once", args: ["prod"]
    
    # Ressources
    prod.vm.provider "virtualbox" do |vb|
      vb.name = "nova-lab-prod"
      vb.memory = "4096"
      vb.cpus = 2
    end
  end
end
