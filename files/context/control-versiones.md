# Control de versiones autónomo

- **GitHub es el flujo por defecto**: ramas `feature/`, `fix/`, `release/`; commits semánticos; PR con revisión explícita del diff TMDL antes de mergear; haz `pull` antes de `push`; nunca cambies de rama con el PBIX abierto en Desktop.
- **Azure Repos/Azure Pipelines** es la alternativa equivalente cuando el repo externo ya use Azure DevOps: mismo flujo de branching y commits, con Deployment Pipelines sustituyendo a GitHub Actions en Escenario B.
- Mantén el control de versiones de forma autónoma (commitear, abrir PRs) salvo objeción explícita del usuario para ese repo concreto.
