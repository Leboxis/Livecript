# Livecript Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking. Le choix du mode d'exécution appartient à l'utilisateur.

**Goal:** Livrer l'application native Livecript, ses maquettes Figma, un IPA compilé et une source SideStore permettant les mises à jour.
**Architecture:** SwiftUI présente une session observable ; un service audio et Speech fournit des événements asynchrones ; SwiftData conserve transcriptions, brouillons et vocabulaire. Deux modules Apple sont sélectionnables sans repli réseau pour la reconnaissance. GitHub Actions macOS compile et publie les artefacts.
**Tech Stack:** Swift, SwiftUI, SwiftData, AVFoundation, Speech, Xcode/SDK iOS 26, Swift Testing, GitHub Actions, Python standard pour empaquetage et source JSON.
**Spec:** ../specs/2026-10-08-livecript-design.md — approuvée par l'utilisateur le 8 octobre 2026.

## Global Constraints
- Trois onglets : Transcrire, Historique, Réglages. Apparence claire, sombre ou système.
- L'historique conserve du texte, pas de fichiers audio.
- Le microphone fonctionne au premier plan.
- Standard : SpeechAnalyzer avec SpeechTranscriber.
- Vocabulaire personnalisé : SpeechAnalyzer avec DictationTranscriber et contexte lexical, en traitement exclusivement local. Aucun repli serveur silencieux.
- Maximum de 100 expressions actives.
- Espacement de référence : 8, 16, 24 et 32 points. Cibles tactiles d'au moins 44 points.
- Animations brèves, environ 150 à 250 ms, interrompables.
- Identifiant de bundle prévu : com.leboxis.livecript ; version initiale prévue : 1.0.0.
- Les modèles peuvent nécessiter un téléchargement initial depuis Apple.
- Aucun contenu de transcription ni audio dans les journaux de diagnostic. Pas d'analytique distante.
- L'environnement de préparation actuel est Linux sans Xcode ; les builds iOS devront être exécutés sur le runner macOS.
- Ne déclarer un IPA livré qu'après compilation réussie et vérification de l'artefact ; tests appareil explicitement séparés.

## Review Focus
1. Double tap ou interruption pendant la préparation : une seule capture, aucune reprise après annulation ; tâche 4.
2. Résultat final reçu après pause : conserver chaque mot une fois, ne pas ajouter un ancien segment à une nouvelle session ; tâches 2 et 4.
3. Échec de sauvegarde ou fermeture : garder le brouillon et signaler l'erreur, ne pas annoncer un enregistrement réussi ; tâche 3.
4. Modèle non installé en mode avion : message récupérable et aucun repli serveur ; tâches 4 et 5.
5. Release incomplète ou réexécutée : source inchangée en cas d'échec, pas de version dupliquée ; tâche 7.

## Carte des fichiers
- Livecript.xcodeproj/project.pbxproj et xcshareddata/xcschemes/Livecript.xcscheme : projet et schéma partagés.
- Livecript/App/LivecriptApp.swift, RootView.swift, AppPreferences.swift : composition et préférences.
- Livecript/Transcription/TranscriptTypes.swift, TranscriptAccumulator.swift, SpeechService.swift, AppleSpeechService.swift, MicrophoneCapture.swift, TranscriptionSession.swift : données de flux, capture et cycle de session.
- Livecript/Storage/Models.swift, TranscriptStore.swift, VocabularyRules.swift : schéma versionné et persistance.
- Livecript/Views/TranscribeView.swift, HistoryView.swift, TranscriptDetailView.swift, SettingsView.swift, AudioLevelView.swift : interface.
- Livecript/Resources/Info.plist, Assets.xcassets : permissions, ressources et icône.
- LivecriptTests/ : tests des invariants de texte, de stockage et de session.
- scripts/ci-test.sh, package_ipa.py, generate_source.py et scripts/tests/ : vérification et distribution.
- .github/workflows/build.yml, release.yml : CI et publication.
- distribution/source.json, icon.png : catalogue généré et icône publiée.
- docs/design.md, docs/device-validation.md, README.md : lien Figma, validation réelle et installation.

