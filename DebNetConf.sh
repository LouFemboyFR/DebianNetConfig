#!/bin/bash

# Récupérer les interfaces réseau (exclure lo)
interfaces=($(ls /sys/class/net/ | grep -v lo))

# Afficher le menu
echo "=== Choisissez une interface ==="
for i in "${!interfaces[@]}"; do
    echo "$((i+1))) ${interfaces[i]}"
done

# Demander le choix
read -p "Votre choix [1-$(( ${#interfaces[@]} ))]: " choix

# Valider le choix
interface=${interfaces[$((choix-1))]}

if [[ -z "$interface" ]]; then
    echo "Choix invalide."
    exit 1
fi

echo "=== Mode de configuration ==="
echo "1) IP statique (réseau local)"
echo "2) DHCP"
read -p "Choisissez [1-2]: " mode

case $mode in
    1)
        read -p "Adresse IP: " ip
        read -p "Masque: " netmask
        read -p "Passerelle: " gateway

        cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $interface
iface $interface inet static
    address $ip
    netmask $netmask
    gateway $gateway
EOF
        ;;
    2)
        cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto $interface
iface $interface inet dhcp
EOF
        ;;
    *)
        echo "Option invalide."
        exit 1
        ;;
esac

# Appliquer
ifdown "$interface" 2>/dev/null || true
ifup "$interface"

echo "Configuration appliquée sur $interface"   
