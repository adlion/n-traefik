#!/bin/bash

#Traefik variables
PING_PORT="8080"
HTTP_PORT="80"
HTTP_ENTRYPOINT="web"
HTTPS_PORT="443"
HTTPS_ENTRYPOINT="web-secure"
HOST_DOMAIN="localhost"
PING_ENTRYPOINT_NAME="traefik-ping"
LOG_LEVEL="DEBUG"

# Docker variables
TRAEFIK_IMAGE_NAME="traefik"
TRAEFIK_SERVICE_NAME="traefik"
DASHBOARD_PATH="dashboard"
DOCKER_TRAEFIK_NETWORK="traefik-default"

# Configuration variables
PATH_TO_MIDDLEWARE=""
PATH_TO_CERTIFICATES=""
CERTIFICATE_BASE_NAME=""

#Default is only to build the image without running it
SELECTED_MODE="1"

#Dashboard Credentials
DASHBOARD_USERNAME="jenkins"
DASHBOARD_PASSWORD="jenkins"

TMP_INPUT=""
INPUT_VALIDATION_REGEX='[a-zA-Z0-9\-\_]';

#Check whether root
if [ "$(whoami)" != root ]; then
    echo " You must run this script as root in the remote host"
    exit 1
fi

function echo_manual (){
       
    read -p "Domain name.(This domain will be added as new entry at localhost. Should be the same that you generated the certificates.): " TMP_INPUT
    check_input HOST_DOMAIN
    
    read -p "Path to certificates folder.[ENTER] to skip step: " TMP_INPUT
    check_input PATH_TO_CERTIFICATES
    
    read -p "Base name of certificate. (Only name without prefix).[ENTER] to skip step: " TMP_INPUT
    check_input CERTIFICATE_BASE_NAME
    
    read -p "Path to middleware file. [ENTER] to skip step:" TMP_INPUT
    check_input PATH_TO_MIDDLEWARE
    
    read -p "Traefik Ping Port (Default 8080): " TMP_INPUT
    check_input PING_PORT
    
    read -p "Traefik Ping entry point name. (Default \"traefik-ping\"): " TMP_INPUT
    check_input PING_ENTRYPOINT_NAME
    
    read -p "Http Port. (Default 80): " TMP_INPUT
    check_input HTTP_PORT
    
    read -p "Https Port. (Default 443): " TMP_INPUT
    check_input HTTPS_PORT
    
    read -p "Http network name. (Default \"web\"): " TMP_INPUT
    check_input HTTP_ENTRYPOINT
    HTTPS_ENTRYPOINT="${HTTP_ENTRYPOINT}-secure"
    
    read -p "Traefik Image name. (Default \"traefik\"): " TMP_INPUT
    check_input TRAEFIK_IMAGE_NAME
    
    read -p "Traefik service name that will be used when running from docker compose. (Default \"traefik\"): " TMP_INPUT
    check_input TRAEFIK_SERVICE_NAME
    
    read -p "Docker newtork name that traefik should connect. Default (\"traefik-default\"): " TMP_INPUT
    check_input DOCKER_TRAEFIK_NETWORK
    
    copy_configurations
    variable_substitution
    install_requirements
    rm ./traefik/dashboard_credentials 2> /dev/null && touch ./traefik/dashboard_credentials  && chown  $SUDO_USER:$SUDO_USER ./traefik/dashboard_credentials
    
    dashboard_credentials
    check_docker_requirements
    change_hosts
}

function dashboard_credentials(){
    
    read -p "Enter a username for traefik dashboard: " TMP_INPUT
    check_input DASHBOARD_USERNAME
    
    htpasswd -nBC 10 $DASHBOARD_USERNAME >>./traefik/dashboard_credentials
    echo
    echo_blue "Do you want to add more users [y|N]:"
    read user_answer
    
    case "$user_answer" in
        y |Y |yes )
            dashboard_credentials
        ;;
    esac
    
}

