#!/bin/bash


# Build Envirorment
function setup_dir( ){
    echo "Setting envirorment"
    cd "$HOME"/Documents/5sites/WebDesign
    mkdir "$1"
    cp docker-compose.yml "$1"
    cd "$1"
    echo "done."
    if ! docker ps | grep "ID" -q; then
        open /Applications/Docker.app
        printf "Docker Daemon is down. Starting Docker. "
        while ! docker ps -q; do
            sleep 1
            printf ". "
        done

    elif docker ps | grep "Up" -q; then
        echo "Stopping all Containers."
        docker stop $(docker ps -q)
    fi
    printf "Docker is up!\n"

    if [ "$2" != "clean" ]; then
        # Generate Volumes form Templates
        duplicate_volume z_template_wp $1'_wp'
        duplicate_volume z_template_db $1'_db'
    fi

    echo "Building Containers"
    #docker compose up -d --workdir ./"$1" 2> /dev/null
    docker compose up -d > /dev/null

    printf "Waiting for Server "
    while ! curl -s --head --request GET http://localhost | grep "200 OK"; do
        sleep 1
        printf ". "
    done
    open http://localhost
    return 0
}

# Duplicate Volume template
function duplicate_volume () {
    #Check if the source volume name does exist
    if ! docker volume inspect $1 > /dev/null; then
        echo "The source volume \"$1\" does not exist"
        exited
    fi

    #Now check if the destinatin volume name does not yet exist
    if [ docker volume inspect $2 > /dev/null ]; then
        echo "The destination volume \"$2\" already exists"
        exit
    fi

    printf "Creating destination volume \"$2\"..."
    docker volume create --name $2
    echo "done!"

    printf "Copying data from source volume \"$1\" to destination volume \"$2\"..."
    docker run --rm \
           -i \
           -t \
           -v $1:/from \
           -v $2:/to \
           alpine ash -c "cd /from ; cp -av . /to" > /dev/null

    echo "done!"
}

function docker_stat() {
    printf "\tDOCKER VOLUMES\n"
    docker volume ls
    printf "\n\tDOCKER CONTAINERS\n"
    docker ps --format "table {{.Names}}\t\t{{.Status}}\t\t{{.ID}}" -a
}


function export_docker() {
    #get running wp container id
    idd=$(docker ps | grep wp | awk '{split($0,a," "); print a[1]}')
    docker cp $idd:/var/www/html/wp-content/uploads/prime-mover-export-files/1 /var/tmp
    scp -i ~/.ssh/id_rsa /var/tmp/1/* rodri@5sites.co:/home/rodri/docker/
    rm -r /var/tmp/1

    open https://5sites.co/wp-admin/network/site-new.php

    echo "Type in the blog id of the site for this file"
    read blog_id
    if [ $blog_id == '^[0-9]+$' ]; then
        ssh -t root@5sites.co 'bash /home/rodri/sitemod.sh $blog_id'
    else
        echo "Not a valid blog id. Opening terminal"
        echo "CMD-V in your terminal to open remote server and do this manually."
        echo ssh 5sites.co | pbcopy
    fi
    # scp /var/tmp/1/* 5sites:/data/5sites.co/wordpress/wp-content/uploads/prime-mover-export-files/docker/
    # ssh root@5sites.co -t 'chown -R www-data:www-data /data/5sites.co/wordpress/wp-content/uploads/prime-mover-export-files/docker'
}



# Cleanup
function exited() {

    if [ $1 != '' ]; then
        echo "Removing containers asociated"
        docker container rm $1'_wordpress_1'
        docker container rm $1'_db_1'
        echo "Removing volumes asociated"
        docker volume rm $1'_wp'
        docker volume rm $1'_db'

        docker_stat
    fi

    if rm -r $1 > /dev/null ; then
        echo "Cleaned envirorment."
    else
        echo "No files left to clean."
    fi

    kill -term $$
}


###
# MENU
###
function show_usage(){
    printf "Usage:\n"
    printf "\t$ newsite [site Name] \t\t Creates a new Wordpress/Mysql docker envirorment\n"

    printf "Options:\n"
    printf "\t -h,  --help   \t Prints this help\n"
    printf "\t -c,  --clean  \t Creates a new CLEAN Wordpress/Mysql docker envirorment\n"
    printf "\t -r,  --remove \t Removes a Wordpress/Mysql docker envirorment\n"
    printf "\t -s,  --status \t Shows all Docker containers and Volumes\n"

    return 0
}

while [ ! -z "$1" ]; do
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        show_usage
    elif [[ "$1" == "--remove" ]] || [[ "$1" == "-r" ]]; then
        exited $2
    elif [[ "$1" == "--export" ]] || [[ "$1" == "-e" ]]; then
        export_docker
    elif [[ "$1" == "--status" ]] || [[ "$1" == "-s" ]]; then
        docker_stat
    elif [[ "$1" == "--clean" ]] || [[ "$1" == "-c" ]]; then
        trap exited INT
        setup_dir "$2" "clean"
        kill -term $$
        shift
    elif [[ "$1" == "" ]] || [[ "$1" != "" ]]; then
        trap exited INT
        setup_dir "$1"
        kill -term $$
        shift
    else
        echo "Incorrect input provided"
        show_usage
    fi
    shift
done

