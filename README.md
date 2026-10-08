# Livecript

Application SwiftUI pour iOS 26 : votre voix devient du texte, sur votre appareil.

- Microphone, transcription en direct, pause et reprise.
- Texte copiable et partageable ; historique local renommable.
- Mode Standard (SpeechTranscriber) et Vocabulaire personnalisé (DictationTranscriber).
- Thèmes système, clair et sombre, contrôles Liquid Glass natifs.

## Installation

L'IPA compilé sera attaché à la [release](https://github.com/Leboxis/Livecript/releases). La première publication dépend d'un build et de tests réussis. Les sources Swift ne constituent pas un IPA.

Source à ajouter dans SideStore après publication :

```
https://raw.githubusercontent.com/Leboxis/Livecript/main/distribution/source.json
```

SideStore signe l'IPA pour votre appareil. Dans LiveContainer, importer l'IPA depuis Fichiers. La compatibilité des permissions et des services Speech de l'hôte reste à vérifier sur appareil ; voir [validation](docs/device-validation.md).

Le téléchargement initial d'un modèle Apple peut nécessiter Internet. Ensuite, la transcription fonctionne localement pour les langues et appareils compatibles. L'application ne sauvegarde pas l'audio. Les termes personnalisés favorisent la reconnaissance sans garantir chaque orthographe.

## Développement

Ouvrir `Livecript.xcodeproj` avec Xcode 26 ou ultérieur, schéma `Livecript`. iOS minimum : 26.0. Aucune clé API de transcription.

```
bash scripts/ci-test.sh
python3 -m unittest discover -s scripts/tests
```

`python3 scripts/generate_project.py` régénère le projet si des fichiers Swift sont ajoutés. La génération est déterministe. Les préférences, transcriptions et vocabulaire sont conservés localement ; aucune intégration CloudKit.

## Versions

Le workflow `Release IPA` construit l'application, produit l'IPA, publie une release et met à jour la source à partir de l'artefact téléchargé et vérifié. Pour les versions suivantes, utiliser le déclenchement manuel avec une nouvelle version MAJOR.MINOR.PATCH. Une version publique n'est pas écrasée.

[Maquettes Figma](https://www.figma.com/design/bEaKMUIu7sS8rivnrs0t5H?node-id=3-10) · [Spécification](docs/superpowers/specs/2026-10-08-livecript-design.md)