## Tâche 1 — Maquettes et projet iOS compilable
**Interfaces :** produit le schéma Livecript et RootView ; trois onglets et préférences theme: AppTheme, localeIdentifier: String, mode: RecognitionMode. AppTheme = system/light/dark ; RecognitionMode = standard/customVocabulary.
**Fichiers :** projet Xcode, App/*, Resources/*, docs/design.md, scripts/ci-test.sh, .github/workflows/build.yml, .gitignore.

- [ ] Lire les skills Figma create-new-file, use et generate-design avant les opérations correspondantes ; créer les trois écrans clair/sombre et états capture/pause/préparation/erreur, à partir de la spécification approuvée.
- [ ] Inspecter les rendus Figma ; vérifier textes, contrastes, marges 8/16/24/32, cibles 44 points et éléments natifs ; consigner URL et correspondances SwiftUI dans docs/design.md.
- [ ] Vérifier SDK et runner macOS disponibles dans les références officielles ; créer le projet iOS 26 arm64 et schéma partagé Livecript, avec cible LivecriptTests.
- [ ] Créer l'entrée SwiftUI, TabView et préférences persistées ; français par défaut, thème système, mode standard ; inclure les permissions nécessaires effectivement utilisées et l'icône.
- [ ] Écrire scripts/ci-test.sh : sélectionner un simulateur iPhone disponible sous iOS 26 ou ultérieur, lancer xcodebuild test, retourner un code non nul en cas d'échec et conserver le xcresult.
- [ ] Configurer build.yml pour les branches de travail et PR : exécuter ce script puis xcodebuild -project Livecript.xcodeproj -scheme Livecript -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO build.
- [ ] Exécuter la CI : les deux commandes doivent réussir ; ne pas remplacer ce contrôle par une vérification syntaxique Linux.
- [ ] Commit : chore: bootstrap native iOS app and macOS build verification.

## Tâche 2 — Accumulation fiable des résultats
**Fichiers :** TranscriptTypes.swift, TranscriptAccumulator.swift, LivecriptTests/TranscriptAccumulatorTests.swift.
**Interfaces :** RecognitionConfiguration(localeIdentifier: String, mode: RecognitionMode, vocabulary: [String]); TranscriptEvent(segmentID: UUID, text: String, isFinal: Bool). TranscriptAccumulator.beginSegment(id: UUID), receive(_ event: TranscriptEvent), finalText: String, provisionalText: String, displayText: String.
Le service émet les résultats dans l'ordre Apple ; une finale correspond au résultat provisoire courant et le remplace. Une identité de segment protège contre les anciennes sessions.

- [ ] Écrire les tests suivants avec Swift Testing : provisionalReplacement donne "Bonjour tout le monde" après deux hypothèses puis une finale, jamais leur concaténation ; newSegmentAppend conserve "Bonjour." et ajoute "Bonsoir." ; staleSegmentIgnored conserve le texte après réception d'un événement d'un ancien UUID ; emptyFinalClearsProvisional ne crée pas de mot.
- [ ] Exécuter scripts/ci-test.sh sur macOS ; constater l'échec lié à l'absence de l'accumulateur.
- [ ] Implémenter l'accumulateur sans dépendance Speech ; joindre les segments avec un seul séparateur approprié et préserver ponctuation et contenu Unicode.
- [ ] Relancer les tests ; tous doivent passer, incluant "l’été" et emoji sans corruption.
- [ ] Commit : feat: accumulate speech results without provisional duplicates.

## Tâche 3 — Historique, brouillons et vocabulaire persistants
**Fichiers :** Storage/*, LivecriptTests/TranscriptStoreTests.swift, VocabularyRulesTests.swift.
**Interfaces :** StoredTranscript et StoredDraft comportent id, text, localeIdentifier, mode ; StoredTranscript ajoute title, createdAt, updatedAt. VocabularyTerm comporte id et phrase.
TranscriptStore actor : saveDraft(_ draft: DraftSnapshot) async throws ; loadDraft() async throws -> DraftSnapshot? ; saveTranscript(_ draft: DraftSnapshot) async throws -> UUID ; transcripts() async throws -> [TranscriptSnapshot] ; rename(id: UUID, title: String) async throws ; delete(id: UUID) async throws ; discardDraft() async throws ; vocabulary() async throws -> [VocabularyEntry] ; setVocabulary(_ entries: [VocabularyEntry]) async throws.
DraftSnapshot(id: UUID, text: String, localeIdentifier: String, mode: RecognitionMode). TranscriptSnapshot ajoute title, createdAt, updatedAt. VocabularyEntry(id: UUID, phrase: String).
VocabularyRules.normalized(_ phrase: String, existing: [String], replacing: String? = nil) throws -> String ; validation du total lors de setVocabulary.

- [ ] Écrire tests : whitespaceOnlyRejected, caseInsensitiveDuplicateRejected, hundredTermsAcceptedAnd101Rejected, editAtCapacityAllowed, repeatedSaveSameIDCreatesOneRecord, blankRenameRejected, reopenedStoreRetainsTranscriptAndDraft.
- [ ] Ajouter un test d'échec d'écriture injecté : saveTranscript lance une erreur, aucune réussite signalée, brouillon précédent conservé.
- [ ] Exécuter les tests pour constater les échecs attendus.
- [ ] Définir le schéma SwiftData versionné V1 et modèle de migration ; implémenter le store avec contexte isolé, commits atomiques et snapshots Sendable. Les écritures de brouillon sont sérialisées.
- [ ] Un enregistrement d'historique utilise l'identité du brouillon, et ne supprime le brouillon qu'après réussite de la transaction. À la lecture, propager les erreurs au lieu de recréer un stockage vide.
- [ ] Relancer scripts/ci-test.sh ; tests verts avec conteneur temporaire sur disque pour le relancement.
- [ ] Commit : feat: persist transcripts drafts and validated vocabulary.

## Tâche 4 — Microphone et deux moteurs Apple locaux
**Fichiers :** SpeechService.swift, AppleSpeechService.swift, MicrophoneCapture.swift, TranscriptionSession.swift ; LivecriptTests/TranscriptionSessionTests.swift, SpeechConfigurationTests.swift.
**Interfaces :** SpeechService protocol : supportedLocales(mode: RecognitionMode) async -> [String] ; prepare(_ configuration: RecognitionConfiguration) async throws ; start(segmentID: UUID) async throws -> AsyncThrowingStream<SpeechEvent, Error> ; finish() async throws ; cancel() async.
SpeechEvent = transcript(TranscriptEvent), level(Float), interrupted. prepare installe les ressources nécessaires avant toute capture ; finish arrête l'entrée, finalise puis termine le flux ; cancel arrête et termine sans reprise.
TranscriptionSession @MainActor @Observable : state: SessionState, finalText, provisionalText, errorMessage: String?, start(configuration:) async, pause() async, resume() async, finish() async, save() async throws -> UUID, discard() async throws. Injecter SpeechService et TranscriptStore ; réserver un canal observable de niveau audio distinct pour éviter de rafraîchir toute la vue.
SessionState = ready/preparing/recording/paused/finalizing/failed. SpeechConfigurationPolicy produit les paramètres du module et interdit explicitement toute option de reconnaissance serveur.

- [ ] Vérifier dans la documentation Apple les signatures disponibles avec le SDK choisi : SpeechTranscriber, DictationTranscriber, contexte lexical, options locales, ressources, finalisation et conversion de buffers. Consigner ces choix sans inventer une API ; valider la compilation des deux adaptateurs.
- [ ] Écrire des tests avec faux SpeechService : doubleStartStartsOnce, cancelDuringPrepareNeverStartsMicrophone, pauseDrainsFinalBeforeResuming, interruptionPausesWithoutAutoResume, finishFailureKeepsDraft, changedSettingsDoNotMutateActiveConfiguration.
- [ ] Tester la politique : customModePassesVocabulary ; standardModeOmitsVocabulary ; bothModesDisallowServer ; offlineMissingModelFailsBeforeCapture.
- [ ] Constater les échecs puis implémenter la machine d'état et ses protections contre réentrance ; chaque reprise garde l'identité du brouillon mais renouvelle celle du segment.
- [ ] Implémenter AVAudioSession et AVAudioEngine ; copier les buffers dont la durée de vie serait insuffisante, convertir hors thread UI et transmettre à SpeechAnalyzer. Calculer un niveau RMS normalisé et limiter ses notifications ; si le consommateur ne suit pas, terminer proprement avec erreur plutôt qu'accumuler indéfiniment ou perdre silencieusement l'audio.
- [ ] Implémenter installation des ressources avec progression et annulation ; configurer le module local sélectionné et contextualStrings uniquement pour le mode personnalisé. Fournir au réglage ResourceState = absent/downloading(Double)/ready/failed(String) via un modèle observable séparé.
- [ ] Relier autorisations, interruptions et changement de route ; stopper le microphone avant finalisation. En cas de refus, afficher une action ouvrant les réglages système.
- [ ] Persister les résultats finalisés via le store, en regroupant les écritures fréquentes et en vidant la file avant pause/enregistrement ; récupérer le brouillon en pause au relancement.
- [ ] Exécuter les tests et les builds simulateur/appareil ; contrôler les erreurs de concurrence Swift et l'absence d'audio écrit sur disque.
- [ ] Commit : feat: transcribe microphone locally with pause and recovery.

## Tâche 5 — Interface de transcription et réglages
**Fichiers :** TranscribeView.swift, SettingsView.swift, AudioLevelView.swift, App/RootView.swift.
**Interfaces :** vues consomment TranscriptionSession, préférences, TranscriptStore et état des ressources définis ci-dessus ; les réglages n'altèrent pas RecognitionConfiguration déjà capturée.

- [ ] Implémenter l'écran Transcrire selon Figma : placeholder, texte sélectionnable, hypothèse secondaire, onde audio réelle, commandes Démarrer/Pause/Reprendre/Terminer selon l'état.
- [ ] Désactiver les actions incompatibles pendant préparation/finalisation ; protéger la nouvelle session par sauvegarde ou abandon explicite du brouillon.
- [ ] Ajouter copie via presse-papiers et partage natif du texte ; afficher la réussite uniquement après l'action ; enregistrer uniquement le texte finalisé non vide.
- [ ] Implémenter Réglages : thème, langue compatible, mode, CRUD du vocabulaire avec compteur /100, préparation du modèle et reprise après erreur. Présenter l'explication locale et l'application des changements à la prochaine session.
- [ ] Restreindre animations à 150–250 ms et sous-vue du niveau audio ; utiliser couleurs sémantiques et Liquid Glass natif, avec adaptations aux préférences d'accessibilité.
- [ ] Vérifier en simulateur les états prêt, préparation, capture simulée, pause, erreur et modèle absent hors ligne ; vérifier grande police, mode sombre et libellés VoiceOver. Ces captures utilisent un faux service et ne prouvent pas la reconnaissance réelle.
- [ ] Exécuter CI et enregistrer les observations de rendu dans docs/design.md ; corriger les écarts gênant lecture ou actions.
- [ ] Commit : feat: add minimal transcription and settings screens.

## Tâche 6 — Historique et détail
**Fichiers :** HistoryView.swift, TranscriptDetailView.swift, RootView.swift ; LivecriptTests/HistoryTests.swift.
**Interfaces :** consomme TranscriptSnapshot et les opérations TranscriptStore. Après mutation, rafraîchir les snapshots ; la session active conserve son identité.

- [ ] Écrire test : historyNewestFirst attend les dates décroissantes ; renamePersistsAcrossReload conserve le texte et change seulement titre/date de modification ; deleteRemovesOnlySelectedTranscript préserve les autres identifiants.
- [ ] Constater les échecs, puis brancher liste, état vide, détail sélectionnable, renommage non vide et suppression confirmée sur le store.
- [ ] Ajouter copier/partager au détail et gérer les erreurs de stockage avec possibilité de réessayer, sans disparition silencieuse des données.
- [ ] Exécuter tests et parcours sauvegarder → historique → renommer → relancer → partager → supprimer ; vérifier une seule entrée après taps répétés sur Enregistrer.
- [ ] Commit : feat: browse rename and share saved transcripts.

## Tâche 7 — IPA et source SideStore
**Fichiers :** scripts/package_ipa.py, scripts/generate_source.py, scripts/tests/test_distribution.py, .github/workflows/release.yml, distribution/source.json, distribution/icon.png, README.md.
**Interfaces :** package_ipa(app_path: Path, output: Path) -> None ; generate_source(previous: dict, ipa: Path, version: str, date: str, download_url: str, icon_url: str) -> dict. CLI python3 scripts/package_ipa.py --app ... --output ... ; python3 scripts/generate_source.py --previous ... --ipa ... --version ... --date ... --download-url ... --icon-url ... --output ....
Catalogue initial : aucune version installable avant le premier IPA réel.

- [ ] Vérifier le schéma source actuel dans la documentation officielle SideStore/AltStore ; vérifier en particulier versions, permissions et URLs d'icône.
- [ ] Écrire tests : missingAppRejected, archiveContainsPayloadAndBundle, byteSizeMatchesArtifact, repeatedVersionIsIdempotent, olderVersionsPreserved, invalidIPARejected et failedAssetUploadDoesNotPublishCatalogue (simulation du workflow).
- [ ] Exécuter python3 -m unittest discover -s scripts/tests ; constater les échecs puis implémenter empaquetage et génération à partir d'un véritable bundle compilé avec Info.plist et exécutable.
- [ ] Créer release.yml : déclenchement manuel avec version explicite, sérialisation des publications, tests et build macOS, version bundle cohérente, génération IPA, calcul SHA-256 et upload en release brouillon.
- [ ] Après réussite des uploads, publier la release puis mettre à jour distribution/source.json sur main. En cas d'échec, garder la source précédente ; aucune URL privée ou artefact temporaire Actions dans le catalogue.
- [ ] Utiliser comme URL stable https://raw.githubusercontent.com/Leboxis/Livecript/main/distribution/source.json ; référencer les IPA par URL GitHub Release versionnée, jamais un lien expirant.
- [ ] Exécuter le workflow 1.0.0 une fois l'implémentation vérifiée ; contrôler le run, télécharger l'IPA, inspecter Payload, bundle ID, minimum iOS et version ; comparer taille et SHA-256.
- [ ] Vérifier que source, icône et IPA sont récupérables publiquement ; documenter signature SideStore et import LiveContainer. Ne pas réclamer de certificat Apple pour une archive destinée à être resignée.
- [ ] Commit : feat: distribute compiled IPA through a versioned SideStore source.

## Tâche 8 — Validation finale et remise
**Fichiers :** README.md, docs/device-validation.md, docs/design.md ; corrections ciblées si un test échoue.
**Interfaces :** consomme tous les livrables, sans nouvelle fonctionnalité.

- [ ] Exécuter scripts/ci-test.sh, build appareil et tests Python depuis le commit à livrer ; conserver run URL, commit, version et résultats.
- [ ] Sur iPhone accessible, exécuter les parcours de la spécification : permissions, modèles, mode avion dans les deux modes, vocabulaire, pause/reprise, interruption, récupération, historique, partage et installation/mise à jour SideStore puis LiveContainer.
- [ ] Sur appareil ProMotion accessible, observer la capture et le défilement ; profiler les blocages si nécessaire. Documenter appareil, iOS, hôte et résultats ; ne pas affirmer 120 Hz sur la seule base du code.
- [ ] Si aucun appareil n'est disponible, indiquer chaque essai comme non exécuté dans docs/device-validation.md et fournir les étapes reproductibles. Ne pas simuler un succès LiveContainer.
- [ ] Relire les changements, corriger les défauts bloquants et refaire uniquement les vérifications concernées ; appliquer le workflow de revue choisi.
- [ ] Commit : docs: record release verification and installation guide.
- [ ] Remettre les liens du dépôt, Figma, IPA et source JSON, avec une synthèse factuelle des tests et limites restantes.

## Relecture du plan
Couverture : trois onglets, deux modules locaux, vocabulaire, récupération, accessibilité, Figma, build, IPA et source sont attribués ci-dessus.
Les signatures applicatives sont définies ici ; les signatures Apple doivent être vérifiées contre le SDK avant leur utilisation. Aucun accès appareil n'est présumé.
Mode d'exécution recommandé : natif, dans cette session, car audio, session et stockage dépendent étroitement des mêmes invariants ; revue finale selon le workflow.
