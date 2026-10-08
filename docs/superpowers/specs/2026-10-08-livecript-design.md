# Livecript — Spécification de conception
Date : 8 octobre 2026
Dépôt : https://github.com/Leboxis/Livecript
Statut : conception conversationnelle approuvée ; spécification écrite à relire.

## Objectif
Application iOS 26 native en Swift et SwiftUI, minimaliste, consacrée à la transcription du microphone sur l'appareil. Elle permet de démarrer, mettre en pause, reprendre, conserver, renommer, copier et partager une transcription. Aucun compte ni service de transcription distant.

## Périmètre validé
Trois onglets : Transcrire, Historique, Réglages. Apparence claire, sombre ou système. Interfaces et messages en français ; français par défaut pour la reconnaissance, avec sélection des autres langues effectivement prises en charge sur l'appareil.
L'historique conserve du texte, pas de fichiers audio. Pas de synchronisation cloud, traduction, résumé, identification des locuteurs ou import audio dans cette première version.
Le microphone fonctionne au premier plan. Le passage en arrière-plan ou une interruption audio met la session en pause ; la reprise exige une action explicite.

## Deux modes de transcription
- Standard : SpeechAnalyzer avec SpeechTranscriber, pour la transcription continue avec résultats provisoires puis finalisés.
- Vocabulaire personnalisé : SpeechAnalyzer avec DictationTranscriber et contexte lexical, en traitement exclusivement local. Aucun repli serveur silencieux.
La documentation Apple décrit contextualStrings avec DictationTranscriber. Ne pas promettre que le vocabulaire influence SpeechTranscriber.
Les modèles et langues sont vérifiés avant capture. Une langue ou un appareil non pris en charge provoque un message explicite. L'application ne démarre pas une reconnaissance distante pour contourner cette limite.
Les modèles peuvent nécessiter un téléchargement initial depuis Apple. Une fois les ressources installées, la transcription doit fonctionner hors connexion.
Le mode et la langue sont fixés pour une session ; leur modification dans les réglages s'applique à la suivante.

## Écran Transcrire
Titre discret, grand espace de texte lisible et commandes accessibles au pouce.
À vide : invitation à parler et bouton principal Démarrer.
En capture : texte finalisé au premier plan, segment provisoire visuellement secondaire, indicateur de microphone actif, petite onde liée au niveau audio réel. L'onde indique une activité sonore, sans prétendre distinguer parfaitement voix et bruit.
Pause : microphone arrêté, texte conservé, commandes Reprendre et Terminer.
Terminer : arrêter la capture, finaliser les résultats restants avant de proposer l'enregistrement. Aucun doublon entre texte provisoire et finalisé.
Actions Copier, Partager et Enregistrer sur le texte disponible ; retour discret après copie.
Une transcription vide ne peut pas être enregistrée. Un enregistrement réussi ouvre ou met à jour une seule entrée de l'historique, sans doublon lors de taps répétés.
Un brouillon contenant du texte doit être conservé avant de lancer une nouvelle session, ou abandonné explicitement.

## Écran Historique
Liste native avec titre, date et aperçu du texte, du plus récent au plus ancien.
Détail : texte sélectionnable, actions copier et partager, renommage.
Titre initial issu des premiers mots ; titre vide refusé au renommage.
Suppression explicite avec confirmation. État vide explicatif.
Les données persistent entre lancements et mises à jour ; les migrations doivent préserver les transcriptions existantes.

## Écran Réglages
Apparence : Système, Clair, Sombre.
Langue : choix parmi les langues compatibles avec le mode sélectionné.
Mode : Standard ou Vocabulaire personnalisé, avec explication courte de leur différence.
Vocabulaire : ajout, modification et suppression de mots ou expressions courtes. Espaces périphériques supprimés, entrées vides refusées et doublons évités sans distinction de casse.
Maximum de 100 expressions actives, conformément à la recommandation Apple pour contextualStrings ; indication visible de la limite.
Les termes restent stockés lorsque le mode Standard est sélectionné. L'interface précise qu'ils s'appliquent au mode personnalisé et aux nouvelles sessions.
État des ressources linguistiques : absent, téléchargement, prêt ou erreur ; possibilité de réessayer.
Informations de confidentialité : traitement local, téléchargement initial éventuel, absence de conservation audio.

## Direction visuelle et Figma
Créer un fichier Figma dédié Livecript : trois écrans en clair et sombre, plus états de capture, pause, préparation et erreur.
Utiliser les composants natifs SwiftUI pour navigation, onglets, listes et partage. Les barres et contrôles adoptent Liquid Glass sur iOS 26.
Palette sémantique, fonds neutres, une couleur d'accent sobre, icônes SF Symbols, typographie système. Aucun décor occupant l'espace de lecture.
Espacement de référence : 8, 16, 24 et 32 points. Cibles tactiles d'au moins 44 points. Texte dynamique et VoiceOver pris en charge.
Animations brèves, environ 150 à 250 ms, interrompables. Respecter Réduire les animations et Réduire la transparence.
Objectif : sensation fluide sur ProMotion. Ne pas garantir 120 images/s constants : fréquence pilotée par le système et dépendante du matériel, de l'énergie et de la charge.

