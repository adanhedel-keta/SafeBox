# Chemin du répertoire Téléchargements de l'utilisateur
$downloadPath = Join-Path $env:USERPROFILE "Téléchargements"

# Nom du nouveau répertoire à créer
$newFolderName = "RaspberryPi_Vagrant"

# Chemin complet du nouveau répertoire
$newFolderPath = Join-Path $downloadPath $newFolderName

# Vérifier si le répertoire existe déjà
if (-not (Test-Path $newFolderPath)) {
    # Créer le répertoire
    New-Item -Path $newFolderPath -ItemType Directory
    Write-Host "Le répertoire a été créé : $newFolderPath"
} else {
    Write-Host "Le répertoire existe déjà : $newFolderPath"
}
# Déplacer la console dans le répertoire créé
Set-Location -Path $newFolderPath
Write-Host "La console a été déplacée dans : $newFolderPath"

# Fonction pour installer Chocolatey s'il n'est pas déjà installé
function Install-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Chocolatey n'est pas installé. Installation en cours..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Chocolatey a été installé."
    } else {
        Write-Host "Chocolatey est déjà installé."
    }
}

# Fonction pour installer Vagrant
function Install-Vagrant {
    if (-not (Get-Command vagrant -ErrorAction SilentlyContinue)) {
        Write-Host "Installation de Vagrant en cours..."
        choco install vagrant -y
        Write-Host "Vagrant a été installé avec succès."
    } else {
        Write-Host "Vagrant est déjà installé."
    }
}

# Fonction pour installer VirtualBox
function Install-VirtualBox {
    if (-not (Get-Command VBoxManage -ErrorAction SilentlyContinue)) {
        Write-Host "Installation de VirtualBox en cours..."
        choco install virtualbox -y
        Write-Host "VirtualBox a été installé avec succès."
    } else {
        Write-Host "VirtualBox est déjà installé."
    }
}
# Appel des fonctions pour installer Chocolatey puis Vagrant puis Virtualbox
Install-Chocolatey
Install-Vagrant
Install-VirtualBox

Write-Host "Initialisation de Vagrant dans le répertoire : $newFolderPath"

#Initialise vagrant
vagrant init

# Vérifier si le fichier Vagrantfile a été créé
if (Test-Path "$newFolderPath\Vagrantfile") {
    Write-Host "Le fichier Vagrantfile a été créé avec succès."
} else {
    Write-Host "Échec de la création du fichier Vagrantfile."
}

$vagrantFilePath = Join-Path $newFolderPath "Vagrantfile"
# Vérifier si le fichier Vagrantfile existe
if (Test-Path $vagrantFilePath) {
    # Effacer le contenu du Vagrantfile
    Clear-Content -Path $vagrantFilePath
    Write-Host "Le contenu du fichier Vagrantfile a été effacé."
    
    # Ajouter les nouvelles configurations dans le Vagrantfile
    $newConfig = @"
Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/jammy64"
    config.vm.provider "virtualbox" do |vb|
        vb.memory = "8192"
        vb.cpus = "8"
        vb.gui = true
    end
end
"@

    # Écrire les nouvelles configurations dans le Vagrantfile
    Set-Content -Path $vagrantFilePath -Value $newConfig
    Write-Host "Le fichier Vagrantfile a été mis à jour avec les nouvelles configurations."
} else {
    Write-Host "Le fichier Vagrantfile n'existe pas. Assurez-vous que Vagrant a été initialisé."
}




# Lancer la machine Vagrant
Write-Host "Démarrage de la machine Vagrant..."
vagrant up --provider=virtualbox

# Vérifier si la machine est correctement démarrée
$vagrantStatus = vagrant status --machine-readable | Select-String "state,running"
if ($vagrantStatus) {
    Write-Host "La machine Vagrant est en cours d'exécution."

    # Connexion à la machine via SSH
    Write-Host "Connexion à la machine Vagrant via SSH..."
    
} else {
    Write-Host "Échec du démarrage de la machine Vagrant."
}



#Téléchargement de l'image cible sur le site de Raspberry, et décompression totale
vagrant ssh -c "wget --progress=bar:noscroll https://downloads.raspberrypi.com/raspios_full_armhf/images/raspios_full_armhf-2024-07-04/2024-07-04-raspios-bookworm-armhf-full.img.xz"
vagrant ssh -c "unxz -v 2024-07-04-raspios-bookworm-armhf-full.img.xz"

#Installation des paquets qemu
vagrant ssh -c "sudo apt-get update && sudo apt-get install -y util-linux"
vagrant ssh -c "sudo apt-get install -y qemu-utils"
vagrant ssh -c "sudo apt-get install -y qemu-system"
vagrant ssh -c "sudo apt-get update"
vagrant ssh -c "sudo apt-get install -y qemu-user-static"


#Redimensionnement de l'image
vagrant ssh -c "qemu-img info 2024-07-04-raspios-bookworm-armhf-full.img" 
vagrant ssh -c "qemu-img resize 2024-07-04-raspios-bookworm-armhf-full.img +6G"
vagrant ssh -c "fdisk -l 2024-07-04-raspios-bookworm-armhf-full.img"
vagrant ssh -c "growpart 2024-07-04-raspios-bookworm-armhf-full.img 2"
vagrant ssh -c "fdisk -l 2024-07-04-raspios-bookworm-armhf-full.img"

vagrant ssh -c "DEVICE=$(losetup -f --show -P 2024-07-04-raspios-bookworm-armhf-full.img)"
vagrant ssh -c "echo $DEVICE"
vagrant ssh -c "lsblk -o name,label,size $DEVICE"

vagrant ssh -c "losetup -l"
#Montage des disques
vagrant ssh -c "DEVICE=$DEVICE"
vagrant ssh -c "sudo e2fsck -f ${DEVICE}p2"
vagrant ssh -c "sudo resize2fs ${DEVICE}p2"
vagrant ssh -c "mkdir -p rootfs"
vagrant ssh -c "sudo mount ${DEVICE}p2 rootfs/"
vagrant ssh -c "ls rootfs/"

vagrant ssh -c "cat rootfs/etc/fstab"
vagrant ssh -c "ls rootfs/boot/"

vagrant ssh -c "sudo mount ${DEVICE}p1 rootfs/boot/"
vagrant ssh -c "rm -rf /rootfs/dev/*"
vagrant ssh -c "sudo mount -t proc /proc rootfs/proc/"
vagrant ssh -c "sudo mount --bind /sys rootfs/sys/"
vagrant ssh -c "sudo mount --bind /dev rootfs/dev/"

#Connexion au Raspberry en émulation et mise à jour
vagrant ssh -c "sudo chroot rootfs/"
vagrant ssh -c "apt-get update -y"
vagrant ssh -c "apt-get upgrade -y"

#Mise à jour du nom de l'ordinateur
vagrant ssh -c "echo "SafeBox" > /etc/hostname"

#Installation libreoffice
vagrant ssh -c "sudo apt-get install -y libreoffice"

#Changement du fond d'écran 
vagrant ssh -c "apt-get install -y feh"
vagrant ssh -c "mkdir -p /home/pi/wallpapers"
vagrant ssh -c "wget -q "https://image.tmdb.org/t/p/original/gjHZbURgyqjBMHQICu3VZQf41gF.jpg" -O /home/pi/wallpapers/background.jpg"
vagrant ssh -c "DISPLAY=:0 feh --bg-scale "/home/pi/wallpapers/background.jpg""

#Désactivation de Piwiz
vagrant ssh -c "sudo apt purge piwiz"

#Ajout d'utilisateur enfant
vagrant ssh -c "useradd enfant -p "

