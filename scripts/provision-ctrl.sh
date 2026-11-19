#!/usr/bin/env bash
# provision-ctrl.sh : exécuté par Vagrant (en root) à la création de la VM "ctrl"
set -euo pipefail                     # stop à la 1re erreur, variable non définie = erreur
export DEBIAN_FRONTEND=noninteractive # aucune question posée par apt

echo ">>> [1/5] Noms de machines du laboratoire"
grep -q "# nova-lab" /etc/hosts || cat >> /etc/hosts <<'HOSTS'
# nova-lab
192.168.56.10 ctrl
192.168.56.21 node-preprod
192.168.56.22 node-prod
HOSTS

echo ">>> [2/5] Paquets système"
# Miroirs apt : certains réseaux (campus) bloquent le HTTP sortant (port 80)
# tout en laissant passer le HTTPS. Test non bloquant ; si 80 est muet, on
# bascule les sources vers le miroir kernel.org, en HTTPS (même contenu).
if ! timeout 3 bash -c 'echo > /dev/tcp/us.archive.ubuntu.com/80' 2>/dev/null; then
  echo ">>> port 80 sortant bloque (reseau local ?) : miroirs apt -> HTTPS kernel.org"
  sed -i \
    -e 's|http://us.archive.ubuntu.com/ubuntu|https://mirrors.edge.kernel.org/ubuntu|g' \
    -e 's|http://security.ubuntu.com/ubuntu|https://mirrors.edge.kernel.org/ubuntu|g' \
    /etc/apt/sources.list
fi
# Tolerance aux miroirs Ubuntu en cours de synchronisation ("File has unexpected size")
# bornee : 30 essais max (5 min), puis echec explicite -- jamais de boucle infinie
UPD_OK=0
for i in $(seq 1 30); do
  if apt-get update -qq; then UPD_OK=1; break; fi
  echo ">>> apt update a echoue (essai $i/30, miroir ?) : nouvel essai dans 10 s"
  sleep 10
done
if [ "$UPD_OK" -ne 1 ]; then
  echo ">>> FATAL : apt update n'a jamais abouti (30 essais, reseau indisponible ?)"
  exit 1
fi
# Installation des paquets, tolérante aux miroirs capricieux (réseau campus) :
# le téléchargement d'un .deb peut échouer ("Failed to fetch ... Connection
# refused") pendant une synchro de miroir ; on retentera jusqu'à 30 fois.
# $PKGS est volontairement non-quoté (word splitting voulu)  # shellcheck disable=SC2086
PKGS="python3-pip git curl jq unzip make sshpass bash-completion"
INSTALLED=0
for i in $(seq 1 30); do
  if apt-get install -y -qq $PKGS; then
    INSTALLED=1
    break
  fi
  echo ">>> apt install a echoue (essai $i/30, miroir ?) : nouvel essai dans 10 s"
  sleep 10
  apt-get update -qq || true
done
if [ "$INSTALLED" -ne 1 ]; then
  echo ">>> FATAL : apt install n'a jamais abouti (30 essais)"
  exit 1
fi

echo ">>> [3/5] Ansible + outils qualité (ansible-core 2.17 = dernière branche compatible Python 3.10)"
# Même tolérance que pour apt : PyPI est derrière le même réseau capricieux
PIP_OK=0
for i in $(seq 1 5); do
  if pip3 install --quiet "ansible-core~=2.17.0" ansible-lint yamllint; then PIP_OK=1; break; fi
  echo ">>> pip install a echoue (essai $i/5, reseau ?) : nouvel essai dans 15 s"
  sleep 15
done
if [ "$PIP_OK" -ne 1 ]; then
  echo ">>> FATAL : pip install n'a jamais abouti (5 essais)"
  exit 1
fi

echo ">>> [4/5] Helm 3 (pour 'helm lint' et 'helm template' côté ctrl)"
if ! command -v helm >/dev/null; then
  # 5 essais max : raw.githubusercontent.com subit le même réseau campus
  HELM_OK=0
  for i in $(seq 1 5); do
    if curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
         | DESIRED_VERSION=v3.16.4 bash; then HELM_OK=1; break; fi
    echo ">>> get-helm-3 a echoue (essai $i/5, reseau ?) : nouvel essai dans 15 s"
    sleep 15
  done
  if [ "$HELM_OK" -ne 1 ]; then
    echo ">>> FATAL : installation de Helm impossible (5 essais)"
    exit 1
  fi
fi

echo ">>> [5/5] Clé SSH de l'automate + configuration Ansible"
sudo -u vagrant bash -c '[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -C ansible@ctrl -f ~/.ssh/id_ed25519'
mkdir -p /vagrant/.ssh_share                                  # dossier d'échange (ignoré par Git)
cp /home/vagrant/.ssh/id_ed25519.pub /vagrant/.ssh_share/ctrl.pub
echo 'export ANSIBLE_CONFIG=/vagrant/ansible/ansible.cfg' > /etc/profile.d/nova-ansible.sh

echo ">>> ctrl prête."