## Architecture
Une application SwiftUI, sans backend ni dépendance tierce pour la transcription.
- Interface : vues SwiftUI séparant transcription, historique, détail, réglages et indicateur audio.
- Session : état observable et orchestration des actions, sérialisation des transitions pour éviter plusieurs captures simultanées.
- Audio et reconnaissance : AVAudioSession et AVAudioEngine alimentent SpeechAnalyzer ; conversion vers un format accepté par le module ; résultats consommés de manière asynchrone.
- Persistance : SwiftData pour transcriptions et vocabulaire ; préférences simples pour thème, langue et mode.
L'analyse, la conversion audio et les écritures ne doivent pas bloquer l'interface. Les mises à jour rapides du niveau sonore sont limitées à leur petite vue.
États : prêt, préparation, capture, pause, finalisation et erreur. Un échec interrompt proprement le microphone et préserve le texte disponible.
La pause finalise le segment courant ; la reprise crée un nouveau segment ajouté à la même transcription pour éviter pertes et ambiguïtés temporelles.
Libérer tâches, flux et ressources à l'arrêt. Gérer refus de microphone, modèle absent, échec de téléchargement, interruption, changement de route audio et erreur de stockage.
Sauvegarder progressivement le texte finalisé comme brouillon récupérable. Ne pas remplacer les données persistées par un état vide lorsqu'une lecture échoue.

## Données
Transcription : identifiant stable, titre, dates de création et modification, texte finalisé, langue, mode.
Brouillon : identifiant de session, texte finalisé, langue et mode ; récupérable après relancement, sans reprise automatique du microphone.
Terme : identifiant stable et expression.
Aucun contenu de transcription ni audio dans les journaux de diagnostic. Pas d'analytique distante.

## Compilation et distribution
Identifiant de bundle prévu : com.leboxis.livecript ; version initiale prévue : 1.0.0.
Projet Xcode ciblant iOS 26, compilation appareil arm64 avec un SDK iOS 26 ou ultérieur compatible, et configuration de test simulateur.
GitHub Actions sur macOS compile, teste et assemble l'application dans Payload/Livecript.app pour produire Livecript.ipa destiné à la signature par l'outil de sideload.
Ne pas présenter un ZIP de sources comme un IPA. Un IPA n'est déclaré livré qu'après compilation réussie et présence de l'artefact.
Les versions de distribution sont attachées à des GitHub Releases ; les builds de validation restent des artefacts Actions.
Une source JSON SideStore référence les IPA de release avec identifiant stable, version, date, taille réelle, URL, iOS minimum, description, icône et déclarations de permissions nécessaires au schéma utilisé.
Générer les métadonnées depuis l'artefact effectivement produit. Publier la nouvelle entrée seulement après disponibilité de son IPA ; conserver les versions antérieures. Fournir une URL de source stable et accessible sans authentification.
Vérifier le schéma SideStore applicable pendant l'implémentation. Les mises à jour restent installées via SideStore, sans mécanisme de mise à jour exécutable interne à l'app.
LiveContainer : même IPA comme cible initiale, sans modification de LiveContainer. Vérifier en conditions réelles microphone, disponibilité des modules Speech, ressources linguistiques, persistance et partage. Documenter honnêtement tout blocage propre à l'hôte.
L'environnement de préparation actuel est Linux sans Xcode ; les builds iOS devront être exécutés sur le runner macOS.

## Vérification et critères de livraison
Tests ciblés : accumulation des résultats sans duplication, pause/reprise et finalisation, transitions concurrentes, validation du vocabulaire, persistance et renommage, métadonnées de source JSON.
Compiler pour simulateur et appareil dans GitHub Actions et examiner les résultats.
Essais iPhone requis : refus puis autorisation du microphone, téléchargement initial, mode avion après installation des modèles, transcription dans les deux modes, pause/reprise répétée, interruption, sauvegarde et relancement, copie et partage.
Essais visuels : clair/sombre, grande taille de texte, VoiceOver, réduction des animations, défilement pendant la capture.
Évaluer la fluidité sur appareil ProMotion ; une compilation réussie seule ne valide ni 120 Hz ni la qualité de transcription.
Installer l'IPA via SideStore et LiveContainer, puis tester une mise à jour conservant les transcriptions. Si ces appareils ne sont pas accessibles, livrer une procédure et identifier ces validations comme non exécutées.
Livrables : sources dans Livecript, fichier Figma, projet compilable, workflow de build/release, IPA compilé, source JSON hébergée et instructions d'installation. Distinguer explicitement livrables produits, tests exécutés et validations restantes.

## Références techniques consultées
- Apple, SpeechAnalyzer et exemple WWDC25 : https://developer.apple.com/videos/play/wwdc2025/277/
- Apple, contextualStrings : https://developer.apple.com/documentation/speech/analysiscontext/contextualstrings
- Apple, DictationTranscriber : https://developer.apple.com/documentation/speech/dictationtranscriber
- SideStore, sources : https://docs.sidestore.io/docs/advanced/app-sources
