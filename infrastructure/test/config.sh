#!/bin/bash

# Lancer tous les containers
#docker-compose up -d

# Attendre quelques secondes que les services soient accessibles
#echo "[*] Attente du démarrage des services..."
#sleep 10

# Initialiser DVWA pour chaque lab
./init_dvwa.sh lab1
./init_dvwa.sh lab2
./init_dvwa.sh lab3

