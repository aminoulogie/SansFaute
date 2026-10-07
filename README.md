# SansFaute

App iOS de préparation au **TCF Tout public**, pour passer du C1 au C2 en une heure par jour, jusqu'au 9 novembre.

Point de départ : oral 487 (B2), structures 518 (C1), écrit 555 (C1), global 520 (C1).
Priorité : faire passer l'oral au-dessus de 500 et monter les structures.

## Ce qu'il y a dedans

| Onglet | Contenu |
|---|---|
| Aujourd'hui | Compte à rebours, tâches du jour (programme de 33 jours), objectifs par compétence, série de jours |
| Écoute | 18 documents B2 à C2 lus par la voix française de l'iPhone, mode entraînement ou mode examen (une seule écoute), transcription, réglage de vitesse |
| Grammaire | 15 leçons sur les pièges du TCF (subjonctif, concordance, relatifs composés, accords, connecteurs, paronymes, registres, temps littéraires) et 125 exercices corrigés |
| Mots | 180 cartes C1 et C2 avec répétition espacée (connecteurs, verbes soutenus, expressions, vocabulaire académique, génie civil, presse, paronymes) |
| Tests | Test du jour (même test toute la journée, orienté sur tes erreurs), test blanc chronométré, série d'écoute, révision des erreurs, 8 textes de compréhension écrite, courbe de progression |

Tous les textes et questions sont originaux. Les scores affichés sont des estimations indicatives sur 699, pas des scores officiels.

## Obtenir le fichier .ipa

1. Pousse ce dossier dans le dépôt `aminoulogie/SansFaute` (branche `main`).
2. GitHub Actions lance **Build IPA** automatiquement (onglet *Actions*). Compte environ 5 minutes.
3. Le fichier `SansFaute.ipa` est disponible dans l'onglet **Releases** et en artefact du workflow.

Tu peux aussi relancer le build à la main : *Actions › Build IPA › Run workflow*.

## Installer sur l'iPhone

L'IPA n'est pas signée. Un outil de sideloading la signe avec ton identifiant Apple :

- **Sideloadly** (Windows ou Mac) : glisse l'IPA, entre ton Apple ID, clique *Start*.
- **AltStore** ou **SideStore** : *My Apps › +*, choisis l'IPA.

Avec un compte Apple gratuit, l'app doit être re-signée tous les 7 jours (AltStore le fait automatiquement).

## Pour une meilleure voix

Réglages iPhone › Accessibilité › Contenu énoncé › Voix › Français (France), puis télécharge une voix « améliorée » ou « premium ». L'app la choisit automatiquement.

## Structure

```
project.yml                    projet Xcode (généré par XcodeGen dans le CI)
SansFaute/App                  point d'entrée et onglets
SansFaute/Models               modèles de contenu et de progression
SansFaute/Store                chargement du contenu, sauvegarde, synthèse vocale
SansFaute/Views                écrans
SansFaute/Resources/*.json     tout le contenu pédagogique
scripts/validate_content.py    vérifie le contenu avant chaque build
.github/workflows/build-ipa.yml
```

Pour ajouter des questions, édite les fichiers JSON dans `SansFaute/Resources` et pousse : le CI vérifie le contenu puis reconstruit l'IPA.
