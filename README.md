# Projet Radar 2D – DE10-Lite

## 📝 Description du projet

Mini-projet de *Radar 2D* développé sur la carte **DE10-Lite**, utilisant un FPGA, un processeur Nios II et le bus Avalon.  
Le système intègre trois IPs personnalisées :

- **Télémètre ultrasonique (HC-SR04)** pour la mesure de distance  
- **Contrôleur de servomoteur** pour le balayage angulaire de 0° à 180°  
- **Interface UART personnalisée** pour l’exportation des données  

Le projet réalise :

- l’acquisition de distances en temps réel,  
- la cartographie 2D de l’environnement,  
- l’affichage des mesures dans le terminal Nios II,  
- et une visualisation graphique sur **VGA**, formant un micro-radar fonctionnel.

## 📁 Contenu du dépôt

- **/vhdl/** – IPs en VHDL (télémètre, servomoteur, UART)  
- **/simulation/** – Bancs de test et scripts Modelsim  
- **/software/** – Code en C pour le processeur Nios II  
- **/platform-designer/** – Intégration Avalon et système SoC-FPGA  
- **/docs/** – Captures, résultats, notes et compte-rendu du projet  

---

