# 0.2.0 / Android code 3 — 2026-10-24

- Open mineral valley battlefield; full-width map, compact Greek HUD and contextual build button.
- Original layered vector structures and animated insect legs, turret aim/recoil/flash, hit/death/build/core effects.
- Read-only animation adapter; deterministic combat and all original gameplay data preserved.
- Required CI screenshots/video before APK export; design branch preview-only gate.
- Temporary per-run debug signing remains: uninstall previous debug version may be required. Physical Android performance/install not verified.

# Changelog

## 0.1.1 (build 2) — 2026-10-24

- Η εικαστική ανανέωση κυκλοφορεί ως διακριτή Android έκδοση, μετά από αποτυχημένη ενημέρωση λόγω διαφορετικής προσωρινής υπογραφής CI.
- Το package id παραμένει `org.pulsegame.prototype`. Δεν αποθηκεύεται ακόμη πρόοδος παιχνιδιού.
- Για μετάβαση από το παλιό APK απαιτείται απεγκατάσταση του προηγούμενου debug build, επειδή το αρχικό προσωρινό ιδιωτικό κλειδί δεν διατηρήθηκε.
- Τα επόμενα αυτόματα debug builds εξακολουθούν να χρειάζονται σταθερό κλειδί στο GitHub Actions για ενημέρωση χωρίς απεγκατάσταση.

## 2026-10-23 — εικαστική ανανέωση πρωτοτύπου

- Αντικαταστάθηκε το διαγνωστικό grid με εικονογραφημένο περιβάλλον «Θερμικού Περάσματος».
- Η διαδρομή έγινε πλακόστρωτη με φωτεινό ενεργειακό πυρήνα και καθαρά σημεία εισόδου/εξόδου.
- Οι θέσεις κατασκευής, ο Ταχυβόλος και ο εχθρός απέκτησαν πρωτότυπη εικονογράφηση.
- Εναρμονίστηκε η παλέτα του HUD με το νέο περιβάλλον· οι κανόνες μάχης δεν άλλαξαν.
- Προστέθηκε προαιρετική λήψη screenshot από το CI για οπτική επιθεώρηση.

## 2026-10-23 — διόρθωση στόχευσης

- Η στόχευση εντός εμβέλειας υπολογίζει τη θέση του εχθρού από τη διαδρομή· ο εχθρός είναι λογική οντότητα και δεν έχει ιδιότητα θέσης σκηνής.
- Προστέθηκαν έλεγχοι επιλογής στόχου εντός και εκτός εμβέλειας.
- Το Android workflow διατηρεί πλέον τα logs όταν αποτυγχάνει η εξαγωγή APK.
- Ενεργοποιήθηκε η εισαγωγή ETC2/ASTC που απαιτεί το Godot για Android export.
- Το CI επαληθεύει την υπογραφή, το package/version, την απουσία INTERNET permission και το SHA-256 του APK.
- Διορθώθηκε ο προσανατολισμός Android σε landscape και προστέθηκε έλεγχος manifest.

## 0.1.0 — θεμελίωση playable πρωτοτύπου

- Δημιουργήθηκε Godot project για οριζόντιο Android UI και offline runtime.
- Προστέθηκαν διαχωρισμένα δεδομένα, simulation, combat/economy helpers, visual board και touch HUD.
- Προστέθηκε πρώτη πίστα με 28 θέσεις, έναν ενεργό Ταχυβόλο και ένα δοκιμαστικό κύμα.
- Προστέθηκαν headless έλεγχοι και GitHub Actions workflow για δοκιμές και debug APK.
- Οι αριθμητικές τιμές παραμένουν προσχέδιο· βλ. `BALANCE.md`.
