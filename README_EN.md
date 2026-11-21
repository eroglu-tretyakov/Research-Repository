# MATLAB Reproducibility Package

## User Guide and Technical Description

### 1. Purpose and scope

`run_Mathematics_R14_Manuscript.m` is a single-file, Excel-driven MATLAB
application developed to reproduce the numerical analyses, tables, and
figures associated with **"Segmented Bezier Representation of Solar Wind
Speed and a Local Activity Index."**

The program prompts the user to select six solar-wind speed series (Sets
N, A, M, and Sets 1--3) and four 3-hour Kp workbooks (Sets M and 1--3).
It performs segmented Bézier fitting, classical interpolation,
continuity assessment, Local Activity Index (LAI) calculation,
sensitivity and uncertainty analyses, adaptive segmentation,
Gaussian-process (GP) comparison, and Kp--LAI association analyses.

**Scope limitation:** This version is configured for the six datasets,
record counts, and date mappings used in the R14 manuscript. Other
record lengths or date ranges require modification of the expected row
counts and, where applicable, the start-time mapping in the source code.
This is not a fully generic application that automatically adapts to
arbitrary series lengths.

### 2. Software requirements

-   MATLAB R2020a or later.
-   No specialized MATLAB toolbox is specified as a requirement in the
    source code. The GP optimizer is implemented within the script.
-   No external Python, NumPy, SciPy, or third-party MATLAB package is
    called.
-   Input workbooks must be `.xlsx` or `.xls`.
-   The output directory must allow file creation.

**Filename requirement:** The primary MATLAB function is named
`run_Mathematics_R14_Manuscript`; therefore, the file must be named
exactly `run_Mathematics_R14_Manuscript.m`. A suffix such as `(2)` added
during download should be removed. This package includes the unchanged
source under the canonical MATLAB filename.

### 3. Input files

The program uses file-selection dialogs rather than hard-coded input
paths. The user selects each workbook and, where required, its worksheet
and measurement column.

#### 3.1. Solar-wind speed workbooks

Select these six workbooks in order:

  -------------------------------------------------------------------------
                 Order Dataset                     Expected Time handling
                                               observations 
  -------------------- --------------- -------------------- ---------------
                     1 Set N                           2706 Original
                                                            observation
                                                            order; original
                                                            timestamp
                                                            mapping is not
                                                            available in
                                                            the program.

                     2 Set A                           2706 Original
                                                            observation
                                                            order; original
                                                            timestamp
                                                            mapping is not
                                                            available in
                                                            the program.

                     3 Set M                           2706 Consecutive
                                                            hourly UTC; if
                                                            no time column
                                                            exists, 1 Jan
                                                            2026 00:00 UTC
                                                            is assumed.

                     4 Set 1                           2880 Consecutive
                                                            hourly UTC; if
                                                            no time column
                                                            exists, 1 Jan
                                                            2017 00:00 UTC
                                                            is assumed.

                     5 Set 2                           2952 Consecutive
                                                            hourly UTC; if
                                                            no time column
                                                            exists, 1 May
                                                            2017 00:00 UTC
                                                            is assumed.

                     6 Set 3                           2928 Consecutive
                                                            hourly UTC; if
                                                            no time column
                                                            exists, 1 Sep
                                                            2017 00:00 UTC
                                                            is assumed.
  -------------------------------------------------------------------------

The program checks these record counts. Rows containing missing
measurements must not be deleted; retain them in their original
positions as blank cells, `NaN`, or a declared fill value. The
measurement column is identified, where possible, from the Set name or
names such as `speed`, `v_kms`, or `v`. If multiple numeric candidates
are found, the user is prompted to select the correct column.

#### 3.2. Time column

For Sets M and 1--3, a single UTC timestamp column is recommended.
Suggested formats are `yyyy-MM-dd HH:mm:ss` and
`yyyy-MM-dd'T'HH:mm:ss'Z'`. The column name may contain `timestamp_utc`,
`start_utc`, `datetime`, or a similar term. When a time column is
supplied, records must be consecutive hourly observations; otherwise,
the program stops. If no time column is supplied, the program constructs
timestamps from the nominal start dates in the table above. Actual
source timestamps should be supplied whenever available.

