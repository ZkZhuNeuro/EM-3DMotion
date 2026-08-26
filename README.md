# EM-3DMotion
Electrical stimulation in MT and FST to study 3D motion perception

## Output location

Keep this repository focused on source code and lightweight documentation.
Generated figures, tables, MAT files, reports, caches, and other analysis
artifacts should be written under `C:\EM`, normally preserving the analysis
area (for example, `C:\EM\PopulationAnalysis` or `C:\EM\CurrentSpread`).

New analysis functions should default to a `C:\EM` output path while still
accepting an explicit output-folder override when practical. Tests should use
temporary directories rather than repository-local `output`, `results`, or
`tmp` folders.
