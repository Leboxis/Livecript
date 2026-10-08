# Validation sur appareil

Aucun iPhone physique n'est accessible dans cet environnement. Les points suivants sont **non exécutés** ; les tests simulateur et builds CI ne les remplacent pas.

1. Installer via SideStore. Autoriser puis refuser le microphone dans Réglages et vérifier les messages.
2. Télécharger le modèle français, passer en mode avion, transcrire une minute dans chaque mode. Vérifier l'absence de serveur de reconnaissance.
3. Ajouter un nom propre dans Réglages, choisir Vocabulaire personnalisé, démarrer une nouvelle session ; vérifier la prise en compte contextuelle (non garantie mot pour mot).
4. Parler, mettre en pause, attendre, reprendre trois fois puis terminer : aucune répétition du texte provisoire, aucune capture pendant la pause.
5. Appuyer vite deux fois sur Démarrer. Pendant préparation, annuler puis refuser la permission : le microphone doit rester arrêté.
6. Recevoir un appel, changer de microphone, verrouiller l'appareil ou quitter l'application : la capture s'arrête et ne reprend pas spontanément.
7. Sauvegarder, renommer, fermer/rouvrir ; vérifier texte et titre. Copier et partager vers Notes. Supprimer une transcription avec confirmation.
8. Fermer pendant une capture et rouvrir : retrouver le dernier texte finalisé, sans activation automatique du micro.
9. Tester grande police, VoiceOver, clair/sombre, Réduire les animations et Réduire la transparence.
10. Sur iPhone ProMotion, faire défiler une longue transcription pendant capture, vérifier la réactivité et mesurer les blocages avec Instruments. Aucune garantie de 120 images/s constantes.
11. Importer le même IPA dans LiveContainer. Refaire permissions, préparation du modèle, transcription hors ligne, pause, sauvegarde et partage. Noter versions iOS/LiveContainer et erreurs éventuelles.
12. Installer une version suivante via la source SideStore et vérifier la conservation de l'historique et du vocabulaire.

Consigner pour chaque essai : appareil, iOS, mode d'installation, version Livecript et résultat. Ne pas marquer LiveContainer compatible avant ces essais.