For Sets N and A, no original timestamp mapping is used. These series
are analyzed in observation order and displayed using a zero-based
observation index. Unverified timestamps should not be assigned to these
sets.

#### 3.3. Missing-value codes

At startup, additional numeric missing-value codes may be entered as
comma-separated values. `9999` is always treated as missing. Example:
`-999, -9999, 999.9`. Leave the field blank if no additional codes are
used. Blank cells and nonnumeric measurement entries are also treated as
invalid/missing. Missing observations are not automatically
interpolated.

#### 3.4. Kp workbooks

Select four Kp workbooks in this order: Set M, Set 1, Set 2, and Set 3.
No Kp workbook is requested for Sets N and A. Each Kp worksheet must
contain a Kp measurement column and UTC time information.

Two layouts are accepted: 1. Each 3-hour Kp value is repeated across
three consecutive hourly rows. The program verifies each triplet and
retains its first row. 2. Direct 3-hour records, with timestamps exactly
three hours apart.

  Dataset     Hourly-row layout   Direct 3-hour records
  --------- ------------------- -----------------------
  Set M                    2706                     902
  Set 1                    2880                     960
  Set 2                    2952                     984
  Set 3                    2928                     976

Kp timestamps must mark interval starts at 00, 03, 06, ..., 21 UTC. Kp
values must be in the 0--9 range. If the source stores tenths (e.g., 30
for 3.0), values are divided by 10 when the maximum exceeds 9, followed
by a range check.

### 4. Running the program

1.  Save `run_Mathematics_R14_Manuscript.m` in a MATLAB-accessible
    directory and set it as the **Current Folder**.

2.  Run:

    ``` matlab
    run_Mathematics_R14_Manuscript
    ```

3.  Enter additional missing-value codes or leave the field blank.

4.  Select the Set N, A, M, 1, 2, and 3 workbooks in order.

5.  Select the correct worksheet and speed column in each workbook.

6.  Select the Kp workbooks for Sets M, 1, 2, and 3.

7.  Select the output directory and analysis profile.

#### 4.1. Analysis profiles

**Full manuscript run** is required for final manuscript results. It
runs the GP/adaptive analysis, the classical-method moving-block
bootstrap with 5000 replicates, the Bézier perturbation analysis with
1000 realizations, and the Kp bootstrap with 5000 replicates.

**Fast preview** is intended for preliminary input/code checks and rapid
inspection. It skips GP and extended stochastic analyses and reduces Kp
bootstrap replicates to 300. Excel sheets for skipped analyses may
contain `Not calculated in this run.` **Fast-preview results must not be
used as final manuscript tables.**

### 5. Methods implemented

#### 5.1. Bézier and classical interpolation

The baseline uses windows of eight hourly intervals (nine observations);
adjacent windows share one endpoint. Windows containing missing values
are excluded from window-based analyses. Bézier curves of degrees 2--6
are fitted with fixed endpoints and least-squares estimation of interior
control points.

Classical methods are linear interpolation, cubic spline,
shape-preserving cubic Hermite interpolation based on PCHIP (labelled
Hermite/PCHIP in the code), and Lagrange interpolation. The classical
support nodes are `0, 3, 5, 8`; endpoint values are fixed to the
observed endpoints.

#### 5.2. Held-out evaluation and metrics

For each valid window, endpoints are retained and each interior
observation is withheld in turn and reconstructed. The program
calculates sample count, RMSE, MAE, MAPE, and R².

#### 5.3. Continuity

First-derivative jumps at shared Bézier knots are calculated. An
endpoint-interpolating C1 cubic Hermite model is also constructed by
jointly estimating shared knot slopes through least squares across
contiguous valid windows.

#### 5.4. Local Activity Index

LAI is calculated only for Sets M and 1--3 using non-overlapping blocks
of eight observations. Its four components are standard deviation (STD),
range, mean absolute successive difference (MASD), and maximum absolute
successive difference (MaxAD). Component scores use the 25th, 50th, and
75th percentiles; LAI is the mean of the four scores. Class boundaries
are 0.75, 1.50, and 2.25. The code also calculates
component-weight/threshold sensitivity, Pearson/Spearman correlations,
and PC1 weights.