#Modification des serveurs DNS
vagrant ssh -c "apt-get install -y systemd-resolved"
# Ajout des serveurs DNS dans le fichier resolved.conf
vagrant ssh -c "cat >> /etc/systemd/resolved.conf << EOL
DNS=193.110.81.1#kids.dns0.eu
DNS=2a0f:fc80::1#kids.dns0.eu
DNS=185.253.5.1#kids.dns0.eu
DNS=2a0f:fc81::1#kids.dns0.eu
DNSOverTLS=yes
EOL"


# Blocage des services Meta
vagrant ssh -c "cat >> /etc/hosts << EOL
#Blocking Facebook Domains
0.0.0.0 apps.facebook.com
0.0.0.0 connect.facebook.net
0.0.0.0 facebook.com
0.0.0.0 fbcdn.com
0.0.0.0 fbsbx.com
0.0.0.0 fbcdn.net
0.0.0.0 graph.facebook.com
0.0.0.0 login.facebook.com
0.0.0.0 s-static.ak.facebook.com
0.0.0.0 static.ak.connect.facebook.com
0.0.0.0 static.ak.fbcdn.net
0.0.0.0 www.connect.facebook.net
0.0.0.0 www.facebook.com
0.0.0.0 www.fbcdn.com
0.0.0.0 www.fbcdn.net
0.0.0.0 www.graph.facebook.com
0.0.0.0 www.login.facebook.com
0.0.0.0 www.s-static.ak.facebook.com
0.0.0.0 www.static.ak.connect.facebook.com
0.0.0.0 www.static.ak.fbcdn.net
0.0.0.0 0-edge-chat.facebook.com
0.0.0.0 1-edge-chat.facebook.com
0.0.0.0 2-edge-chat.facebook.com
0.0.0.0 3-edge-chat.facebook.com
0.0.0.0 4-edge-chat.facebook.com
0.0.0.0 5-edge-chat.facebook.com
0.0.0.0 6-edge-chat.facebook.com
0.0.0.0 alpha-shv-03-ash5.facebook.com
0.0.0.0 alpha-shv-03-atn1.facebook.com
0.0.0.0 alpha-shv-03-lla1.facebook.com
0.0.0.0 alpha-shv-04-prn2.facebook.com
0.0.0.0 alpha-shv-09-frc1.facebook.com
0.0.0.0 alpha.vvv.facebook.com
0.0.0.0 a.ns.facebook.com
0.0.0.0 api.facebook.com
0.0.0.0 atlasalpha-shv-09-frc3.facebook.com
0.0.0.0 atlas.c10r.facebook.com
0.0.0.0 atlasinyour-shv-05-ash3.facebook.com
0.0.0.0 atlas-shv-01-prn2.facebook.com
0.0.0.0 atlas-shv-04-lla1.facebook.com
0.0.0.0 atlas-shv-05-ash3.facebook.com
0.0.0.0 atlas-shv-06-ash2.facebook.com
0.0.0.0 atlas-shv-06-frc1.facebook.com
0.0.0.0 atlas-shv-07-lla1.facebook.com
0.0.0.0 atlas-shv-09-frc3.facebook.com
0.0.0.0 atlas-shv-13-prn1.facebook.com
0.0.0.0 atlas-www-shv-04-prn2.facebook.com
0.0.0.0 atlas-www-shv-07-ash4.facebook.com
0.0.0.0 atlas-www-shv-09-frc1.facebook.com
0.0.0.0 aura-11-01-snc7.facebook.com
0.0.0.0 badge.facebook.com
0.0.0.0 b-api.facebook.com
0.0.0.0 beta-chat-01-05-ash3.facebook.com
0.0.0.0 betanet-shv-03-atn1.facebook.com
0.0.0.0 betanet-shv-03-lla1.facebook.com
0.0.0.0 betanet-shv-04-prn2.facebook.com
0.0.0.0 betanet-shv-09-frc1.facebook.com
0.0.0.0 beta-shv-03-atn1.facebook.com
0.0.0.0 beta-shv-03-lla1.facebook.com
0.0.0.0 beta-shv-04-prn2.facebook.com
0.0.0.0 beta-shv-09-frc1.facebook.com
0.0.0.0 beta.vvv.facebook.com
0.0.0.0 b-graph.facebook.com
0.0.0.0 bidder-shv-05-frc3.facebook.com
0.0.0.0 bidder-shv-10-frc1.facebook.com
0.0.0.0 b.ns.facebook.com
0.0.0.0 channel-proxy-shv-04-frc3.facebook.com
0.0.0.0 channel-proxy-shv-06-ash2.facebook.com
0.0.0.0 channel-proxy-shv-07-ash2.facebook.com
0.0.0.0 channel-proxy-shv-13-prn1.facebook.com
0.0.0.0 channel-proxy-test-shv-07-ash2.facebook.com
0.0.0.0 code.facebook.com
0.0.0.0 connect.facebook.com
0.0.0.0 dev.vvv.facebook.com
0.0.0.0 d.vvv.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-01-ash5.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-03-ash5.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-07-ash4.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-07-frc3.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-09-frc1.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-12-frc1.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-12-frc3.facebook.com
0.0.0.0 edge-atlas-proxyprotocol-shv-13-frc1.facebook.com
0.0.0.0 edge-atlas-shv-01-ams2.facebook.com
0.0.0.0 edge-atlas-shv-01-ams3.facebook.com
0.0.0.0 edge-atlas-shv-01-ash5.facebook.com
0.0.0.0 edge-atlas-shv-01-atl1.facebook.com
0.0.0.0 edge-atlas-shv-01-bru2.facebook.com
0.0.0.0 edge-atlas-shv-01-cai1.facebook.com
0.0.0.0 edge-atlas-shv-01-cdg2.facebook.com
0.0.0.0 edge-atlas-shv-01-dfw1.facebook.com
0.0.0.0 edge-atlas-shv-01-fra3.facebook.com
0.0.0.0 edge-atlas-shv-01-gru1.facebook.com
0.0.0.0 edge-atlas-shv-01-hkg2.facebook.com
0.0.0.0 edge-atlas-shv-01-iad3.facebook.com
0.0.0.0 edge-atlas-shv-01-kul1.facebook.com
0.0.0.0 edge-atlas-shv-01-lax1.facebook.com
0.0.0.0 edge-atlas-shv-01-lga1.facebook.com
0.0.0.0 edge-atlas-shv-01-lhr3.facebook.com
0.0.0.0 edge-atlas-shv-01-mad1.facebook.com
0.0.0.0 edge-atlas-shv-01-mia1.facebook.com
0.0.0.0 edge-atlas-shv-01-mxp1.facebook.com
0.0.0.0 edge-atlas-shv-01-nrt1.facebook.com
0.0.0.0 edge-atlas-shv-01-ord1.facebook.com
0.0.0.0 edge-atlas-shv-01-sea1.facebook.com
0.0.0.0 edge-atlas-shv-01-sin1.facebook.com
0.0.0.0 edge-atlas-shv-01-sjc2.facebook.com
0.0.0.0 edge-atlas-shv-01-syd1.facebook.com
0.0.0.0 edge-atlas-shv-01-vie1.facebook.com
0.0.0.0 edge-atlas-shv-02-cai1.facebook.com
0.0.0.0 edge-atlas-shv-02-hkg2.facebook.com
0.0.0.0 edge-atlas-shv-03-ash5.facebook.com
0.0.0.0 edge-atlas-shv-03-atn1.facebook.com
0.0.0.0 edge-atlas-shv-03-hkg1.facebook.com
0.0.0.0 edge-atlas-shv-03-lla1.facebook.com
0.0.0.0 edge-atlas-shv-03-prn2.facebook.com
0.0.0.0 edge-atlas-shv-03-xdc1.facebook.com
0.0.0.0 edge-atlas-shv-04-hkg1.facebook.com
0.0.0.0 edge-atlas-shv-04-prn2.facebook.com
0.0.0.0 edge-atlas-shv-06-atn1.facebook.com
0.0.0.0 edge-atlas-shv-06-lla1.facebook.com
0.0.0.0 edge-atlas-shv-07-ash4.facebook.com
0.0.0.0 edge-atlas-shv-09-frc1.facebook.com
0.0.0.0 edge-atlas-shv-09-lla1.facebook.com
0.0.0.0 edge-atlas-shv-12-frc1.facebook.com
0.0.0.0 edge-atlas-shv-12-frc3.facebook.com
0.0.0.0 edge-atlas-shv-12-lla1.facebook.com
0.0.0.0 edge-atlas-shv-12-prn1.facebook.com
0.0.0.0 edge-atlas-shv-13-frc1.facebook.com
0.0.0.0 edge-atlas-shv-17-prn1.facebook.com
0.0.0.0 edge-atlas-shv-18-prn1.facebook.com
0.0.0.0 edge-chat.facebook.com
0.0.0.0 edge-liverail-shv-01-ams2.facebook.com
0.0.0.0 edge-liverail-shv-01-ams3.facebook.com
0.0.0.0 edge-liverail-shv-01-ash5.facebook.com
0.0.0.0 edge-liverail-shv-01-atl1.facebook.com
0.0.0.0 edge-liverail-shv-01-bru2.facebook.com
0.0.0.0 edge-liverail-shv-01-cai1.facebook.com
0.0.0.0 edge-liverail-shv-01-cdg2.facebook.com
0.0.0.0 edge-liverail-shv-01-dfw1.facebook.com
0.0.0.0 edge-liverail-shv-01-fra3.facebook.com
0.0.0.0 edge-liverail-shv-01-gru1.facebook.com
0.0.0.0 edge-liverail-shv-01-hkg2.facebook.com
0.0.0.0 edge-liverail-shv-01-iad3.facebook.com
0.0.0.0 edge-liverail-shv-01-kul1.facebook.com
0.0.0.0 edge-liverail-shv-01-lax1.facebook.com
0.0.0.0 edge-liverail-shv-01-lga1.facebook.com
0.0.0.0 edge-liverail-shv-01-lhr3.facebook.com
0.0.0.0 edge-liverail-shv-01-mad1.facebook.com
0.0.0.0 edge-liverail-shv-01-mia1.facebook.com
0.0.0.0 edge-liverail-shv-01-mxp1.facebook.com
0.0.0.0 edge-liverail-shv-01-nrt1.facebook.com
0.0.0.0 edge-liverail-shv-01-ord1.facebook.com
0.0.0.0 edge-liverail-shv-01-sea1.facebook.com
0.0.0.0 edge-liverail-shv-01-sin1.facebook.com
0.0.0.0 edge-liverail-shv-01-sjc2.facebook.com
0.0.0.0 edge-liverail-shv-01-syd1.facebook.com
0.0.0.0 edge-liverail-shv-01-tpe1.facebook.com
0.0.0.0 edge-liverail-shv-01-vie1.facebook.com
0.0.0.0 edge-liverail-shv-02-cai1.facebook.com
0.0.0.0 edge-liverail-shv-02-hkg2.facebook.com
0.0.0.0 edge-liverail-shv-03-ash5.facebook.com
0.0.0.0 edge-liverail-shv-03-atn1.facebook.com
0.0.0.0 edge-liverail-shv-03-hkg1.facebook.com
0.0.0.0 edge-liverail-shv-03-lla1.facebook.com
0.0.0.0 edge-liverail-shv-03-prn2.facebook.com
0.0.0.0 edge-liverail-shv-03-xdc1.facebook.com
0.0.0.0 edge-liverail-shv-04-hkg1.facebook.com
0.0.0.0 edge-liverail-shv-04-prn2.facebook.com
0.0.0.0 edge-liverail-shv-06-atn1.facebook.com
0.0.0.0 edge-liverail-shv-06-lla1.facebook.com
0.0.0.0 edge-liverail-shv-07-ash4.facebook.com
0.0.0.0 edge-liverail-shv-07-frc3.facebook.com
0.0.0.0 edge-liverail-shv-09-frc1.facebook.com
0.0.0.0 edge-liverail-shv-09-lla1.facebook.com
0.0.0.0 edge-liverail-shv-12-frc1.facebook.com
0.0.0.0 edge-liverail-shv-12-frc3.facebook.com
0.0.0.0 edge-liverail-shv-12-lla1.facebook.com
0.0.0.0 edge-liverail-shv-12-prn1.facebook.com
0.0.0.0 edge-liverail-shv-13-frc1.facebook.com
0.0.0.0 edge-liverail-shv-17-prn1.facebook.com
0.0.0.0 edge-liverail-shv-18-prn1.facebook.com
0.0.0.0 edge-mqtt.facebook.com
0.0.0.0 edge-mqtt-shv-01-ams2.facebook.com
0.0.0.0 edge-mqtt-shv-01-ams3.facebook.com
0.0.0.0 edge-mqtt-shv-01-ash5.facebook.com
0.0.0.0 edge-mqtt-shv-01-atl1.facebook.com
0.0.0.0 edge-mqtt-shv-01-bru2.facebook.com
0.0.0.0 edge-mqtt-shv-01-cai1.facebook.com
0.0.0.0 edge-mqtt-shv-01-cdg2.facebook.com
0.0.0.0 edge-mqtt-shv-01-dfw1.facebook.com
0.0.0.0 edge-mqtt-shv-01-fra3.facebook.com
0.0.0.0 edge-mqtt-shv-01-gru1.facebook.com
0.0.0.0 edge-mqtt-shv-01-hkg2.facebook.com
0.0.0.0 edge-mqtt-shv-01-iad3.facebook.com
0.0.0.0 edge-mqtt-shv-01-kul1.facebook.com
0.0.0.0 edge-mqtt-shv-01-lax1.facebook.com
0.0.0.0 edge-mqtt-shv-01-lga1.facebook.com
0.0.0.0 edge-mqtt-shv-01-lhr3.facebook.com
0.0.0.0 edge-mqtt-shv-01-mad1.facebook.com
0.0.0.0 edge-mqtt-shv-01-mia1.facebook.com
0.0.0.0 edge-mqtt-shv-01-mxp1.facebook.com
0.0.0.0 edge-mqtt-shv-01-nrt1.facebook.com
0.0.0.0 edge-mqtt-shv-01-ord1.facebook.com
0.0.0.0 edge-mqtt-shv-01-sea1.facebook.com
0.0.0.0 edge-mqtt-shv-01-sin1.facebook.com
0.0.0.0 edge-mqtt-shv-01-sjc2.facebook.com
0.0.0.0 edge-mqtt-shv-01-syd1.facebook.com
0.0.0.0 edge-mqtt-shv-01-tpe1.facebook.com
0.0.0.0 edge-mqtt-shv-01-vie1.facebook.com
0.0.0.0 edge-mqtt-shv-02-cai1.facebook.com
0.0.0.0 edge-mqtt-shv-02-hkg2.facebook.com
0.0.0.0 edge-mqtt-shv-03-ash5.facebook.com
0.0.0.0 edge-mqtt-shv-03-atn1.facebook.com
0.0.0.0 edge-mqtt-shv-03-hkg1.facebook.com
0.0.0.0 edge-mqtt-shv-03-lla1.facebook.com
0.0.0.0 edge-mqtt-shv-03-prn2.facebook.com
0.0.0.0 edge-mqtt-shv-03-xdc1.facebook.com
0.0.0.0 edge-mqtt-shv-04-hkg1.facebook.com
0.0.0.0 edge-mqtt-shv-04-prn2.facebook.com
0.0.0.0 edge-mqtt-shv-06-atn1.facebook.com
0.0.0.0 edge-mqtt-shv-06-lla1.facebook.com
0.0.0.0 edge-mqtt-shv-07-ash4.facebook.com
0.0.0.0 edge-mqtt-shv-07-frc3.facebook.com
0.0.0.0 edge-mqtt-shv-09-lla1.facebook.com
0.0.0.0 edge-mqtt-shv-12-frc1.facebook.com
0.0.0.0 edge-mqtt-shv-12-frc3.facebook.com
0.0.0.0 edge-mqtt-shv-12-lla1.facebook.com
0.0.0.0 edge-mqtt-shv-12-prn1.facebook.com
0.0.0.0 edge-mqtt-shv-13-frc1.facebook.com
0.0.0.0 edge-mqtt-shv-17-prn1.facebook.com
0.0.0.0 edge-mqtt-shv-18-prn1.facebook.com
0.0.0.0 edgeray-origin-shv-05-prn2.facebook.com
0.0.0.0 edgeray-origin-shv-07-lla1.facebook.com
0.0.0.0 edgeray-origin-shv-09-frc3.facebook.com
0.0.0.0 edgeray-origin-shv-11-frc3.facebook.com
0.0.0.0 edgeray-shv-01-ams2.facebook.com
0.0.0.0 edgeray-shv-01-ams3.facebook.com
0.0.0.0 edgeray-shv-01-atl1.facebook.com
0.0.0.0 edgeray-shv-01-bru2.facebook.com
0.0.0.0 edgeray-shv-01-cdg2.facebook.com
0.0.0.0 edgeray-shv-01-dfw1.facebook.com
0.0.0.0 edgeray-shv-01-fra3.facebook.com
0.0.0.0 edgeray-shv-01-gru1.facebook.com
0.0.0.0 edgeray-shv-01-iad3.facebook.com
0.0.0.0 edgeray-shv-01-kul1.facebook.com
0.0.0.0 edgeray-shv-01-lax1.facebook.com
0.0.0.0 edgeray-shv-01-lga1.facebook.com
0.0.0.0 edgeray-shv-01-lhr3.facebook.com
0.0.0.0 edgeray-shv-01-mad1.facebook.com
0.0.0.0 edgeray-shv-01-mia1.facebook.com
0.0.0.0 edgeray-shv-01-mxp1.facebook.com
0.0.0.0 edgeray-shv-01-ord1.facebook.com
0.0.0.0 edgeray-shv-01-sea1.facebook.com
0.0.0.0 edgeray-shv-01-sin1.facebook.com
0.0.0.0 edgeray-shv-01-sjc2.facebook.com
0.0.0.0 edgeray-shv-01-syd1.facebook.com
0.0.0.0 edgeray-shv-01-vie1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-ams3.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-atl1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-bru2.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-cai1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-cdg2.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-dfw1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-fra3.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-gru1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-iad3.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-kul1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-lax1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-lhr3.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-mad1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-nrt1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-ord1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-sea1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-01-syd1.facebook.com
0.0.0.0 edge-snaptu-http-p1-shv-02-cai1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-ams3.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-ash5.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-atl1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-bru2.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-cai1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-cdg2.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-dfw1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-fra3.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-gru1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-hkg2.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-iad3.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-kul1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-lax1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-lhr3.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-mad1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-nrt1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-ord1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-sea1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-01-syd1.facebook.com
0.0.0.0 edge-snaptu-tunnel-shv-02-cai1.facebook.com
0.0.0.0 edge-star-shv-12-frc3.facebook.com
0.0.0.0 l.facebook.com
0.0.0.0 liverail.c10r.facebook.com
0.0.0.0 lm.facebook.com
0.0.0.0 m.facebook.com
0.0.0.0 mqtt.c10r.facebook.com
0.0.0.0 mqtt.vvv.facebook.com
0.0.0.0 pixel.facebook.com
0.0.0.0 profile.ak.facebook.com.edgesuite.net
0.0.0.0 research.facebook.com
0.0.0.0 snaptu-d-shv-05-frc3.facebook.com
0.0.0.0 snaptu-d-shv-10-frc1.facebook.com
0.0.0.0 s-static.ak.facebook.com.edgekey.net
0.0.0.0 star.c10r.facebook.com
0.0.0.0 star.facebook.com
0.0.0.0 star-mini.c10r.facebook.com
0.0.0.0 static.ak.facebook.com
0.0.0.0 static.ak.facebook.com.edgesuite.net
0.0.0.0 staticxx.facebook.com
0.0.0.0 webdav.facebook.com
0.0.0.0 z-m.c10r.facebook.com
0.0.0.0 z-m.facebook.com
0.0.0.0 edge-sonar-shv-01-ams2.fbcdn.net
0.0.0.0 edge-sonar-shv-01-ams3.fbcdn.net
0.0.0.0 edge-sonar-shv-01-ash5.fbcdn.net
0.0.0.0 edge-sonar-shv-01-atl1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-bru2.fbcdn.net
0.0.0.0 edge-sonar-shv-01-cai1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-cdg2.fbcdn.net
0.0.0.0 edge-sonar-shv-01-dfw1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-fra3.fbcdn.net
0.0.0.0 edge-sonar-shv-01-gru1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-iad3.fbcdn.net
0.0.0.0 edge-sonar-shv-01-kul1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-lax1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-lga1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-lhr3.fbcdn.net
0.0.0.0 edge-sonar-shv-01-mad1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-mia1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-mrs1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-mxp1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-nrt1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-ord1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-sea1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-sin1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-sjc2.fbcdn.net
0.0.0.0 edge-sonar-shv-01-syd1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-tpe1.fbcdn.net
0.0.0.0 edge-sonar-shv-01-vie1.fbcdn.net
0.0.0.0 edge-sonar-shv-02-cai1.fbcdn.net
0.0.0.0 edge-sonar-shv-02-hkg2.fbcdn.net
0.0.0.0 edge-sonar-shv-03-ash5.fbcdn.net
0.0.0.0 edge-sonar-shv-03-atn1.fbcdn.net
0.0.0.0 edge-sonar-shv-03-hkg1.fbcdn.net
0.0.0.0 edge-sonar-shv-03-lla1.fbcdn.net
0.0.0.0 edge-sonar-shv-03-prn2.fbcdn.net
0.0.0.0 edge-sonar-shv-03-xdc1.fbcdn.net
0.0.0.0 edge-sonar-shv-04-hkg1.fbcdn.net
0.0.0.0 edge-sonar-shv-04-prn2.fbcdn.net
0.0.0.0 edge-sonar-shv-06-atn1.fbcdn.net
0.0.0.0 edge-sonar-shv-06-lla1.fbcdn.net
0.0.0.0 edge-sonar-shv-07-ash4.fbcdn.net
0.0.0.0 edge-sonar-shv-07-frc3.fbcdn.net
0.0.0.0 edge-sonar-shv-09-frc1.fbcdn.net
0.0.0.0 edge-sonar-shv-09-lla1.fbcdn.net
0.0.0.0 edge-sonar-shv-12-frc1.fbcdn.net
0.0.0.0 edge-sonar-shv-12-frc3.fbcdn.net
0.0.0.0 edge-sonar-shv-12-lla1.fbcdn.net
0.0.0.0 edge-sonar-shv-12-prn1.fbcdn.net
0.0.0.0 edge-sonar-shv-13-frc1.fbcdn.net
0.0.0.0 edge-sonar-shv-17-prn1.fbcdn.net
0.0.0.0 edge-sonar-shv-18-prn1.fbcdn.net
0.0.0.0 external-iad3-1.xx.fbcdn.net
0.0.0.0 external.fsjc1-2.fna.fbcdn.net
0.0.0.0 fdda274d380ki4frcgi-rumjfjai1460158783-sonar.xx.fbcdn.net
0.0.0.0 herningrideklub.netscontent-a-ams.xx.fbcdn.net
0.0.0.0 ncontent.xx.fbcdn.net
0.0.0.0 origincache-ash.t.fbcdn.net
0.0.0.0 origincache-frc.t.fbcdn.net
0.0.0.0 origincache-prn.t.fbcdn.net
0.0.0.0 origincache-tf.t.fbcdn.net
0.0.0.0 origincache-tl.t.fbcdn.net
0.0.0.0 origincache-xtf.fbcdn.net
0.0.0.0 origincache-xtl.fbcdn.net
0.0.0.0 origincache-xx-shv-05-atn1.fbcdn.net
0.0.0.0 origincache-xx-shv-05-frc3.fbcdn.net
0.0.0.0 origincache-xx-shv-05-prn2.fbcdn.net
0.0.0.0 origincache-xx-shv-06-ash3.fbcdn.net
0.0.0.0 origincache-xx-shv-06-ash4.fbcdn.net
0.0.0.0 origincache-xx-shv-07-ash2.fbcdn.net
0.0.0.0 origincache-xx-shv-07-atn1.fbcdn.net
0.0.0.0 origincache-xx-shv-08-ash2.fbcdn.net
0.0.0.0 origincache-xx-shv-08-frc3.fbcdn.net
0.0.0.0 origincache-xx-shv-08-prn2.fbcdn.net
0.0.0.0 origincache-xx-shv-09-frc3.fbcdn.net
0.0.0.0 origincache-xx-shv-09-prn2.fbcdn.net
0.0.0.0 origincache-xx-shv-13-prn1.fbcdn.net
0.0.0.0 photos-a-ord.xx.fbcdn.net
0.0.0.0 photos-a.xx.fbcdn.net
0.0.0.0 photos-b-ord.xx.fbcdn.net
0.0.0.0 photos-b.xx.fbcdn.net
0.0.0.0 profile-a-atl.xx.fbcdn.net
0.0.0.0 profile-a-dfw.xx.fbcdn.net
0.0.0.0 profile-a-iad.xx.fbcdn.net
0.0.0.0 profile-a-lax.xx.fbcdn.net
0.0.0.0 profile-a-lga.xx.fbcdn.net
0.0.0.0 profile-a-mia.xx.fbcdn.net
0.0.0.0 profile-a-ord.xx.fbcdn.net
0.0.0.0 profile-a-sea.xx.fbcdn.net
0.0.0.0 profile-a-sjc.xx.fbcdn.net
0.0.0.0 profile-a.xx.fbcdn.net
0.0.0.0 profile-b-dfw.xx.fbcdn.net
0.0.0.0 profile-b-iad.xx.fbcdn.net
0.0.0.0 profile-b-lga.xx.fbcdn.net
0.0.0.0 profile-b-mia.xx.fbcdn.net
0.0.0.0 profile-b-ord.xx.fbcdn.net
0.0.0.0 profile-b-sjc.xx.fbcdn.net
0.0.0.0 profile-b.xx.fbcdn.net
0.0.0.0 profile.ak.fbcdn.net
0.0.0.0 profile.xx.fbcdn.net
0.0.0.0 scontent-1.2914.fna.fbcdn.net
0.0.0.0 scontent-2.2914.fna.fbcdn.net
0.0.0.0 scontent-a-ams.xx.fbcdn.net
0.0.0.0 scontent-a-atl.xx.fbcdn.net
0.0.0.0 scontent-a-cdg.xx.fbcdn.net
0.0.0.0 scontent-a-dfw.xx.fbcdn.net
0.0.0.0 scontent-a-fra.xx.fbcdn.net
0.0.0.0 scontent-a-gru.xx.fbcdn.net
0.0.0.0 scontent-a-iad.xx.fbcdn.net
0.0.0.0 scontent-a-lax.xx.fbcdn.net
0.0.0.0 scontent-a-lga.xx.fbcdn.net
0.0.0.0 scontent-a-lhr.xx.fbcdn.net
0.0.0.0 scontent-a-mad.xx.fbcdn.net
0.0.0.0 scontent-a-mia.xx.fbcdn.net
0.0.0.0 scontent-a-mxp.xx.fbcdn.net
0.0.0.0 scontent-a-ord.xx.fbcdn.net
0.0.0.0 scontent-a-pao.xx.fbcdn.net
0.0.0.0 scontent-a-sea.xx.fbcdn.net
0.0.0.0 scontent-a-sin.xx.fbcdn.net
0.0.0.0 scontent-a-sjc.xx.fbcdn.net
0.0.0.0 scontent-a-vie.xx.fbcdn.net
0.0.0.0 scontent-a.xx.fbcdn.net
0.0.0.0 scontent-ams.xx.fbcdn.net
0.0.0.0 scontent-atl.xx.fbcdn.net
0.0.0.0 scontent-b-ams.xx.fbcdn.net
0.0.0.0 scontent-b-atl.xx.fbcdn.net
0.0.0.0 scontent-b-cdg.xx.fbcdn.net
0.0.0.0 scontent-b-dfw.xx.fbcdn.net
0.0.0.0 scontent-b-fra.xx.fbcdn.net
0.0.0.0 scontent-b-gru.xx.fbcdn.net
0.0.0.0 scontent-b-hkg.xx.fbcdn.net
0.0.0.0 scontent-b-lax.xx.fbcdn.net
0.0.0.0 scontent-b-lga.xx.fbcdn.net
0.0.0.0 scontent-b-lhr.xx.fbcdn.net
0.0.0.0 scontent-b-mad.xx.fbcdn.net
0.0.0.0 scontent-b-mia.xx.fbcdn.net
0.0.0.0 scontent-b-mxp.xx.fbcdn.net
0.0.0.0 scontent-b-ord.xx.fbcdn.net
0.0.0.0 scontent-b-pao.xx.fbcdn.net
0.0.0.0 scontent-b-sea.xx.fbcdn.net
0.0.0.0 scontent-b-sin.xx.fbcdn.net
0.0.0.0 scontent-b-sjc.xx.fbcdn.net
0.0.0.0 scontent-b-vie.xx.fbcdn.net
0.0.0.0 scontent-b.xx.fbcdn.net
0.0.0.0 scontent-cdg.xx.fbcdn.net
0.0.0.0 scontent-dfw.xx.fbcdn.net
0.0.0.0 scontent-fra.xx.fbcdn.net
0.0.0.0 scontent-gru.xx.fbcdn.net
0.0.0.0 scontent-iad3-1.xx.fbcdn.net
0.0.0.0 scontent-lax.xx.fbcdn.net
0.0.0.0 scontent-lax3-1.xx.fbcdn.net
0.0.0.0 scontent-lga.xx.fbcdn.net
0.0.0.0 scontent-lga3-1.xx.fbcdn.net
0.0.0.0 scontent-lhr.xx.fbcdn.net
0.0.0.0 scontent-mia.xx.fbcdn.net
0.0.0.0 scontent-mxp.xx.fbcdn.net
0.0.0.0 scontent-ord.xx.fbcdn.net
0.0.0.0 scontent-sea.xx.fbcdn.net
0.0.0.0 scontent-sin.xx.fbcdn.net
0.0.0.0 scontent-sjc.xx.fbcdn.net
0.0.0.0 scontent-sjc2-1.xx.fbcdn.net
0.0.0.0 scontent-vie.xx.fbcdn.net
0.0.0.0 scontent.fsjc1-2.fna.fbcdn.net
0.0.0.0 scontent.fsnc1-1.fna.fbcdn.net
0.0.0.0 scontent.xx.fbcdn.net
0.0.0.0 sonar-iad.xx.fbcdn.net
0.0.0.0 sphotos-a-ams.xx.fbcdn.net
0.0.0.0 sphotos-a-atl.xx.fbcdn.net
0.0.0.0 sphotos-a-cdg.xx.fbcdn.net
0.0.0.0 sphotos-a-dfw.xx.fbcdn.net
0.0.0.0 sphotos-a-iad.xx.fbcdn.net
0.0.0.0 sphotos-a-lax.xx.fbcdn.net
0.0.0.0 sphotos-a-lga.xx.fbcdn.net
0.0.0.0 sphotos-a-lhr.xx.fbcdn.net
0.0.0.0 sphotos-a-mad.xx.fbcdn.net
0.0.0.0 sphotos-a-mia.xx.fbcdn.net
0.0.0.0 sphotos-a-mxp.xx.fbcdn.net
0.0.0.0 sphotos-a-ord.xx.fbcdn.net
0.0.0.0 sphotos-a-pao.xx.fbcdn.net
0.0.0.0 sphotos-a-sea.xx.fbcdn.net
0.0.0.0 sphotos-a-sjc.xx.fbcdn.net
0.0.0.0 sphotos-a-vie.xx.fbcdn.net
0.0.0.0 sphotos-a.xx.fbcdn.net
0.0.0.0 sphotos-b-ams.xx.fbcdn.net
0.0.0.0 sphotos-b-atl.xx.fbcdn.net
0.0.0.0 sphotos-b-cdg.xx.fbcdn.net
0.0.0.0 sphotos-b-dfw.xx.fbcdn.net
0.0.0.0 sphotos-b-iad.xx.fbcdn.net
0.0.0.0 sphotos-b-lax.xx.fbcdn.net
0.0.0.0 sphotos-b-lga.xx.fbcdn.net
0.0.0.0 sphotos-b-lhr.xx.fbcdn.net
0.0.0.0 sphotos-b-mad.xx.fbcdn.net
0.0.0.0 sphotos-b-mia.xx.fbcdn.net
0.0.0.0 sphotos-b-mxp.xx.fbcdn.net
0.0.0.0 sphotos-b-ord.xx.fbcdn.net
0.0.0.0 sphotos-b-pao.xx.fbcdn.net
0.0.0.0 sphotos-b-sea.xx.fbcdn.net
0.0.0.0 sphotos-b-sjc.xx.fbcdn.net
0.0.0.0 sphotos-b-vie.xx.fbcdn.net
0.0.0.0 sphotos-b.xx.fbcdn.net
0.0.0.0 sphotos.xx.fbcdn.net
0.0.0.0 sphotosbord.xx.fbcdn.net
0.0.0.0 static.xx.fbcdn.net
0.0.0.0 video-iad3-1.xx.fbcdn.net
0.0.0.0 vthumb.xx.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-ams2.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-ams3.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-atl1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-bru2.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-cdg2.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-dfw1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-fra3.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-gru1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-hkg2.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-iad3.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-lax1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-lga1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-lhr3.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-mad1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-mia1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-mrs1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-mxp1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-nrt1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-ord1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-sea1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-sin1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-sjc2.fbcdn.net
0.0.0.0 xx-fbcdn-shv-01-vie1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-02-cai1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-03-ash5.fbcdn.net
0.0.0.0 xx-fbcdn-shv-04-hkg1.fbcdn.net
0.0.0.0 xx-fbcdn-shv-04-prn2.fbcdn.net
0.0.0.0 z-1-scontent-sjc2-1.xx.fbcdn.net
0.0.0.0 z-1-scontent.xx.fbcdn.net