function check_input(){
    if [[ "$TMP_INPUT" =~ $INPUT_VALIDATION_REGEX ]]; then
        eval $1=$TMP_INPUT
        echo
    else
        echo_blue "Using Default value.$TMP_INPUT "
        echo
    fi
}

function install_requirements(){
    echo_yellow "Installing required dependencies"
    apt install apache2-utils -y
}

function change_hosts(){
    echo_blue "Adding ${HOST_DOMAIN} to hosts."
    declare file_content=$( cat /etc/hosts )
    declare regex="\s+$HOST_DOMAIN\s+"
    declare host_entry="127.0.0.1    $HOST_DOMAIN"
    if [[ " $file_content " =~ $regex ]]; then
        echo_blue "Host entry found. Skipping adding new entry to hosts"
        echo
    else
        sed "3 a$host_entry " /etc/hosts >> ./tmp_hosts
        mv ./tmp_hosts /etc/hosts
        echo_red_slim "Added ${HOST_DOMAIN} to hosts file."
        echo
    fi
}

function entyrpoint (){
    echo
    echo
    initialize_colors
    echo_yellow "Please follow the instructions to build and run traefik at your localmachine."
    echo_yellow "In order to get a valid certificate for your host please generate one manually or get one from: https://seinopsys.dev/selfsigned"
    echo_red "Please do not run this on production. This is a quick and dirty way of setting up and running containers and exposing them using Traefik."
    echo
    echo

    echo "Enter the option to build ,run traefik and press [ENTER]: "
    echo_blue "    0. Build and run Traefik."
    echo_blue "    1. Only build Traefik."
    echo_blue "    2. Only run Traefik."
    read SELECTED_MODE
    
    echo
    if [[ "$SELECTED_MODE" =~ [0-9] ]]; then
        echo
    else
        echo_blue "Building and running Traefik."
        SELECTED_MODE=1
        echo
    fi

    case "$SELECTED_MODE" in
        0 )
            echo_manual
            echo_yellow "----------------------- Building and running Traefik -----------------------"
            build_traefik
            deploy_traefik
        ;;
        1 )
            echo_manual
            echo_yellow "----------------------- Building Traefik Image -----------------------"
            build_traefik
        ;;
        2 )
            echo_yellow "----------------------- Running Traefik -----------------------"
            deploy_traefik
        ;;
        *)
            echo_red "Option $1 not known"
        ;;
        
    esac
}