#### 5.5. Adaptive segmentation and GP

In the full run, each series is evaluated in 24-hour/24-interval blocks.
The fixed cubic knots are 0, 8, 16, and 24. The adaptive method searches
permitted interior knot locations to minimize training error.

The GP uses a squared-exponential covariance function, the training-data
mean, and scaling by the training-data population standard deviation.
Hyperparameters are optimized using a bounded, multi-start BFGS method
with an analytic gradient implemented in the code. Bounds are 0.1--10
for signal standard deviation, 0.5--24 for length scale, and 0.001--1
for noise standard deviation. Convergence and fallback diagnostics are
written to `GP_Optimizer_Diagnostics`.

#### 5.6. Bootstrap, perturbation, and Kp--LAI association

In the full run, the classical-method moving-block bootstrap uses 5000
replicates (seed `4691220`). Bézier perturbations use 1000 realizations
at 1%, 3%, and 5% relative standard-deviation levels (seed `4691221`).
The Kp bootstrap seed is `4691222`.

Kp records are matched to eight-hour LAI blocks using temporal overlap.
The time-overlap-weighted mean Kp and maximum Kp are calculated for each
block. Spearman associations and moving-block bootstrap confidence
intervals using 24-hour and 72-hour block lengths are obtained. This
analysis is performed for Sets M and 1--3.

#### 5.7. Runtime measurement

Each method is run three times for warm-up, followed by 21 timed
repetitions. Median runtime and the 25th--75th percentiles are reported.
Runtime depends on hardware, operating system, and MATLAB version and
should not be interpreted as an absolute cross-computer speed
comparison.

### 6. Output files

The selected output directory contains:

  -----------------------------------------------------------------------------------------
  File/folder                                           Contents
  ----------------------------------------------------- -----------------------------------
  `SolarWindSpeed_Bezier_LAI_Manuscript_Results.xlsx`   Main-text and appendix result
                                                        tables, diagnostics, and validation
                                                        tables

  `Figures/`                                            Figures 1--15 and A1--A12, each as
                                                        600-dpi PNG and vector PDF

  `Figure_Index.csv`                                    Figure IDs, descriptions, and
                                                        filenames

  `Kp_3h_Combined.csv`                                  Combined 3-hour Kp records from the
                                                        four selected workbooks, sorted by
                                                        UTC

  `RUN_SUMMARY.txt`                                     MATLAB version, computer
                                                        architecture, run time, input
                                                        files, record/missing counts, and
                                                        analysis profile
  -----------------------------------------------------------------------------------------

The workbook contains `Table_01`--`Table_19`, `Table_11a`--`Table_11c`,
appendix sheets `Table_A1`--`Table_A11` (including the `A5a/A5b`,
`A8a/A8b`, and `A9a/A9b` subdivisions), `Calibration_Offset_Check`, and
`GP_Optimizer_Diagnostics`. `Table_20_Manual` contains only a note that
Table 20 is a manually curated literature comparison; the literature
values are not generated by the program. This version generates **Figure
A12** but does not generate a **Table A12** sheet. GP diagnostics are
provided in `GP_Optimizer_Diagnostics`. Skipped analyses in fast-preview
mode may be marked `Not calculated in this run.`

### 7. Quality control and limitations

-   Check record counts, missing-value counts, source filenames,
    worksheet names, and selected measurement columns in
    `RUN_SUMMARY.txt`.
-   Verify hourly continuity for Sets M and 1--3 and 3-hour UTC starts
    for Kp records.
-   Use `Full manuscript run` for final tables.
-   Review convergence and fallback counts in `GP_Optimizer_Diagnostics`
    when interpreting GP results.
-   Sets N and A are analyzed in observation order because their
    original timestamp mapping is not available in the program.
-   Missing observations are not interpolated; windows containing
    missing values are excluded.
-   LAI and Kp--LAI analyses are restricted to Sets M and 1--3.
-   Table A7 storage values are analytical estimates derived from stored
    scalar-parameter counts; they are not measured RAM or peak process
    memory.
-   Runtime values depend on the execution environment.
-   The program does not independently verify the provenance of input
    workbooks. Data-provider citations must be supplied according to the
    actual sources used.