0.0.0.0 ae0.bb01.ams2.tfbnw.net
0.0.0.0 ae0.bb01.atl1.tfbnw.net
0.0.0.0 ae0.bb01.bos2.tfbnw.net
0.0.0.0 ae0.bb01.hkg1.tfbnw.net
0.0.0.0 ae0.bb01.hnd1.tfbnw.net
0.0.0.0 ae0.bb01.lhr2.tfbnw.net
0.0.0.0 ae0.bb01.lla1.tfbnw.net
0.0.0.0 ae0.bb01.mia1.tfbnw.net
0.0.0.0 ae0.bb01.nrt1.tfbnw.net
0.0.0.0 ae0.bb01.sin1.tfbnw.net
0.0.0.0 ae0.bb02.ams2.tfbnw.net
0.0.0.0 ae0.bb02.atl1.tfbnw.net
0.0.0.0 ae0.bb02.bos2.tfbnw.net
0.0.0.0 ae0.bb02.hkg1.tfbnw.net
0.0.0.0 ae0.bb02.lhr2.tfbnw.net
0.0.0.0 ae0.bb02.lla1.tfbnw.net
0.0.0.0 ae0.bb02.mia1.tfbnw.net
0.0.0.0 ae0.bb02.sin1.tfbnw.net
0.0.0.0 ae0.bb03.atn1.tfbnw.net
0.0.0.0 ae0.bb03.frc3.tfbnw.net
0.0.0.0 ae0.bb03.lla1.tfbnw.net
0.0.0.0 ae0.bb03.prn2.tfbnw.net
0.0.0.0 ae0.bb03.sjc1.tfbnw.net
0.0.0.0 ae0.bb04.atn1.tfbnw.net
0.0.0.0 ae0.bb04.frc3.tfbnw.net
0.0.0.0 ae0.bb04.lla1.tfbnw.net
0.0.0.0 ae0.bb04.prn2.tfbnw.net
0.0.0.0 ae0.bb04.sjc1.tfbnw.net
0.0.0.0 ae0.bb05.frc3.tfbnw.net
0.0.0.0 ae0.bb05.lla1.tfbnw.net
0.0.0.0 ae0.bb05.prn2.tfbnw.net
0.0.0.0 ae0.bb06.frc3.tfbnw.net
0.0.0.0 ae0.bb06.lla1.tfbnw.net
0.0.0.0 ae0.bb07.lla1.tfbnw.net
0.0.0.0 ae0.br01.arn2.tfbnw.net
0.0.0.0 ae0.br01.bru2.tfbnw.net
0.0.0.0 ae0.br01.cai1.tfbnw.net
0.0.0.0 ae0.br01.gru1.tfbnw.net
0.0.0.0 ae0.br01.mad1.tfbnw.net
0.0.0.0 ae0.br01.mrs1.tfbnw.net
0.0.0.0 ae0.br01.mxp1.tfbnw.net
0.0.0.0 ae0.br01.syd1.tfbnw.net
0.0.0.0 ae0.br01.tpe1.tfbnw.net
0.0.0.0 ae0.br01.vie1.tfbnw.net
0.0.0.0 ae0.dr01.prn2.tfbnw.net
0.0.0.0 ae0.dr01.snc1.tfbnw.net
0.0.0.0 ae0.dr02.prn2.tfbnw.net
0.0.0.0 ae0.dr02.snc1.tfbnw.net
0.0.0.0 ae0.dr03.ash3.tfbnw.net
0.0.0.0 ae0.dr03.prn2.tfbnw.net
0.0.0.0 ae0.dr04.ash3.tfbnw.net
0.0.0.0 ae0.dr04.prn2.tfbnw.net
0.0.0.0 ae0.lr01.ash3.tfbnw.net
0.0.0.0 ae0.lr02.ash3.tfbnw.net
0.0.0.0 ae0.pr01.ams2.tfbnw.net
0.0.0.0 ae0.pr01.ams3.tfbnw.net
0.0.0.0 ae0.pr01.dfw1.tfbnw.net
0.0.0.0 ae0.pr01.fra2.tfbnw.net
0.0.0.0 ae0.pr01.lhr2.tfbnw.net
0.0.0.0 ae0.pr01.mia1.tfbnw.net
0.0.0.0 ae0.pr02.dfw1.tfbnw.net
0.0.0.0 ae0.pr02.fra2.tfbnw.net
0.0.0.0 ae0.pr02.iad3.tfbnw.net
0.0.0.0 ae0.pr02.lax1.tfbnw.net
0.0.0.0 ae0.pr02.lga1.tfbnw.net
0.0.0.0 ae0.pr02.mia1.tfbnw.net
0.0.0.0 ae0.pr02.ord1.tfbnw.net
0.0.0.0 ae0.pr03.sjc1.tfbnw.net
0.0.0.0 ae0.pr04.sjc1.tfbnw.net
0.0.0.0 ae10.bb01.atl1.tfbnw.net
0.0.0.0 ae10.bb01.lhr2.tfbnw.net
0.0.0.0 ae10.bb01.lla1.tfbnw.net
0.0.0.0 ae10.bb01.mia1.tfbnw.net
0.0.0.0 ae10.bb01.sin1.tfbnw.net
0.0.0.0 ae10.bb02.atl1.tfbnw.net
0.0.0.0 ae10.bb02.hkg1.tfbnw.net
0.0.0.0 ae10.bb02.lhr2.tfbnw.net
0.0.0.0 ae10.bb02.lla1.tfbnw.net
0.0.0.0 ae10.bb02.mia1.tfbnw.net
0.0.0.0 ae10.bb02.sin1.tfbnw.net
0.0.0.0 ae10.bb03.atn1.tfbnw.net
0.0.0.0 ae10.bb03.frc3.tfbnw.net
0.0.0.0 ae10.bb03.lla1.tfbnw.net
0.0.0.0 ae10.bb03.sjc1.tfbnw.net
0.0.0.0 ae10.bb04.atn1.tfbnw.net
0.0.0.0 ae10.bb04.frc3.tfbnw.net
0.0.0.0 ae10.bb04.lla1.tfbnw.net
0.0.0.0 ae10.bb04.sjc1.tfbnw.net
0.0.0.0 ae10.bb05.lla1.tfbnw.net
0.0.0.0 ae10.bb06.frc3.tfbnw.net
0.0.0.0 ae10.bb06.lla1.tfbnw.net
0.0.0.0 ae10.br01.bru2.tfbnw.net
0.0.0.0 ae10.br01.kul1.tfbnw.net
0.0.0.0 ae10.br01.mad1.tfbnw.net
0.0.0.0 ae10.br01.mxp1.tfbnw.net
0.0.0.0 ae10.br01.tpe1.tfbnw.net
0.0.0.0 ae10.br02.vie1.tfbnw.net
0.0.0.0 ae10.dr01.frc1.tfbnw.net
0.0.0.0 ae10.dr02.frc1.tfbnw.net
0.0.0.0 ae10.dr02.prn1.tfbnw.net
0.0.0.0 ae10.dr05.prn1.tfbnw.net
0.0.0.0 ae10.dr06.prn1.tfbnw.net
0.0.0.0 ae10.pr01.atl1.tfbnw.net
0.0.0.0 ae10.pr01.dfw1.tfbnw.net
0.0.0.0 ae10.pr01.fra2.tfbnw.net
0.0.0.0 ae10.pr01.lax1.tfbnw.net
0.0.0.0 ae10.pr01.mia1.tfbnw.net
0.0.0.0 ae10.pr01.nrt1.tfbnw.net
0.0.0.0 ae10.pr01.sin1.tfbnw.net
0.0.0.0 ae10.pr02.atl1.tfbnw.net
0.0.0.0 ae10.pr02.fra2.tfbnw.net
0.0.0.0 ae10.pr02.sin1.tfbnw.net
0.0.0.0 ae11.bb01.ams2.tfbnw.net
0.0.0.0 ae11.bb01.atl1.tfbnw.net
0.0.0.0 ae11.bb01.lhr2.tfbnw.net
0.0.0.0 ae11.bb01.mia1.tfbnw.net
0.0.0.0 ae11.bb01.nrt1.tfbnw.net
0.0.0.0 ae11.bb01.sin1.tfbnw.net
0.0.0.0 ae11.bb02.ams2.tfbnw.net
0.0.0.0 ae11.bb02.atl1.tfbnw.net
0.0.0.0 ae11.bb02.hkg1.tfbnw.net
0.0.0.0 ae11.bb02.lhr2.tfbnw.net
0.0.0.0 ae11.bb02.mia1.tfbnw.net
0.0.0.0 ae11.bb02.sin1.tfbnw.net
0.0.0.0 ae11.bb03.atn1.tfbnw.net
0.0.0.0 ae11.bb03.frc3.tfbnw.net
0.0.0.0 ae11.bb03.prn2.tfbnw.net
0.0.0.0 ae11.bb03.sjc1.tfbnw.net
0.0.0.0 ae11.bb04.atn1.tfbnw.net
0.0.0.0 ae11.bb04.frc3.tfbnw.net
0.0.0.0 ae11.bb04.prn2.tfbnw.net
0.0.0.0 ae11.bb04.sjc1.tfbnw.net
0.0.0.0 ae11.bb05.lla1.tfbnw.net
0.0.0.0 ae11.bb06.frc3.tfbnw.net
0.0.0.0 ae11.bb06.lla1.tfbnw.net
0.0.0.0 ae11.br01.kul1.tfbnw.net
0.0.0.0 ae11.br01.mad1.tfbnw.net
0.0.0.0 ae11.br01.tpe1.tfbnw.net
0.0.0.0 ae11.br01.vie1.tfbnw.net
0.0.0.0 ae11.br02.mxp1.tfbnw.net
0.0.0.0 ae11.br02.vie1.tfbnw.net
0.0.0.0 ae11.dr01.atn1.tfbnw.net
0.0.0.0 ae11.dr01.frc1.tfbnw.net
0.0.0.0 ae11.dr01.snc1.tfbnw.net
0.0.0.0 ae11.dr02.atn1.tfbnw.net
0.0.0.0 ae11.dr02.frc1.tfbnw.net
0.0.0.0 ae11.dr02.snc1.tfbnw.net
0.0.0.0 ae11.dr03.atn1.tfbnw.net
0.0.0.0 ae11.dr03.frc1.tfbnw.net
0.0.0.0 ae11.dr04.atn1.tfbnw.net
0.0.0.0 ae11.dr04.frc1.tfbnw.net
0.0.0.0 ae11.pr01.atl1.tfbnw.net
0.0.0.0 ae11.pr01.dfw1.tfbnw.net
0.0.0.0 ae11.pr01.hkg1.tfbnw.net
0.0.0.0 ae11.pr01.lga1.tfbnw.net
0.0.0.0 ae11.pr01.lhr2.tfbnw.net
0.0.0.0 ae11.pr01.lhr3.tfbnw.net
0.0.0.0 ae11.pr01.ord1.tfbnw.net
0.0.0.0 ae11.pr02.atl1.tfbnw.net
0.0.0.0 ae11.pr02.cdg1.tfbnw.net
0.0.0.0 ae11.pr02.fra2.tfbnw.net
0.0.0.0 ae11.pr02.lax1.tfbnw.net
0.0.0.0 ae12.bb01.ams2.tfbnw.net
0.0.0.0 ae12.bb01.lhr2.tfbnw.net
0.0.0.0 ae12.bb01.mia1.tfbnw.net
0.0.0.0 ae12.bb01.nrt1.tfbnw.net
0.0.0.0 ae12.bb02.ams2.tfbnw.net
0.0.0.0 ae12.bb02.atl1.tfbnw.net
0.0.0.0 ae12.bb02.lhr2.tfbnw.net
0.0.0.0 ae12.bb02.mia1.tfbnw.net
0.0.0.0 ae12.bb03.atn1.tfbnw.net
0.0.0.0 ae12.bb03.frc3.tfbnw.net
0.0.0.0 ae12.bb03.prn2.tfbnw.net
0.0.0.0 ae12.bb03.sjc1.tfbnw.net
0.0.0.0 ae12.bb04.atn1.tfbnw.net
0.0.0.0 ae12.bb04.frc3.tfbnw.net
0.0.0.0 ae12.bb04.prn2.tfbnw.net
0.0.0.0 ae12.bb04.sjc1.tfbnw.net
0.0.0.0 ae12.bb05.lla1.tfbnw.net
0.0.0.0 ae12.bb06.frc3.tfbnw.net
0.0.0.0 ae12.bb06.lla1.tfbnw.net
0.0.0.0 ae12.br01.kul1.tfbnw.net
0.0.0.0 ae12.br01.mad1.tfbnw.net
0.0.0.0 ae12.br01.mxp1.tfbnw.net
0.0.0.0 ae12.br01.vie1.tfbnw.net
0.0.0.0 ae12.br02.mxp1.tfbnw.net
0.0.0.0 ae12.br02.vie1.tfbnw.net
0.0.0.0 ae12.dr01.atn1.tfbnw.net
0.0.0.0 ae12.dr01.frc1.tfbnw.net
0.0.0.0 ae12.dr01.snc1.tfbnw.net
0.0.0.0 ae12.dr02.atn1.tfbnw.net
0.0.0.0 ae12.dr02.frc1.tfbnw.net
0.0.0.0 ae12.dr02.snc1.tfbnw.net
0.0.0.0 ae12.dr03.atn1.tfbnw.net
0.0.0.0 ae12.dr03.frc1.tfbnw.net
0.0.0.0 ae12.dr04.atn1.tfbnw.net
0.0.0.0 ae12.dr04.frc1.tfbnw.net
0.0.0.0 ae12.pr01.ams2.tfbnw.net
0.0.0.0 ae12.pr01.ams3.tfbnw.net
0.0.0.0 ae12.pr01.atl1.tfbnw.net
0.0.0.0 ae12.pr01.hkg1.tfbnw.net
0.0.0.0 ae12.pr01.lga1.tfbnw.net
0.0.0.0 ae12.pr01.lhr2.tfbnw.net
0.0.0.0 ae12.pr01.mia1.tfbnw.net
0.0.0.0 ae12.pr01.ord1.tfbnw.net
0.0.0.0 ae12.pr01.sea1.tfbnw.net
0.0.0.0 ae12.pr01.sin1.tfbnw.net
0.0.0.0 ae12.pr02.atl1.tfbnw.net
0.0.0.0 ae12.pr02.sea1.tfbnw.net
0.0.0.0 ae13.bb01.atl1.tfbnw.net
0.0.0.0 ae13.bb01.lhr2.tfbnw.net
0.0.0.0 ae13.bb01.mia1.tfbnw.net
0.0.0.0 ae13.bb01.nrt1.tfbnw.net
0.0.0.0 ae13.bb01.sin1.tfbnw.net
0.0.0.0 ae13.bb02.lhr2.tfbnw.net
0.0.0.0 ae13.bb02.mia1.tfbnw.net
0.0.0.0 ae13.bb03.atn1.tfbnw.net
0.0.0.0 ae13.bb03.frc3.tfbnw.net
0.0.0.0 ae13.bb03.prn2.tfbnw.net
0.0.0.0 ae13.bb03.sjc1.tfbnw.net
0.0.0.0 ae13.bb04.atn1.tfbnw.net
0.0.0.0 ae13.bb04.frc3.tfbnw.net
0.0.0.0 ae13.bb04.prn2.tfbnw.net
0.0.0.0 ae13.bb04.sjc1.tfbnw.net
0.0.0.0 ae13.bb05.lla1.tfbnw.net
0.0.0.0 ae13.bb06.lla1.tfbnw.net
0.0.0.0 ae13.br01.mad1.tfbnw.net
0.0.0.0 ae13.br01.mxp1.tfbnw.net
0.0.0.0 ae13.br01.tpe1.tfbnw.net
0.0.0.0 ae13.br01.vie1.tfbnw.net
0.0.0.0 ae13.br02.mxp1.tfbnw.net
0.0.0.0 ae13.br02.vie1.tfbnw.net
0.0.0.0 ae13.dr01.atn1.tfbnw.net
0.0.0.0 ae13.dr01.frc1.tfbnw.net
0.0.0.0 ae13.dr02.atn1.tfbnw.net
0.0.0.0 ae13.dr02.frc1.tfbnw.net
0.0.0.0 ae13.dr03.atn1.tfbnw.net
0.0.0.0 ae13.dr03.frc1.tfbnw.net
0.0.0.0 ae13.dr04.atn1.tfbnw.net
0.0.0.0 ae13.dr04.frc1.tfbnw.net
0.0.0.0 ae13.dr05.prn1.tfbnw.net
0.0.0.0 ae13.pr01.ams2.tfbnw.net
0.0.0.0 ae13.pr01.atl1.tfbnw.net
0.0.0.0 ae13.pr01.cdg1.tfbnw.net
0.0.0.0 ae13.pr01.hkg1.tfbnw.net
0.0.0.0 ae13.pr01.iad3.tfbnw.net
0.0.0.0 ae13.pr01.lhr2.tfbnw.net
0.0.0.0 ae13.pr01.mia1.tfbnw.net
0.0.0.0 ae13.pr01.ord1.tfbnw.net
0.0.0.0 ae13.pr01.sea1.tfbnw.net
0.0.0.0 connect.facebook.net.edgekey.net
0.0.0.0 ct-m-fbx.fbsbx.com
0.0.0.0 facebook-web-clients.appspot.com
0.0.0.0 fb.me
0.0.0.0 fbcdn-profile-a.akamaihd.net
0.0.0.0 h-ct-m-fbx.fbsbx.com.online-metrix.net
0.0.0.0 sac-h-ct-m-fbx.fbsbx.com.online-metrix.net
0.0.0.0 fb.com
0.0.0.0 newsroom.fb.com
0.0.0.0 investor.fb.com
EOL"


#Lancement automatique au démarrage
vagrant ssh -c "systemctl enable systemd-resolved"
vagrant ssh -c "ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf"

#Sortie de chroot
vagrant ssh -c "exit"

#Démontage des médias
vagrant ssh -c "sudo umount -l rootfs/dev/"
vagrant ssh -c "sudo umount -l rootfs/sys/"
vagrant ssh -c "sudo umount -l rootfs/proc/"
vagrant ssh -c "sudo losetup-d $DEVICE"

#Compression de l'image et sortie de vagrant
vagrant ssh -c "xz -v 2024-07-04-raspios-bookworm-arm64.img"
vagrant ssh -c "mv *.xz /vagrant/"
vagrant ssh -c "exit "
vagrant ssh -c "logout"
vagrant ssh -c "vagrant halt -y"

Write-Host "Processus terminé."
Exit-PSHostProcess