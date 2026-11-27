/// CSV layouts are verified against each app's own export implementation:
/// openGym: frontend/src/lib/export-csv.js
/// LiftLog: app/src/store/settings/export-plaintext-effects.ts
/// Fast N Fitness: app/src/main/java/com/easyfitness/DAO/export/CVSManager.java
enum ExternalWorkoutFormat { openGym, liftLog, fastNFitness }
