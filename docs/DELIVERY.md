# Vérifier ma livraison — 0.19 locale

Nino contrôle les exports avant leur envoi : un fichier oublié, une vidéo horizontale à la place d’une verticale, une durée ou un poids dépassé, une piste audio absente.

## Utilisation

1. Ouvre **Ma livraison**, ou le raccourci **Vérifier ma livraison** dans un profil créatif.
2. Pars du modèle vidéo ou visuels et adapte les noms exacts et limites au brief. Un zéro signifie « aucune limite » pour ce critère. Le brief sert de référence : il n’est pas interprété automatiquement.
3. Choisis ou dépose le dossier des exports, puis clique **Vérifier ma livraison**.
4. Consulte chaque écart, retrouve le fichier dans le Finder, corrige-le dans ton logiciel puis relance la vérification. Exporte le rapport Markdown si nécessaire.

Les critères sont enregistrés par projet, ou par profil sans projet. Les fichiers attendus doivent être directement dans le dossier choisi. Un changement de critères ou de dossier invalide le rapport. Les résultats sont datés et ne sont pas conservés après redémarrage.

## Ce qui est réellement contrôlé

- Existence, fichier non vide et poids maximal.
- Images : dimensions, avec prise en compte de l’orientation EXIF.
- Vidéos : dimensions après transformation d’orientation, durée maximale et présence d’une piste audio.
- Fichiers libres, dont SRT/PDF : présence et poids seulement.

Un média illisible ou une métadonnée indisponible apparaît **Non vérifié**, jamais comme réussi. Une modification pendant la lecture rend le contrôle incomplet. Les liens symboliques sont refusés.

Le rapport ne certifie ni la qualité visuelle, ni l’audibilité, ni la justesse des sous-titres, ni le codec demandé, ni une conformité éditoriale. Nino ne pilote pas Premiere ou DaVinci : il vérifie les fichiers que ces logiciels exportent.

## Dans l’encoche

Les profils Montage, Design, Communication et Création voient ce parcours en priorité au repos. Il devient aussi accessible dès qu’une livraison est engagée. Les actions d’appel, de transcription, de lecture et le minuteur gardent la priorité lorsqu’ils sont actifs. « Tous les outils » permet de revenir aux autres raccourcis.

Aucun transfert réseau, permission micro ou capture d’écran n’est nécessaire pour ce contrôle. Aucun export source n’est modifié.
