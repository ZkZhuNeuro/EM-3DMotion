# Repository output policy

- Keep this repository focused on source code and lightweight documentation.
- Write generated figures, MAT files, tables, reports, caches, and other
  analysis artifacts under `C:\EM`, preserving the analysis area when useful.
- Do not default new code to repository-local `output`, `outputs`, `results`,
  or `tmp` directories.
- Give analysis functions an explicit output-path override when practical;
  their default should remain outside the repository.
- Use a temporary directory for automated tests and smoke runs.
- Before a long run, verify that its resolved output path is not inside this
  repository.
- Do not relocate committed input or reference data without checking all code
  dependencies first.
