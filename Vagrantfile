# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Vagrantfile : laboratoire NOVA (fil rouge du module Gestion des configurations)
# 3 machines : ctrl (poste de contrôle Ansible) + preprod et prod (nœuds k3s)

# Description déclarative des machines : nom => paramètres
NODES = {
  "ctrl"    => { ip: "192.168.56.10", cpus: 1, memory: 1024, script: "provision-ctrl.sh" },
  "preprod" => { ip: "192.168.56.21", cpus: 2, memory: 2048, script: "provision-node.sh" },
  "prod"    => { ip: "192.168.56.22", cpus: 2, memory: 2048, script: "provision-node.sh" },
}

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"       # ✅ Image Ubuntu 22.04 LTS
  config.vm.box_check_update = false         # ✅ Évite une vérification réseau à chaque 'up'
  config.vm.synced_folder ".", "/vagrant"    # ✅ Le dépôt est partagé hôte <-> VMs

  NODES.each do |name, cfg|                  # ✅ ctrl démarre en premier
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.network "private_network", ip: cfg[:ip]   # ✅ Réseau 192.168.56.0/24
      node.vm.provider "virtualbox" do |vb|
        vb.name         = "nova-#{name}"     # ✅ Noms : nova-ctrl, nova-preprod, nova-prod
        vb.cpus         = cfg[:cpus]        # ✅ Ressources exactes du TP
        vb.memory       = cfg[:memory]
        vb.linked_clone = true               # ✅ Économise l'espace disque
      end
      node.vm.provision "shell", path: "scripts/#{cfg[:script]}"
    end
  end
end