#Copying the certificates and the middleware configurations
function copy_configurations() {
    
    if [[ $PATH_TO_MIDDLEWARE != ""  && ! -f $PATH_TO_MIDDLEWARE ]]; then
        cp $PATH_TO_MIDDLEWARE ./traefik/
        echo
    fi
    
    if [[ $PATH_TO_CERTIFICATES != "" && ! -f $PATH_TO_CERTIFICATES ]]; then
        cp $PATH_TO_CERTIFICATES/* ./traefik/certs/
        echo
    fi
    
}

function variable_substitution() {
    
    echo_yellow "Updating traefik configuration files"
    
    sed -i -e "s/PING_ENTRYPOINT_NAME/$PING_ENTRYPOINT_NAME/g" ./traefik/traefik.yml
    sed -i -e "s/PING_PORT/$PING_PORT/g" ./traefik/traefik.yml
    sed -i -e "s/HTTP_PORT/$HTTP_PORT/g" ./traefik/traefik.yml
    sed -i -e "s/HTTP_ENTRYPOINT/$HTTP_ENTRYPOINT/g" ./traefik/traefik.yml
    sed -i -e "s/HTTPS_PORT/$HTTPS_PORT/g" ./traefik/traefik.yml
    sed -i -e "s/HTTPS_ENTRYPOINT/$HTTPS_ENTRYPOINT/g" ./traefik/traefik.yml
    sed -i -e "s/HOST_DOMAIN/$HOST_DOMAIN/g" ./traefik/traefik.yml
    sed -i -e "s/LOG_LEVEL/$LOG_LEVEL/g" ./traefik/traefik.yml
    sed -i -e "s/TRAEFIK_IMAGE_NAME/$TRAEFIK_IMAGE_NAME/g" ./docker-compose.yml
    sed -i -e "s/TRAEFIK_IMAGE_NAME/$TRAEFIK_IMAGE_NAME/g" ./docker-compose.yml
    sed -i -e "s/DASHBOARD_PATH/$DASHBOARD_PATH/g" ./docker-compose.yml
    sed -i -e "s/HOST_DOMAIN/$HOST_DOMAIN/g" ./docker-compose.yml
    sed -i -e "s/DOCKER_TRAEFIK_NETWORK/$DOCKER_TRAEFIK_NETWORK/g" ./docker-compose.yml
    sed -i -e "s/TRAEFIK_SERVICE_NAME/$TRAEFIK_SERVICE_NAME/g" ./docker-compose.yml
    sed -i -e "s/HTTPS_ENTRYPOINT/$HTTPS_ENTRYPOINT/g" ./docker-compose.yml

}

function build_traefik() {
    docker build -t $TRAEFIK_IMAGE_NAME --progress=plain .
}

function deploy_traefik() {
    docker-compose up -d

    echo_green "To check if Traefik is running open on you browser https://${HOST_DOMAIN}/dashboard"
    echo_red "If after some time you want to change some configurations of traefik is better to download a fresh copy. "
    echo_red "Durng setup time the script will update docker-compose ,traefik.yml,the hosts file at /etc/hosts,and will create an external network if not exist and also uodate it at docker-compose"
}

function check_docker_requirements() {
    docker_traefik_network=$(docker network ls --format '{{.Name}}')
    docker_newtork_exist=0
    
    for el in $docker_traefik_network
    do
        if [[ $el == $DOCKER_TRAEFIK_NETWORK ]]; then
            docker_newtork_exist=1
        else
            docker_newtork_exist=0
        fi
    done

    if [[ $docker_newtork_exist == 0 ]]; then
            echo_red_slim "Docker network not found. Creating network."
            docker network create $DOCKER_TRAEFIK_NETWORK
    else
            echo_green "Docker network found. Skipping network creation."
    fi
}

#Canalize the echo functions
function last_echo() {
    echo -e "${2}$*${normal_color}"
}

#Initialize colors vars
function initialize_colors() {
    normal_color="\e[1;0m"
    green_color="\033[1;32m"
    green_color_title="\033[0;32m"
    red_color="\033[1;31m"
    red_color_slim="\033[0;031m"
    blue_color="\033[1;34m"
    cyan_color="\033[1;36m"
    brown_color="\033[0;33m"
    yellow_color="\033[1;33m"
    pink_color="\033[1;35m"
    white_color="\e[1;97m"
}


#Print green messages
function echo_green() {
    last_echo "${1}" "${green_color}"
}

#Print blue messages
function echo_blue() {
    last_echo "${1}" "${blue_color}"
}

#Print yellow messages
function echo_yellow() {
    last_echo "${1}" "${yellow_color}"
}

#Print red messages
function echo_red() {
    last_echo "${1}" "${red_color}"
}

#Print red messages using a slimmer thickness
function echo_red_slim() {
    last_echo "${1}" "${red_color_slim}"
}

#Print black messages with background for titles
function echo_green_title() {
    last_echo "${1}" "${green_color_title}"
}

#Print pink messages
function echo_pink() {
    last_echo "${1}" "${pink_color}"
}

#Print cyan messages
function echo_cyan() {
    last_echo "${1}" "${cyan_color}"
}

#Print brown messages
function echo_brown() {
    last_echo "${1}" "${brown_color}"
}

#Print white messages
function echo_white() {
    last_echo "${1}" "${white_color}"
}


entyrpoint