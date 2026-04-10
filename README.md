# Q_166_Q_04454
Micron GitHub Environment

## `%ars_ancova_make_output_subgrp` usage guide

This macro builds report-ready ANCOVA subgroup rows (`col0`, `col1`, `col2`) from the normalized ARS results dataset.

### 1) Include the macro source

```sas
%include "ars_ancova_make_output_subgrp.sas";
```

### 2) Minimal call (single parameter / single subgroup analysis)

```sas
%ars_ancova_make_output_subgrp(
    arsds=work.ars_results_long_sex,
    out=work.page_subgrp,
    subgroup_label=Sex,
    test_value=AON-D21,
    ref_value=Placebo,
    paramcd=MCHGSF7,
    display_id=T_SF_RATIO
);
```

### 3) Recommended call for readable subgroup labels + custom text

If subgroup values are coded (for example `F`, `M`), create a format and pass it in `subgroup_fmt`.

```sas
proc format;
    value $sexfmt
        'F'='Female'
        'M'='Male';
run;

%ars_ancova_make_output_subgrp(
    arsds=work.ars_results_long_sex,
    out=work.page_subgrp,
    subgroup_label=Sex,
    subgroup_fmt=$sexfmt.,
    subgroup_title_prefix=Subgroup,
    interaction_label=Treatment-by-Sex Interaction p-value,
    test_value=AON-D21,
    ref_value=Placebo,
    paramcd=MCHGSF7,
    display_id=T_SF_RATIO
);
```

### 4) Build one big table for all variables by subgroup

Leave `paramcd=` and `param=` blank so all parameters in `arsds` are included.

```sas
%ars_ancova_make_output_subgrp(
    arsds=work.ars_results_long_sex,
    out=work.page_subgrp_all_vars,
    subgroup_label=Sex,
    subgroup_fmt=$sexfmt.,
    test_value=AON-D21,
    ref_value=Placebo,
    display_id=T_SF_RATIO
);
```

Output structure now includes, for each variable:
- `Variable: <parameter>` subtitle row
- `Subgroup: <subgroup label>` row
- `Treatment-by-Subgroup Interaction p-value` row
- then each subgroup block (`Sex: Female`, `Sex: Male`, etc.)

### 5) Send output to TXT/RTF report

```sas
%ars_ancova_report_output_to_txt(
    dsin=work.page_subgrp_all_vars,
    outd=&outdir,
    outf=&outfile,
    col0txt=
);
```

### Notes
- `arsds=` must be the long-form analysis result dataset produced by `%ars_ancova_production_analysis`.
- Interaction p-value is sourced from `operation_id='OP_SUBGRP_INTERACT'` and `operation_role='PVALUE'`.
- `mockshell=Y` replaces numeric values with placeholders for shell/mock outputs.

## `%ars_tte_production_analysis` + `%ars_tte_make_output` usage guide

These macros provide a time-to-event companion flow aligned to the same ARS canonical pattern used for the ANCOVA/MIXED wrappers:

1. `%ars_tte_production_analysis` runs:
   - `PROC LIFETEST` for Kaplan-Meier statistics (median, CI, and cumulative incidence at a selected day), and
   - `PROC PHREG` for Cox proportional hazards (HR, 95% CI, p-value),
   then normalizes all values into one ARS-style long dataset.

2. `%ars_tte_make_output` reshapes that normalized dataset into report-ready `col0/col1/col2` rows matching the shell layout pattern.

### Example

```sas
%include "ars_tte_production_analysis.sas";
%include "ars_tte_make_output.sas";

%ars_tte_production_analysis(
    adam=derived.adtte(where=(PARAMCD='TTRS' and MITTFL='Y')),
    out=work.ars_tte_long,
    trt_var=TRT01A,
    time_var=AVAL,
    censor_var=CNSR,
    censor_value=0,
    km_timepoint=28,
    test_value=AON-D21,
    ref_value=Placebo,
    display_id=T_TTRS
);

%ars_tte_make_output(
    arsds=work.ars_tte_long,
    out=work.page_tte,
    test_value=AON-D21,
    ref_value=Placebo,
    test_hdr=AON-D21,
    ref_hdr=Placebo,
    day_label=28,
    display_id=T_TTRS,
    strict_param=N,
    mockshell=N
);
```

### Key operation IDs emitted by `%ars_tte_production_analysis`

- `OP_TTE_DESC`: `N`, `MEAN`, `SD`, `MEDIAN`, `MIN`, `MAX` by treatment.
- `OP_TTE_KM_CINC`: cumulative incidence (`PCT`) at `KM_TIMEPOINT`.
- `OP_TTE_CENSOR`: censored count and percent (`N_CENS`, `PCT_CENS`) by treatment.
- `OP_TTE_KM_MEDIAN`: Kaplan-Meier median + CI (`ESTIMATE`, `LCL`, `UCL`).
- `OP_TTE_COX_HR`: Cox hazard ratio + CI + p-value (`ESTIMATE`, `LCL`, `UCL`, `PVALUE`).

`%ars_tte_make_output` note:
- By default (`strict_param=N`), when `paramcd=` is supplied the macro does **not** hard-filter on `param=` label text.
  This avoids accidental row loss when endpoint label wording differs slightly between ADTTE and driver text.
- `censor_value=` should match your ADTTE coding of the censored state. Current examples assume `CNSR=0` means censored.

### Driver template

- See `ars_tte_main_driver.sas` for an end-to-end outline analogous to the continuous ANCOVA driver pattern:
  1. `%ars_tte_production_analysis`
  2. `%ars_tte_make_output`
  3. `%ars_ancova_report_output_to_txt`

## Binary endpoint (Fisher's exact) wrappers

Added companion wrappers following the same 3-step ARS pattern:

1. `%ars_binary_production_analysis`
   - Runs `PROC FREQ` with Fisher's exact test.
   - Normalizes counts/percentages by treatment and odds ratio outputs into ARS-like long rows.

2. `%ars_binary_make_output`
   - Converts normalized binary rows into report-ready `col0/col1/col2` shell rows.
   - By default (`strict_param=N`), ignores exact `param=` label matching when `paramcd=` is supplied.

3. `%ars_binary_report_output_to_txt`
   - Thin wrapper around `%ars_ancova_report_output_to_txt` for binary outputs.

- See `ars_binary_main_driver.sas` for an end-to-end binary driver outline analogous to the continuous/TTE wrappers.
