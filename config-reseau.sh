#!/bin/bash

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté avec sudo ou en tant que root"
   exit 1
fi

# Fonction pour afficher la configuration actuelle
show_current_config() {
    echo "============================================"
    echo "CONFIGURATION RÉSEAU ACTUELLE"
    echo "============================================"
    ip -br addr show | grep -v "lo"
    echo ""
    echo "Fichiers de configuration existants:"
    ls -1 /etc/network/interfaces.d/ 2>/dev/null || echo "Aucun fichier de configuration trouvé"
    echo "============================================"
    echo ""
}

# Fonction pour lister les interfaces réseau actives
list_interfaces() {
    ip link show | awk -F': ' '/^[0-9]+:/ && !/lo:/ {print $2}' | sed 's/@.*//'
}

# Fonction pour sélectionner une interface
select_interface() {
    local interfaces=($(list_interfaces))
    
    if [[ ${#interfaces[@]} -eq 0 ]]; then
        echo "Aucune interface réseau trouvée!"
        exit 1
    fi
    
    echo "Interfaces réseau disponibles:"
    PS3="Choisissez une interface (numéro): "
    select interface in "${interfaces[@]}" "Annuler"; do
        if [[ "$interface" == "Annuler" ]]; then
            return 1
        elif [[ -n "$interface" ]]; then
            echo "$interface"
            return 0
        else
            echo "Choix invalide, réessayez."
        fi
    done
}

# Fonction pour obtenir une saisie non vide
get_non_empty_input() {
    local prompt="$1"
    local input
    while true; do
        read -p "$prompt: " input
        if [[ -n "$input" ]]; then
            echo "$input"
            return 0
        else
            echo "Ce champ ne peut pas être vide."
        fi
    done
}

# Fonction pour valider une adresse IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Fonction de configuration DHCP
configure_dhcp() {
    echo ""
    echo "=== CONFIGURATION DHCP ==="
    
    INTERFACE=$(select_interface)
    [[ $? -ne 0 ]] && return 1
    
    echo ""
    echo "Configuration qui sera appliquée:"
    echo "  Interface: $INTERFACE"
    echo "  Mode: DHCP"
    echo ""
    
    read -p "Confirmer la configuration? (o/n): " confirm
    if [[ ! "$confirm" =~ ^[Oo]$ ]]; then
        echo "Configuration annulée."
        return 1
    fi
    
    # Création du fichier de configuration
    cat <<EOF > "/etc/network/interfaces.d/$INTERFACE"
# Configuration DHCP générée automatiquement
auto $INTERFACE
iface $INTERFACE inet dhcp
EOF
    
    echo "Configuration DHCP créée pour $INTERFACE"
    return 0
}

# Fonction de configuration IP statique
configure_static() {
    echo ""
    echo "=== CONFIGURATION IP STATIQUE ==="
    
    INTERFACE=$(select_interface)
    [[ $? -ne 0 ]] && return 1
    
    echo ""
    while true; do
        ADDRESS=$(get_non_empty_input "Adresse IP")
        if validate_ip "$ADDRESS"; then
            break
        else
            echo "Format d'adresse IP invalide. Format attendu: xxx.xxx.xxx.xxx"
        fi
    done
    
    while true; do
        NETMASK=$(get_non_empty_input "Masque de sous-réseau (ex: 255.255.255.0)")
        if validate_ip "$NETMASK"; then
            break
        else
            echo "Format de masque invalide."
        fi
    done
    
    GATEWAY=$(get_non_empty_input "Passerelle par défaut")
    
    echo ""
    echo "Configuration qui sera appliquée:"
    echo "  Interface: $INTERFACE"
    echo "  Mode: IP Statique"
    echo "  Adresse: $ADDRESS"
    echo "  Masque: $NETMASK"
    echo "  Passerelle: $GATEWAY"
    echo ""
    
    read -p "Confirmer la configuration? (o/n): " confirm
    if [[ ! "$confirm" =~ ^[Oo]$ ]]; then
        echo "Configuration annulée."
        return 1
    fi
    
    # Création du fichier de configuration
    cat <<EOF > "/etc/network/interfaces.d/$INTERFACE"
# Configuration IP statique générée automatiquement
auto $INTERFACE
iface $INTERFACE inet static
    address $ADDRESS
    netmask $NETMASK
    gateway $GATEWAY
EOF
    
    echo "Configuration IP statique créée pour $INTERFACE"
    return 0
}

# Fonction pour redémarrer le réseau
restart_network() {
    echo ""
    echo "Redémarrage du service réseau..."
    
    systemctl restart networking
    sleep 2
    
    echo ""
    echo "Nouvelle configuration:"
    ip -br addr show | grep -v "lo"
    echo ""
    echo "Service réseau redémarré avec succès."
}

# Script principal
clear
echo "╔════════════════════════════════════════════╗"
echo "║  CONFIGURATION RÉSEAU DEBIAN               ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Afficher la configuration actuelle
show_current_config

while true; do
    echo ""
    echo "Choisissez le type de configuration:"
    PS3="Votre choix: "
    options=("DHCP (configuration automatique)" "IP Statique (pour console EOS/OLA)" "Quitter")
    
    select opt in "${options[@]}"; do
        case $REPLY in
            1)
                configure_dhcp
                config_result=$?
                break
                ;;
            2)
                configure_static
                config_result=$?
                break
                ;;
            3)
                echo "Au revoir!"
                exit 0
                ;;
            *)
                echo "Choix invalide, réessayez."
                ;;
        esac
    done
    
    # Si la configuration a été validée, redémarrer le réseau
    if [[ $config_result -eq 0 ]]; then
        echo ""
        read -p "Appliquer la configuration maintenant? (o/n): " apply
        if [[ "$apply" =~ ^[Oo]$ ]]; then
            restart_network
        else
            echo "Configuration enregistrée. Redémarrez le réseau avec: sudo systemctl restart networking"
        fi
    fi
    
    echo ""
    read -p "Configurer une autre interface? (o/n): " again
    if [[ ! "$again" =~ ^[Oo]$ ]]; then
        echo "Au revoir!"
        exit 0
    fi
    
    # Réafficher la config actuelle
    show_current_config
done
