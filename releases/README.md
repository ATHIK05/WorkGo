# WorkGo Application Releases & Version History

This directory documents release versions and distribution channels for the **WorkGo Customer** and **WorkGo Karya (Worker)** mobile applications.

---

## 📦 How Automated Versioning Works

Every time code is pushed to the `main` branch:
1. **GitHub Actions CI/CD** triggers `.github/workflows/build_apk_release.yml`.
2. It compiles release APKs using Flutter & Java 17 for both apps.
3. It assigns an incremental version tag: `v1.0.<build_number>` (e.g., `v1.0.1`, `v1.0.2`, `v1.0.3`...).
4. The APKs are published under **[GitHub Releases](https://github.com/ATHIK05/WorkGo/releases)**:
   - `WorkGo-Customer-v1.0.X.apk` (Customer App)
   - `WorkGo-Karya-v1.0.X.apk` (Artisan/Worker App)

> **Why GitHub Releases instead of committing .apk files into git tree?**  
> APK binaries are 40MB–60MB each. Committing raw APKs into git folders on every commit would inflate the `.git` database by several gigabytes in weeks, hitting GitHub's 2GB repository limit and causing `git clone` to fail or slow down. **GitHub Releases** provides unlimited high-speed binary distribution with full version history, direct download links, and changelogs.

---

## 📱 Quick Download Links

| Version | Target App | Direct Link |
| :--- | :--- | :--- |
| **Latest Release** | Customer & Karya | [Download Latest APKs](https://github.com/ATHIK05/WorkGo/releases/latest) |
| **All Releases** | Complete Version History | [View All Versions](https://github.com/ATHIK05/WorkGo/releases) |
